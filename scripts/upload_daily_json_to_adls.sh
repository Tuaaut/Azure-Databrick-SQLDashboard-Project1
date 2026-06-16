#!/usr/bin/env bash
set -euo pipefail

if [[ -f .azure_resources.env ]]; then
  # shellcheck disable=SC1091
  source .azure_resources.env
fi

STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-${STORAGE:-}}"
CONTAINER="${CONTAINER:-raw}"
BUSINESS_DATE="${BUSINESS_DATE:-$(date -u -v-1d +%F 2>/dev/null || date -u -d yesterday +%F)}"
LOCAL_FILE="${LOCAL_FILE:-data/raw/qr_printing/start_date=${BUSINESS_DATE}/machine_api_response.json}"
BLOB_PATH="${BLOB_PATH:-qr_printing/uploaded_at=manual/start_date=${BUSINESS_DATE}/machine_api_response.json}"

if [[ -z "$STORAGE_ACCOUNT" ]]; then
  echo "Set STORAGE_ACCOUNT or STORAGE before running."
  exit 1
fi

if [[ ! -f "$LOCAL_FILE" ]]; then
  echo "Missing local file: $LOCAL_FILE"
  echo "Generate it first:"
  echo "python3 scripts/generate_daily_machine_json.py --date $BUSINESS_DATE"
  exit 1
fi

az storage blob upload \
  --auth-mode login \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --file "$LOCAL_FILE" \
  --name "$BLOB_PATH" \
  --overwrite true
