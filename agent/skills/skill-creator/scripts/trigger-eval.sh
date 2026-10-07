#!/usr/bin/env bash
#
# trigger-eval.sh — measure how reliably a skill's description triggers.
#
# Usage: trigger-eval.sh <queries.json> <skill-name> [runs]
#
# queries.json is an array of { "query": "...", "should_trigger": true|false }.
# Aim for ~20 queries: 8-10 should-trigger, 8-10 should-not-trigger (near
# misses are the valuable negatives). See references/trigger-evals.md.
#
# Env:
#   TRIGGER_EVAL_CMD    run template (default: opencode run --format json --pure)
#   TRIGGER_EVAL_DUMP   dir to keep raw outputs (default: a temp dir, kept)
#   TRIGGER_EVAL_THRESHOLD  pass threshold, default 0.5
#
# Exit: 0 all queries pass, 1 some failed, 2 usage error.
#
# DETECTION IS A HEURISTIC. The default looks for a skill-tool invocation
# naming the skill. opencode's --format json event schema may differ by
# version, so before trusting the numbers run one query with the raw output
# kept and read it:
#
#     TRIGGER_EVAL_DUMP=/tmp/te bash trigger-eval.sh queries.json my-skill 1
#     less /tmp/te/*.out
#
# then edit detect_triggered() below to match what you actually see.

set -uo pipefail

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

[ $# -ge 2 ] || usage
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required" >&2; exit 2; }

QUERIES="$1"
SKILL="$2"
RUNS="${3:-3}"
CMD="${TRIGGER_EVAL_CMD:-opencode run --format json --pure}"
DUMP="${TRIGGER_EVAL_DUMP:-$(mktemp -d)}"
THRESHOLD="${TRIGGER_EVAL_THRESHOLD:-0.5}"

[ -f "$QUERIES" ] || { echo "FAIL: no such queries file: $QUERIES" >&2; exit 2; }
mkdir -p "$DUMP"

detect_triggered() {
  local out="$1" skill="$2"
  # Best-effort default: a skill-tool invocation that names the skill.
  # Tune against a dumped run if your opencode build emits a different shape.
  grep -Eq '"tool"[[:space:]]*:[[:space:]]*"skill"' "$out" \
    && grep -q "$skill" "$out"
}

echo "# Trigger eval — skill '$SKILL', $RUNS runs/query, threshold $THRESHOLD"
echo "# Command: $CMD"
echo "# Raw outputs: $DUMP"
echo ""

count=$(jq 'length' "$QUERIES")
failed=0
i=0
while [ "$i" -lt "$count" ]; do
  query=$(jq -r ".[$i].query" "$QUERIES")
  should=$(jq -r ".[$i].should_trigger" "$QUERIES")
  triggers=0
  run=1
  while [ "$run" -le "$RUNS" ]; do
    out="$DUMP/q${i}_r${run}.out"
    # shellcheck disable=SC2086
    eval $CMD "\"\$query\"" >"$out" 2>&1
    if detect_triggered "$out" "$SKILL"; then
      triggers=$((triggers + 1))
    fi
    run=$((run + 1))
  done

  rate=$(awk -v t="$triggers" -v r="$RUNS" 'BEGIN { printf "%.2f", t/r }')
  pass=$(awk -v rate="$rate" -v should="$should" -v th="$THRESHOLD" \
    'BEGIN { print (should=="true" ? (rate+0>=th) : (rate+0<th)) ? "PASS" : "FAIL" }')
  [ "$pass" = "FAIL" ] && failed=$((failed + 1))

  printf '%-5s should_trigger=%-5s rate=%s  %s\n' "$pass" "$should" "$rate" "$query"
  i=$((i + 1))
done

echo ""
if [ "$failed" -eq 0 ]; then
  echo "ALL PASS ($count queries)"
  exit 0
fi
echo "$failed of $count queries FAILED"
echo "Revise the description: broaden when should-trigger queries miss, add an"
echo "explicit boundary when should-not-trigger queries fire. Do not paste the"
echo "failed queries' keywords in — address the general category instead."
exit 1
