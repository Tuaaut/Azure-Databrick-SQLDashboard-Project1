# Azure Resources

Created on 2026-06-16.

## Subscription

- Name: Azure subscription 1
- ID: c3136072-0e2e-4a2d-b5a5-b00700a61661
- Tenant: ISS

## Resource Group

- Name: `rg-qr-dbx-demo`
- Location: `southeastasia`

## ADLS Gen2 Storage

- Storage account: `qrdbx06162114`
- Container: `raw`
- Hierarchical namespace: enabled
- Public blob access: disabled
- Sample payload path:

```text
raw/qr_printing/uploaded_at=manual/start_hour=2026-06-16T08/sample_machine_api_response.json
```

- Generated daily payload path:

```text
raw/qr_printing/uploaded_at=manual/start_date=2026-06-15/machine_api_response.json
```

Generated daily payload counts:

```text
print_events: 2880
machine_telemetry: 1440
machine_logs: 67
```

## Azure Databricks

- Workspace: `adb-qr-printing-demo`
- SKU: `premium`
- Unity Catalog enabled: yes
- Project catalog: `adb_qr_printing_demo`
- Workspace URL:

```text
https://adb-7405612371776871.11.azuredatabricks.net
```

## Azure Function Raw Generator

- Local scaffold: `azure_function/`
- Intended trigger: timer
- Intended schedule: `0 0 0 * * *`
- Schedule meaning: 00:00 UTC / 07:00 Bangkok daily
- Intended target storage: `qrdbx06162114`
- Intended target container: `raw`
- Intended auth: Azure Function managed identity
- Required role: `Storage Blob Data Contributor` on the target storage account
- Function app: `func-qr-daily-740561`
- Function host storage account: `qrfunc7405610617`
- Managed identity principal ID: `28a35307-9f78-4b6d-baae-80eb0784e31e`
- Role assignment: `Storage Blob Data Contributor` on `qrdbx06162114`
- Current status: Azure resources created, Function code indexed, and manual trigger verified
- Indexed functions:

```text
ManualGenerate
TimerGenerate
```

Verified manual output:

```text
raw/qr_printing/uploaded_at=azure_function_manual/machine_api_response.json
size: 1525874 bytes
print_events: 2880
machine_telemetry: 1440
machine_logs: 67
business window: 2026-06-15T00:00:00Z to 2026-06-16T00:00:00Z
```

Scheduled daily output:

```text
raw/qr_printing/uploaded_at=azure_function/machine_api_response.json
```

Deployment helper:

```text
scripts/deploy_azure_function_daily_generator.sh
```

## Databricks CLI

- Installed with Homebrew: `databricks` v1.3.0
- Auth verified with Azure login for user `pattaraworaphu@pattaraworaphu.onmicrosoft.com`

## Manual Compute Attempt

On 2026-06-16, three single-node cluster attempts were made and then terminated:

- `Standard_D2ads_v6`: stayed pending while acquiring instances
- `Standard_D2ds_v6`: stayed pending while acquiring instances
- `Standard_D4s_v3`: stayed pending while acquiring instances

All three clusters are terminated. No cluster is running.

## Serverless SQL Warehouse

- Warehouse: `Serverless Starter Warehouse`
- ID: `a10d49c1b859854a`
- Size: `Small`
- Serverless: enabled
- Auto-stop: 10 minutes
- Current verified state after setup: `STOPPED`

## Verified Medallion Objects

Created and verified through serverless SQL after the real-data test run:

```text
adb_qr_printing_demo.bronze_qr_printing.print_events_raw: 2880 rows
adb_qr_printing_demo.bronze_qr_printing.machine_telemetry_raw: 1440 rows
adb_qr_printing_demo.bronze_qr_printing.machine_logs_raw: 67 rows
adb_qr_printing_demo.silver_qr_printing.fact_print_event: 2880 rows
adb_qr_printing_demo.silver_qr_printing.fact_machine_telemetry_minute: 1440 rows
adb_qr_printing_demo.silver_qr_printing.fact_machine_log: 67 rows
adb_qr_printing_demo.silver_qr_printing.dim_machine: 1 row
adb_qr_printing_demo.silver_qr_printing.dim_product: 1 row
adb_qr_printing_demo.gold_qr_printing.hourly_kpi_summary: 24 rows
adb_qr_printing_demo.gold_qr_printing.machine_health_summary: 24 rows
adb_qr_printing_demo.gold_qr_printing.downtime_fault_summary: 20 rows
```

Production overview KPI check:

```text
latest_production_hour: 2026-06-15T23:00:00.000Z
machine_id: M01
items_processed: 2880
avg_reject_rate_pct: 9.55
avg_qr_read_rate_pct: 98.23
avg_quality_pct: 90.45
```

## Saved Databricks SQL Queries

- `QR Production Overview`: `032c9491-fefe-47d4-90b1-7f204dee2a2c`
- `QR Machine Health`: `57b516d8-0e4b-4a33-b672-bf097c21f812`
- `QR Downtime and Faults`: `039687cc-b864-4ead-a420-4932b1a18a10`

