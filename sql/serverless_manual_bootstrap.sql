CREATE SCHEMA IF NOT EXISTS adb_qr_printing_demo.bronze_qr_printing;

CREATE SCHEMA IF NOT EXISTS adb_qr_printing_demo.silver_qr_printing;

CREATE SCHEMA IF NOT EXISTS adb_qr_printing_demo.gold_qr_printing;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.bronze_qr_printing.print_events_raw (
  event_id STRING,
  event_ts TIMESTAMP_NTZ,
  machine_id STRING,
  product_id STRING,
  product_name STRING,
  qr_code STRING,
  print_status STRING,
  qr_read_success BOOLEAN,
  is_reject BOOLEAN,
  qr_grade_score DOUBLE,
  position_error_mm DOUBLE
) USING DELTA;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.bronze_qr_printing.machine_telemetry_raw (
  telemetry_ts TIMESTAMP_NTZ,
  machine_id STRING,
  actual_speed_cpm DOUBLE,
  planned_speed_cpm DOUBLE,
  printhead_temp_c DOUBLE,
  vibration_mm_s DOUBLE,
  ink_used_ml DOUBLE
) USING DELTA;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.bronze_qr_printing.machine_logs_raw (
  log_id STRING,
  log_ts TIMESTAMP_NTZ,
  machine_id STRING,
  severity STRING,
  fault_code STRING,
  message STRING,
  downtime_minutes DOUBLE
) USING DELTA;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.silver_qr_printing.fact_print_event (
  event_id STRING,
  event_ts TIMESTAMP_NTZ,
  event_date DATE,
  machine_id STRING,
  product_id STRING,
  product_name STRING,
  qr_code STRING,
  print_status STRING,
  qr_read_success BOOLEAN,
  is_reject BOOLEAN,
  qr_grade_score DOUBLE,
  position_error_mm DOUBLE
) USING DELTA;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.silver_qr_printing.fact_machine_telemetry_minute (
  telemetry_ts TIMESTAMP_NTZ,
  telemetry_minute TIMESTAMP_NTZ,
  machine_id STRING,
  actual_speed_cpm DOUBLE,
  planned_speed_cpm DOUBLE,
  printhead_temp_c DOUBLE,
  vibration_mm_s DOUBLE,
  ink_used_ml DOUBLE
) USING DELTA;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.silver_qr_printing.fact_machine_log (
  log_id STRING,
  log_ts TIMESTAMP_NTZ,
  machine_id STRING,
  severity STRING,
  fault_code STRING,
  message STRING,
  downtime_minutes DOUBLE
) USING DELTA;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.silver_qr_printing.dim_machine (
  machine_id STRING,
  machine_name STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS adb_qr_printing_demo.silver_qr_printing.dim_product (
  product_id STRING,
  product_name STRING
) USING DELTA;

-- Staging reads daily raw JSON files directly from ADLS through the Unity Catalog external location.
-- Source examples:
-- abfss://raw@qrdbx06162114.dfs.core.windows.net/qr_printing/uploaded_at=azure_function/YYYYMMDDTHHMMSSZ/machine_api_response.json
CREATE OR REPLACE TABLE adb_qr_printing_demo.bronze_qr_printing.raw_daily_payload_staging AS
SELECT *
FROM read_files(
  'abfss://raw@qrdbx06162114.dfs.core.windows.net/qr_printing/uploaded_at=azure_function/*/machine_api_response.json',
  format => 'json',
  multiLine => true
);

MERGE INTO adb_qr_printing_demo.bronze_qr_printing.print_events_raw AS target
USING (
  SELECT DISTINCT
    event.event_id,
    CAST(from_utc_timestamp(CAST(event.event_ts AS TIMESTAMP), 'Asia/Bangkok') AS TIMESTAMP_NTZ) AS event_ts,
    event.machine_id,
    event.product_id,
    event.product_name,
    event.qr_code,
    event.print_status,
    event.qr_read_success,
    event.is_reject,
    CAST(event.qr_grade_score AS DOUBLE) AS qr_grade_score,
    CAST(event.position_error_mm AS DOUBLE) AS position_error_mm
  FROM adb_qr_printing_demo.bronze_qr_printing.raw_daily_payload_staging
  LATERAL VIEW explode(print_events) exploded AS event
) AS source
ON target.event_id = source.event_id
WHEN MATCHED THEN UPDATE SET
  event_ts = source.event_ts,
  machine_id = source.machine_id,
  product_id = source.product_id,
  product_name = source.product_name,
  qr_code = source.qr_code,
  print_status = source.print_status,
  qr_read_success = source.qr_read_success,
  is_reject = source.is_reject,
  qr_grade_score = source.qr_grade_score,
  position_error_mm = source.position_error_mm
WHEN NOT MATCHED THEN INSERT (
  event_id,
  event_ts,
  machine_id,
  product_id,
  product_name,
  qr_code,
  print_status,
  qr_read_success,
  is_reject,
  qr_grade_score,
  position_error_mm
) VALUES (
  source.event_id,
  source.event_ts,
  source.machine_id,
  source.product_id,
  source.product_name,
  source.qr_code,
  source.print_status,
  source.qr_read_success,
  source.is_reject,
  source.qr_grade_score,
  source.position_error_mm
);

MERGE INTO adb_qr_printing_demo.bronze_qr_printing.machine_telemetry_raw AS target
USING (
  SELECT DISTINCT
    CAST(from_utc_timestamp(CAST(telemetry.telemetry_ts AS TIMESTAMP), 'Asia/Bangkok') AS TIMESTAMP_NTZ) AS telemetry_ts,
    telemetry.machine_id,
    CAST(telemetry.actual_speed_cpm AS DOUBLE) AS actual_speed_cpm,
    CAST(telemetry.planned_speed_cpm AS DOUBLE) AS planned_speed_cpm,
    CAST(telemetry.printhead_temp_c AS DOUBLE) AS printhead_temp_c,
    CAST(telemetry.vibration_mm_s AS DOUBLE) AS vibration_mm_s,
    CAST(telemetry.ink_used_ml AS DOUBLE) AS ink_used_ml
  FROM adb_qr_printing_demo.bronze_qr_printing.raw_daily_payload_staging
  LATERAL VIEW explode(machine_telemetry) exploded AS telemetry
) AS source
ON target.telemetry_ts = source.telemetry_ts
AND target.machine_id = source.machine_id
WHEN MATCHED THEN UPDATE SET
  actual_speed_cpm = source.actual_speed_cpm,
  planned_speed_cpm = source.planned_speed_cpm,
  printhead_temp_c = source.printhead_temp_c,
  vibration_mm_s = source.vibration_mm_s,
  ink_used_ml = source.ink_used_ml
WHEN NOT MATCHED THEN INSERT (
  telemetry_ts,
  machine_id,
  actual_speed_cpm,
  planned_speed_cpm,
  printhead_temp_c,
  vibration_mm_s,
  ink_used_ml
) VALUES (
  source.telemetry_ts,
  source.machine_id,
  source.actual_speed_cpm,
  source.planned_speed_cpm,
  source.printhead_temp_c,
  source.vibration_mm_s,
  source.ink_used_ml
);

MERGE INTO adb_qr_printing_demo.bronze_qr_printing.machine_logs_raw AS target
USING (
  SELECT DISTINCT
    log.log_id,
    CAST(from_utc_timestamp(CAST(log.log_ts AS TIMESTAMP), 'Asia/Bangkok') AS TIMESTAMP_NTZ) AS log_ts,
    log.machine_id,
    log.severity,
    log.fault_code,
    log.message,
    CAST(log.downtime_minutes AS DOUBLE) AS downtime_minutes
  FROM adb_qr_printing_demo.bronze_qr_printing.raw_daily_payload_staging
  LATERAL VIEW explode(machine_logs) exploded AS log
) AS source
ON target.log_id = source.log_id
WHEN MATCHED THEN UPDATE SET
  log_ts = source.log_ts,
  machine_id = source.machine_id,
  severity = source.severity,
  fault_code = source.fault_code,
  message = source.message,
  downtime_minutes = source.downtime_minutes
WHEN NOT MATCHED THEN INSERT (
  log_id,
  log_ts,
  machine_id,
  severity,
  fault_code,
  message,
  downtime_minutes
) VALUES (
  source.log_id,
  source.log_ts,
  source.machine_id,
  source.severity,
  source.fault_code,
  source.message,
  source.downtime_minutes
);

MERGE INTO adb_qr_printing_demo.silver_qr_printing.fact_print_event AS target
USING (
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
  FROM adb_qr_printing_demo.bronze_qr_printing.print_events_raw
) AS source
ON target.event_id = source.event_id
WHEN MATCHED THEN UPDATE SET
  event_ts = source.event_ts,
  event_date = source.event_date,
  machine_id = source.machine_id,
  product_id = source.product_id,
  product_name = source.product_name,
  qr_code = source.qr_code,
  print_status = source.print_status,
  qr_read_success = source.qr_read_success,
  is_reject = source.is_reject,
  qr_grade_score = source.qr_grade_score,
  position_error_mm = source.position_error_mm
WHEN NOT MATCHED THEN INSERT (
  event_id,
  event_ts,
  event_date,
  machine_id,
  product_id,
  product_name,
  qr_code,
  print_status,
  qr_read_success,
  is_reject,
  qr_grade_score,
  position_error_mm
) VALUES (
  source.event_id,
  source.event_ts,
  source.event_date,
  source.machine_id,
  source.product_id,
  source.product_name,
  source.qr_code,
  source.print_status,
  source.qr_read_success,
  source.is_reject,
  source.qr_grade_score,
  source.position_error_mm
);

MERGE INTO adb_qr_printing_demo.silver_qr_printing.fact_machine_telemetry_minute AS target
USING (
  SELECT DISTINCT
    telemetry_ts,
    CAST(date_trunc('minute', telemetry_ts) AS TIMESTAMP_NTZ) AS telemetry_minute,
    machine_id,
    actual_speed_cpm,
    planned_speed_cpm,
    printhead_temp_c,
    vibration_mm_s,
    ink_used_ml
  FROM adb_qr_printing_demo.bronze_qr_printing.machine_telemetry_raw
) AS source
ON target.telemetry_ts = source.telemetry_ts
AND target.machine_id = source.machine_id
WHEN MATCHED THEN UPDATE SET
  telemetry_minute = source.telemetry_minute,
  actual_speed_cpm = source.actual_speed_cpm,
  planned_speed_cpm = source.planned_speed_cpm,
  printhead_temp_c = source.printhead_temp_c,
  vibration_mm_s = source.vibration_mm_s,
  ink_used_ml = source.ink_used_ml
WHEN NOT MATCHED THEN INSERT (
  telemetry_ts,
  telemetry_minute,
  machine_id,
  actual_speed_cpm,
  planned_speed_cpm,
  printhead_temp_c,
  vibration_mm_s,
  ink_used_ml
) VALUES (
  source.telemetry_ts,
  source.telemetry_minute,
  source.machine_id,
  source.actual_speed_cpm,
  source.planned_speed_cpm,
  source.printhead_temp_c,
  source.vibration_mm_s,
  source.ink_used_ml
);

MERGE INTO adb_qr_printing_demo.silver_qr_printing.fact_machine_log AS target
USING (
  SELECT DISTINCT
    log_id,
    log_ts,
    machine_id,
    severity,
    fault_code,
    message,
    downtime_minutes
  FROM adb_qr_printing_demo.bronze_qr_printing.machine_logs_raw
) AS source
ON target.log_id = source.log_id
WHEN MATCHED THEN UPDATE SET
  log_ts = source.log_ts,
  machine_id = source.machine_id,
  severity = source.severity,
  fault_code = source.fault_code,
  message = source.message,
  downtime_minutes = source.downtime_minutes
WHEN NOT MATCHED THEN INSERT (
  log_id,
  log_ts,
  machine_id,
  severity,
  fault_code,
  message,
  downtime_minutes
) VALUES (
  source.log_id,
  source.log_ts,
  source.machine_id,
  source.severity,
  source.fault_code,
  source.message,
  source.downtime_minutes
);

MERGE INTO adb_qr_printing_demo.silver_qr_printing.dim_machine AS target
USING (
  SELECT DISTINCT
    machine_id,
    concat('QR Printer ', machine_id) AS machine_name
  FROM (
    SELECT machine_id FROM adb_qr_printing_demo.silver_qr_printing.fact_print_event
    UNION
    SELECT machine_id FROM adb_qr_printing_demo.silver_qr_printing.fact_machine_telemetry_minute
  )
) AS source
ON target.machine_id = source.machine_id
WHEN MATCHED THEN UPDATE SET
  machine_name = source.machine_name
WHEN NOT MATCHED THEN INSERT (
  machine_id,
  machine_name
) VALUES (
  source.machine_id,
  source.machine_name
);

MERGE INTO adb_qr_printing_demo.silver_qr_printing.dim_product AS target
USING (
  SELECT DISTINCT
    product_id,
    product_name
  FROM adb_qr_printing_demo.silver_qr_printing.fact_print_event
) AS source
ON target.product_id = source.product_id
WHEN MATCHED THEN UPDATE SET
  product_name = source.product_name
WHEN NOT MATCHED THEN INSERT (
  product_id,
  product_name
) VALUES (
  source.product_id,
  source.product_name
);

CREATE OR REPLACE VIEW adb_qr_printing_demo.gold_qr_printing.hourly_kpi_summary AS
SELECT
  CAST(date_trunc('hour', event_ts) AS TIMESTAMP_NTZ) AS production_hour,
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
  CAST(date_trunc('hour', telemetry_ts) AS TIMESTAMP_NTZ) AS production_hour,
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
  CAST(date_trunc('hour', log_ts) AS TIMESTAMP_NTZ) AS production_hour,
  machine_id,
  sum(CASE WHEN severity = 'FAULT' THEN 1 ELSE 0 END) AS fault_count,
  sum(CASE WHEN severity = 'WARNING' THEN 1 ELSE 0 END) AS warning_count,
  sum(coalesce(downtime_minutes, 0)) AS downtime_minutes
FROM adb_qr_printing_demo.silver_qr_printing.fact_machine_log
GROUP BY 1, 2;
