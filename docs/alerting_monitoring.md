# Alerting and Monitoring

This project uses a Databricks audit layer to monitor the daily QR printing pipeline stages, store a readable run summary, and send basic Databricks job success/failure email notifications.

## Current Status

Databricks monitoring objects are created and verified.

```text
Catalog: adb_qr_printing_demo
Schema: ops_qr_printing
```

Verified latest alert:

```text
Subject: QR Pipeline Updated - 2026-06-15 - SUCCESS
Recipient hint: Pattaratua@gmail.com
Alert status: INTERNAL_AUDIT_ONLY
```

The alert payload is stored in Databricks for review. Databricks Jobs sends daily success/failure email notifications to Gmail. No custom external email connector is currently configured.

## Databricks Job Notification

Working scheduled job:

```text
Job: qr-printing-serverless-sql-daily-refresh
Job ID: 205329090700528
Schedule: 07:10 Bangkok daily
Pause status: UNPAUSED
Latest test run: 811234223268645
Result: SUCCESS
```

Email notifications:

```text
On success: Pattaratua@gmail.com
On failure: Pattaratua@gmail.com
```

## Why This Design

This is a data freshness and business pipeline alert, not an infrastructure log alert.

Use:

```text
Databricks audit tables/views
→ Databricks job success/failure email to Pattaratua@gmail.com
→ detailed run summary stored in Databricks tables/views
```

Azure Monitor is still useful for infrastructure alerts such as Function failure, Databricks resource errors, and cost alerts.

## Audit Tables

Run-level audit:

```text
adb_qr_printing_demo.ops_qr_printing.pipeline_run_audit
```

Stage-level audit:

```text
adb_qr_printing_demo.ops_qr_printing.pipeline_stage_audit
```

Audit summary outbox:

```text
adb_qr_printing_demo.ops_qr_printing.email_alert_outbox
```

Latest audit summary view:

```text
adb_qr_printing_demo.ops_qr_printing.latest_pipeline_alert_email
```

Latest run summary view:

```text
adb_qr_printing_demo.ops_qr_printing.latest_pipeline_run_summary
```

SQL source file:

```text
sql/pipeline_audit_monitoring.sql
```

## Alert Coverage

The alert covers these stages:

```text
ADLS raw file
Bronze raw tables
Silver fact tables
Gold KPI views
Business KPI highlights
Dashboard link
Cost reminder
```

Verified stage summary from the real-data test run:

```text
ADLS_RAW: total 4387, new 4387, SUCCESS
BRONZE: total 4387, new 4382, SUCCESS
SILVER: total 4387, new 4382, SUCCESS
GOLD: total 68, new 65, SUCCESS
```

Important note:

```text
The current raw daily JSON has 2880 print events, 1440 telemetry rows, and 67 log rows.
The current Bronze/Silver/Gold tables now reflect that real generated daily JSON test load.
```

## Stored Summary Body

The stored summary body includes:

```text
Pipeline status
Business date
Run timestamp
ADLS raw path and file size
Raw payload counts
Bronze total/new row counts
Silver total/new row counts
Gold total/new row counts
Latest production hour
Items processed
Reject rate
QR read rate
Quality rate
Fault and warning counts
Downtime minutes
Average printhead temperature
Average vibration
Dashboard link
Cost reminder
```

## How to Run Manually

Run the scheduled job manually:

```bash
export DATABRICKS_HOST="https://adb-7405612371776871.11.azuredatabricks.net"
databricks jobs run-now 205329090700528
```

Run only the monitoring SQL:

```bash
export DATABRICKS_HOST="https://adb-7405612371776871.11.azuredatabricks.net"
./scripts/run_databricks_sql_file.sh sql/pipeline_audit_monitoring.sql
databricks warehouses stop a10d49c1b859854a
```

Preview the latest stored summary:

```sql
SELECT *
FROM adb_qr_printing_demo.ops_qr_printing.latest_pipeline_alert_email;
```

Preview the latest run:

```sql
SELECT *
FROM adb_qr_printing_demo.ops_qr_printing.latest_pipeline_run_summary;
```

## Related Docs

```text
README.md
docs/project_implementation_details.md
docs/azure_resources.md
docs/kpi_definitions.md
```
