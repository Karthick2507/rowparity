"""Tests for CSV-driven per-table column exclusions (exclusions.py).

The exclusion path exists to prevent a specific failure: believing a column is
out of scope when it is still being compared. Most of these tests therefore
assert that a misconfiguration *raises* rather than quietly excluding nothing.
"""
import os

import pytest

from rowparity.cases import Case, discover_cases
from rowparity.exclusions import ExclusionError, load_exclusions, merge_ignore_columns

BCV_CSV = """table,column
request,__path__
slot,__path__
ad,__path__
request,__offset__
slot,__offset__
request,__file_size__
"""


def _write(tmp_path, text=BCV_CSV, name="exclude.csv", encoding="utf-8"):
    path = tmp_path / name
    path.write_text(text, encoding=encoding)
    return str(path)


class TestLoad:
    def test_filters_by_table(self, tmp_path):
        # The whole point of one shared file: other tables' rows must not leak
        # into this case, or a request case would drop slot's columns.
        _write(tmp_path)
        assert load_exclusions("exclude.csv", "request", str(tmp_path)) == [
            "__file_size__",
            "__offset__",
            "__path__",
        ]
        assert load_exclusions("exclude.csv", "slot", str(tmp_path)) == [
            "__offset__",
            "__path__",
        ]
        assert load_exclusions("exclude.csv", "ad", str(tmp_path)) == ["__path__"]

    def test_result_is_sorted_and_deduplicated(self, tmp_path):
        _write(tmp_path, "table,column\nt,b\nt,a\nt,a\n")
        assert load_exclusions("exclude.csv", "t", str(tmp_path)) == ["a", "b"]

    def test_whitespace_is_stripped(self, tmp_path):
        _write(tmp_path, "table,column\n  request , __path__  \n")
        assert load_exclusions("exclude.csv", "request", str(tmp_path)) == ["__path__"]

    def test_blank_rows_are_skipped(self, tmp_path):
        _write(tmp_path, "table,column\nrequest,__path__\n\n,\nrequest,\n,__x__\n")
        assert load_exclusions("exclude.csv", "request", str(tmp_path)) == ["__path__"]

    def test_table_matching_is_case_insensitive(self, tmp_path):
        _write(tmp_path, "table,column\nRequest,__path__\n")
        assert load_exclusions("exclude.csv", "request", str(tmp_path)) == ["__path__"]

    def test_column_casing_is_preserved(self, tmp_path):
        # Column names go on to be matched against real schema names, which are
        # case-sensitive in the comparison path -- so do not normalise them.
        _write(tmp_path, "table,column\nt,MixedCase\n")
        assert load_exclusions("exclude.csv", "t", str(tmp_path)) == ["MixedCase"]

    def test_headers_may_be_capitalised(self, tmp_path):
        _write(tmp_path, "Table,Column\nrequest,__path__\n")
        assert load_exclusions("exclude.csv", "request", str(tmp_path)) == ["__path__"]

    def test_bom_does_not_break_the_first_header(self, tmp_path):
        # A CSV round-tripped through Excel carries a BOM. Read as plain utf-8
        # the first header becomes "﻿table", the table column is never
        # found, and nothing is excluded -- silently.
        _write(tmp_path, BCV_CSV, encoding="utf-8-sig")
        assert load_exclusions("exclude.csv", "request", str(tmp_path)) == [
            "__file_size__",
            "__offset__",
            "__path__",
        ]

    def test_absolute_path_is_used_as_is(self, tmp_path):
        path = _write(tmp_path)
        assert load_exclusions(path, "ad", base_dir="/nonexistent") == ["__path__"]


class TestLoudFailures:
    def test_missing_file_raises(self, tmp_path):
        with pytest.raises(ExclusionError) as exc:
            load_exclusions("nope.csv", "request", str(tmp_path))
        message = str(exc.value)
        assert "not found" in message
        # The error must show the resolved path, since the bug is usually that
        # the relative path resolved somewhere unexpected.
        assert "nope.csv" in message
        assert "query_file" in message  # names the rule it follows

    def test_missing_headers_raise(self, tmp_path):
        _write(tmp_path, "tbl,col\nrequest,__path__\n")
        with pytest.raises(ExclusionError) as exc:
            load_exclusions("exclude.csv", "request", str(tmp_path))
        assert "missing required header" in str(exc.value)
        assert "table,column" in str(exc.value)

    def test_unknown_table_raises_and_lists_known_tables(self, tmp_path):
        # The typo case. Returning an empty set here would exclude nothing and
        # say nothing.
        _write(tmp_path)
        with pytest.raises(ExclusionError) as exc:
            load_exclusions("exclude.csv", "requests", str(tmp_path))
        message = str(exc.value)
        assert "no exclusions for table 'requests'" in message
        assert "'ad', 'request', 'slot'" in message  # the escape hatch
        assert "drop ignore_columns_file" in message

    def test_file_with_no_usable_rows_raises(self, tmp_path):
        _write(tmp_path, "table,column\n")
        with pytest.raises(ExclusionError) as exc:
            load_exclusions("exclude.csv", "request", str(tmp_path))
        assert "no usable rows" in str(exc.value)

    def test_empty_table_argument_raises(self, tmp_path):
        _write(tmp_path)
        with pytest.raises(ExclusionError) as exc:
            load_exclusions("exclude.csv", "", str(tmp_path))
        assert "ignore_columns_table" in str(exc.value)

    def test_entry_for_a_nonexistent_column_is_not_an_error(self, tmp_path):
        # BCV's own file lists the same four metadata columns for all six
        # tables and they are not all present on every one. An exclusion states
        # intent; it is not an assertion about the schema.
        _write(tmp_path, "table,column\nt,never_existed\n")
        assert load_exclusions("exclude.csv", "t", str(tmp_path)) == ["never_existed"]


