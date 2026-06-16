# Alerting and Monitoring

This project uses a Databricks audit layer to monitor the daily QR printing pipeline stages and prepare an email-ready alert message.

## Current Status

Databricks monitoring objects are created and verified.

```text
Catalog: adb_qr_printing_demo
Schema: ops_qr_printing
```

Verified latest alert:

```text
Subject: QR Pipeline Updated - 2026-06-16 - SUCCESS
Recipient hint: Pattaratua@gmail.com
Alert status: PENDING_EMAIL_CONNECTOR
```

The alert payload is ready in Databricks. The remaining step for automatic email delivery is authorizing an Azure Logic Apps email connector such as Gmail or Outlook.

## Why This Design

This is a data freshness and business pipeline alert, not an infrastructure log alert.

Use:

```text
Databricks audit tables/views
→ Azure Logic Apps Consumption
→ email to Pattaratua@gmail.com
```

Azure Logic Apps is preferred because it can receive a structured payload and send a readable business email.

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

Email-ready outbox:

```text
adb_qr_printing_demo.ops_qr_printing.email_alert_outbox
```

Latest alert view:

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

Verified stage summary from the first audit run:

```text
ADLS_RAW: total 4387, new 4387, SUCCESS
BRONZE: total 5, new 5, SUCCESS
SILVER: total 5, new 5, SUCCESS
GOLD: total 3, new 3, SUCCESS
```

Important note:

```text
The current raw Azure Function output has 2880 print events, 1440 telemetry rows, and 67 log rows.
The current Bronze/Silver/Gold tables still reflect the small Serverless SQL demo sample until the ingestion path is connected to read that raw Function output.
```

## Email Body

The email-ready body includes:

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

Run the monitoring SQL:

```bash
export DATABRICKS_HOST="https://adb-7405612371776871.11.azuredatabricks.net"
./scripts/run_databricks_sql_file.sh sql/pipeline_audit_monitoring.sql
databricks warehouses stop a10d49c1b859854a
```

Preview the latest email alert:

```sql
SELECT *
FROM adb_qr_printing_demo.ops_qr_printing.latest_pipeline_alert_email;
```

Preview the latest run:

```sql
SELECT *
FROM adb_qr_printing_demo.ops_qr_printing.latest_pipeline_run_summary;
```

## Remaining Email Automation Step

To fully automate email delivery:

1. Create Azure Logic Apps Consumption workflow.
2. Add an HTTP request trigger.
3. Add Gmail or Outlook send-email action.
4. Authorize the connector interactively.
5. Send the `subject` and `body` from `latest_pipeline_alert_email`.

Connector authorization is the part that normally requires the user to sign in through Azure Portal.

## Related Docs

```text
README.md
docs/project_implementation_details.md
docs/azure_resources.md
docs/kpi_definitions.md
docs/learning_and_quiz.md
```
