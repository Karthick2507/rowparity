#!/usr/bin/env bash
#
# One entry point for the BCV verification suite -- all steps or any one of them.
#
#   scripts/run_bcv.sh              # everything, in dependency order
#   scripts/run_bcv.sh schema       # just the schema cases
#   scripts/run_bcv.sh tests demo   # just the offline steps (no VPN needed)
#
# Why a script rather than a list of commands in a doc: the steps have an order
# that matters (a batch column check before a run that depends on it), and
# `rowparity run` returns 1 both for "the tables differ" and for "a case
# errored". Those mean opposite things here -- the migration is genuinely
# incomplete, so DIFFERENT is the honest expected answer, while an
# ExclusionError or a dead connection is a real failure. Conflating them gives a
# suite that is always red and therefore ignored. This distinguishes them and
# only fails the run on the second kind, unless --strict says otherwise.
#
# Exit codes:
#   0  every step ran; any differences found are reported but not fatal
#   1  a step ERRORED (bad config, no connection, unreadable case)
#   2  a step reported differences AND --strict was passed
#   3  usage error / missing prerequisite
#
# The Presto token is never printed, logged, or passed on a command line -- only
# whether it is set. Keep it out of shell history too:
#   read -rs TRINO_JWT_TOKEN && export TRINO_JWT_TOKEN

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 3

OUT_DIR="reports/bcv"
STRICT=0
PASSTHRU=()
STEPS=()

# The four metadata columns exclude.csv covers. Verified absent from the report
# after every live run, since a silently-ignored exclusion file is the failure
# mode the feature exists to prevent.
META_COLUMNS='["__path__", "__offset__", "__file_size__", "__footer_size__"]'

C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[36m'
fi

usage() {
  cat <<'USAGE'
Usage: scripts/run_bcv.sh [steps...] [options] [-- extra rowparity args]

Steps (default: all of them, in this order):
  tests      Offline unit tests for the BCV paths.        no VPN needed
  demo       Offline proof that exclusions work (A/B).    no VPN needed
  connect    Trino connectivity + auth check.             needs VPN
  columns    Verify the configured batch column names.    needs VPN
  schema     The 3 schema_check cases (zero rows read).   needs VPN
  value      The 2 value cases (samples rows).            needs VPN

Options:
  --out DIR    Where reports go (default: reports/bcv)
  --strict     Exit 2 when cases report differences (for CI gating)
  --list       Show the steps and exit
  -h, --help   This message
  --           Everything after is passed through to `rowparity run`,
               e.g. -- --param sample_modulus=1 --param batch_id=20260813060000

Examples:
  scripts/run_bcv.sh                       # everything
  scripts/run_bcv.sh tests demo            # offline only, before connecting
  scripts/run_bcv.sh schema value          # the actual comparisons
  scripts/run_bcv.sh value -- --param sample_modulus=1     # whole batch
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    tests|demo|connect|columns|schema|value) STEPS+=("$1"); shift ;;
    all) STEPS+=(tests demo connect columns schema value); shift ;;
    --out) OUT_DIR="${2:-}"; [[ -z "$OUT_DIR" ]] && { echo "--out needs a directory" >&2; exit 3; }; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --list) usage; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; PASSTHRU=("$@"); break ;;
    *) echo "unknown argument: $1" >&2; echo >&2; usage >&2; exit 3 ;;
  esac
