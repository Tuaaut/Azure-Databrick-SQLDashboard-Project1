from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timedelta, timezone

import azure.functions as func

from databricks_controller import set_databricks_job_pause_status
from qr_generator import build_payload


app = func.FunctionApp()


def get_setting(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None or value == "":
        raise ValueError(f"Missing required app setting: {name}")
    return value


def business_date_from_timer() -> datetime.date:
    return (datetime.now(timezone.utc).date() - timedelta(days=1))


@app.timer_trigger(
    schedule="%QR_TIMER_SCHEDULE%",
    arg_name="timer",
    run_on_startup=False,
    use_monitor=True,
)
@app.blob_output(
    arg_name="output_blob",
    path="raw/qr_printing/uploaded_at=azure_function/{DateTime:yyyyMMddTHHmmssZ}/machine_api_response.json",
    connection="TARGET_STORAGE_CONNECTION",
)
def generate_daily_machine_json(timer: func.TimerRequest, output_blob: func.Out[str]) -> None:
    if timer.past_due:
        logging.warning("Timer trigger is past due.")

    payload = generate_payload()
    output_blob.set(json.dumps(payload, indent=2))

    logging.info(
        "Generated QR printing daily JSON for business_date=%s with counts=%s",
        payload["start_ts"][:10],
        payload["record_counts"],
    )


@app.route(route="manual-generate", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
@app.blob_output(
    arg_name="output_blob",
    path="raw/qr_printing/uploaded_at=azure_function_manual/{DateTime:yyyyMMddTHHmmssZ}/machine_api_response.json",
    connection="TARGET_STORAGE_CONNECTION",
)
def manual_generate(req: func.HttpRequest, output_blob: func.Out[str]) -> func.HttpResponse:
    payload = generate_payload()
    output_blob.set(json.dumps(payload, indent=2))
    return func.HttpResponse(
        json.dumps({"status": "ok", "record_counts": payload["record_counts"]}),
        status_code=200,
        mimetype="application/json",
    )


@app.timer_trigger(
    schedule="%DATABRICKS_UNPAUSE_SCHEDULE%",
    arg_name="timer",
    run_on_startup=False,
    use_monitor=True,
)
def unpause_databricks_job(timer: func.TimerRequest) -> None:
    if timer.past_due:
        logging.warning("Unpause Databricks timer is past due.")

    result = set_databricks_job_pause_status("UNPAUSED")
    logging.info("Unpause Databricks completed: %s", result)


@app.timer_trigger(
    schedule="%DATABRICKS_PAUSE_SCHEDULE%",
    arg_name="timer",
    run_on_startup=False,
    use_monitor=True,
)
def pause_databricks_job(timer: func.TimerRequest) -> None:
    if timer.past_due:
        logging.warning("Pause Databricks timer is past due.")

    result = set_databricks_job_pause_status("PAUSED")
    logging.info("Pause Databricks completed: %s", result)


def generate_payload() -> dict:
    business_date = business_date_from_timer()
    line_id = get_setting("QR_LINE_ID", "line-01")
    machine_id = get_setting("QR_MACHINE_ID", "M01")
    product_id = get_setting("QR_PRODUCT_ID", "SKU-COLA-330")
    product_name = get_setting("QR_PRODUCT_NAME", "Cola Can 330ml")
    planned_speed_cpm = float(get_setting("QR_PLANNED_SPEED_CPM", "84.0"))
    events_per_hour = int(get_setting("QR_EVENTS_PER_HOUR", "120"))

    payload = build_payload(
        business_date=business_date,
        line_id=line_id,
        machine_id=machine_id,
        product_id=product_id,
        product_name=product_name,
        planned_speed_cpm=planned_speed_cpm,
        events_per_hour=events_per_hour,
    )
    return payload
