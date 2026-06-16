#!/usr/bin/env bash
set -euo pipefail

SQL_FILE="${1:-sql/serverless_manual_bootstrap.sql}"
WAREHOUSE_ID="${WAREHOUSE_ID:-a10d49c1b859854a}"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "SQL file not found: $SQL_FILE"
  exit 1
fi

awk 'BEGIN { RS=";"; ORS="" } NF { print $0 "\036" }' "$SQL_FILE" |
while IFS= read -r -d $'\036' statement; do
  trimmed="$(printf '%s' "$statement" | sed '/^[[:space:]]*--/d' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [[ -z "$trimmed" ]]; then
    continue
  fi

  preview="$(printf '%s' "$trimmed" | sed '/^[[:space:]]*$/d' | head -n 1 | cut -c1-100)"
  echo "Running SQL: $preview"
  payload_file="$(mktemp)"
  trap 'rm -f "$payload_file"' EXIT
  jq -n \
    --arg warehouse_id "$WAREHOUSE_ID" \
    --arg statement "$trimmed" \
    '{warehouse_id: $warehouse_id, statement: $statement, wait_timeout: "50s", on_wait_timeout: "CONTINUE"}' > "$payload_file"

  response="$(
    databricks api post /api/2.0/sql/statements --json @"$payload_file"
  )"
  rm -f "$payload_file"
  trap - EXIT

  state="$(printf '%s' "$response" | jq -r '.status.state')"
  if [[ "$state" != "SUCCEEDED" ]]; then
    printf '%s\n' "$response" | jq .
    echo "SQL failed with state: $state"
    exit 1
  fi
done
