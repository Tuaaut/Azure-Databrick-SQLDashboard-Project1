# Databricks notebook source
# Bronze ingestion for QR printing raw JSON.

from pyspark.sql import functions as F

dbutils.widgets.text(
    "raw_path",
    "abfss://raw@qrdbx06162114.dfs.core.windows.net/qr_printing",
)
dbutils.widgets.text("storage_account", "qrdbx06162114")
dbutils.widgets.text("secret_scope", "qr-printing-secrets")
dbutils.widgets.text("secret_key", "adls-account-key")
dbutils.widgets.text("catalog", "adb_qr_printing_demo")
dbutils.widgets.text("bronze_schema", "bronze_qr_printing")

raw_path = dbutils.widgets.get("raw_path")
storage_account = dbutils.widgets.get("storage_account")
secret_scope = dbutils.widgets.get("secret_scope")
secret_key = dbutils.widgets.get("secret_key")
catalog = dbutils.widgets.get("catalog")
bronze_schema = dbutils.widgets.get("bronze_schema")

spark.conf.set(
    f"fs.azure.account.key.{storage_account}.dfs.core.windows.net",
    dbutils.secrets.get(scope=secret_scope, key=secret_key),
)

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {catalog}.{bronze_schema}")

raw_df = (
    spark.read.option("multiLine", True)
    .option("recursiveFileLookup", True)
    .json(raw_path)
    .withColumn("_ingested_at", F.current_timestamp())
    .withColumn("_source_file", F.input_file_name())
)

for source_col, table_name in [
    ("print_events", "print_events_raw"),
    ("machine_telemetry", "machine_telemetry_raw"),
    ("machine_logs", "machine_logs_raw"),
]:
    if source_col in raw_df.columns:
        (
            raw_df.select(F.explode_outer(source_col).alias("record"), "_ingested_at", "_source_file")
            .select("record.*", "_ingested_at", "_source_file")
            .write.mode("append")
            .format("delta")
            .saveAsTable(f"{catalog}.{bronze_schema}.{table_name}")
        )