done
[[ ${#STEPS[@]} -eq 0 ]] && STEPS=(tests demo connect columns schema value)

ERRORED=()
DIFFERED=()
PASSED=()

banner() { printf '\n%s%s== %s %s%s\n' "$C_BOLD" "$C_BLUE" "$1" "$(printf '=%.0s' {1..40})" "$C_RESET"; }
ok()     { printf '%s  PASS%s  %s\n' "$C_GREEN" "$C_RESET" "$1"; PASSED+=("$1"); }
diff_()  { printf '%s  DIFF%s  %s\n' "$C_YELLOW" "$C_RESET" "$1"; DIFFERED+=("$1"); }
err()    { printf '%s  ERROR%s %s\n' "$C_RED" "$C_RESET" "$1"; ERRORED+=("$1"); }

needs_live() {
  # Fail fast rather than after a 60-second TCP timeout. Values are never
  # printed -- only whether each is set.
  local missing=()
  [[ -z "${TRINO_HOST:-}" ]] && missing+=(TRINO_HOST)
  [[ -z "${TRINO_USER:-}" ]] && missing+=(TRINO_USER)
  if [[ ${#missing[@]} -gt 0 ]]; then
    err "$1 (not run: ${missing[*]} unset)"
    cat >&2 <<'HINT'
    Set the connection first, e.g.:
      export TRINO_HOST=presto-gateway.presto.stg.aws.fwmrm.net
      export TRINO_PORT=8080 TRINO_HTTP_SCHEME=https
      export TRINO_USER=<your user>
      read -rs TRINO_JWT_TOKEN && export TRINO_JWT_TOKEN
HINT
    return 1
  fi
  if [[ -z "${TRINO_JWT_TOKEN:-}" && -z "${TRINO_PASSWORD:-}" ]]; then
    printf '%s  note%s  no TRINO_JWT_TOKEN or TRINO_PASSWORD set; assuming an open cluster\n' \
      "$C_YELLOW" "$C_RESET"
  fi
  return 0
}

# Classify a `rowparity run`: exit 1 covers both "differs" and "errored", and
# only the log distinguishes them. An errored case never reaches the JSON
# report either, which is the cross-check used by verify_exclusions.
run_cases() {
  local label="$1"; shift
  local log="$OUT_DIR/$label.log"
  local rc=0

  # tee so the output is both visible and kept as evidence.
  rowparity run "$@" "${PASSTHRU[@]+"${PASSTHRU[@]}"}" 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}

  # Anchored to the CLI's exact per-case error line. A bare grep for "ERROR"
  # would also match a diff example whose *data* contains the word -- a status
  # column holding 'ERROR' is entirely plausible in this warehouse, and it would
  # misreport a legitimate finding as a broken run.
  if grep -qE "^Case '.*': ERROR - " "$log"; then
    err "$label (a case failed to run -- see $log)"
    return 1
  fi
  case "$rc" in
    0) ok "$label" ;;
    1) diff_ "$label (cases report differences -- see $OUT_DIR/)" ;;
    *) err "$label (rowparity exited $rc -- see $log)"; return 1 ;;
  esac
  return 0
}

# The exclusion check from the other direction: prove the metadata columns are
# absent from the report, not merely that the run succeeded. A missing or
# misconfigured exclude.csv now raises, but this also catches the case where a
# column was renamed and the exclusion silently stopped applying.
verify_exclusions() {
  local json="$1" label="$2"
  [[ -f "$json" ]] || { err "$label exclusion check (no $json)"; return 1; }
  if "$PY_BIN" - "$json" "$META_COLUMNS" <<'PY'
import json, sys
report, meta = sys.argv[1], json.loads(sys.argv[2])
cases = json.load(open(report))
# An empty report means every case errored before comparing anything. Checking
# "no excluded column appears" against nothing at all passes trivially -- the
# vacuous green this whole feature exists to avoid.
if not cases:
    print("    no cases in the report -- nothing was compared, so this proves nothing")
    sys.exit(2)
leaked_any = False
for case in cases:
    in_scope = (case["compared_columns"] + case["columns_only_in_expected"]
                + case["columns_only_in_actual"] + [t[0] for t in case["type_mismatches"]])
    leaked = [m for m in meta if m in in_scope]
    print(f"    {case['case']:28} {len(in_scope):5} columns in scope   "
          f"excluded_ok={'NO -> ' + str(leaked) if leaked else 'yes'}")
    leaked_any |= bool(leaked)
sys.exit(1 if leaked_any else 0)
PY
  then
    ok "$label exclusion check (no metadata column in scope)"
  else
    local rc=$?
    if [[ $rc -eq 2 ]]; then
      err "$label exclusion check (report is empty -- see above)"
    else
      err "$label exclusion check (excluded columns reached the comparison)"
    fi
    return 1
  fi
}

step_tests() {
  banner "OFFLINE TESTS"
  local rc=0
  pytest -q \
    tests/test_exclusions.py \
    tests/test_bcv_schema_cases.py \
    tests/test_bcv_value_cases.py \
    tests/test_params.py \
    tests/test_param_queries.py \
    tests/test_equivalence.py \
    tests/test_schema_introspect_trino.py \
    tests/test_csv_report.py || rc=$?
  [[ $rc -eq 0 ]] && ok "offline tests" || err "offline tests (pytest exited $rc)"
}

step_demo() {
  banner "EXCLUSION A/B (offline)"
  local d="$OUT_DIR/demo"
  rm -rf "$d" && mkdir -p "$d"
  printf 'table,column\nrequest,__path__\nrequest,__offset__\n' > "$d/exclude.csv"
  cat > "$d/on.yaml" <<'YAML'
name: exclusion_demo
expected:
  type: inline
  rows:
    - {request__transaction_id: "t1", revenue: 10, __path__: "s3://src/a", __offset__: 1}
    - {request__transaction_id: "t2", revenue: 20, __path__: "s3://src/b", __offset__: 2}
actual:
  type: inline
  rows:
    - {request__transaction_id: "t1", revenue: 10, __path__: "s3://bcv/z", __offset__: 99}
    - {request__transaction_id: "t2", revenue: 20, __path__: "s3://bcv/y", __offset__: 98}
compare:
  keys: [request__transaction_id]
  ignore_columns_file: exclude.csv
  ignore_columns_table: request
YAML
  grep -v 'ignore_columns_' "$d/on.yaml" > "$d/off.yaml"

  # Identical data both ways; only the exclusions differ. The OFF run is what
  # makes the ON run meaningful -- without it, ON passing proves nothing.
  echo "  exclusions ON  (metadata columns disagree, must still pass):"
  rowparity run "$d/on.yaml" --json "$d/on.json" 2>&1 | sed 's/^/    /'
  local on=${PIPESTATUS[0]}
  echo "  exclusions OFF (same data, must now fail):"
  rowparity run "$d/off.yaml" 2>&1 | sed 's/^/    /'
  local off=${PIPESTATUS[0]}

  if [[ $on -eq 0 && $off -ne 0 ]]; then
    ok "exclusion A/B (on=pass off=fail, as required)"
  else
    err "exclusion A/B (on=$on off=$off; expected on=0 and off!=0)"
  fi

  # Exercises the same report-level check the live steps use, so its success
  # path is covered without a cluster. Offline, this is the only place it runs.
  verify_exclusions "$d/on.json" "demo"
}

step_connect() {
  banner "TRINO CONNECTIVITY"
  needs_live "connectivity" || return 1
  local rc=0
  "$PY_BIN" scripts/trino_connectivity_check.py 2>&1 | tee "$OUT_DIR/connect.log" || true
  rc=${PIPESTATUS[0]}
  [[ $rc -eq 0 ]] && ok "connectivity" || err "connectivity (exited $rc -- see $OUT_DIR/connect.log)"
}

step_columns() {
  banner "BATCH COLUMN NAMES"
  needs_live "batch columns" || return 1
  local rc=0
  "$PY_BIN" scripts/find_batch_column.py 2>&1 | tee "$OUT_DIR/columns.log" || true
  rc=${PIPESTATUS[0]}
  if grep -q 'MISSING' "$OUT_DIR/columns.log"; then
    # Not fatal on its own: it names what to pass as --param. But running the
    # value cases against a wrong column wastes a whole round trip, so say so.
    err "batch columns (a configured name does not exist -- see $OUT_DIR/columns.log)"
    return 1
  fi
  [[ $rc -eq 0 ]] && ok "batch columns" || err "batch columns (exited $rc)"
}

step_schema() {
  banner "SCHEMA PARITY (zero rows read)"
  needs_live "schema cases" || return 1
  run_cases schema examples/cases_bcv/schema_parity.yaml \
    --csv "$OUT_DIR/schema" --json "$OUT_DIR/schema.json" --md "$OUT_DIR/schema.md" \
    && verify_exclusions "$OUT_DIR/schema.json" "schema"
}

step_value() {
  banner "VALUE PARITY (samples rows)"
  needs_live "value cases" || return 1
  # batch_id resolves itself from the warehouse; pass --param batch_id=... in
  # the passthrough to pin a specific one instead.
  run_cases value examples/cases_bcv/value_parity.yaml \
    --csv "$OUT_DIR/value" --json "$OUT_DIR/value.json" --md "$OUT_DIR/value.md" \
    && verify_exclusions "$OUT_DIR/value.json" "value"
}

# python3 on a bare system, python inside a venv. Pick once rather than
# assuming, so the exclusion check does not fail for a missing alias.
PY_BIN="$(command -v python3 || command -v python)"
[[ -z "$PY_BIN" ]] && { echo "no python interpreter on PATH" >&2; exit 3; }

command -v rowparity >/dev/null 2>&1 || {
  echo "rowparity is not on PATH. Install it first:" >&2
  echo '  pip install -e ".[duckdb,test]"    # in a venv' >&2
  exit 3
}
mkdir -p "$OUT_DIR" || exit 3

printf '%srowparity BCV suite%s  steps: %s  reports: %s/\n' \
  "$C_BOLD" "$C_RESET" "${STEPS[*]}" "$OUT_DIR"

for step in "${STEPS[@]}"; do
  "step_$step"
done

banner "SUMMARY"
[[ ${#PASSED[@]}   -gt 0 ]] && printf '%s  passed%s      %s\n' "$C_GREEN"  "$C_RESET" "${#PASSED[@]}"
[[ ${#DIFFERED[@]} -gt 0 ]] && printf '%s  differences%s %s\n' "$C_YELLOW" "$C_RESET" "${DIFFERED[*]}"
[[ ${#ERRORED[@]}  -gt 0 ]] && printf '%s  errors%s      %s\n' "$C_RED"    "$C_RESET" "${ERRORED[*]}"
echo "  reports:     $OUT_DIR/"

if [[ ${#ERRORED[@]} -gt 0 ]]; then
  echo
  echo "One or more steps could not run. That is a configuration or connection"
  echo "problem, not a data finding -- fix it before reading the reports."
  exit 1
fi
if [[ ${#DIFFERED[@]} -gt 0 ]]; then
  echo
  echo "Every step ran. Differences were found, which is the expected answer"
  echo "while the migration is incomplete -- read $OUT_DIR/ for the detail."
  [[ $STRICT -eq 1 ]] && exit 2
fi
exit 0
