#!/usr/bin/env bash
# Run a rowparity suite end to end without a scheduler, the way the Airflow DAG does:
#   list the pairs -> run them N at a time, each publishing its own result -> summarize.
#
# Usage:
#   scripts/rowparity_flow.sh SUITE --publish DEST [--limit N | --group I/N | --cases FILE]
#                             [--workers 5] [--run-id ID] [--presto] [--date YYYY-MM-DD]
#                             [--batch <id>] [--param name=value] [--client-tags TAGS]
#
# Client tags pick the cluster the Presto gateway routes to. They apply to every
# connection in the run (each pair, summarize, any batch lookup): --client-tags, else
# TRINO_CLIENT_TAGS, else hoover_regression. A case's own connection.client_tags
# still wins for that case.
#
# The batch: resolved once and pinned for every case, so one run measures every
# test on the same data. A batch_params.py beside the suite renders the ids for
# a run date (--date, default today); failing that, the suite's param_queries.
# --batch <id> pins a specific hour instead, which makes two runs directly
# comparable -- the same rows, so any difference is the code, not the data.
#
# Examples:
#   scripts/rowparity_flow.sh examples/flow_demo/rowparity.yaml --publish ./flow-test --limit 10
#   scripts/rowparity_flow.sh suite/rowparity.yaml --publish s3://bucket/sandbox --group 2/7 --presto
#
# Cron: one line per weekday, naming that day's suites. schedule.yaml beside the
# suite has the mapping; a two-suite day concatenates the lists.
#   0 2 * * 1 cd /opt/rowparity && scripts/rowparity_flow.sh suite/rowparity.yaml \
#             --publish s3://bucket/rowparity --cases suite/suites/hoover_auction.txt --presto
#   0 2 * * 3 cd /opt/rowparity && scripts/rowparity_flow.sh suite/rowparity.yaml \
#             --publish s3://bucket/rowparity --presto \
#             --cases <(cat suite/suites/hoover_ack_delivery_events.txt suite/suites/hoover_slot.txt)
#
# Exit code is summarize's: 0 all passed, 1 something failed or never reported, 2 could not run.
# Per-pair logs go to $LOG_DIR (default ./rowparity-logs/<run_id>).
set -euo pipefail

die() { echo "rowparity_flow: $*" >&2; exit 2; }

[ $# -ge 1 ] || die "usage: rowparity_flow.sh SUITE --publish DEST [--limit N|--group I/N|--cases FILE] [--workers N] [--run-id ID] [--date YYYY-MM-DD] [--batch ID] [--presto] [--client-tags TAGS]"
SUITE=$1; shift
DEST=${ROWPARITY_PUBLISH_URI:-}
WORKERS=5
LIMIT=""
GROUP=""
CASES=""
PRESTO=""
PARAMS=""
BATCH_PARAM=""
CLIENT_TAGS=${TRINO_CLIENT_TAGS:-hoover_regression}
RUN_DATE=""
RUN_ID="local-$(date -u +%Y%m%dT%H%M%S)"
ROWPARITY_BIN=${ROWPARITY_BIN:-rowparity}

while [ $# -gt 0 ]; do
  case "$1" in
    --publish) DEST=$2; shift 2 ;;
    --limit)   LIMIT=$2; shift 2 ;;
    --group)   GROUP=$2; shift 2 ;;
    --cases)   CASES=$2; shift 2 ;;
    --workers) WORKERS=$2; shift 2 ;;
    --run-id)  RUN_ID=$2; shift 2 ;;
    --presto)  PRESTO="--presto"; shift ;;
    --param)   PARAMS="$PARAMS --param $2"; shift 2 ;;
    --batch)   BATCH_PARAM="$2"; shift 2 ;;
    --date)    RUN_DATE="$2"; shift 2 ;;
    --client-tags) CLIENT_TAGS=$2; shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done
[ -n "$DEST" ] || die "--publish DEST (or ROWPARITY_PUBLISH_URI) is required"
# Exported before the first rowparity call, so every connection is routed alike.
export TRINO_CLIENT_TAGS=$CLIENT_TAGS
echo "Client tags: $TRINO_CLIENT_TAGS"

# One slice for the whole run: resolved once here, pinned for every case, and
# recorded in each result. Resolving per case would let a batch land mid-run
# and leave half the suite measured on different data.
#
# batch_params.py renders every id the suite's slice needs. Pinning batch_id
# alone would leave the earlier ones on their defaults, so --batch goes through
# the same script rather than straight into --param.
SUITE_DIR=$(cd "$(dirname "$SUITE")" && pwd)
if [ -f "$SUITE_DIR/batch_params.py" ]; then
  PARAM_LINES=$(python3 "$SUITE_DIR/batch_params.py" ${BATCH_PARAM:-$RUN_DATE}) \
    || die "batch_params.py could not resolve the batch ids"
  # Each line is name=value, digits only: safe to split on whitespace.
  for line in $PARAM_LINES; do PARAMS="$PARAMS --param $line"; done
  echo "Slice: $(echo "$PARAM_LINES" | tr '\n' ' ')"
elif [ -n "$BATCH_PARAM" ]; then
  PARAMS="$PARAMS --param batch_id=$BATCH_PARAM"
  echo "Batch: $BATCH_PARAM"
elif grep -q "^param_queries:" "$SUITE" 2>/dev/null; then
  BATCH_PARAM=$($ROWPARITY_BIN param "$SUITE" batch_id) || die "could not resolve batch_id"
  PARAMS="$PARAMS --param batch_id=$BATCH_PARAM"
  echo "Batch: $BATCH_PARAM"
fi

LOG_DIR=${LOG_DIR:-./rowparity-logs/$RUN_ID}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$LOG_DIR"

if [ -n "$CASES" ]; then
  grep -v '^[[:space:]]*$' "$CASES" > "$WORK/cases.txt"
else
  # shellcheck disable=SC2086
  $ROWPARITY_BIN list "$SUITE" ${GROUP:+--group "$GROUP"} --format names > "$WORK/cases.txt"
fi
if [ -n "$LIMIT" ]; then
  head -n "$LIMIT" "$WORK/cases.txt" > "$WORK/limited.txt" && mv "$WORK/limited.txt" "$WORK/cases.txt"
fi

COUNT=$(wc -l < "$WORK/cases.txt" | tr -d ' ')
echo "Running $COUNT SQL pair(s), $WORKERS at a time, run_id $RUN_ID"
echo "Publishing to $DEST; logs in $LOG_DIR"

export SUITE RUN_ID LOG_DIR ROWPARITY_BIN PARAMS
export ROWPARITY_PUBLISH_URI=$DEST
# -n 1 rather than -I{}: BSD xargs on macOS caps -I commands at 255 bytes.
# A failing pair must not stop the others, so xargs' own exit status is ignored.
xargs -n 1 -P "$WORKERS" sh -c '
  $ROWPARITY_BIN run "$SUITE" --select "$1" --quiet --run-id "$RUN_ID" $PARAMS > "$LOG_DIR/$1.log" 2>&1
  echo "  $(head -n 1 "$LOG_DIR/$1.log")"
' _ < "$WORK/cases.txt" || true

echo
set +e
# shellcheck disable=SC2086
$ROWPARITY_BIN summarize --run-id "$RUN_ID" --expect "$WORK/cases.txt" $PRESTO
exit $?
