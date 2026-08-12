import csv
import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

import bcv_analyzer
import openpyxl
from bcv_analyzer import (
    add_usage_info,
    build_bcv_describe_sql,
    build_bcv_table_name,
    build_describe_sql,
    build_engine_url,
    build_full_table_name,
    build_http_headers,
    build_usage_sql,
    compare_schema_rows,
    count_missing_bcv_columns,
    execute_sql,
    format_rows,
    load_field_sizes,
    normalize_connection_kwargs,
    print_rows_as_json,
    resolve_table,
)


class FakeConnection:
    def __init__(self, rows, columns):
        self.rows = rows
        self.description = [(column, None, None, None, None, None, None) for column in columns]
        self.executed = []
        self.closed = False
        self.cursor_closed = False

    def cursor(self):
        return self

    def execute(self, sql):
        self.executed.append(sql)

    def fetchall(self):
        return self.rows

    def close(self):
        if self.cursor_closed:
            self.closed = True
        else:
            self.cursor_closed = True


class FakeEngine:
    def __init__(self, rows, columns):
        self.connection = FakeConnection(rows, columns)

    def raw_connection(self):
        return self.connection


class BcvAnalyzerTests(unittest.TestCase):
    def test_resolve_table_accepts_known_table_and_rejects_invalid_table(self):
        self.assertEqual(resolve_table("request"), "request")

        with self.assertRaises(SystemExit):
            resolve_table("invalid")

    def test_resolve_table_prompts_when_table_is_not_provided(self):
        prompt = unittest.mock.Mock()
        prompt.ask.return_value = "slot"

        with (
            patch.object(bcv_analyzer.UI_CONSOLE, "print") as print_panel,
            patch.object(bcv_analyzer.questionary, "select", return_value=prompt) as select,
        ):
            self.assertEqual(resolve_table(None), "slot")

        print_panel.assert_called_once()
        self.assertIn("BCV", print_panel.call_args.args[0].renderable)
        self.assertIn("Analyzer", print_panel.call_args.args[0].renderable)
        self.assertIn("v0.1", print_panel.call_args.args[0].renderable)
        select.assert_called_once_with("Select table:", choices=list(bcv_analyzer.ALLOWED_TABLES))

    def test_main_uses_hardcoded_catalog_and_schema(self):
        argv = [
            "bcv_analyzer.py",
            "--host",
            "presto.example.com",
            "--user",
            "analyst",
            "--table",
            "request",
        ]
        src_rows = [
            {"Column": "matched_col", "Type": "varchar", "Extra": "", "Comment": "internal"},
            {
                "Column": "request__context__distributor_asset_id",
                "Type": "bigint",
                "Extra": "",
                "Comment": "internal",
            },
            {"Column": "type_changed", "Type": "integer", "Extra": "", "Comment": "internal"},
        ]
        bcv_rows = [
            {"Column": "matched_col", "Type": "varchar", "Extra": "", "Comment": "internal"},
            {"Column": "type_changed", "Type": "bigint", "Extra": "", "Comment": "internal"},
            {"Column": "bcv_only", "Type": "array(varchar)", "Extra": "", "Comment": "internal"},
        ]
        original_cwd = os.getcwd()
        with tempfile.TemporaryDirectory() as tmpdir:
            try:
                os.chdir(tmpdir)
                field_size_dir = Path(tmpdir) / "field_size"
                field_size_dir.mkdir()
                workbook = openpyxl.Workbook()
                worksheet = workbook.active
                worksheet.title = "Field Sizes"
                worksheet.append(["Field Name", "Size (Bytes)", "Size (TiB)"])
                worksheet.append(["request.context.distributor_asset_id", 123, 1.236])
                workbook.save(field_size_dir / "request_raw_size_in_TiB.xlsx")
                with (
                    patch.object(
                        bcv_analyzer,
                        "execute_sql",
                        side_effect=[
                            src_rows,
                            bcv_rows,
                            [
                                {
                                    "column_name": "request__context__distributor_asset_id",
                                    "user": "Arena",
                                    "usage_count": 3,
                                },
                                {
                                    "column_name": "request__context__distributor_asset_id",
                                    "user": "Others",
                                    "usage_count": 2,
                                },
                            ],
                        ],
                    ) as execute,
                    patch.object(bcv_analyzer, "FIELD_SIZE_DIR", field_size_dir),
                    patch.object(bcv_analyzer, "OUTPUT_DIR", Path(tmpdir) / "output"),
                    patch.object(
                        bcv_analyzer, "ETL_FIELDS_PATH", Path(tmpdir) / "missing_etl_fields.json"
                    ),
                    patch.object(
                        bcv_analyzer, "resolve_run_mode", return_value=bcv_analyzer.RunMode.TRIAL
                    ),
                    patch.object(
                        bcv_analyzer, "prompt_for_value_validation", return_value=False
                    ) as prompt_value_validation,
                    patch.object(
                        bcv_analyzer, "current_timestamp", return_value="2026-06-24 12:34:56"
                    ),
                    redirect_stdout(io.StringIO()) as stdout,
                ):
                    bcv_analyzer.main(host="presto.example.com", user="analyst", table="request")

                output_dir = Path(tmpdir) / "output"
                written_rows = json.loads((output_dir / "request.json").read_text(encoding="utf-8"))
                written_bcv_rows = json.loads(
                    (output_dir / "bcv_request.json").read_text(encoding="utf-8")
                )
                with (output_dir / "request_result.csv").open(encoding="utf-8") as result_file:
                    result_rows = list(csv.DictReader(result_file))
            finally:
                os.chdir(original_cwd)

        self.assertEqual(execute.call_args_list[0].args[0], "DESCRIBE mrm_log_flat.default.request")
        self.assertEqual(execute.call_args_list[1].args[0], "DESCRIBE etl.public_test1.request")
        self.assertEqual(
            execute.call_args_list[2].args[0],
            build_usage_sql("request", "request__context__distributor_asset_id"),
        )
        self.assertEqual(
            execute.call_args_list[0].kwargs["connection_kwargs"]["catalog"], "mrm_log_flat"
        )
        self.assertEqual(execute.call_args_list[0].kwargs["connection_kwargs"]["schema"], "default")
        self.assertEqual(execute.call_args_list[1].kwargs["connection_kwargs"]["catalog"], "etl")
        self.assertEqual(
            execute.call_args_list[1].kwargs["connection_kwargs"]["schema"], "public_test1"
        )
        self.assertIn(
            "[2026-06-24 12:34:56] Retrieving column list for table: mrm_log_flat.default.request",
            stdout.getvalue(),
        )
        self.assertIn("[2026-06-24 12:34:56] Retrieving column size", stdout.getvalue())
        prompt_value_validation.assert_called_once()
        self.assertEqual(len(written_rows), 3)
        self.assertEqual(
            set(written_rows[0].keys()),
            {"Column", "Type"},
        )
        self.assertEqual(written_bcv_rows[0], {"Column": "matched_col", "Type": "varchar"})
        self.assertEqual(
            result_rows,
            [
                {
                    "status": "MATCHED",
                    "src_field": "matched_col",
                    "src_type": "varchar",
                    "bcv_field": "matched_col",
                    "bcv_type": "varchar",
                    "size": "",
                    "usage:ETL": "",
                    "usage:Insights": "",
                    "usage:Arena": "",
                    "usage:LQS": "",
                    "usage:Others": "",
                    "recommended_action": "",
                },
                {
                    "status": "DIFF",
                    "src_field": "request__context__distributor_asset_id",
                    "src_type": "bigint",
                    "bcv_field": "",
                    "bcv_type": "",
                    "size": "1.24",
                    "usage:ETL": "",
                    "usage:Insights": "",
                    "usage:Arena": "3",
                    "usage:LQS": "",
                    "usage:Others": "2",
                    "recommended_action": "Excluded - Size Too Large",
                },
                {
                    "status": "DIFF",
                    "src_field": "type_changed",
                    "src_type": "integer",
                    "bcv_field": "type_changed",
                    "bcv_type": "bigint",
                    "size": "",
                    "usage:ETL": "",
                    "usage:Insights": "",
                    "usage:Arena": "",
                    "usage:LQS": "",
                    "usage:Others": "",
                    "recommended_action": "",
                },
                {
                    "status": "DIFF",
                    "src_field": "",
                    "src_type": "",
                    "bcv_field": "bcv_only",
                    "bcv_type": "array(varchar)",
                    "size": "",
                    "usage:ETL": "",
                    "usage:Insights": "",
                    "usage:Arena": "",
                    "usage:LQS": "",
                    "usage:Others": "",
                    "recommended_action": "",
                },
            ],
        )

    def test_add_usage_info_queries_only_first_ten_missing_bcv_columns(self):
        rows = [
            {
                "status": "DIFF",
                "src_field": f"col_{index}",
                "src_type": "varchar",
                "bcv_field": "",
                "bcv_type": "",
                "size": "",
            }
            for index in range(11)
        ]
        rows.append(
            {
                "status": "DIFF",
                "src_field": "",
                "src_type": "",
                "bcv_field": "bcv_only",
                "bcv_type": "varchar",
                "size": "",
            }
        )

        usage_rows = [
            {"column_name": f"col_{index}", "user": "LQS", "usage_count": 4} for index in range(10)
        ]

        with (
            patch.object(bcv_analyzer, "execute_sql", return_value=usage_rows) as execute,
            redirect_stdout(io.StringIO()),
        ):
            add_usage_info("request", rows, {"catalog": "mrm_log_flat"})

        self.assertEqual(execute.call_count, 1)
        self.assertEqual(
            execute.call_args_list[0].args[0],
            bcv_analyzer.build_usage_sql_batch("request", [f"col_{index}" for index in range(10)]),
        )
        self.assertEqual(rows[0]["usage:LQS"], 4)
        self.assertEqual(rows[9]["usage:LQS"], 4)
        self.assertEqual(rows[10]["usage:LQS"], "")
        self.assertEqual(rows[11]["usage:LQS"], "")

    def test_add_usage_info_refreshes_progress_on_one_line(self):
        rows = [
            {
                "status": "DIFF",
                "src_field": f"col_{index}",
                "src_type": "varchar",
                "bcv_field": "",
                "bcv_type": "",
                "size": "",
            }
            for index in range(2)
        ]

        with (
            patch.object(bcv_analyzer, "execute_sql", return_value=[]) as execute,
            patch.object(bcv_analyzer, "current_timestamp", return_value="2026-06-24 12:34:56"),
            redirect_stdout(io.StringIO()) as stdout,
        ):
            add_usage_info("request", rows, {"catalog": "mrm_log_flat"})

        self.assertEqual(execute.call_count, 1)
        self.assertIn("Retrieving usage info for missing columns in BCV", stdout.getvalue())

    def test_build_usage_sql_uses_latest_query_template(self):
        sql = build_usage_sql("request", "request__context__custom_distributor_signature")

        self.assertIn("WHEN a.source LIKE '%Arena%' THEN 'Arena'", sql)
        self.assertIn("WHEN a.source LIKE '%lqs%' THEN 'LQS'", sql)
        self.assertIn("SELECT DISTINCT\n        q.pid,\n        q.user,\n        q.source,", sql)
        self.assertIn(
            "AND q.user NOT IN ('sqyang', 'yjgou', 'kbhargava', 'yuwang', 'zhfan')",
            sql,
        )
        self.assertIn("AND q.source NOT IN ('presto-python-client')", sql)
        self.assertIn("AND pcu.catalog = 'mrm_log_flat'", sql)
        self.assertIn("AND pcu.table_name = 'request'", sql)
        self.assertIn("AND p.col IN ('request__context__custom_distributor_signature')", sql)
        self.assertIn("AND (NOT regexp_like(q.query, '(?i)select\\s*\\*'))", sql)
        self.assertIn("AND error_type is null AND error_name is null", sql)
        self.assertIn("GROUP BY 1, 2\nORDER BY 1, 3 DESC", sql)

    def test_compare_schema_rows_matches_by_field_and_type(self):
        compared = compare_schema_rows(
            "request",
            [
                {"Column": "matched_col", "Type": "varchar"},
                {"Column": "request__context__distributor_asset_id", "Type": "bigint"},
                {"Column": "type_changed", "Type": "integer"},
            ],
            [
                {"Column": "matched_col", "Type": "varchar"},
                {"Column": "type_changed", "Type": "bigint"},
                {"Column": "bcv_only", "Type": "array(varchar)"},
            ],
            {"request.context.distributor_asset_id": 1.236},
        )
        self.assertEqual(
            compared,
            [
                {
                    "status": "MATCHED",
                    "src_field": "matched_col",
                    "src_type": "varchar",
                    "bcv_field": "matched_col",
                    "bcv_type": "varchar",
                    "size": "",
                },
                {
                    "status": "DIFF",
                    "src_field": "request__context__distributor_asset_id",
                    "src_type": "bigint",
                    "bcv_field": "",
                    "bcv_type": "",
                    "size": 1.24,
                },
                {
                    "status": "DIFF",
                    "src_field": "type_changed",
                    "src_type": "integer",
                    "bcv_field": "type_changed",
                    "bcv_type": "bigint",
                    "size": "",
                },
                {
                    "status": "DIFF",
                    "src_field": "",
                    "src_type": "",
                    "bcv_field": "bcv_only",
                    "bcv_type": "array(varchar)",
                    "size": "",
                },
            ],
        )
        self.assertEqual(count_missing_bcv_columns(compared), 1)

    def test_load_field_sizes_reads_matching_workbook(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            field_size_dir = Path(tmpdir)
            workbook = openpyxl.Workbook()
            worksheet = workbook.active
            worksheet.title = "Field Sizes"
            worksheet.append(["Field Name", "Size (Bytes)", "Size (TiB)"])
            worksheet.append(["request.context.distributor_asset_id", 123, 1.236])
            workbook.save(field_size_dir / "request_raw_size_in_TiB.xlsx")

            self.assertEqual(
                load_field_sizes("request", field_size_dir=field_size_dir),
                {"request.context.distributor_asset_id": 1.236},
            )

    def test_add_etl_usage_info_matches_src_field_with_double_underscore_normalization(self):
        rows = [
            {
                "status": "DIFF",
                "src_field": "request__context__distributor_asset_id",
                "src_type": "bigint",
                "bcv_field": "",
                "bcv_type": "",
                "size": "",
            },
            {
                "status": "DIFF",
                "src_field": "request__context__other_id",
                "src_type": "bigint",
                "bcv_field": "",
                "bcv_type": "",
                "size": "",
            },
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            etl_fields_path = Path(tmpdir) / "etl_fields.json"
            etl_fields_path.write_text(
                json.dumps({"request": ["request.context.distributor_asset_id"]}),
                encoding="utf-8",
            )

            bcv_analyzer.add_etl_usage_info("request", rows, etl_fields_path=etl_fields_path)

        self.assertEqual(rows[0]["usage:ETL"], "Y")
        self.assertEqual(rows[1]["usage:ETL"], "")

    def test_etl_usage_meets_threshold_for_backfill_without_presto_query(self):
        row = {
            "status": "DIFF",
            "src_field": "request__context__distributor_asset_id",
            "src_type": "bigint",
            "bcv_field": "",
            "bcv_type": "",
            "size": "",
            "usage:ETL": "Y",
            "usage:Insights": "",
            "usage:Arena": "",
            "usage:LQS": "",
            "usage:Others": "",
        }

        self.assertTrue(bcv_analyzer.usage_meets_threshold(row))
        self.assertEqual(bcv_analyzer.get_recommended_action(row, was_queried=False), "Backfill")

    def test_build_value_validation_batch_id_uses_previous_hour_bucket(self):
        self.assertEqual(
            bcv_analyzer.build_value_validation_batch_id(datetime(2025, 5, 12, 18, 42, 31)),
            "20250511180000",
        )

    def test_load_matched_columns_from_result_csv_reads_only_matched_src_fields(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result_path = Path(tmpdir) / "request_result.csv"
            with result_path.open("w", encoding="utf-8", newline="") as output:
                writer = csv.DictWriter(output, fieldnames=("status", "src_field"))
                writer.writeheader()
                writer.writerows(
                    [
                        {"status": "MATCHED", "src_field": "matched_a"},
                        {"status": "DIFF", "src_field": "diff_col"},
                        {"status": "MATCHED", "src_field": "matched_b"},
                        {"status": "MATCHED", "src_field": ""},
                    ]
                )

            self.assertEqual(
                bcv_analyzer.load_matched_columns_from_result_csv(result_path),
                ["matched_a", "matched_b"],
            )

    def test_build_value_validation_sql_batches_matched_columns(self):
        sql_batches = bcv_analyzer.build_value_validation_sql_batches(
            "request",
            ["request__transaction_id", "matched_a", "matched_b", "matched_c"],
            batch_id="20250511180000",
            batch_size=3,
        )

        self.assertEqual(len(sql_batches), 2)
        self.assertEqual(
            sql_batches[0]["src_sql"],
            "SELECT\n"
            "    request__transaction_id,\n"
            "    matched_a,\n"
            "    matched_b\n"
            "FROM mrm_log_flat.default.request TABLESAMPLE BERNOULLI (1)\n"
            "WHERE bitwise_and(request__bit_flags, 576460752303423488) > 0\n"
            "  AND process_batch_id = '20250511180000'\n"
            "LIMIT 10",
        )
        self.assertIn("matched_c", sql_batches[1]["src_sql"])

    def test_build_value_validation_bcv_sql_uses_transaction_ids_from_src_result(self):
        bcv_sql = bcv_analyzer.build_value_validation_bcv_sql(
            "request",
            ["request__transaction_id", "matched_a", "matched_b"],
            batch_id="20250511180000",
            transaction_ids=["tx_1", "tx'2"],
        )

        self.assertEqual(
            bcv_sql,
            "SELECT\n"
            "    request__transaction_id,\n"
            "    matched_a,\n"
            "    matched_b\n"
            "FROM etl.public_test1.request\n"
            "WHERE batch_id = '20250511180000'\n"
            "  AND request__transaction_id IN (\n"
            "      'tx_1',\n"
            "      'tx''2'\n"
            "  )\n"
            "LIMIT 10",
        )
        self.assertNotIn("request__bit_flags", bcv_sql)
        self.assertNotIn("process_batch_id", bcv_sql)

    def test_compare_value_validation_results_summarizes_matched_and_mismatched_fields(self):
        summary = bcv_analyzer.compare_value_validation_results(
            [
                {"request__transaction_id": "tx_1", "matched_a": "same", "matched_b": "src_only"},
                {"request__transaction_id": "tx_2", "matched_a": "same", "matched_b": "left"},
            ],
            [
                {"request__transaction_id": "tx_1", "matched_a": "same", "matched_b": "bcv_only"},
                {"request__transaction_id": "tx_2", "matched_a": "same", "matched_b": "right"},
            ],
            ["request__transaction_id", "matched_a", "matched_b"],
        )

        self.assertEqual(summary["matched_fields"], ["matched_a"])
        self.assertEqual(summary["mismatched_fields"], ["matched_b"])
        self.assertEqual(summary["total_field_count"], 2)
        self.assertEqual(summary["matched_field_count"], 1)
        self.assertEqual(summary["mismatched_field_count"], 1)
        self.assertEqual(summary["matched_field_ratio"], 50.0)
        self.assertEqual(summary["mismatched_field_ratio"], 50.0)

    def test_print_value_validation_sql_executes_src_then_bcv_and_prints_comparison_summary(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result_path = Path(tmpdir) / "request_result.csv"
            with result_path.open("w", encoding="utf-8", newline="") as output:
                writer = csv.DictWriter(output, fieldnames=("status", "src_field"))
                writer.writeheader()
                writer.writerows(
                    [
                        {"status": "MATCHED", "src_field": "request__transaction_id"},
                        {"status": "MATCHED", "src_field": "matched_a"},
                        {"status": "MATCHED", "src_field": "matched_b"},
                        {"status": "DIFF", "src_field": "diff_col"},
                    ]
                )

            stdout = io.StringIO()
            with (
                patch.object(
                    bcv_analyzer,
                    "execute_sql",
                    side_effect=[
                        [
                            {
                                "request__transaction_id": "tx_1",
                                "matched_a": "same",
                                "matched_b": "src_value",
                            },
                            {
                                "request__transaction_id": "tx_2",
                                "matched_a": "same",
                                "matched_b": "same",
                            },
                        ],
                        [
                            {
                                "request__transaction_id": "tx_1",
                                "matched_a": "same",
                                "matched_b": "bcv_value",
                            },
                            {
                                "request__transaction_id": "tx_2",
                                "matched_a": "same",
                                "matched_b": "same",
                            },
                        ],
                    ],
                ) as execute,
                redirect_stdout(stdout),
            ):
                bcv_analyzer.print_value_validation_sql(
                    "request",
                    result_path,
                    {"catalog": "mrm_log_flat"},
                    {"catalog": "etl"},
                    now=datetime(2025, 5, 12, 18, 42, 31),
                    batch_size=3,
                )

        output = stdout.getvalue()
        self.assertEqual(execute.call_count, 2)
        self.assertIn("process_batch_id = '20250511180000'", execute.call_args_list[0].args[0])
        self.assertEqual(
            execute.call_args_list[0].kwargs["connection_kwargs"], {"catalog": "mrm_log_flat"}
        )
        self.assertIn("batch_id = '20250511180000'", execute.call_args_list[1].args[0])
        self.assertIn("'tx_1'", execute.call_args_list[1].args[0])
        self.assertIn("request__transaction_id IN", execute.call_args_list[1].args[0])
        self.assertEqual(execute.call_args_list[1].kwargs["connection_kwargs"], {"catalog": "etl"})
        self.assertIn("Value validation batch_id: 20250511180000", output)
        self.assertIn("Value validation SQL batch 1/1", output)
        self.assertIn("SRC SQL:", output)
        self.assertIn("BCV SQL:", output)
        self.assertIn("Value validation summary:", output)
        self.assertIn("Matched fields: 1/2 (50.00%)", output)
        self.assertIn("Unmatched fields: 1/2 (50.00%)", output)
        self.assertIn("Unmatched field list: matched_b", output)
        self.assertNotIn("src_value", output)
        self.assertNotIn("bcv_value", output)
        self.assertIn("request__transaction_id IN", output)
        self.assertIn("batch_id = '20250511180000'", output)
        self.assertNotIn("Value validation SQL batch 2/2", output)

    def test_build_describe_sql_uses_full_table_name(self):
        self.assertEqual(
            build_full_table_name("request"),
            "mrm_log_flat.default.request",
        )
        self.assertEqual(
            build_describe_sql("request"),
            "DESCRIBE mrm_log_flat.default.request",
        )
        self.assertEqual(
            build_bcv_table_name("request"),
            "etl.public_test1.request",
        )
        self.assertEqual(
            build_bcv_describe_sql("request"),
            "DESCRIBE etl.public_test1.request",
        )

    def test_main_requires_connection_args(self):
        with self.assertRaises(SystemExit):
            with patch.object(
                bcv_analyzer, "resolve_run_mode", return_value=bcv_analyzer.RunMode.TRIAL
            ):
                bcv_analyzer.main(host=None, user="analyst", table="request")

    def test_execute_sql_runs_statement_and_returns_dict_rows(self):
        engine = FakeEngine([(1, "slot"), (2, "request")], ["query_count", "col"])
        calls = []

        result = execute_sql(
            "SELECT query_count, col FROM usage",
            connection_kwargs={
                "host": "https://presto.example.com:8443",
                "port": 8080,
                "user": "analyst",
                "catalog": "mrm_log_flat",
                "schema": "default",
                "request_timeout": 10.0,
            },
            engine_factory=lambda *args, **kwargs: calls.append((args, kwargs)) or engine,
        )

        self.assertEqual(
            result,
            [
                {"query_count": 1, "col": "slot"},
                {"query_count": 2, "col": "request"},
            ],
        )
        self.assertEqual(engine.connection.executed, ["SELECT query_count, col FROM usage"])
        self.assertTrue(engine.connection.closed)
        self.assertEqual(
            calls[0][0][0], "trino://analyst@presto.example.com:8443/mrm_log_flat/default"
        )
        self.assertEqual(calls[0][1]["connect_args"]["http_scheme"], "https")
        self.assertEqual(calls[0][1]["connect_args"]["request_timeout"], 10.0)

    def test_format_rows_uses_cursor_description_column_names(self):
        result = format_rows([(1, "varchar")], [("count",), ("type",)])

        self.assertEqual(result, [{"count": 1, "type": "varchar"}])

    def test_build_engine_url_matches_tx_validator_pattern(self):
        self.assertEqual(
            build_engine_url("presto.example.com", 8080, "analyst", "hive", "default"),
            "trino://analyst@presto.example.com:8080/hive/default",
        )

    def test_normalize_connection_kwargs_strips_scheme_and_uses_embedded_port(self):
        normalized = normalize_connection_kwargs(
            {
                "host": "http://presto.example.com:8081",
                "port": 8080,
                "user": "analyst",
            }
        )

        self.assertEqual(
            normalized,
            {
                "host": "presto.example.com",
                "port": 8081,
                "http_scheme": "https",
                "user": "analyst",
            },
        )

    def test_build_http_headers_uses_bearer_authorization_by_default(self):
        self.assertEqual(
            build_http_headers("secret", None),
            {"Authorization": "Bearer secret"},
        )

    def test_print_rows_as_json_writes_json_array(self):
        stdout = io.StringIO()

        with redirect_stdout(stdout):
            print_rows_as_json([{"col": "request", "query_count": 3}])

        self.assertEqual(json.loads(stdout.getvalue()), [{"col": "request", "query_count": 3}])


if __name__ == "__main__":
    unittest.main()
