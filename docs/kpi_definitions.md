# KPI Definitions

## Production

- Items Processed: count of print event rows.
- Printed Items: rows where `print_status = 'PRINTED'`.
- Reject Count: rows where `is_reject = true`.
- Reject Rate %: `reject_count / items_processed * 100`.

## QR Quality

- QR Read Success Count: rows where `qr_read_success = true`.
- QR Read Fail Count: rows where `qr_read_success = false`.
- QR Read Rate %: `qr_read_success_count / items_processed * 100`.
- Average QR Grade Score: average `qr_grade_score`.
- Average Position Error mm: average `position_error_mm`.

## Machine Health

- Average Actual Speed CPM: average `actual_speed_cpm`.
- Performance %: `average actual speed / average planned speed * 100`.
- Average Printhead Temperature C: average `printhead_temp_c`.
- Average Vibration mm/s: average `vibration_mm_s`.
- Ink ml per 1,000 Prints: `ink_used_ml / estimated printed output * 1000`.

## Downtime

- Fault Count: log rows where `severity = 'FAULT'`.
- Warning Count: log rows where `severity = 'WARNING'`.
- Downtime Minutes: sum of `downtime_minutes`.

## OEE

- Availability %: `run time minutes / planned production minutes * 100`.
- Performance %: `actual output / target output * 100`.
- Quality %: `good QR count / items processed * 100`.
- OEE %: `availability * performance * quality`.

