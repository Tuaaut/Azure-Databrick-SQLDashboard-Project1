CREATE SCHEMA IF NOT EXISTS adb_qr_printing_demo.bronze_qr_printing;

CREATE SCHEMA IF NOT EXISTS adb_qr_printing_demo.silver_qr_printing;

CREATE SCHEMA IF NOT EXISTS adb_qr_printing_demo.gold_qr_printing;

CREATE VOLUME IF NOT EXISTS adb_qr_printing_demo.bronze_qr_printing.raw_files;

CREATE OR REPLACE TABLE adb_qr_printing_demo.bronze_qr_printing.print_events_raw AS
WITH raw AS (
  SELECT *
  FROM read_files(
    '/Volumes/adb_qr_printing_demo/bronze_qr_printing/raw_files/qr_printing/start_date=2026-06-15/machine_api_response.json',
    format => 'json',
    multiLine => true
  )
)
SELECT
  event.event_id,
  timestamp(event.event_ts) AS event_ts,
  event.machine_id,
  event.product_id,
  event.product_name,
  event.qr_code,
  event.print_status,
  boolean(event.qr_read_success) AS qr_read_success,
  boolean(event.is_reject) AS is_reject,
  double(event.qr_grade_score) AS qr_grade_score,
  double(event.position_error_mm) AS position_error_mm
FROM raw
LATERAL VIEW explode(print_events) pe AS event;

CREATE OR REPLACE TABLE adb_qr_printing_demo.bronze_qr_printing.machine_telemetry_raw AS
WITH raw AS (
  SELECT *
  FROM read_files(
    '/Volumes/adb_qr_printing_demo/bronze_qr_printing/raw_files/qr_printing/start_date=2026-06-15/machine_api_response.json',
    format => 'json',
    multiLine => true
  )
)
SELECT
  timestamp(telemetry.telemetry_ts) AS telemetry_ts,
  telemetry.machine_id,
  double(telemetry.actual_speed_cpm) AS actual_speed_cpm,
  double(telemetry.planned_speed_cpm) AS planned_speed_cpm,
  double(telemetry.printhead_temp_c) AS printhead_temp_c,
  double(telemetry.vibration_mm_s) AS vibration_mm_s,
  double(telemetry.ink_used_ml) AS ink_used_ml
FROM raw
LATERAL VIEW explode(machine_telemetry) mt AS telemetry;

CREATE OR REPLACE TABLE adb_qr_printing_demo.bronze_qr_printing.machine_logs_raw AS
WITH raw AS (
  SELECT *
  FROM read_files(
    '/Volumes/adb_qr_printing_demo/bronze_qr_printing/raw_files/qr_printing/start_date=2026-06-15/machine_api_response.json',
    format => 'json',
    multiLine => true
  )
)
SELECT
  log.log_id,
  timestamp(log.log_ts) AS log_ts,
  log.machine_id,
  log.severity,
  log.fault_code,
  log.message,
  double(log.downtime_minutes) AS downtime_minutes
FROM raw
LATERAL VIEW explode(machine_logs) ml AS log;

CREATE OR REPLACE TABLE adb_qr_printing_demo.silver_qr_printing.fact_print_event AS
SELECT DISTINCT
  event_id,
  event_ts,
  to_date(event_ts) AS event_date,
  machine_id,
  product_id,
  product_name,
  qr_code,
  print_status,
  qr_read_success,
  is_reject,
  qr_grade_score,
  position_error_mm
FROM adb_qr_printing_demo.bronze_qr_printing.print_events_raw;

CREATE OR REPLACE TABLE adb_qr_printing_demo.silver_qr_printing.fact_machine_telemetry_minute AS
SELECT DISTINCT
  telemetry_ts,
  date_trunc('minute', telemetry_ts) AS telemetry_minute,
  machine_id,
  actual_speed_cpm,
  planned_speed_cpm,
  printhead_temp_c,
  vibration_mm_s,
  ink_used_ml
FROM adb_qr_printing_demo.bronze_qr_printing.machine_telemetry_raw;