## AI/BI Dashboard

- Draft dashboard: `QR Printing Lakehouse Dashboard`
- Dashboard ID: `01f1699203951f9389c58c97cd030c79`
- Published with embedded owner credentials
- Pages created:

```text
Production Overview
Machine Health
Downtime and Faults
```

- Published URL:

```text
https://adb-7405612371776871.11.azuredatabricks.net/dashboardsv3/01f1699203951f9389c58c97cd030c79/published
```

Dashboard widgets were created programmatically and the dashboard was republished.

Verified widget counts:

```text
Production Overview: 6 widgets
Machine Health: 5 widgets
Downtime and Faults: 5 widgets
```

## Databricks Workflow

- Workflow name: `qr-printing-medallion-manual`
- Job ID: `383404437598073`
- Trigger: manual only
- Tasks:

```text
01_ingest_bronze
→ 02_transform_silver
→ 03_build_gold
```

- Compute: temporary single-node job cluster
- Current status: workflow created but not run because all-purpose/job cluster capacity is currently blocked in Southeast Asia.

## Paused Daily Databricks Workflow

- Workflow name: `qr-printing-medallion-daily-paused`
- Job ID: `67401473932489`
- Trigger: scheduled, but paused
- Schedule: `07:00 Bangkok daily`
- Pause status: `PAUSED`
- Tasks:

```text
01_ingest_bronze
→ 02_transform_silver
→ 03_build_gold
```

- Compute: temporary single-node job cluster
- Current status: created and paused. It will not run or create cluster cost until unpaused or triggered manually.
- Important limitation: this uses the PySpark notebook path, so it still depends on Azure Databricks cluster capacity becoming available.

## Serverless SQL Workflow

- Workflow name: `qr-printing-serverless-sql-daily-refresh`
- Job ID: `205329090700528`
- Latest verified run ID: `811234223268645`
- Result: `SUCCESS`
- Schedule: `07:10 Bangkok daily`
- Pause status: `UNPAUSED`
- Databricks job email notifications: success/failure
- Notification recipient:

```text
Pattaratua@gmail.com
```
- Tasks:

```text
refresh_medallion_sql_notebook
→ refresh_dashboard
→ create_pipeline_audit_email_payload
```

- Compute: `Serverless Starter Warehouse`
- Current status: workflow scheduled, unpaused, and successfully test-run.

## Databricks Alerting and Monitoring

- Schema: `adb_qr_printing_demo.ops_qr_printing`
- SQL source: `sql/pipeline_audit_monitoring.sql`
- Run audit table: `pipeline_run_audit`
- Stage audit table: `pipeline_stage_audit`
- Email outbox table: `email_alert_outbox`
- Latest alert view: `latest_pipeline_alert_email`
- Latest run view: `latest_pipeline_run_summary`
- Current email recipient hint: `Pattaratua@gmail.com`
- Current delivery status: `INTERNAL_AUDIT_ONLY`
- Databricks job-level success/failure email notifications are enabled separately from this stored audit summary.

Verified real-data audit stage summary:

```text
ADLS_RAW: total 4387, new 4387, SUCCESS
BRONZE: total 4387, new 4382, SUCCESS
SILVER: total 4387, new 4382, SUCCESS
GOLD: total 68, new 65, SUCCESS
```

Detailed alerting notes:

```text
docs/alerting_monitoring.md
```

Earlier attempted SQL file workflow:

- Workflow name: `qr-printing-serverless-sql-refresh-manual`
- Job ID: `273117550895567`
- Status: not recommended; SQL file task could not fetch the imported SQL notebook path.

## Current Compute State

Verified after setup:

```text
All attempted all-purpose clusters: TERMINATED
SQL Warehouse Serverless Starter Warehouse: STOPPED
```

## Azure Budgets

The original broad resource-group budget `qr-dbx-demo-monthly-20` was deleted because it covered the full project resource group, not only Databricks.

Current Databricks-focused budgets:

```text
qr-dbx-workspace-monthly-20
qr-dbx-managed-compute-monthly-20
```

Workspace budget:

- Name: `qr-dbx-workspace-monthly-20`
- Amount: `$20`
- Filter: Databricks workspace resource ID
- Resource: `/subscriptions/c3136072-0e2e-4a2d-b5a5-b00700a61661/resourceGroups/rg-qr-dbx-demo/providers/Microsoft.Databricks/workspaces/adb-qr-printing-demo`

Managed compute budget:

- Name: `qr-dbx-managed-compute-monthly-20`
- Amount: `$20`
- Filter: Databricks-managed resource group
- Resource group: `databricks-rg-adb-qr-printing-demo-ajz5s9prssap1`

Shared alert settings:

- Time grain: monthly
- Period: `2026-06-01` to `2027-06-30`
- Email alerts: 50% and 90%
- Alert recipient: `Pattaratua@gmail.com`

Scope note:

```text
These budgets are Databricks-focused and exclude Fabric. They also exclude the ADLS storage account in rg-qr-dbx-demo.
```
