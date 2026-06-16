-- Databricks SQL dashboard starter queries.

-- Production overview
SELECT
  production_hour,
  machine_id,
  items_processed,
  printed_items,
  reject_rate_pct,
  qr_read_rate_pct,
  quality_pct
FROM adb_qr_printing_demo.gold_qr_printing.hourly_kpi_summary
ORDER BY production_hour;

-- Machine health
SELECT
  production_hour,
  machine_id,
  avg_actual_speed_cpm,
  performance_pct,
  avg_printhead_temp_c,
  avg_vibration_mm_s,
  ink_ml_per_1000_prints
FROM adb_qr_printing_demo.gold_qr_printing.machine_health_summary
ORDER BY production_hour;

-- Downtime and faults
SELECT
  production_hour,
  machine_id,
  fault_count,
  warning_count,
  downtime_minutes
FROM adb_qr_printing_demo.gold_qr_printing.downtime_fault_summary
ORDER BY production_hour;