class TestMerge:
    def test_no_file_returns_inline_unchanged(self):
        assert merge_ignore_columns(["a", "b"], None, None) == ["a", "b"]
        assert merge_ignore_columns(None, None, None) == []

    def test_union_preserves_inline_order_then_appends_file_entries(self, tmp_path):
        _write(tmp_path)
        assert merge_ignore_columns(
            ["zzz_inline"], "exclude.csv", "ad", str(tmp_path)
        ) == ["zzz_inline", "__path__"]

    def test_overlap_is_not_duplicated(self, tmp_path):
        _write(tmp_path)
        assert merge_ignore_columns(
            ["__path__"], "exclude.csv", "ad", str(tmp_path)
        ) == ["__path__"]

    def test_table_without_file_raises(self):
        # Sets a selector with nothing to select from: does nothing on its own.
        with pytest.raises(ExclusionError) as exc:
            merge_ignore_columns([], None, "request")
        assert "without ignore_columns_file" in str(exc.value)


class TestCompareBlockWiring:
    """The compare: block resolves the file into CompareConfig.ignore_columns,
    so every engine sees a plain list and stays unaware a file was involved.
    """

    YAML = """
name: c
expected: {type: inline, rows: [{id: 1, keep: 1, __path__: "a"}]}
actual:   {type: inline, rows: [{id: 1, keep: 1, __path__: "b"}]}
compare:
  keys: [id]
  ignore_columns_file: exclude.csv
  ignore_columns_table: request
"""

    def _case(self, tmp_path):
        _write(tmp_path)
        (tmp_path / "case.yaml").write_text(self.YAML, encoding="utf-8")
        cases = discover_cases(str(tmp_path / "case.yaml"), {})
        return cases[0]

    def test_config_merges_the_file_into_ignore_columns(self, tmp_path):
        cfg = self._case(tmp_path).config()
        assert "__path__" in cfg.ignore_columns
        assert "__offset__" in cfg.ignore_columns

    def test_the_file_keys_do_not_reach_compareconfig(self, tmp_path):
        cfg = self._case(tmp_path).config()
        assert not hasattr(cfg, "ignore_columns_file")
        assert not hasattr(cfg, "ignore_columns_table")

    def test_the_excluded_column_is_actually_not_compared(self, tmp_path):
        # The end-to-end point: __path__ differs between the two sides, and the
        # case must still pass. Without the exclusion it would fail.
        result = self._case(tmp_path).run()
        assert result.equivalent, result.summary()
        assert "__path__" not in result.compared_columns
        assert "keep" in result.compared_columns

    def test_without_the_exclusion_the_same_case_fails(self, tmp_path):
        # Guards against the test above passing for the wrong reason.
        _write(tmp_path)
        stripped = self.YAML.replace("  ignore_columns_file: exclude.csv\n", "").replace(
            "  ignore_columns_table: request\n", ""
        )
        (tmp_path / "bare.yaml").write_text(stripped, encoding="utf-8")
        result = discover_cases(str(tmp_path / "bare.yaml"), {})[0].run()
        assert not result.equivalent
        assert "__path__" in result.compared_columns

    def test_error_names_the_case(self, tmp_path):
        bad = self.YAML.replace("exclude.csv", "missing.csv")
        (tmp_path / "bad.yaml").write_text(bad, encoding="utf-8")
        case = discover_cases(str(tmp_path / "bad.yaml"), {})[0]
        with pytest.raises(ExclusionError) as exc:
            case.config()
        assert "case 'c'" in str(exc.value)

    def test_path_resolves_relative_to_the_case_yaml(self, tmp_path):
        # Not relative to the working directory: a run from elsewhere must
        # still find the file.
        _write(tmp_path)
        (tmp_path / "case.yaml").write_text(self.YAML, encoding="utf-8")
        case = discover_cases(str(tmp_path / "case.yaml"), {})[0]
        cwd = os.getcwd()
        try:
            os.chdir(tmp_path.parent)
            assert "__path__" in case.config().ignore_columns
        finally:
            os.chdir(cwd)

    def test_variables_are_substituted_in_both_keys(self, tmp_path):
        _write(tmp_path)
        parameterised = self.YAML.replace(
            "ignore_columns_table: request", 'ignore_columns_table: "${tbl}"'
        ).replace("ignore_columns_file: exclude.csv", 'ignore_columns_file: "${f}"')
        (tmp_path / "v.yaml").write_text(parameterised, encoding="utf-8")
        case = discover_cases(
            str(tmp_path / "v.yaml"), {"tbl": "ad", "f": "exclude.csv"}
        )[0]
        # ad has only __path__, so this proves the table parameter took effect.
        assert case.config().ignore_columns == ["__path__"]

    def test_unknown_compare_key_still_rejected(self, tmp_path):
        bad = self.YAML.replace("ignore_columns_file:", "ignore_columns_fil:")
        (tmp_path / "typo.yaml").write_text(bad, encoding="utf-8")
        case = discover_cases(str(tmp_path / "typo.yaml"), {})[0]
        with pytest.raises(ValueError, match="unknown compare option"):
            case.config()


