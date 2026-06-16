# Databricks Learning and Quiz Notes

This file tracks the Databricks learning path, quiz questions, correct answers, and review links for this project.

## Review Links

Clickable local quiz:

```text
databricks_quiz.html
```

If the local web server is running:

```text
http://127.0.0.1:8765/databricks_quiz.html
```

Main Databricks links:

```text
Workspace:
https://adb-7405612371776871.11.azuredatabricks.net/?o=7405612371776871

Catalog Explorer:
https://adb-7405612371776871.11.azuredatabricks.net/explore/data?o=7405612371776871

SQL Warehouses:
https://adb-7405612371776871.11.azuredatabricks.net/sql/warehouses?o=7405612371776871

Dashboard:
https://adb-7405612371776871.11.azuredatabricks.net/dashboardsv3/01f1699203951f9389c58c97cd030c79/published?o=7405612371776871
```

## Learning Goal

Understand the project in this order:

1. What Databricks Workspace is.
2. What Compute and SQL Warehouse are.
3. Why compute can cost money when active.
4. What Catalog, Schema, Table, and View mean.
5. What Bronze, Silver, and Gold layers mean.
6. How Gold KPI views feed the dashboard.
7. How to check data in Catalog Explorer.
8. How to stop compute after testing.

## Core Mental Model

```text
Workspace = where you work
Compute / SQL Warehouse = engine that runs code or SQL
Catalog = top-level data container
Schema = folder/group inside a catalog
Table = stored data
View = saved SQL logic that shows query results
Bronze = raw data
Silver = cleaned data
Gold = business-ready KPI data
Dashboard = charts built from Gold views
```

## Conceptual Quiz History

### Question 1

What is the main difference between Workspace and Compute?

Correct answer:

```text
Workspace is where project UI/files live. Compute runs code or SQL and can cost money when active.
```

Remember:

```text
Workspace is the house. Compute is the engine.
```

### Question 2

In this project, which compute path is currently working?

Correct answer:

```text
Serverless SQL Warehouse path.
```

The PySpark cluster path is prepared, but blocked by Azure VM acquisition in Southeast Asia.

### Question 3

What does a SQL Warehouse do in Databricks?

Correct answer:

```text
Runs SQL queries for tables, views, and dashboards.
```

### Question 4

What do Bronze, Silver, and Gold mean?

Correct answer:

```text
Data quality layers: raw, cleaned, business-ready.
```

### Question 5

Which layer should the dashboard read from?

Correct answer:

```text
Gold.
```

Dashboards should use Gold because Gold contains KPI-ready data.

### Question 6

What is a Databricks catalog used for?

Correct answer:

```text
Organizing schemas, tables, and views under governance.
```

### Question 7

What is a schema?

Correct answer:

```text
A folder/group inside a catalog that contains tables and views.
```

Example:

```text
adb_qr_printing_demo.gold_qr_printing.hourly_kpi_summary
```

### Question 8

What does `bronze_qr_printing.machine_logs_raw` represent?

Correct answer:

```text
Raw machine warning/fault log data.
```

## UI Quiz History

These questions are meant to be answered while looking at Databricks Catalog Explorer.

### UI Question 1

In Catalog Explorer, what type of object is `hourly_kpi_summary`?

Correct answer:

```text
View.
```

Why:

```text
It is a saved SQL result, not a physical raw table.
```

### UI Question 2

In `hourly_kpi_summary`, which column tells the time bucket?

Correct answer:

```text
production_hour
```

Why:

```text
The Gold KPI view groups production by hour and machine.
```

### UI Question 3

How do you show the data for a table or view?

Correct answer:

```text
Open the object in Catalog Explorer, then click Sample Data.
```

Note:

```text
Sample Data may start the Serverless SQL Warehouse.
```

### UI Question 4

In the screenshot, why does `hourly_kpi_summary` show only 1 row?

Correct answer:

```text
The sample data has 2 print events for the same machine and same hour, so the Gold view groups them into 1 hourly KPI row.
```

The row is expected:

```text
production_hour: 2026-06-16 08:00
machine_id: M01
items_processed: 2
```

### UI Question 5

What does the green dot next to `Serverless Starter Warehouse` mean?

Correct answer:

```text
The SQL Warehouse is running / active.
```

Important:

```text
This is the SQL Warehouse, not a PySpark cluster.
```

### UI Question 6

How do you stop the running SQL Warehouse manually?

Correct answer:

```text
Left menu -> SQL Warehouses -> Serverless Starter Warehouse -> Stop
```

Shortcut:

```text
Click the warehouse name near the top of Catalog Explorer, then click Stop.
```

## Cost Safety Checklist

After learning or testing:

1. Check SQL Warehouse.
2. Stop `Serverless Starter Warehouse` if it is running.
3. Check Compute.
4. Confirm no all-purpose or job clusters are running.
5. Remember that sample data, SQL queries, and dashboards can start the SQL Warehouse.

CLI stop command:

```bash
export DATABRICKS_HOST="https://adb-7405612371776871.11.azuredatabricks.net"
databricks warehouses stop a10d49c1b859854a
```

## Suggested Learning Journey

Use short practice loops:

1. Learn one Databricks concept.
2. Click the matching place in the UI.
3. Answer one quiz question.
4. Check why the answer is correct.
5. Stop compute if it started.

Recommended next lessons:

1. Catalog Explorer: how to find Catalog -> Schema -> View.
2. Sample Data: how to inspect rows and columns.
3. Gold KPIs: what each KPI column means.
4. SQL Warehouse: start, stop, and cost behavior.
5. Dashboard: how widgets read from Gold views.

## Concerns

Keep learning focused on one screen at a time. The Codex in-app browser currently works best with one active page, so side-by-side Databricks plus quiz is limited.

Best workaround:

```text
Use Databricks UI in the browser, and keep quiz questions in chat.
```

For deeper review later, open `databricks_quiz.html`.
