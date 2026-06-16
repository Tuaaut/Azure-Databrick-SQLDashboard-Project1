CREATE SCHEMA IF NOT EXISTS adb_qr_printing_demo.bronze_qr_printing;

CREATE SCHEMA IF NOT EXISTS adb_qr_printing_demo.silver_qr_printing;

CREATE SCHEMA IF NOT EXISTS adb_qr_printing_demo.gold_qr_printing;

CREATE OR REPLACE TABLE adb_qr_printing_demo.bronze_qr_printing.print_events_raw AS
SELECT * FROM VALUES
  ('evt-0001', timestamp('2026-06-16T08:00:02Z'), 'M01', 'SKU-COLA-330', 'Cola Can 330ml', 'QR-20260616-0001', 'PRINTED', true, false, 0.96D, 0.21D),
  ('evt-0002', timestamp('2026-06-16T08:00:05Z'), 'M01', 'SKU-COLA-330', 'Cola Can 330ml', 'QR-20260616-0002', 'PRINTED', false, true, 0.41D, 1.34D)
AS t(event_id, event_ts, machine_id, product_id, product_name, qr_code, print_status, qr_read_success, is_reject, qr_grade_score, position_error_mm);

CREATE OR REPLACE TABLE adb_qr_printing_demo.bronze_qr_printing.machine_telemetry_raw AS
SELECT * FROM VALUES
  (timestamp('2026-06-16T08:00:00Z'), 'M01', 79.5D, 84.0D, 42.8D, 1.21D, 4.8D),
  (timestamp('2026-06-16T08:01:00Z'), 'M01', 82.0D, 84.0D, 43.1D, 1.18D, 4.9D)
AS t(telemetry_ts, machine_id, actual_speed_cpm, planned_speed_cpm, printhead_temp_c, vibration_mm_s, ink_used_ml);

CREATE OR REPLACE TABLE adb_qr_printing_demo.bronze_qr_printing.machine_logs_raw AS
SELECT * FROM VALUES
  ('log-0001', timestamp('2026-06-16T08:00:05Z'), 'M01', 'WARNING', 'QR_READ_FAIL', 'QR reader failed validation', 0)
AS t(log_id, log_ts, machine_id, severity, fault_code, message, downtime_minutes);

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
