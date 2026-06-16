CREATE SCHEMA IF NOT EXISTS adb_qr_printing_demo.ops_qr_printing;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.ops_qr_printing.pipeline_run_audit (
  run_id STRING,
  run_ts TIMESTAMP,
  business_date DATE,
  status STRING,
  trigger_type STRING,
  raw_source_path STRING,
  raw_file_status STRING,
  raw_file_size_bytes BIGINT,
  raw_print_events_count BIGINT,
  raw_machine_telemetry_count BIGINT,
  raw_machine_logs_count BIGINT,
  bronze_print_events_total BIGINT,
  bronze_machine_telemetry_total BIGINT,
  bronze_machine_logs_total BIGINT,
  bronze_print_events_new BIGINT,
  bronze_machine_telemetry_new BIGINT,
  bronze_machine_logs_new BIGINT,
  silver_print_events_total BIGINT,
  silver_machine_telemetry_total BIGINT,
  silver_machine_logs_total BIGINT,
  silver_print_events_new BIGINT,
  silver_machine_telemetry_new BIGINT,
  silver_machine_logs_new BIGINT,
  gold_hourly_kpi_rows_total BIGINT,
  gold_machine_health_rows_total BIGINT,
  gold_downtime_fault_rows_total BIGINT,
  gold_hourly_kpi_rows_new BIGINT,
  gold_machine_health_rows_new BIGINT,
  gold_downtime_fault_rows_new BIGINT,
  latest_production_hour TIMESTAMP,
  total_items_processed BIGINT,
  avg_reject_rate_pct DOUBLE,
  avg_qr_read_rate_pct DOUBLE,
  avg_quality_pct DOUBLE,
  total_fault_count BIGINT,
  total_warning_count BIGINT,
  total_downtime_minutes DOUBLE,
  avg_printhead_temp_c DOUBLE,
  avg_vibration_mm_s DOUBLE,
  dashboard_url STRING,
  alert_subject STRING,
  alert_body STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.ops_qr_printing.pipeline_stage_audit (
  run_id STRING,
  run_ts TIMESTAMP,
  business_date DATE,
  stage_name STRING,
  stage_status STRING,
  source_or_table STRING,
  rows_total BIGINT,
  rows_new BIGINT,
  detail STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.ops_qr_printing.email_alert_outbox (
  run_id STRING,
  created_at TIMESTAMP,
  alert_status STRING,
  recipient_hint STRING,
  subject STRING,
  body STRING,
  delivery_service STRING,
  delivery_note STRING
) USING DELTA;

CREATE OR REPLACE VIEW adb_qr_printing_demo.ops_qr_printing.current_pipeline_metrics_staging AS
WITH previous AS (
  SELECT
    coalesce(max(bronze_print_events_total), 0) AS prev_bronze_print_events_total,
    coalesce(max(bronze_machine_telemetry_total), 0) AS prev_bronze_machine_telemetry_total,
    coalesce(max(bronze_machine_logs_total), 0) AS prev_bronze_machine_logs_total,
    coalesce(max(silver_print_events_total), 0) AS prev_silver_print_events_total,
    coalesce(max(silver_machine_telemetry_total), 0) AS prev_silver_machine_telemetry_total,
    coalesce(max(silver_machine_logs_total), 0) AS prev_silver_machine_logs_total,
    coalesce(max(gold_hourly_kpi_rows_total), 0) AS prev_gold_hourly_kpi_rows_total,
    coalesce(max(gold_machine_health_rows_total), 0) AS prev_gold_machine_health_rows_total,
    coalesce(max(gold_downtime_fault_rows_total), 0) AS prev_gold_downtime_fault_rows_total
  FROM adb_qr_printing_demo.ops_qr_printing.pipeline_run_audit
),
bronze AS (
  SELECT
    (SELECT count(*) FROM adb_qr_printing_demo.bronze_qr_printing.print_events_raw) AS bronze_print_events_total,
    (SELECT count(*) FROM adb_qr_printing_demo.bronze_qr_printing.machine_telemetry_raw) AS bronze_machine_telemetry_total,
    (SELECT count(*) FROM adb_qr_printing_demo.bronze_qr_printing.machine_logs_raw) AS bronze_machine_logs_total
),
silver AS (
  SELECT
    (SELECT count(*) FROM adb_qr_printing_demo.silver_qr_printing.fact_print_event) AS silver_print_events_total,
    (SELECT count(*) FROM adb_qr_printing_demo.silver_qr_printing.fact_machine_telemetry_minute) AS silver_machine_telemetry_total,
    (SELECT count(*) FROM adb_qr_printing_demo.silver_qr_printing.fact_machine_log) AS silver_machine_logs_total
),
gold AS (
  SELECT
    (SELECT count(*) FROM adb_qr_printing_demo.gold_qr_printing.hourly_kpi_summary) AS gold_hourly_kpi_rows_total,
    (SELECT count(*) FROM adb_qr_printing_demo.gold_qr_printing.machine_health_summary) AS gold_machine_health_rows_total,
    (SELECT count(*) FROM adb_qr_printing_demo.gold_qr_printing.downtime_fault_summary) AS gold_downtime_fault_rows_total
),
kpi AS (
  SELECT
    max(production_hour) AS latest_production_hour,
    to_date(max(production_hour)) AS business_date,
    sum(items_processed) AS total_items_processed,
    round(avg(reject_rate_pct), 2) AS avg_reject_rate_pct,
    round(avg(qr_read_rate_pct), 2) AS avg_qr_read_rate_pct,
    round(avg(quality_pct), 2) AS avg_quality_pct
  FROM adb_qr_printing_demo.gold_qr_printing.hourly_kpi_summary
),
health AS (
  SELECT
    round(avg(avg_printhead_temp_c), 2) AS avg_printhead_temp_c,
    round(avg(avg_vibration_mm_s), 3) AS avg_vibration_mm_s
  FROM adb_qr_printing_demo.gold_qr_printing.machine_health_summary
),
downtime AS (
  SELECT
    coalesce(sum(fault_count), 0) AS total_fault_count,
    coalesce(sum(warning_count), 0) AS total_warning_count,
    coalesce(sum(downtime_minutes), 0) AS total_downtime_minutes
  FROM adb_qr_printing_demo.gold_qr_printing.downtime_fault_summary
)
SELECT
  uuid() AS run_id,
  current_timestamp() AS run_ts,
  coalesce(kpi.business_date, current_date()) AS business_date,
  'SUCCESS' AS status,
  'MANUAL_MONITORING_REFRESH' AS trigger_type,
  'raw/qr_printing/uploaded_at=azure_function_manual/machine_api_response.json' AS raw_source_path,
  'VERIFIED_MANUAL_AZURE_FUNCTION_OUTPUT' AS raw_file_status,
  1525874L AS raw_file_size_bytes,
  2880L AS raw_print_events_count,
  1440L AS raw_machine_telemetry_count,
  67L AS raw_machine_logs_count,
  bronze.*,
  greatest(bronze.bronze_print_events_total - previous.prev_bronze_print_events_total, 0) AS bronze_print_events_new,
  greatest(bronze.bronze_machine_telemetry_total - previous.prev_bronze_machine_telemetry_total, 0) AS bronze_machine_telemetry_new,
  greatest(bronze.bronze_machine_logs_total - previous.prev_bronze_machine_logs_total, 0) AS bronze_machine_logs_new,
  silver.*,
  greatest(silver.silver_print_events_total - previous.prev_silver_print_events_total, 0) AS silver_print_events_new,
  greatest(silver.silver_machine_telemetry_total - previous.prev_silver_machine_telemetry_total, 0) AS silver_machine_telemetry_new,
  greatest(silver.silver_machine_logs_total - previous.prev_silver_machine_logs_total, 0) AS silver_machine_logs_new,
  gold.*,
  greatest(gold.gold_hourly_kpi_rows_total - previous.prev_gold_hourly_kpi_rows_total, 0) AS gold_hourly_kpi_rows_new,
  greatest(gold.gold_machine_health_rows_total - previous.prev_gold_machine_health_rows_total, 0) AS gold_machine_health_rows_new,
  greatest(gold.gold_downtime_fault_rows_total - previous.prev_gold_downtime_fault_rows_total, 0) AS gold_downtime_fault_rows_new,
  kpi.latest_production_hour,
  kpi.total_items_processed,
  kpi.avg_reject_rate_pct,
  kpi.avg_qr_read_rate_pct,
  kpi.avg_quality_pct,
  downtime.total_fault_count,
  downtime.total_warning_count,
  downtime.total_downtime_minutes,
  health.avg_printhead_temp_c,
  health.avg_vibration_mm_s,
  'https://adb-7405612371776871.11.azuredatabricks.net/dashboardsv3/01f1699203951f9389c58c97cd030c79/published?o=7405612371776871' AS dashboard_url
FROM previous
CROSS JOIN bronze
CROSS JOIN silver
CROSS JOIN gold
CROSS JOIN kpi
CROSS JOIN health
CROSS JOIN downtime;

CREATE OR REPLACE VIEW adb_qr_printing_demo.ops_qr_printing.current_pipeline_alert_staging AS
SELECT
  *,
  concat('QR Pipeline Updated - ', cast(business_date AS STRING), ' - ', status) AS alert_subject,
  concat(
    'Pipeline status: ', status, '\n',
    'Business date: ', cast(business_date AS STRING), '\n',
    'Run timestamp: ', cast(run_ts AS STRING), '\n\n',
    '1. ADLS raw file\n',
    '- Status: ', raw_file_status, '\n',
    '- Path: ', raw_source_path, '\n',
    '- File size bytes: ', cast(raw_file_size_bytes AS STRING), '\n',
    '- Raw print events: ', cast(raw_print_events_count AS STRING), '\n',
    '- Raw telemetry rows: ', cast(raw_machine_telemetry_count AS STRING), '\n',
    '- Raw log rows: ', cast(raw_machine_logs_count AS STRING), '\n\n',
    '2. Bronze\n',
    '- print_events_raw total/new: ', cast(bronze_print_events_total AS STRING), '/', cast(bronze_print_events_new AS STRING), '\n',
    '- machine_telemetry_raw total/new: ', cast(bronze_machine_telemetry_total AS STRING), '/', cast(bronze_machine_telemetry_new AS STRING), '\n',
    '- machine_logs_raw total/new: ', cast(bronze_machine_logs_total AS STRING), '/', cast(bronze_machine_logs_new AS STRING), '\n\n',
    '3. Silver\n',
    '- fact_print_event total/new: ', cast(silver_print_events_total AS STRING), '/', cast(silver_print_events_new AS STRING), '\n',
    '- fact_machine_telemetry_minute total/new: ', cast(silver_machine_telemetry_total AS STRING), '/', cast(silver_machine_telemetry_new AS STRING), '\n',
    '- fact_machine_log total/new: ', cast(silver_machine_logs_total AS STRING), '/', cast(silver_machine_logs_new AS STRING), '\n\n',
    '4. Gold\n',
    '- hourly_kpi_summary total/new: ', cast(gold_hourly_kpi_rows_total AS STRING), '/', cast(gold_hourly_kpi_rows_new AS STRING), '\n',
    '- machine_health_summary total/new: ', cast(gold_machine_health_rows_total AS STRING), '/', cast(gold_machine_health_rows_new AS STRING), '\n',
    '- downtime_fault_summary total/new: ', cast(gold_downtime_fault_rows_total AS STRING), '/', cast(gold_downtime_fault_rows_new AS STRING), '\n\n',
    'KPI highlights\n',
    '- Latest production hour: ', cast(latest_production_hour AS STRING), '\n',
    '- Items processed: ', cast(total_items_processed AS STRING), '\n',
    '- Avg reject rate %: ', cast(avg_reject_rate_pct AS STRING), '\n',
    '- Avg QR read rate %: ', cast(avg_qr_read_rate_pct AS STRING), '\n',
    '- Avg quality %: ', cast(avg_quality_pct AS STRING), '\n',
    '- Fault count: ', cast(total_fault_count AS STRING), '\n',
    '- Warning count: ', cast(total_warning_count AS STRING), '\n',
    '- Downtime minutes: ', cast(total_downtime_minutes AS STRING), '\n',
    '- Avg printhead temp C: ', cast(avg_printhead_temp_c AS STRING), '\n',
    '- Avg vibration mm/s: ', cast(avg_vibration_mm_s AS STRING), '\n\n',
    'Dashboard: ', dashboard_url, '\n\n',
    'Cost note: check Databricks compute after manual runs.'
  ) AS alert_body
FROM adb_qr_printing_demo.ops_qr_printing.current_pipeline_metrics_staging;

CREATE OR REPLACE TABLE adb_qr_printing_demo.ops_qr_printing.current_pipeline_alert_snapshot AS
SELECT *
FROM adb_qr_printing_demo.ops_qr_printing.current_pipeline_alert_staging;

INSERT INTO adb_qr_printing_demo.ops_qr_printing.pipeline_run_audit
SELECT
  run_id,
  run_ts,
  business_date,
  status,
  trigger_type,
  raw_source_path,
  raw_file_status,
  raw_file_size_bytes,
  raw_print_events_count,
  raw_machine_telemetry_count,
  raw_machine_logs_count,
  bronze_print_events_total,
  bronze_machine_telemetry_total,
  bronze_machine_logs_total,
  bronze_print_events_new,
  bronze_machine_telemetry_new,
  bronze_machine_logs_new,
  silver_print_events_total,
  silver_machine_telemetry_total,
  silver_machine_logs_total,
  silver_print_events_new,
  silver_machine_telemetry_new,
  silver_machine_logs_new,
  gold_hourly_kpi_rows_total,
  gold_machine_health_rows_total,
  gold_downtime_fault_rows_total,
  gold_hourly_kpi_rows_new,
  gold_machine_health_rows_new,
  gold_downtime_fault_rows_new,
  latest_production_hour,
  total_items_processed,
  avg_reject_rate_pct,
  avg_qr_read_rate_pct,
  avg_quality_pct,
  total_fault_count,
  total_warning_count,
  total_downtime_minutes,
  avg_printhead_temp_c,
  avg_vibration_mm_s,
  dashboard_url,
  alert_subject,
  alert_body
FROM adb_qr_printing_demo.ops_qr_printing.current_pipeline_alert_snapshot;

INSERT INTO adb_qr_printing_demo.ops_qr_printing.pipeline_stage_audit
SELECT run_id, run_ts, business_date, 'ADLS_RAW', status, raw_source_path, raw_print_events_count + raw_machine_telemetry_count + raw_machine_logs_count, raw_print_events_count + raw_machine_telemetry_count + raw_machine_logs_count, concat('file_size_bytes=', cast(raw_file_size_bytes AS STRING)) FROM adb_qr_printing_demo.ops_qr_printing.current_pipeline_alert_snapshot
UNION ALL
SELECT run_id, run_ts, business_date, 'BRONZE', status, 'bronze_qr_printing', bronze_print_events_total + bronze_machine_telemetry_total + bronze_machine_logs_total, bronze_print_events_new + bronze_machine_telemetry_new + bronze_machine_logs_new, 'print_events_raw, machine_telemetry_raw, machine_logs_raw' FROM adb_qr_printing_demo.ops_qr_printing.current_pipeline_alert_snapshot
UNION ALL
SELECT run_id, run_ts, business_date, 'SILVER', status, 'silver_qr_printing', silver_print_events_total + silver_machine_telemetry_total + silver_machine_logs_total, silver_print_events_new + silver_machine_telemetry_new + silver_machine_logs_new, 'fact_print_event, fact_machine_telemetry_minute, fact_machine_log' FROM adb_qr_printing_demo.ops_qr_printing.current_pipeline_alert_snapshot
UNION ALL
SELECT run_id, run_ts, business_date, 'GOLD', status, 'gold_qr_printing', gold_hourly_kpi_rows_total + gold_machine_health_rows_total + gold_downtime_fault_rows_total, gold_hourly_kpi_rows_new + gold_machine_health_rows_new + gold_downtime_fault_rows_new, 'hourly_kpi_summary, machine_health_summary, downtime_fault_summary' FROM adb_qr_printing_demo.ops_qr_printing.current_pipeline_alert_snapshot;

INSERT INTO adb_qr_printing_demo.ops_qr_printing.email_alert_outbox
SELECT
  run_id,
  run_ts AS created_at,
  'PENDING_EMAIL_CONNECTOR' AS alert_status,
  'Pattaratua@gmail.com' AS recipient_hint,
  alert_subject AS subject,
  alert_body AS body,
  'Azure Logic Apps Consumption' AS delivery_service,
  'Email-ready payload created. Logic App email connector authorization is the remaining delivery step.' AS delivery_note
FROM adb_qr_printing_demo.ops_qr_printing.current_pipeline_alert_snapshot;

CREATE OR REPLACE VIEW adb_qr_printing_demo.ops_qr_printing.latest_pipeline_alert_email AS
SELECT
  run_id,
  created_at,
  recipient_hint,
  subject,
  body,
  alert_status,
  delivery_service,
  delivery_note
FROM adb_qr_printing_demo.ops_qr_printing.email_alert_outbox
QUALIFY row_number() OVER (ORDER BY created_at DESC) = 1;

CREATE OR REPLACE VIEW adb_qr_printing_demo.ops_qr_printing.latest_pipeline_run_summary AS
SELECT *
FROM adb_qr_printing_demo.ops_qr_printing.pipeline_run_audit
QUALIFY row_number() OVER (ORDER BY run_ts DESC) = 1;