class TestSchemaCheckBlockWiring:
    YAML = """
name: s
schema_check:
  expected: {type: inline, rows: [{id: 1, __path__: "a"}]}
  actual:   {type: inline, rows: [{id: 1}]}
  ignore_columns_file: exclude.csv
  ignore_columns_table: request
"""

    def test_excluded_column_is_dropped_from_schema_comparison(self, tmp_path):
        _write(tmp_path)
        (tmp_path / "s.yaml").write_text(self.YAML, encoding="utf-8")
        result = discover_cases(str(tmp_path / "s.yaml"), {})[0].run()
        # __path__ exists only on the expected side; excluded, the schemas match.
        assert result.equivalent, result.summary()
        assert "__path__" not in result.columns_only_in_expected

    def test_without_the_exclusion_it_reports_drift(self, tmp_path):
        _write(tmp_path)
        stripped = self.YAML.replace("  ignore_columns_file: exclude.csv\n", "").replace(
            "  ignore_columns_table: request\n", ""
        )
        (tmp_path / "bare.yaml").write_text(stripped, encoding="utf-8")
        result = discover_cases(str(tmp_path / "bare.yaml"), {})[0].run()
        assert result.columns_only_in_expected == ["__path__"]

    def test_unknown_schema_check_key_is_rejected(self, tmp_path):
        # A silently-ignored typo here means "nothing excluded", the exact
        # failure this feature is meant to prevent.
        from rowparity.schema_check import SchemaCheckError

        bad = self.YAML.replace("ignore_columns_table:", "ignore_columns_tabel:")
        (tmp_path / "typo.yaml").write_text(bad, encoding="utf-8")
        with pytest.raises(SchemaCheckError, match="unknown field"):
            discover_cases(str(tmp_path / "typo.yaml"), {})

    def test_inline_and_file_are_unioned(self, tmp_path):
        _write(tmp_path)
        both = self.YAML.replace(
            "  ignore_columns_table: request\n",
            "  ignore_columns_table: request\n  ignore_columns: [id]\n",
        )
        (tmp_path / "both.yaml").write_text(both, encoding="utf-8")
        result = discover_cases(str(tmp_path / "both.yaml"), {})[0].run()
        # Both sides end up with no columns at all, which is equivalent.
        assert result.compared_columns == []
        assert result.equivalent


class TestCaseWithoutExclusionsIsUnaffected:
    def test_plain_case_needs_no_file(self, tmp_path):
        yaml_text = """
name: plain
expected: {type: inline, rows: [{id: 1}]}
actual:   {type: inline, rows: [{id: 1}]}
compare: {keys: [id], ignore_columns: [x]}
"""
        (tmp_path / "p.yaml").write_text(yaml_text, encoding="utf-8")
        case = discover_cases(str(tmp_path / "p.yaml"), {})[0]
        assert case.config().ignore_columns == ["x"]
        assert case.run().equivalent

    def test_config_signature_stays_callable_with_no_arguments(self):
        # Existing callers pass nothing; base_dir falls back to source_file's
        # directory.
        case = Case(
            name="n",
            expected={"type": "inline", "rows": [{"id": 1}]},
            actual={"type": "inline", "rows": [{"id": 1}]},
            compare={"keys": ["id"]},
        )
        assert case.config().keys == ["id"]
