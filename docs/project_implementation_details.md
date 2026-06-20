# Industrial IoT QR Printing Lakehouse on Azure Databricks

This project is a cost-controlled Azure Databricks showcase for QR printing machine analytics.

It uses a simulated manufacturing scenario:

- one row per printed QR item
- one row per minute for machine telemetry
- machine warning/fault logs
- production, QR quality, machine health, downtime, and OEE-style KPIs

Business timestamps in Bronze, Silver, Gold, and latest monitoring views are stored as Bangkok-local `TIMESTAMP_NTZ` values to avoid manual UTC conversion in Databricks SQL results.

## Short Version

The original plan was to build the medallion pipeline with PySpark notebooks on a temporary Databricks job cluster.

That PySpark path was prepared, but could not be run because Azure Databricks could not acquire the tested VM sizes in Southeast Asia.

To avoid waiting, the same Bronze/Silver/Gold and dashboard outcome was completed with Databricks Serverless SQL Warehouse.

Current working path:

```text
Serverless SQL
→ daily JSON files in ADLS through a Unity Catalog external location
→ incremental Bronze MERGE
→ incremental Silver MERGE
→ Gold KPI views
→ AI/BI dashboard with widgets
→ Serverless SQL workflow refresh
→ Ops audit tables and email-ready alert payload
→ Databricks job success/failure email notification
```

## What Is Done

- Local project scaffold created.
- Sample QR printing data created.
- Azure resource group created.
- ADLS Gen2 storage account and `raw` container created.
- Sample JSON uploaded to ADLS.
- Databricks workspace created.
- Databricks CLI installed and authenticated.
- PySpark notebooks created and uploaded.
- PySpark Databricks Workflow created.
- Serverless SQL Warehouse verified.
- Bronze/Silver/Gold tables and views created through Serverless SQL.
- Serverless SQL daily ingestion now reads raw JSON directly from ADLS and merges rows instead of rebuilding the full accumulated demo range.
- Row counts and KPI output verified.
- Saved SQL queries created.
- AI/BI dashboard created, published, and populated with widgets.
- Working Serverless SQL workflow created and successfully run.
- Dashboard refresh task successfully run.
- Daily Serverless SQL workflow schedule enabled.
- Databricks job success/failure email notifications enabled.
- Databricks-focused $20/month Azure budget alerts created.
- Daily machine JSON generator added.
- One generated daily JSON payload uploaded to ADLS.
- Paused daily Databricks PySpark workflow created.
- Pipeline audit and email-ready alert payload created.
- Final compute check verified all clusters terminated and SQL Warehouse stopped.
- Real-data Serverless SQL run verified all tasks successfully and SQL Warehouse was stopped afterward.

## What Is Blocked

The PySpark notebook workflow has not been run.

Reason:

```text
Databricks job/all-purpose cluster stayed pending while acquiring Azure VM instances in Southeast Asia.
```

Tested VM sizes:

```text
Standard_D2ads_v6
Standard_D2ds_v6
Standard_D4s_v3
```

All attempted clusters were terminated.

## Two Execution Paths

### Path A: Prepared PySpark Path

This is the original target path.

```text
ADLS raw JSON
→ notebooks/01_ingest_bronze.py
→ notebooks/02_transform_silver.py
→ notebooks/03_build_gold.py
→ Databricks Workflow job 383404437598073
→ Gold KPI views
→ Dashboard
```

Status:

```text
Prepared but not run.
```

Why:

```text
Needs a Databricks job cluster, and Azure VM acquisition stayed pending.
```

### Path B: Working Serverless SQL Path

This is the current functional version.

```text
sql/serverless_manual_bootstrap.sql
→ Bronze tables
→ Silver fact/dimension tables
→ Gold KPI views
→ AI/BI dashboard widgets
→ Serverless SQL workflow job 205329090700528
```

Status:

```text
Working and verified.
```

### Daily Raw JSON Generator

This project now includes the Databricks-side equivalent of the Airflow project's daily machine JSON pattern.

Generate one daily raw JSON file locally:

```bash
python3 scripts/generate_daily_machine_json.py --date 2026-06-15
```

Output pattern:

```text
data/raw/qr_printing/start_date=YYYY-MM-DD/machine_api_response.json
```

Upload that daily JSON file to ADLS Gen2:

