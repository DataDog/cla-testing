#!/usr/bin/env bash
# Deterministic recheck soak: posts `recheck` comments on a pull request and
# classifies the CLA workflow runs triggered by each comment.
#
# In the all-signed state, every recheck re-executes the legacy action's
# workflow-ID lookup (a paginated listing of all repository workflows). A
# pagination miss fails the run with "Unable to locate this workflow's ID in
# this repository, can't trigger job." - the failure mode under test.
#
# Usage: soak-recheck.sh <pr-number> <cycles> <output-csv>
set -uo pipefail

REPO="DataDog/cla-testing"
PR="${1:?pr number required}"
CYCLES="${2:?cycle count required}"
OUT="${3:?output csv required}"

mkdir -p "$(dirname "$OUT")"
echo "cycle,variant,run_id,conclusion,classification" > "$OUT"

completed_ids() {
  gh run list --repo "$REPO" --event issue_comment --limit 30 \
    --json databaseId,status --jq '[.[] | select(.status == "completed") | .databaseId] | @tsv' | tr '\t' '\n'
}

classify() {
  local run_id="$1" conclusion variant log
  variant=$(gh api "repos/$REPO/actions/runs/$run_id" --jq '.name')
  conclusion=$(gh api "repos/$REPO/actions/runs/$run_id" --jq '.conclusion')
  log=$(gh run view "$run_id" --repo "$REPO" --log 2>/dev/null || true)
  local cls="other"
  if echo "$log" | grep -q "Unable to locate this workflow"; then
    cls="workflow-id-miss"
  elif echo "$log" | grep -q "Could not update the JSON file"; then
    cls="signature-write-error"
  elif echo "$log" | grep -q "All contributors have signed the CLA"; then
    cls="all-signed-ok"
  elif echo "$log" | grep -q "have to sign the CLA"; then
    cls="unsigned"
  fi
  printf '%s,"%s",%s,%s,%s\n' "$CYCLE_CUR" "$variant" "$run_id" "$conclusion" "$cls" >> "$OUT"
}

for CYCLE_CUR in $(seq 1 "$CYCLES"); do
  before=$(completed_ids | sort)
  gh api "repos/$REPO/issues/$PR/comments" -f body='recheck' >/dev/null 2>&1

  ok=0
  for _ in $(seq 1 40); do
    sleep 15
    after=$(completed_ids | sort)
    new=$(comm -13 <(echo "$before") <(echo "$after"))
    count=$(echo "$new" | grep -c . || true)
    if [ "$count" -ge 3 ]; then ok=1; break; fi
  done

  if [ "$ok" -ne 1 ]; then
    printf '%s,,,,timeout-waiting-for-runs\n' "$CYCLE_CUR" >> "$OUT"
    continue
  fi

  for id in $new; do
    classify "$id"
  done
  echo "cycle $CYCLE_CUR done: $(grep -c "^$CYCLE_CUR," "$OUT") runs classified"
done

echo "SOAK COMPLETE"
echo "=== summary ==="
tail -n +2 "$OUT" | awk -F',' '{print $NF}' | sort | uniq -c
