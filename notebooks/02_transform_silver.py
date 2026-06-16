# Databricks notebook source
# Silver transformations for typed QR printing facts and dimensions.

from pyspark.sql import functions as F

dbutils.widgets.text("catalog", "adb_qr_printing_demo")
dbutils.widgets.text("bronze_schema", "bronze_qr_printing")
dbutils.widgets.text("silver_schema", "silver_qr_printing")

catalog = dbutils.widgets.get("catalog")
bronze_schema = dbutils.widgets.get("bronze_schema")
silver_schema = dbutils.widgets.get("silver_schema")

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {catalog}.{silver_schema}")

print_events = spark.table(f"{catalog}.{bronze_schema}.print_events_raw")
telemetry = spark.table(f"{catalog}.{bronze_schema}.machine_telemetry_raw")
logs = spark.table(f"{catalog}.{bronze_schema}.machine_logs_raw")

(
    print_events
    .withColumn("event_ts", F.to_timestamp("event_ts"))
    .withColumn("event_date", F.to_date("event_ts"))
    .dropDuplicates(["event_id"])
    .write.mode("overwrite")
    .format("delta")
    .option("overwriteSchema", "true")
    .saveAsTable(f"{catalog}.{silver_schema}.fact_print_event")
)

(
    telemetry
    .withColumn("telemetry_ts", F.to_timestamp("telemetry_ts"))
    .withColumn("telemetry_minute", F.date_trunc("minute", "telemetry_ts"))
    .dropDuplicates(["machine_id", "telemetry_minute"])
    .write.mode("overwrite")
    .format("delta")
    .option("overwriteSchema", "true")
    .saveAsTable(f"{catalog}.{silver_schema}.fact_machine_telemetry_minute")
)

(
    logs
    .withColumn("log_ts", F.to_timestamp("log_ts"))
    .dropDuplicates(["log_id"])
    .write.mode("overwrite")
    .format("delta")
    .option("overwriteSchema", "true")
    .saveAsTable(f"{catalog}.{silver_schema}.fact_machine_log")
)

(
    print_events.select("machine_id").union(telemetry.select("machine_id")).distinct()
    .withColumn("machine_name", F.concat(F.lit("QR Printer "), F.col("machine_id")))
    .write.mode("overwrite")
    .format("delta")
    .saveAsTable(f"{catalog}.{silver_schema}.dim_machine")
)

(
    print_events.select("product_id", "product_name").distinct()
    .write.mode("overwrite")
    .format("delta")
    .saveAsTable(f"{catalog}.{silver_schema}.dim_product")
)
