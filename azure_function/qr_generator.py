from __future__ import annotations

import hashlib
import os
import random
from datetime import date, datetime, time, timedelta, timezone
from typing import Any


FAULTS = {
    "QR_READ_FAIL": "QR reader failed validation",
    "VISION_DIRTY_LENS": "Vision camera lens requires cleaning",
    "PRINTHEAD_TEMP_HIGH": "Printhead temperature above normal band",
    "ENCODER_SIGNAL_LOSS": "Conveyor encoder signal unstable",
    "REJECT_GATE_JAM": "Reject gate did not complete movement",
}


def seeded_rng(*parts: Any) -> random.Random:
    seed_text = "|".join(str(part) for part in parts)
    seed = int(hashlib.sha256(seed_text.encode("utf-8")).hexdigest()[:16], 16)
    return random.Random(seed)


def minute_range(start_ts: datetime, end_ts: datetime) -> list[datetime]:
    current = start_ts
    minutes = []
    while current < end_ts:
        minutes.append(current)
        current += timedelta(minutes=1)
    return minutes


def machine_state(minute: datetime, rng: random.Random) -> tuple[str, str | None, int]:
    minute_of_day = minute.hour * 60 + minute.minute
    if 2 <= minute.hour < 3:
        return "PLANNED_STOP", None, 60
    if minute_of_day % 211 in {0, 1, 2}:
        return "FAULT", "REJECT_GATE_JAM", 60
    if minute_of_day % 97 == 0:
        return "WARNING", "VISION_DIRTY_LENS", 0
    if rng.random() < 0.018:
        fault_code = rng.choice(list(FAULTS))
        severity = "FAULT" if fault_code in {"REJECT_GATE_JAM", "ENCODER_SIGNAL_LOSS"} else "WARNING"
        downtime = 60 if severity == "FAULT" else 0
        return severity, fault_code, downtime
    return "RUNNING", None, 0


def events_for_minute(events_per_hour: int, minute: datetime) -> int:
    base_events, extra_events = divmod(events_per_hour, 60)
    return base_events + (1 if minute.minute < extra_events else 0)


def build_payload(
    business_date: date,
    line_id: str,
    machine_id: str,
    product_id: str,
    product_name: str,
    planned_speed_cpm: float,
    events_per_hour: int,
) -> dict[str, Any]:
    start_ts = datetime.combine(business_date, time.min, tzinfo=timezone.utc)
    end_ts = start_ts + timedelta(days=1)

    print_events = []
    telemetry = []
    logs = []

    for minute in minute_range(start_ts, end_ts):
        rng = seeded_rng(line_id, machine_id, minute.isoformat())
        state, fault_code, downtime_seconds = machine_state(minute, rng)
        target_events = events_for_minute(events_per_hour, minute)
        speed_factor = 0 if state in {"FAULT", "PLANNED_STOP"} else rng.uniform(0.88, 1.03)
        actual_speed = min(round(planned_speed_cpm * speed_factor, 2), float(target_events))
        printhead_temp = round(rng.normalvariate(42, 2.5) + (1.8 if actual_speed > planned_speed_cpm else 0), 2)
        vibration = round(max(0.4, rng.normalvariate(1.7, 0.45) + (0.5 if fault_code else 0)), 3)
        ink_used = round(actual_speed * 0.058, 3)

        telemetry.append(
            {
                "telemetry_ts": minute.isoformat().replace("+00:00", "Z"),
                "machine_id": machine_id,
                "actual_speed_cpm": actual_speed,
                "planned_speed_cpm": planned_speed_cpm,
                "printhead_temp_c": printhead_temp,
                "vibration_mm_s": vibration,
                "ink_used_ml": ink_used,
            }
        )

        if fault_code:
            logs.append(
                {
                    "log_id": f"log-{machine_id}-{minute:%Y%m%d%H%M}-{fault_code}",
                    "log_ts": minute.isoformat().replace("+00:00", "Z"),
                    "machine_id": machine_id,
                    "severity": state,
                    "fault_code": fault_code,
                    "message": FAULTS[fault_code],
                    "downtime_minutes": round(downtime_seconds / 60, 2),
                }
            )

        for index in range(target_events):
            item_rng = seeded_rng(line_id, machine_id, minute.isoformat(), index)
            event_ts = minute + timedelta(seconds=index * 60 / max(target_events, 1))
            qr_read_success = item_rng.random() > (0.018 + (0.02 if vibration > 2.4 else 0))
            print_status = "PRINTED" if state not in {"FAULT", "PLANNED_STOP"} and item_rng.random() > 0.006 else "FAILED"
            position_error = round(item_rng.normalvariate(0.18, 0.09) + (0.16 if vibration > 2.4 else 0), 3)
            is_reject = print_status != "PRINTED" or not qr_read_success or abs(position_error) > 0.45
            grade_score = round(max(0.0, min(1.0, item_rng.normalvariate(0.94, 0.05) - abs(position_error) * 0.16)), 3)

            print_events.append(
                {
                    "event_id": f"evt-{machine_id}-{event_ts:%Y%m%d%H%M%S}-{index:04d}",
                    "event_ts": event_ts.isoformat().replace("+00:00", "Z"),
                    "machine_id": machine_id,
                    "product_id": product_id,
                    "product_name": product_name,
                    "qr_code": f"QR-{business_date:%Y%m%d}-{minute:%H%M}-{index:04d}",
                    "print_status": print_status,
                    "qr_read_success": qr_read_success,
                    "is_reject": is_reject,
                    "qr_grade_score": grade_score,
                    "position_error_mm": position_error,
                }
            )

    return {
        "batch_id": f"batch-{business_date:%Y%m%d}",
        "line_id": line_id,
        "start_ts": start_ts.isoformat().replace("+00:00", "Z"),
        "end_ts": end_ts.isoformat().replace("+00:00", "Z"),
        "record_counts": {
            "print_events": len(print_events),
            "machine_telemetry": len(telemetry),
            "machine_logs": len(logs),
        },
        "print_events": print_events,
        "machine_telemetry": telemetry,
        "machine_logs": logs,
    }


def get_setting(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None or value == "":
        raise ValueError(f"Missing required app setting: {name}")
    return value


def business_date_from_timer() -> date:
    return datetime.now(timezone.utc).date() - timedelta(days=1)


def generate_payload_from_settings() -> dict[str, Any]:
    return build_payload(
        business_date=business_date_from_timer(),
        line_id=get_setting("QR_LINE_ID", "line-01"),
        machine_id=get_setting("QR_MACHINE_ID", "M01"),
        product_id=get_setting("QR_PRODUCT_ID", "SKU-COLA-330"),
        product_name=get_setting("QR_PRODUCT_NAME", "Cola Can 330ml"),
        planned_speed_cpm=float(get_setting("QR_PLANNED_SPEED_CPM", "84.0")),
        events_per_hour=int(get_setting("QR_EVENTS_PER_HOUR", "120")),
    )