```bash
BUSINESS_DATE=2026-06-15 scripts/upload_daily_json_to_adls.sh
```

ADLS output pattern:

```text
raw/qr_printing/uploaded_at=manual/start_date=YYYY-MM-DD/machine_api_response.json
```

Prepared paused Databricks daily workflow config:

```text
databricks_workflow_qr_printing_daily_paused.json
```

Created paused Databricks daily workflow:

```text
Workflow name: qr-printing-medallion-daily-paused
Job ID: 67401473932489
Schedule: 07:00 Bangkok daily
Status: PAUSED
```

This workflow is intentionally paused by default. It uses the PySpark notebook path and will need Databricks cluster capacity before it can run.

The working daily automation now uses the Serverless SQL workflow instead:

```text
Workflow name: qr-printing-serverless-sql-daily-refresh
Job ID: 205329090700528
Schedule: 07:10 Bangkok daily
Status: PAUSED
Email notifications: success/failure to Pattaratua@gmail.com
```

### Azure Function Raw Generator

Preferred longer-term raw generation path:

```text
Azure Function timer
→ generate one daily machine JSON payload
→ write to ADLS Gen2 raw container
→ Databricks reads ADLS raw JSON later
```

Local scaffold:

```text
azure_function/
```

Timer schedule:

```text
0 0 0 * * *
```

That is midnight UTC, equal to 07:00 Bangkok.

Deployment helper:

```bash
scripts/deploy_azure_function_daily_generator.sh
```

This deployment creates a Consumption-plan Azure Function with managed identity and gives it `Storage Blob Data Contributor` on the target ADLS storage account.

Current Azure Function deployment status:

```text
Function app created: func-qr-daily-740561
Function host storage created: qrfunc7405610617
Managed identity created: yes
ADLS write role assigned: yes
App settings applied: yes
Function code active/indexed: yes
Manual test trigger verified: yes
```

The Function uses a timer trigger and a blob output binding to write JSON into ADLS without running code on the laptop.

Verified manual output path:

```text
raw/qr_printing/uploaded_at=azure_function_manual/YYYYMMDDTHHMMSSZ/machine_api_response.json
```

Verified manual output counts:

```text
print_events: 2880
machine_telemetry: 1440
machine_logs: 61
```

Scheduled daily output path:

```text
raw/qr_printing/uploaded_at=azure_function/YYYYMMDDTHHMMSSZ/machine_api_response.json
```

Note: the current blob binding writes each Function output to a timestamped folder. This prevents the raw JSON output from being overwritten by the next run.

## Architecture

Original target architecture:

```text
Raw JSON files or Machine API
→ ADLS Gen2 raw/qr_printing/
→ Azure Databricks notebook 01
→ Bronze Delta tables
→ Azure Databricks notebook 02
→ Silver facts and dimensions
→ Azure Databricks notebook 03
→ Gold KPI views
→ Databricks SQL / AI/BI Dashboard
```

Actual working architecture:

```text
ADLS daily JSON source through Unity Catalog external location
→ Databricks Serverless SQL Warehouse
→ Bronze Delta tables updated by MERGE
→ Silver fact/dimension tables updated by MERGE
→ Gold KPI views
→ Databricks AI/BI dashboard
→ Serverless SQL workflow refresh
```

Current scheduled dependency chain:

```text
07:00 Bangkok Azure Function timer
→ ADLS raw JSON timestamped folder

07:05 Bangkok Azure Function controller
→ unpause Databricks Serverless SQL workflow

07:10 Bangkok Databricks Serverless SQL workflow
→ run serverless_manual_bootstrap.sql
→ merge new raw JSON rows into Bronze Delta tables
→ merge new Bronze rows into Silver Delta tables
→ refresh Gold KPI views
→ refresh dashboard
→ run pipeline_audit_monitoring.sql
→ write latest run summary and email-ready payload
→ Databricks job success/failure email notification

07:25 Bangkok local DuckDB export
→ mirror Databricks result tables into data/local/qr_printing_mirror.duckdb for DBeaver practice

07:30 Bangkok Azure Function controller
→ pause Databricks Serverless SQL workflow again

07:45 Bangkok Codex automation
→ report source-to-Databricks validation, DuckDB mirror freshness, and cost safety
```