CREATE OR REPLACE TABLE adb_qr_printing_demo.silver_qr_printing.fact_machine_log AS
SELECT DISTINCT
  log_id,
  log_ts,
  machine_id,
  severity,
  fault_code,
  message,
  downtime_minutes
FROM adb_qr_printing_demo.bronze_qr_printing.machine_logs_raw;

CREATE OR REPLACE TABLE adb_qr_printing_demo.silver_qr_printing.dim_machine AS
SELECT DISTINCT
  machine_id,
  concat('QR Printer ', machine_id) AS machine_name
FROM (
  SELECT machine_id FROM adb_qr_printing_demo.silver_qr_printing.fact_print_event
  UNION
  SELECT machine_id FROM adb_qr_printing_demo.silver_qr_printing.fact_machine_telemetry_minute
);

CREATE OR REPLACE TABLE adb_qr_printing_demo.silver_qr_printing.dim_product AS
SELECT DISTINCT
  product_id,
  product_name
FROM adb_qr_printing_demo.silver_qr_printing.fact_print_event;

CREATE OR REPLACE VIEW adb_qr_printing_demo.gold_qr_printing.hourly_kpi_summary AS
SELECT
  date_trunc('hour', event_ts) AS production_hour,
  machine_id,
  count(*) AS items_processed,
  sum(CASE WHEN print_status = 'PRINTED' THEN 1 ELSE 0 END) AS printed_items,
  sum(CASE WHEN is_reject THEN 1 ELSE 0 END) AS reject_count,
  round(100.0 * sum(CASE WHEN is_reject THEN 1 ELSE 0 END) / count(*), 2) AS reject_rate_pct,
  sum(CASE WHEN qr_read_success THEN 1 ELSE 0 END) AS qr_read_success_count,
  sum(CASE WHEN NOT qr_read_success THEN 1 ELSE 0 END) AS qr_read_fail_count,
  round(100.0 * sum(CASE WHEN qr_read_success THEN 1 ELSE 0 END) / count(*), 2) AS qr_read_rate_pct,
  round(avg(qr_grade_score), 2) AS avg_qr_grade_score,
  round(avg(position_error_mm), 3) AS avg_position_error_mm,
  round(100.0 * sum(CASE WHEN qr_read_success AND NOT is_reject THEN 1 ELSE 0 END) / count(*), 2) AS quality_pct
FROM adb_qr_printing_demo.silver_qr_printing.fact_print_event
GROUP BY 1, 2;

CREATE OR REPLACE VIEW adb_qr_printing_demo.gold_qr_printing.machine_health_summary AS
SELECT
  date_trunc('hour', telemetry_ts) AS production_hour,
  machine_id,
  round(avg(actual_speed_cpm), 2) AS avg_actual_speed_cpm,
  round(avg(planned_speed_cpm), 2) AS avg_planned_speed_cpm,
  round(100.0 * avg(actual_speed_cpm) / nullif(avg(planned_speed_cpm), 0), 2) AS performance_pct,
  round(avg(printhead_temp_c), 2) AS avg_printhead_temp_c,
  round(avg(vibration_mm_s), 3) AS avg_vibration_mm_s,
  round(1000.0 * sum(ink_used_ml) / nullif(sum(actual_speed_cpm), 0), 2) AS ink_ml_per_1000_prints
FROM adb_qr_printing_demo.silver_qr_printing.fact_machine_telemetry_minute
GROUP BY 1, 2;

CREATE OR REPLACE VIEW adb_qr_printing_demo.gold_qr_printing.downtime_fault_summary AS
SELECT
  date_trunc('hour', log_ts) AS production_hour,
  machine_id,
  sum(CASE WHEN severity = 'FAULT' THEN 1 ELSE 0 END) AS fault_count,
  sum(CASE WHEN severity = 'WARNING' THEN 1 ELSE 0 END) AS warning_count,
  sum(coalesce(downtime_minutes, 0)) AS downtime_minutes
FROM adb_qr_printing_demo.silver_qr_printing.fact_machine_log
GROUP BY 1, 2;
