# BCV Analyzer

A command-line tool for analyzing schema differences between the **SRC** (source) tables and **BCV** (Backward Compatible View) tables in Presto/Trino, and generating backfill recommendations based on column usage data.

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Interactive Mode](#interactive-mode)
  - [CLI Arguments](#cli-arguments)
  - [Environment Variables](#environment-variables)
- [Run Modes](#run-modes)
- [How It Works](#how-it-works)
  - [1. Schema Comparison](#1-schema-comparison)
  - [2. Column Size Lookup](#2-column-size-lookup)
  - [3. Column Exclusion](#3-column-exclusion)
  - [4. Usage Data Query](#4-usage-data-query)
  - [5. Analysis Summary](#5-analysis-summary)
- [Analysis Rules](#analysis-rules)
- [Output](#output)
  - [`<table>_result.csv`](#table_resultcsv)
  - [JSON Files](#json-files)
- [Matched Column Value Validation](#matched-column-value-validation)
  - [Triggering Validation](#triggering-validation)
  - [Network ID Filter](#network-id-filter)
  - [Per-Table Join Keys](#per-table-join-keys)
  - [Parent Structure Node Exclusion](#parent-structure-node-exclusion)
  - [Global Equivalence Mode](#global-equivalence-mode)
  - [Batching Strategy](#batching-strategy)
  - [Comparison Logic](#comparison-logic)
  - [Validation Summary Output](#validation-summary-output)
  - [Validation Output Files](#validation-output-files)
- [Supported Tables](#supported-tables)
- [Thresholds Reference](#thresholds-reference)

---

## Overview

BCV Analyzer compares the schema of a source table (`mrm_log_flat.default.<table>`) against its corresponding BCV table (`etl.public_test1.<table>`), identifies **DIFF** columns (columns present in SRC but missing in BCV), checks whether those columns are used by ETL or SOS, queries Presto for their historical usage data, and produces a prioritized backfill recommendation report.

```
SRC Table  ──┐
             ├──► Schema Comparison ──► MATCHED - TYPE DIFF columns ──► (magenta panel in summary)
BCV Table  ──┘         │
                       ▼
                  exclude.csv filter (removed from all further steps)
                       │
                       ▼
                  DIFF Columns ──► ETL / SOS Usage Check ──► Presto Usage Query ──► Analysis Summary + <table>_result.csv
                                                               (batch, 500/query)
                                                                       │
                                                                       ▼
                                          Value Validation (MATCHED + MATCHED - TYPE DIFF columns)
                                          ──► <table>_validation_report.md
                                          ──► <table>_result.csv  (validation column)
```

---

## Project Structure

```
BCV/
├── bcv_analyzer.py          # Main application
├── requirements.txt         # Python dependencies
├── etl_fields.json          # ETL-used fields, grouped by table name
├── sos_fields.csv           # SOS-used fields (columns: table, column)
├── exclude.csv              # Columns to skip entirely (columns: table, column)
├── field_size/              # Column size data (one .xlsx per table)
│   ├── request_raw_size_in_TiB.xlsx
│   ├── ad_raw_size_in_TiB.xlsx
│   ├── slot_raw_size_in_TiB.xlsx
│   ├── candidate_raw_size_in_TiB.xlsx
│   ├── auction_raw_size_in_TiB.xlsx
│   └── ack_raw_size_in_TiB.xlsx
├── output/                  # Generated output (auto-created)
│   ├── <table>_result.csv             # Main analysis result (+ validation column after validation)
│   ├── <table>_validation_report.md  # Detailed value validation report
│   ├── <table>.json                  # SRC column list
│   └── bcv_<table>.json              # BCV column list
└── tests/
    └── test_bcv_analyzer.py
```

---

## Requirements

- Python 3.11+
- Access to a Presto/Trino gateway
- Column size `.xlsx` files in the `field_size/` directory
- `etl_fields.json` in the project root for ETL usage lookup
- `sos_fields.csv` in the project root for SOS usage lookup
- `exclude.csv` in the project root to skip specific columns _(optional; create with `table,column` headers)_

---

## Installation

```bash
# Create and activate a Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

> **Tip — Increase Terminal Scrollback Lines**
>
> The Analysis Summary output can be lengthy. It is recommended to increase your terminal's scrollback buffer to **30 000** lines so you can scroll back through the full results.
>
> **iTerm2 setup:**
> 1. Open iTerm2 → **Settings** → **Profiles** → select your profile → **Terminal** tab
> 2. Set **Scrollback lines** to `30000`

---

## Usage

### Recommended Execution

```bash
python bcv_analyzer.py \
  --host presto-gateway.presto.fw1.aws.fwmrm.net:8080 \
  --user yuwang \
  --auth-token cfeac6c3-db15-4e03-9bad-e0e96ae4932a
```

To get your own token follow the wiki guide:
https://freewheel.atlassian.net/wiki/spaces/DDEU2/pages/528557481/Presto+Gateway+Userguide#Geta-a-token-with-LDAP-account

> **Note:** You must be connected to VPN to reach the production Presto gateway.

### Interactive Mode

```bash
python bcv_analyzer.py
```

You will be prompted to:
1. **Select a table** — choose from the supported tables using ↑/↓ arrow keys
2. **Select a run mode** — Full Run or Validation Only (see [Run Modes](#run-modes))

### CLI Arguments

| Option              | Description                                      | Default                           |
|---------------------|--------------------------------------------------|-----------------------------------|
| `--host`            | Presto host                                      | `$PRESTO_HOST`                    |
| `--port`            | Presto port                                      | `$PRESTO_PORT` or `8080`          |
| `--user`            | Presto user                                      | `$PRESTO_USER`                    |
| `--request-timeout` | Request timeout (seconds)                        | `$PRESTO_REQUEST_TIMEOUT` or `5`  |
| `--auth-token`      | Auth token (`Authorization: Bearer ...`)         | `$PRESTO_AUTH_TOKEN`              |
| `--auth-header`     | Custom auth header name                          | `$PRESTO_AUTH_HEADER`             |
| `--table`           | Skip table selection prompt                      | _(interactive)_                   |
| `--help`            | Show help message                                |                                   |

### Environment Variables

```bash
PRESTO_HOST=presto.example.com PRESTO_USER=alice python bcv_analyzer.py --table request
```

---

## Run Modes

| Mode                | Description |
|---------------------|-------------|
| **Full Run**        | Queries Presto for **all** DIFF columns. |
| **Validation Only** | Skips schema comparison and usage analysis entirely. Reads the previously generated `output/<table>_result.csv` and proceeds directly to value validation. Requires a result CSV to already exist. |

---

## How It Works

### 1. Schema Comparison

The tool runs `DESCRIBE` on both the SRC and BCV tables, then assigns each column one of three statuses:

| Status | Condition |
|--------|-----------|
| `MATCHED` | Column exists in both tables with the **same** type |
| `MATCHED - TYPE DIFF` | Column exists in both tables but with **different** types |
| `DIFF` | Column is present in SRC but **missing** from BCV entirely |

`MATCHED - TYPE DIFF` columns are shown in a dedicated **magenta panel** in the Analysis Summary and are included in value validation. Columns present in BCV but not in SRC are recorded as `DIFF` (with an empty `src_field`) for informational purposes.

### 2. Column Size Lookup

For each SRC column, the tool looks up its raw data size (in TiB) from pre-generated `.xlsx` files in `field_size/`:

```
field_size/<table>_raw_size_in_TiB.xlsx
```

The file must contain at minimum two columns: `Field Name` and `Size (TiB)`.

### 3. Column Exclusion

Before any usage check or Presto query, columns listed in `exclude.csv` are removed from the analysis for the selected table.

**Format** (`table,column` headers, SRC column names use `__` notation):

```
table,column
request,request__some_deprecated_field
slot,slot__internal_only_field
```

Excluded columns are:
- Filtered out immediately after schema comparison
- **Not** included in ETL/SOS lookup or Presto usage queries
- **Not** written to `result.csv`
- **Not** validated during value validation
- Shown in a dedicated **white/grey panel** at the very top of the Analysis Summary (field name, status, SRC type, BCV type)

### 4. Usage Data Query

For each remaining DIFF column (SRC present, BCV missing), the tool checks two local reference files and then queries Presto:

**ETL usage** — `etl_fields.json`, keyed by table name with dot-separated field paths:

```json
{
  "request": ["request.context.distributor_asset_id"]
}
```

**SOS usage** — `sos_fields.csv`, with `table` and `column` headers and dot-separated field paths:

```
table,column
request,execution_networks.network_selection_info.candidate_ad_funnel_metrics.ad_creative_checking_metrics.auction_max_ad_duration
slot,partners.network_selection_info.candidate_ad_funnel_metrics.ad_filling_metrics.pod_position_targeting_check_failed
```

For both lookups the SRC column name is normalised by replacing `__` with `.` before matching (e.g. `request__context__distributor_asset_id` → `request.context.distributor_asset_id`).

**Presto usage query** — counts distinct queries per column broken down by user type:

| User Type  | Source     | Description |
|------------|------------|-------------|
| `ETL`      | local file | Column in `etl_fields.json` for the selected table — `Y` or empty |
| `SOS`      | local file | Column in `sos_fields.csv` for the selected table — `Y` or empty |
| `Insights` | Presto     | `sa-dataapp-insights`, `sa-dmo-aqs`, `sa-dataapp-yield`, and related accounts |
| `Arena`    | Presto     | Queries from Arena-based sources |
| `LQS`      | Presto     | Queries from LQS-based sources |
| `CP`       | Presto     | Custom Reports (`publisher` user) |
| `AF`       | Presto     | AF ETL (`sa-presto-af-etl` user) |
| `Others`   | Presto     | All other query sources |

**Batching:** 500 columns per Presto query (`USAGE_QUERY_BATCH_SIZE`).  
**Retry:** up to 3 attempts per batch (`USAGE_QUERY_MAX_RETRIES`).  
**Query scope:** `2026-01-01` onwards · `prd` environment · admin users and `presto-python-client` excluded.

### 5. Analysis Summary

The tool prints a color-coded **Analysis Summary** with up to five panels displayed in this order:

| # | Panel | Color | Contents |
|---|-------|-------|----------|
| 1 | **Excluded Columns** | ⚪ White/Grey | Columns from `exclude.csv` — skipped from all steps |
| 2 | **Recommended for Backfill** | 🔵 Cyan | DIFF columns where usage meets threshold AND size < 0.03 TiB |
| 3 | **Recommended Excluded** | 🟡 Yellow | DIFF columns where usage meets threshold AND size ≥ 0.03 TiB |
| 4 | **Recommended No Backfill** | 🔴 Red | DIFF columns where usage is below all thresholds |
| 5 | **Type Mismatch** | 🟣 Magenta | `MATCHED - TYPE DIFF` columns — field exists in both tables but types differ |

Panels 1 and 5 are only shown when they have entries. Panels 2–4 are always shown.

---

## Analysis Rules

Applied to `DIFF` rows where SRC has a value and the BCV column is missing:

| Panel | Color | Condition | `recommended_action` |
|-------|-------|-----------|----------------------|
| Recommended for Backfill | 🔵 Cyan | Usage meets threshold **AND** (size unknown **OR** < 0.03 TiB) | `Backfill` |
| Recommended Excluded | 🟡 Yellow | Usage meets threshold **AND** size ≥ 0.03 TiB | `Excluded - Size Too Large` |
| Recommended No Backfill | 🔴 Red | Usage **does not** meet any threshold | `No Backfill - Low Usage` |

**Usage threshold** — any one of the following must be met:

| Source   | Threshold |
|----------|-----------|
| ETL      | `Y`       |
| SOS      | `Y`       |
| Insights | > 0       |
| Arena    | > 0       |
| LQS      | ≥ 10      |
| CP       | > 0       |
| AF       | > 0       |
| Others   | ≥ 100     |

> `MATCHED - TYPE DIFF` columns do not receive a `recommended_action`; they are shown in the magenta panel only.  
> Columns in `exclude.csv` do not receive any recommendation and are not written to `result.csv`.

---

## Output

### `<table>_result.csv`

Written to `output/<table>_result.csv`. Excluded columns are **not** present in this file.

| Column | Description |
|--------|-------------|
| `status` | `MATCHED` · `MATCHED - TYPE DIFF` · `DIFF` |
| `src_field` | Column name in the SRC table |
| `src_type` | Column type in the SRC table |
| `bcv_field` | Column name in the BCV table (empty if missing) |
| `bcv_type` | Column type in the BCV table (empty if missing) |
| `size` | Raw column size in TiB (empty if not in size data) |
| `usage:ETL` | `Y` if used by ETL (`etl_fields.json`); otherwise empty |
| `usage:SOS` | `Y` if used by SOS (`sos_fields.csv`); otherwise empty |
| `usage:Insights` | Distinct Insights query count |
| `usage:Arena` | Distinct Arena query count |
| `usage:LQS` | Distinct LQS query count |
| `usage:CP` | Distinct Custom Reports query count |
| `usage:AF` | Distinct AF ETL query count |
| `usage:Others` | Distinct query count from all other sources |
| `recommended_action` | `Backfill` / `Excluded - Size Too Large` / `No Backfill - Low Usage` / _(empty for MATCHED and MATCHED - TYPE DIFF)_ |
| `validation` | Added after value validation: `Y` (exact match) · `E` (globally equivalent) · `N` (mismatch) · `-` (parent node, skipped) · _(empty for DIFF rows)_ |

### JSON Files

| File | Description |
|------|-------------|
| `output/<table>.json` | Full SRC column list from DESCRIBE |
| `output/bcv_<table>.json` | Full BCV column list from DESCRIBE |

---

## Matched Column Value Validation

Validates the actual data values of all `MATCHED` and `MATCHED - TYPE DIFF` columns by running live queries against both SRC and BCV and comparing row by row. Type-mismatched columns are included so the nature of any data difference can be observed directly.

### Triggering Validation

1. **After a Full Run** — once `result.csv` is written the tool prompts:
   > `Continue to validate values for MATCHED columns?`  
   Selecting `Yes` then asks:
   > `Select number of transactions to sample for validation: 10 / 100 / 1000`  
   followed by:
   > `Enable global equivalence mode? (treats null/\N/0/false/[]/[] as equivalent where applicable)`

2. **Validation Only mode** — select at startup to skip schema comparison entirely and jump straight to validation using a previously generated `result.csv`. The transaction-count and global-equivalence prompts are shown at the start of the validation step.

### Per-Table Join Keys

| Table | Key Columns |
|-------|-------------|
| `request` | `request__transaction_id` |
| `slot` | `request__transaction_id`, `slot__index` _(int)_ |
| `ad` | `request__transaction_id`, `advertisement__ad_id`, `advertisement__ad_replica_id` _(int)_, `advertisement__ad_type` _(varchar)_ |

Tables without a configured key (`candidate`, `auction`, `ack`) skip validation with a warning. Integer key columns are written as unquoted integer literals in `IN (...)` clauses.

### Parent Structure Node Exclusion

A column is treated as a **parent structure node** and excluded from validation when **both** conditions hold:

1. `src_type` is one of: `varchar` · `array(varchar)` · `array(array(varchar))` · `array(array(array(varchar)))`
2. At least one child column `<field>__<suffix>` exists anywhere in the result CSV

Parent nodes are:
- Excluded from all validation queries (no SQL generated for them)
- Marked **`-`** in the `validation` column of `result.csv`
- Listed in a dedicated section of the validation report markdown

### Global Equivalence Mode

When prompted after choosing a transaction limit, you can enable **Global Equivalence Mode**:

> `Enable global equivalence mode? (treats null/\N/0/false/[]/[] as equivalent where applicable)`

When enabled, value differences that are **semantically the same** are treated as matches rather than failures. This is useful when SRC and BCV represent "no data" differently — for example, an empty array `[]` in SRC vs. `null` in BCV for an optional field.

#### Equivalence Groups

Two values are globally equivalent if they both normalise into the same equivalence group:

| Group | Members |
|-------|---------|
| **Null-like / zero / false** | `null`, `\N`, `""` (empty string), `none`, `0`, `0.0`, `false` |
| **Null-like / empty container** | `null`, `\N`, `""` (empty string), `none`, `[]`, `{}` |

Matching is case-insensitive.

**Array handling** — an array whose elements are all null-like (e.g. `[None, None]`) is itself treated as null-like before group lookup. This means `[None, None]` ≡ `null` ≡ `[]`.

**Element-wise list comparison** — if two lists have the **same length**, each pair of corresponding elements is checked recursively for global equivalence. This covers the common BCV pattern where `[]` appears in SRC at positions where BCV stores `None`:

```
SRC:  [  [],   None, [1, 2] ]
BCV:  [ None,  None, [1, 2] ]   ← only the [] vs None slot differs → EQUIVALENT
```

Length mismatches (e.g. structural compaction where BCV drops empty sub-arrays entirely) are **not** treated as equivalent.

#### Effect on Results

| Scenario | Without equiv mode | With equiv mode |
|----------|--------------------|-----------------|
| `[]` vs `null` | **N** (unmatched) | **E** (equivalent) |
| `[[], []]` vs `[None, None]` | **N** (unmatched) | **E** (equivalent) |
| `[[data], []]` vs `[[data]]` | **N** (unmatched) | **N** — different lengths, not equivalent |
| `0` vs `null` | **N** (unmatched) | **E** (equivalent) |
| `"FIRST_PRICE"` vs `null` | **N** (unmatched) | **N** — not in same group |

Globally equivalent fields are:
- Counted separately from exact matches in the terminal summary and report
- Marked **`E`** in the `validation` column of `result.csv`
- Listed in a dedicated **Globally Equivalent Fields** section in the validation report markdown

### Batching Strategy

Columns are split into batches of up to **500** (`VALUE_VALIDATION_BATCH_SIZE`). Key columns are automatically prepended to any batch that doesn't already include them.

**Batch 1 — TABLESAMPLE (anchors the key set):**

```sql
SELECT
    <key_columns>,
    <columns_batch_1>
FROM mrm_log_flat.default.<table> TABLESAMPLE BERNOULLI (1)
WHERE bitwise_and(request__bit_flags, 576460752303423488) > 0
  AND process_batch_id = '<batch_id>'
LIMIT <transaction_limit>
```

`batch_id` = current time − 24 h, rounded to the hour (`YYYYMMDDHHMMSS`). Shown in **green** in the terminal.  
`transaction_limit` = the value selected in the prompt (10 / 100 / 1000).

**Batch 2+ — SRC (targets the same rows):**

```sql
SELECT <key_columns>, <columns_batch_N>
FROM mrm_log_flat.default.<table>
WHERE process_batch_id = '<batch_id>'
  AND (<key_columns>) IN ((<v1>, <v2>), ...)
```

**BCV (all batches):**

```sql
SELECT <key_columns>, <columns_batch_N>
FROM etl.public_test1.<table>
WHERE batch_id = '<batch_id>'
  AND (<key_columns>) IN ((<v1>, <v2>), ...)
LIMIT <transaction_limit>
```

All batches run sequentially. Progress is shown with a live spinning indicator (refreshes every second). Results from all batches are merged in memory before the final comparison.

### Comparison Logic

1. Keys from batch 1 SRC rows establish the transaction universe.
2. Only rows present in **both** SRC and BCV (by key) are compared; unmatched keys are skipped.
3. Each non-key column is compared value by value across all matched rows.
4. A column is **matched** (`Y`) if every row agrees exactly (null-safe).
5. If global equivalence mode is on, a column where all diffs are globally equivalent is marked **`E`** rather than **`N`**.
6. A column is **unmatched** (`N`) only when at least one row contains a difference that is neither null-safe equal nor globally equivalent.

### Validation Summary Output

```
[2026-06-25 10:31:00] Value validation summary:
[2026-06-25 10:31:00] Matched transactions:  10/10
[2026-06-25 10:31:00] Matched fields (exact): 342/350  (97.71%)  +  5 globally-equivalent
[2026-06-25 10:31:00] Unmatched fields:         3/350   (0.86%)
```

When global equivalence mode is **off** the `+ N globally-equivalent` suffix is not shown.

Key counts are highlighted in color. Both output file paths are printed in **green**.

### Validation Output Files

| File | Description |
|------|-------------|
| `output/<table>_result.csv` | Patched with a `validation` column (`Y` / `E` / `N` / `-`) |
| `output/<table>_validation_report.md` | Detailed markdown report |

#### `<table>_validation_report.md` sections

| Section | Contents |
|---------|----------|
| **Summary** | Transaction counts, exact-matched / globally-equivalent / unmatched field counts and percentages |
| **Excluded Parent Structure Nodes** | Fields skipped as parent nodes, with their types |
| **Globally Equivalent Fields** | _(only when global equivalence mode is on)_ Fields that had differences but all diffs fell within an equivalence group; includes a sample diff per field |
| **SQL Queries** | All SRC and BCV SQL for every batch as fenced code blocks |
| **Unmatched Field Details** | Per-column diff table: join key · SRC value · BCV value |

Example entry:

```markdown
### 1. `slot__environment`  _(3 diff(s))_

| Key | SRC | BCV |
|:---|:---|:---|
| `abc123 / 1` | `web` | `WEB`    |
| `def456 / 2` | `app` | *(null)* |
```

---

## Supported Tables

| Table | SRC Full Name | BCV Full Name | Validation Key Columns |
|-------|---------------|---------------|------------------------|
| `request` | `mrm_log_flat.default.request` | `etl.public_test1.request` | `request__transaction_id` |
| `ad` | `mrm_log_flat.default.ad` | `etl.public_test1.ad` | `request__transaction_id`, `advertisement__ad_id`, `advertisement__ad_replica_id` |
| `slot` | `mrm_log_flat.default.slot` | `etl.public_test1.slot` | `request__transaction_id`, `slot__index` |
| `candidate` | `mrm_log_flat.default.candidate` | `etl.public_test1.candidate` | _(not configured — validation skipped)_ |
| `auction` | `mrm_log_flat.default.auction` | `etl.public_test1.auction` | _(not configured — validation skipped)_ |
| `ack` | `mrm_log_flat.default.ack` | `etl.public_test1.ack` | _(not configured — validation skipped)_ |

---

## Thresholds Reference

| Constant | Value | Description |
|----------|-------|-------------|
| `USAGE_QUERY_BATCH_SIZE` | `500` | Columns per Presto usage batch query |
| `USAGE_QUERY_MAX_RETRIES` | `3` | Max retry attempts per usage batch on failure |
| `VALUE_VALIDATION_BATCH_SIZE` | `500` | Columns per value validation batch query |