The Serverless SQL refresh no longer rebuilds the main Bronze and Silver tables with `CREATE OR REPLACE TABLE`. It now creates the target Delta tables only if missing, reads daily JSON directly from the scheduled Azure Function ADLS folder via `qr_raw_adls_location`, and uses `MERGE` keys to update/insert Bronze and Silver rows. Gold remains view-based.

Planned resilient raw generation architecture:

```text
Azure Function timer
→ ADLS Gen2 raw/qr_printing/
→ Databricks Bronze ingestion
→ Silver transforms
→ Gold KPI views
→ Databricks AI/BI dashboard
```

## Key Resources

- Resource group: `rg-qr-dbx-demo`
- Region: `southeastasia`
- ADLS Gen2 storage: `qrdbx06162114`
- Storage container: `raw`
- Databricks workspace: `adb-qr-printing-demo`
- Databricks catalog: `adb_qr_printing_demo`
- SQL Warehouse: `Serverless Starter Warehouse`
- SQL Warehouse ID: `a10d49c1b859854a`
- PySpark workflow job ID: `383404437598073`
- Paused daily PySpark workflow job ID: `67401473932489`
- Serverless SQL workflow job ID: `205329090700528`
- Latest successful Serverless SQL workflow run: `536209218276513`
- Dashboard ID: `01f1699203951f9389c58c97cd030c79`

Published dashboard:

```text
https://adb-7405612371776871.11.azuredatabricks.net/dashboardsv3/01f1699203951f9389c58c97cd030c79/published
```

Detailed resource ledger:

```text
docs/azure_resources.md
```

Alerting and monitoring details:

```text
docs/alerting_monitoring.md
```

## Verified Data Objects

Created and verified through Serverless SQL after the direct ADLS incremental-source fix:

```text
adb_qr_printing_demo.bronze_qr_printing.print_events_raw: 11520 rows
adb_qr_printing_demo.bronze_qr_printing.machine_telemetry_raw: 5760 rows
adb_qr_printing_demo.silver_qr_printing.fact_print_event: 11520 rows
adb_qr_printing_demo.silver_qr_printing.fact_machine_telemetry_minute: 5760 rows
adb_qr_printing_demo.silver_qr_printing.dim_machine: 1 row
adb_qr_printing_demo.silver_qr_printing.dim_product: 1 row
adb_qr_printing_demo.gold_qr_printing.hourly_kpi_summary: 96 rows
adb_qr_printing_demo.gold_qr_printing.machine_health_summary: 96 rows
```

Verified KPI example:

```text
timezone: Asia/Bangkok
first_production_hour: 2026-06-15T07:00:00.000
latest_production_hour: 2026-06-20T06:00:00.000
machine_id: M01
items_processed: 11520
gold_hourly_kpi_rows: 96
```

## Dashboard

Dashboard pages and widget counts:

```text
Production Overview: 6 widgets
Machine Health: 5 widgets
Downtime and Faults: 5 widgets
```

Dashboard definition file:

```text
dashboard_qr_printing.lvdash.json
```

Saved SQL queries:

```text
QR Production Overview: 032c9491-fefe-47d4-90b1-7f204dee2a2c
QR Machine Health: 57b516d8-0e4b-4a33-b672-bf097c21f812
QR Downtime and Faults: 039687cc-b864-4ead-a420-4932b1a18a10
```

## Cost Controls

- No always-on all-purpose cluster.
- SQL Warehouse is Serverless, 2X-Small, with 10-minute auto-stop.
- Working Serverless SQL workflow is scheduled daily at 07:10 Bangkok, but the Azure Function controller keeps it active only during the morning run window.
- PySpark cluster workflows remain manual or paused.
- Broad project resource-group budget was removed.
- Databricks-focused budgets were created instead.
- Alerts are configured at 50% and 90%.
- After each run, SQL Warehouse was stopped and compute state was checked.

Budgets:

```text
qr-dbx-workspace-monthly-20
qr-dbx-managed-compute-monthly-20
```

These budgets exclude Fabric and the ADLS storage account. They target:

```text
Databricks workspace resource
Databricks-managed compute resource group
```

### Current SQL Warehouse Cost Decision

The active Databricks SQL warehouse was resized from `Small` to `2X-Small` to reduce cost for showcase and validation runs.

Current confirmed settings:

```text
warehouse_id: a10d49c1b859854a
name: Serverless Starter Warehouse
size: 2X-Small
state: STOPPED
auto_stop_mins: 10
max_num_clusters: 1
```

