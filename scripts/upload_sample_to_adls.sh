#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-qr-dbx-demo}"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-}"
CONTAINER="${CONTAINER:-raw}"
LOCAL_FILE="${LOCAL_FILE:-data/raw/qr_printing/sample_machine_api_response.json}"
BLOB_PATH="${BLOB_PATH:-qr_printing/uploaded_at=manual/start_hour=2026-06-16T08/sample_machine_api_response.json}"

if [[ -z "$STORAGE_ACCOUNT" ]]; then
  echo "Set STORAGE_ACCOUNT before running."
  exit 1
fi

az storage blob upload \
  --auth-mode login \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --file "$LOCAL_FILE" \
  --name "$BLOB_PATH" \
  --overwrite true

