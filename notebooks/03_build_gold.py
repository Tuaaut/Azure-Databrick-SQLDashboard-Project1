# Databricks notebook source
# Gold KPI tables/views for Databricks SQL dashboards.

dbutils.widgets.text("catalog", "adb_qr_printing_demo")
dbutils.widgets.text("silver_schema", "silver_qr_printing")
dbutils.widgets.text("gold_schema", "gold_qr_printing")

catalog = dbutils.widgets.get("catalog")
silver_schema = dbutils.widgets.get("silver_schema")
gold_schema = dbutils.widgets.get("gold_schema")

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {catalog}.{gold_schema}")

spark.sql(f"""
CREATE OR REPLACE VIEW {catalog}.{gold_schema}.hourly_kpi_summary AS
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
FROM {catalog}.{silver_schema}.fact_print_event
GROUP BY 1, 2
""")

spark.sql(f"""
CREATE OR REPLACE VIEW {catalog}.{gold_schema}.machine_health_summary AS
SELECT
  date_trunc('hour', telemetry_ts) AS production_hour,
  machine_id,
  round(avg(actual_speed_cpm), 2) AS avg_actual_speed_cpm,
  round(avg(planned_speed_cpm), 2) AS avg_planned_speed_cpm,
  round(100.0 * avg(actual_speed_cpm) / nullif(avg(planned_speed_cpm), 0), 2) AS performance_pct,
  round(avg(printhead_temp_c), 2) AS avg_printhead_temp_c,
  round(avg(vibration_mm_s), 3) AS avg_vibration_mm_s,
  round(1000.0 * sum(ink_used_ml) / nullif(sum(actual_speed_cpm), 0), 2) AS ink_ml_per_1000_prints
FROM {catalog}.{silver_schema}.fact_machine_telemetry_minute
GROUP BY 1, 2
""")

spark.sql(f"""
CREATE OR REPLACE VIEW {catalog}.{gold_schema}.downtime_fault_summary AS
SELECT
  date_trunc('hour', log_ts) AS production_hour,
  machine_id,
  sum(CASE WHEN severity = 'FAULT' THEN 1 ELSE 0 END) AS fault_count,
  sum(CASE WHEN severity = 'WARNING' THEN 1 ELSE 0 END) AS warning_count,
  sum(coalesce(downtime_minutes, 0)) AS downtime_minutes
FROM {catalog}.{silver_schema}.fact_machine_log
GROUP BY 1, 2
""")
