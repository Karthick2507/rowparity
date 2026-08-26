"""Live progress reporting and per-step timing.

These exist because the failure they prevent is not a wrong answer but an
unusable one: a case running two multi-minute warehouse queries printed nothing
until both finished, so a working run and a hung run looked identical from the
terminal. The only way to tell them apart was to open the cluster's web UI.
"""
import io
import re
import time

import pytest

from rowparity import progress
from rowparity.cases import Case
from rowparity.report import render_console, to_dict


@pytest.fixture(autouse=True)
def isolated_progress():
    """Progress is global state; give every test its own stream and reset after."""
    stream = io.StringIO()
    progress.configure(enabled=True, stream=stream, heartbeat_seconds=0)
    yield stream
    progress.configure(enabled=False, stream=io.StringIO(), heartbeat_seconds=progress.DEFAULT_HEARTBEAT_SECONDS)


class TestDisabledByDefault:
    def test_library_use_is_silent(self):
        # Importing rowparity or running it under pytest must not print, and
        # must not start heartbeat threads.
        stream = io.StringIO()
        progress.configure(enabled=False, stream=stream)
        progress.emit("should not appear")
        with progress.step("neither should this"):
            pass
        assert stream.getvalue() == ""
        assert progress.is_enabled() is False


class TestStep:
    def test_announces_before_running_and_reports_after(self, isolated_progress):
        with progress.step("expected  (trino)") as st:
            st.result("87,412 rows x 262 cols")
        start, done = isolated_progress.getvalue().splitlines()
        # The announcement has to come first, or it cannot tell you a slow step
        # is under way -- which is the entire point.
        assert start.lstrip().startswith("-> expected  (trino)")
        assert done.lstrip().startswith("OK expected  (trino)")
        assert "87,412 rows x 262 cols" in done

    def test_completion_line_carries_an_elapsed_time(self, isolated_progress):
        with progress.step("work"):
            time.sleep(0.02)
        assert re.search(r"OK work\s+\d+\.\d+s", isolated_progress.getvalue())

    def test_elapsed_is_readable_after_the_block(self):
        with progress.step("work") as st:
            time.sleep(0.02)
        assert st.elapsed >= 0.02

    def test_failure_is_reported_with_its_duration_and_reraises(self, isolated_progress):
        # "It failed after four minutes" is still worth being told.
        with pytest.raises(ValueError, match="boom"):
            with progress.step("expected  (trino)"):
                raise ValueError("boom")
        out = isolated_progress.getvalue()
        assert "FAILED expected  (trino)" in out
        assert "ValueError: boom" in out
        assert "OK" not in out

    def test_elapsed_is_recorded_even_on_failure(self):
        st_seen = {}
        with pytest.raises(RuntimeError):
            with progress.step("work") as st:
                st_seen["st"] = st
                time.sleep(0.02)
                raise RuntimeError
        assert st_seen["st"].elapsed >= 0.02


class TestHeartbeat:
    def test_it_fires_while_a_step_is_in_flight(self, isolated_progress):
        with progress.step("slow", heartbeat_seconds=0.05):
            time.sleep(0.22)
        assert "still running" in isolated_progress.getvalue()

    def test_it_stops_when_the_step_ends(self, isolated_progress):
        with progress.step("slow", heartbeat_seconds=0.05):
            time.sleep(0.15)
        before = isolated_progress.getvalue().count("still running")
        time.sleep(0.2)
        assert isolated_progress.getvalue().count("still running") == before

    def test_zero_disables_it_but_keeps_the_step_lines(self, isolated_progress):
        with progress.step("quick", heartbeat_seconds=0):
            time.sleep(0.12)
        out = isolated_progress.getvalue()
        assert "still running" not in out
        assert "-> quick" in out and "OK quick" in out


class TestFormatting:
    @pytest.mark.parametrize("seconds,expected", [
        (0.0, "0.0s"), (9.25, "9.2s"), (59.9, "59.9s"),
        (60, "1m00s"), (135, "2m15s"), (3600, "1h00m00s"), (3725, "1h02m05s"),
    ])
    def test_durations_read_naturally(self, seconds, expected):
        assert progress.format_duration(seconds) == expected

    def test_describe_table(self):
        import pyarrow as pa

        tbl = pa.table({"a": [1, 2, 3], "b": [4, 5, 6]})
        assert progress.describe_table(tbl) == "3 rows x 2 cols"

    def test_describe_table_never_raises(self):
        # It runs inside the step body; a surprising object must not turn a
        # successful comparison into a crash.
        assert progress.describe_table(object()) == ""


class TestEmitIsNeverFatal:
    def test_a_broken_stream_does_not_fail_the_run(self):
        class Broken(io.StringIO):
            def write(self, _):
                raise OSError("closed pager")

        progress.configure(enabled=True, stream=Broken())
        progress.emit("x")  # must not raise
        with progress.step("x"):
            pass


def _case(**compare):
    rows = [{"id": 1, "v": "a"}, {"id": 2, "v": "b"}]
    return Case(
        name="timed",
        expected={"type": "inline", "rows": rows},
        actual={"type": "inline", "rows": rows},
        compare=compare,
    )


class TestTimingReachesTheResult:
    def test_all_three_phases_are_measured(self):
        result = _case(keys=["id"]).run()
        assert result.expected_load_seconds > 0
        assert result.actual_load_seconds > 0
        assert result.compare_seconds > 0
        assert result.total_seconds == pytest.approx(
            result.expected_load_seconds
            + result.actual_load_seconds
            + result.compare_seconds
        )

    def test_json_carries_the_split_not_just_a_total(self):
        # Split because a slow query and a slow comparison need different
        # fixes: one is the warehouse's problem, the other is ours.
        payload = to_dict(_case(keys=["id"]).run(), "timed")
        timing = payload["timing_seconds"]
        assert set(timing) == {"expected_load", "actual_load", "compare", "total"}
        assert timing["total"] > 0

    def test_console_shows_timing_when_measured(self):
        text = render_console(_case(keys=["id"]).run(), "timed")
        assert "timing:" in text
        assert "expected" in text and "compare" in text

    def test_console_omits_timing_when_not_measured(self):
        # compare_tables() called directly leaves the fields at zero; printing
        # "0.0s" there would look like a measurement rather than its absence.
        import pyarrow as pa

        from rowparity.compare import CompareConfig, compare_tables

        tbl = pa.table({"id": [1]})
        result = compare_tables(tbl, tbl, CompareConfig())
        assert "timing:" not in render_console(result, "direct")