This warehouse should be used for:

- scheduled Databricks showcase refreshes
- Azure Function to Databricks demo flow
- final Databricks-side validation
- small live demo queries

It should not be the default engine for repeated heavy SQL exploration. DBeaver connections to Databricks SQL still use the SQL warehouse and can restart billable serverless compute.

### Future Local Mirror For Heavy SQL

For local learning and SQL practice, mirror the needed lakehouse data into a local database and query it locally.

Preferred pattern:

```text
Databricks Bronze/Silver/Gold/Ops result tables
→ local mirror
→ DuckDB
→ DBeaver or local SQL scripts for practice
→ primary validation remains ADLS-to-Databricks cross-checks
```

Recommended use:

```text
DuckDB: local SQL learning, DBeaver practice, and exported row-count checks.
Databricks SQL: scheduled demo, showcase, and primary cloud-side validation.
```

This keeps the real Databricks architecture for the portfolio while avoiding repeated serverless warehouse cost during learning and investigation.

Current local mirror flow:

```text
07:10 Bangkok Databricks refresh
→ 07:25 Bangkok local launchd export
→ data/local/qr_printing_mirror.duckdb
→ DBeaver local DuckDB connection
```

The local export guard skips when the Databricks job is paused, so it should not wake the SQL Warehouse unnecessarily.

## Useful Commands

Set Databricks host:

```bash
export DATABRICKS_HOST="https://adb-7405612371776871.11.azuredatabricks.net"
```

Run the working Serverless SQL workflow:

```bash
databricks jobs run-now 205329090700528 --timeout 10m
databricks warehouses stop a10d49c1b859854a
```

Generate and upload one daily raw machine JSON:

```bash
python3 scripts/generate_daily_machine_json.py --date 2026-06-15
BUSINESS_DATE=2026-06-15 scripts/upload_daily_json_to_adls.sh
```

Deploy the Azure Function daily generator when ready:

```bash
scripts/deploy_azure_function_daily_generator.sh
```

Run the SQL bootstrap directly:

```bash
./scripts/run_databricks_sql_file.sh sql/serverless_manual_bootstrap.sql
databricks warehouses stop a10d49c1b859854a
```

Check compute state:

```bash
databricks clusters list -o json | jq -r '.[] | [.cluster_id,.cluster_name,.state,.node_type_id] | @tsv'
databricks warehouses get a10d49c1b859854a -o json | jq '{name,state,cluster_size,auto_stop_mins,num_active_sessions,num_clusters}'
```

Stop SQL Warehouse:

```bash
databricks warehouses stop a10d49c1b859854a
```

## Teaching Walkthrough

When learning this project later, use this order:

1. What the business case is: QR printing machine analytics.
2. What Bronze/Silver/Gold means.
3. What Azure resources were created.
4. Why the PySpark path was prepared but blocked.
5. How Serverless SQL completed the same business outcome and now accumulates daily demo data.
6. How Gold KPI views feed dashboard widgets.
7. How the Serverless SQL workflow refreshes data and dashboard.
8. How to verify cost safety.
9. How the Gold schema supports business SQL questions.
10. How Bangkok-local `TIMESTAMP_NTZ` avoids UTC conversion confusion.

Simple explanation to remember:

```text
I prepared the original PySpark medallion pipeline, but the Databricks job cluster could not acquire Azure VM capacity in Southeast Asia. Instead of waiting, I completed the same Bronze/Silver/Gold and dashboard outcome with Databricks Serverless SQL Warehouse. The Serverless SQL workflow and dashboard refresh are verified.
```

## Local-Only Learning Files

The Databricks quiz and learning helper files are intentionally kept local and are not uploaded to GitHub.

Local-only files:

```text
docs/learning_and_quiz.md
databricks_quiz.html
databricks_split_learning.html
```

Reason:

```text
These files are personal learning aids for guided practice. The public GitHub repo should stay focused on the business case, architecture, implementation, screenshots, and reusable project documentation.
```

Git handling:

```text
The files still exist on the local Mac, but they are excluded through .git/info/exclude so they are not tracked or pushed.
```

## Remaining Work

- Visually inspect the published dashboard in Databricks UI.
- Retry the PySpark notebook workflow when Azure job cluster capacity is available.
- Optionally recreate the Databricks workspace in another Azure region if cluster acquisition remains blocked.
