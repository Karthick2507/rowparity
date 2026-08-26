"""Live progress reporting for long-running steps.

A case that runs two multi-minute warehouse queries printed nothing at all
until both had finished. From the terminal that is indistinguishable from a
hang, and the only way to tell them apart was to open the cluster's web UI and
look for a running query. That is not a reasonable thing to ask of someone
waiting on a verification run.

So each step announces itself before it starts, emits a heartbeat while it
runs, and reports how long it took and what came back::

    Case 'f_demand_portfolio_hourly'
      -> expected  (trino)  running query ...
         ... still running (30s)
         ... still running (60s)
      OK expected  (trino)  71.4s  87,412 rows x 262 cols
      -> actual    (trino)  running query ...
      OK actual    (trino)  68.9s  87,412 rows x 262 cols
      -> comparing 262 columns ...
      OK comparing 262 columns  3.1s

Design notes:

* **Output goes to stderr**, so ``rowparity run > results.txt`` keeps stdout
  clean and parseable while progress still reaches the terminal. Redirect with
  ``2>&1`` to capture both into one log.
* **Every write is flushed.** Without that, a pipe into ``tee`` or a file
  buffers the output and it arrives all at once when the run ends -- which
  defeats the entire purpose.
* **Off by default**, switched on by the CLI. Importing rowparity as a library
  or running it under pytest stays silent, and no heartbeat threads are
  created.
* **The heartbeat is a daemon thread** that only ever writes to the stream. It
  cannot keep the process alive and it cannot fail the run.
"""
from __future__ import annotations

import sys
import threading
import time
from contextlib import contextmanager
from typing import Optional, TextIO

DEFAULT_HEARTBEAT_SECONDS = 30.0

_enabled = False
_stream: TextIO = sys.stderr
_heartbeat_seconds = DEFAULT_HEARTBEAT_SECONDS


def configure(
    enabled: bool,
    stream: Optional[TextIO] = None,
    heartbeat_seconds: Optional[float] = None,
) -> None:
    """Turn progress output on or off. Called by the CLI, not by library users."""
    global _enabled, _stream, _heartbeat_seconds
    _enabled = enabled
    if stream is not None:
        _stream = stream
    if heartbeat_seconds is not None:
        _heartbeat_seconds = max(0.0, heartbeat_seconds)


def is_enabled() -> bool:
    return _enabled


def emit(text: str = "") -> None:
    """Write one line of progress, flushed immediately."""
    if not _enabled:
        return
    try:
        _stream.write(text + "\n")
        _stream.flush()
    except Exception:
        # Progress reporting must never be the reason a run fails. A closed or
        # broken stream (a killed pager, a full disk) is not a comparison error.
        pass


def format_duration(seconds: float) -> str:
    if seconds < 60:
        return f"{seconds:.1f}s"
    minutes, secs = divmod(int(seconds), 60)
    if minutes < 60:
        return f"{minutes}m{secs:02d}s"
    hours, minutes = divmod(minutes, 60)
    return f"{hours}h{minutes:02d}m{secs:02d}s"


class _Heartbeat:
    """Prints '... still running (Ns)' until stopped."""

    def __init__(self, interval: float):
        self._interval = interval
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._started = 0.0

    def start(self) -> None:
        if not _enabled or self._interval <= 0:
            return
        self._started = time.monotonic()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def _run(self) -> None:
        while not self._stop.wait(self._interval):
            elapsed = time.monotonic() - self._started
            emit(f"     ... still running ({format_duration(elapsed)})")

    def stop(self) -> None:
        self._stop.set()
        if self._thread is not None:
            # Nothing to wait for -- the thread is either sleeping on the event
            # (now set) or writing one line. join() with a bound keeps a wedged
            # stream from blocking the run.
            self._thread.join(timeout=1.0)


class Step:
    """One timed step. ``elapsed`` is valid once the context exits."""

    def __init__(self, label: str):
        self.label = label
        self.elapsed = 0.0
        self._summary = ""

    def result(self, summary: str) -> None:
        """Describe what the step produced, shown on the completion line."""
        self._summary = summary

    @property
    def summary(self) -> str:
        return self._summary


@contextmanager
def step(label: str, heartbeat_seconds: Optional[float] = None):
    """Announce a step, time it, and report the outcome.

    Yields a :class:`Step`; call ``.result(...)`` on it to add a summary to the
    completion line. Timing is recorded whether the step succeeds or raises, so
    "it failed after 4 minutes" is still a useful thing to have been told.
    """
    handle = Step(label)
    emit(f"  -> {label} ...")
    beat = _Heartbeat(
        _heartbeat_seconds if heartbeat_seconds is None else heartbeat_seconds
    )
    beat.start()
    started = time.monotonic()
    try:
        yield handle
    except BaseException as exc:
        handle.elapsed = time.monotonic() - started
        beat.stop()
        emit(
            f"  FAILED {label}  {format_duration(handle.elapsed)}  "
            f"{type(exc).__name__}: {exc}"
        )
        raise
    else:
        handle.elapsed = time.monotonic() - started
        beat.stop()
        tail = f"  {handle.summary}" if handle.summary else ""
        emit(f"  OK {label}  {format_duration(handle.elapsed)}{tail}")


def describe_table(table) -> str:
    """'87,412 rows x 262 cols' for a pyarrow.Table, defensively."""
    try:
        return f"{table.num_rows:,} rows x {table.num_columns} cols"
    except Exception:
        return ""
