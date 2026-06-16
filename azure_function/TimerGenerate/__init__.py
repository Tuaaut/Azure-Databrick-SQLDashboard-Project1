from __future__ import annotations

import json
import logging

import azure.functions as func

from qr_generator import generate_payload_from_settings


def main(timer: func.TimerRequest, output_blob: func.Out[str]) -> None:
    if timer.past_due:
        logging.warning("Timer trigger is past due.")

    payload = generate_payload_from_settings()
    output_blob.set(json.dumps(payload, indent=2))
    logging.info("Generated daily QR machine JSON: %s", payload["record_counts"])
