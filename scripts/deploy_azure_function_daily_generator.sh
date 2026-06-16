#!/usr/bin/env bash
set -euo pipefail

if [[ -f .azure_resources.env ]]; then
  # shellcheck disable=SC1091
  source .azure_resources.env
fi

RESOURCE_GROUP="${RESOURCE_GROUP:-${RG:-rg-qr-dbx-demo}}"
LOCATION="${LOCATION:-southeastasia}"
TARGET_STORAGE_ACCOUNT="${TARGET_STORAGE_ACCOUNT:-${STORAGE:-qrdbx06162114}}"
TARGET_CONTAINER="${TARGET_CONTAINER:-raw}"
FUNCTION_STORAGE_ACCOUNT="${FUNCTION_STORAGE_ACCOUNT:-qrfunc$(date +%m%d%H%M%S)}"
FUNCTION_APP_NAME="${FUNCTION_APP_NAME:-func-qr-daily-$(date +%m%d%H%M%S)}"
FUNCTIONS_VERSION="${FUNCTIONS_VERSION:-4}"
PYTHON_VERSION="${PYTHON_VERSION:-3.11}"
QR_TIMER_SCHEDULE="${QR_TIMER_SCHEDULE:-0 0 0 * * *}"
PACKAGE_DIR="${PACKAGE_DIR:-/tmp/qr_daily_function_pkg}"
PACKAGE_PATH="${PACKAGE_PATH:-/tmp/qr_daily_function.zip}"

az storage account create \
  --name "$FUNCTION_STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

az functionapp create \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --storage-account "$FUNCTION_STORAGE_ACCOUNT" \
  --consumption-plan-location "$LOCATION" \
  --runtime python \
  --runtime-version "$PYTHON_VERSION" \
  --functions-version "$FUNCTIONS_VERSION" \
  --os-type Linux \
  --assign-identity

principal_id="$(az functionapp identity show \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId \
  -o tsv)"

target_storage_id="$(az storage account show \
  --name "$TARGET_STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query id \
  -o tsv)"

az role assignment create \
  --assignee "$principal_id" \
  --role "Storage Blob Data Contributor" \
  --scope "$target_storage_id"

az functionapp config appsettings set \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings \
    "QR_TIMER_SCHEDULE=$QR_TIMER_SCHEDULE" \
    "TARGET_STORAGE_CONNECTION__blobServiceUri=https://${TARGET_STORAGE_ACCOUNT}.blob.core.windows.net" \
    "QR_LINE_ID=line-01" \
    "QR_MACHINE_ID=M01" \
    "QR_PRODUCT_ID=SKU-COLA-330" \
    "QR_PRODUCT_NAME=Cola Can 330ml" \
    "QR_PLANNED_SPEED_CPM=84.0" \
    "QR_EVENTS_PER_HOUR=120" \
    "AzureWebJobsFeatureFlags=EnableWorkerIndexing"

rm -rf "$PACKAGE_DIR" "$PACKAGE_PATH"
mkdir -p "$PACKAGE_DIR"
cp azure_function/host.json azure_function/requirements.txt azure_function/qr_generator.py "$PACKAGE_DIR/"
cp -R azure_function/TimerGenerate azure_function/ManualGenerate "$PACKAGE_DIR/"
(cd "$PACKAGE_DIR" && zip -qr "$PACKAGE_PATH" .)

function_storage_key="$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$FUNCTION_STORAGE_ACCOUNT" \
  --query '[0].value' \
  -o tsv)"

az storage container create \
  --account-name "$FUNCTION_STORAGE_ACCOUNT" \
  --account-key "$function_storage_key" \
  --name function-releases \
  -o none

package_blob="qr-function-$(date -u +%Y%m%dT%H%M%SZ).zip"

az storage blob upload \
  --account-name "$FUNCTION_STORAGE_ACCOUNT" \
  --account-key "$function_storage_key" \
  --container-name function-releases \
  --name "$package_blob" \
  --file "$PACKAGE_PATH" \
  --overwrite true \
  -o none

package_expiry="$(python3 - <<'PY'
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc) + timedelta(days=3650)).strftime("%Y-%m-%dT%H:%MZ"))
PY
)"

package_sas="$(az storage blob generate-sas \
  --account-name "$FUNCTION_STORAGE_ACCOUNT" \
  --account-key "$function_storage_key" \
  --container-name function-releases \
  --name "$package_blob" \
  --permissions r \
  --expiry "$package_expiry" \
  -o tsv)"

package_url="https://${FUNCTION_STORAGE_ACCOUNT}.blob.core.windows.net/function-releases/${package_blob}?${package_sas}"

az functionapp config appsettings set \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings "WEBSITE_RUN_FROM_PACKAGE=$package_url" \
  -o none

az functionapp restart \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  -o none

az rest \
  --method post \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${FUNCTION_APP_NAME}/syncfunctiontriggers?api-version=2022-03-01" \
  -o none

cat <<EOF
Azure Function deployed.

Function app: $FUNCTION_APP_NAME
Function storage: $FUNCTION_STORAGE_ACCOUNT
Target ADLS storage: $TARGET_STORAGE_ACCOUNT
Target container: $TARGET_CONTAINER
Schedule: $QR_TIMER_SCHEDULE
Package blob: $package_blob
EOF
