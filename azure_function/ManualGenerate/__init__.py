from __future__ import annotations

import json

import azure.functions as func

from qr_generator import generate_payload_from_settings


def main(req: func.HttpRequest, output_blob: func.Out[str]) -> func.HttpResponse:
    payload = generate_payload_from_settings()
    output_blob.set(json.dumps(payload, indent=2))
    return func.HttpResponse(
        json.dumps({"status": "ok", "record_counts": payload["record_counts"]}),
        status_code=200,
        mimetype="application/json",
    )
