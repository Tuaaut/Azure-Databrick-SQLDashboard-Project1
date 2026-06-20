from __future__ import annotations

import json
import logging
import os
import urllib.error
import urllib.parse
import urllib.request


DATABRICKS_RESOURCE = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"
AZURE_MANAGEMENT_RESOURCE = "https://management.core.windows.net/"


def get_setting(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing app setting: {name}")
    return value


def get_managed_identity_token(resource: str) -> str:
    endpoint = os.getenv("IDENTITY_ENDPOINT") or os.getenv("MSI_ENDPOINT")
    header_value = os.getenv("IDENTITY_HEADER") or os.getenv("MSI_SECRET")
    if not endpoint or not header_value:
        raise RuntimeError("Managed identity endpoint is not available.")

    query = urllib.parse.urlencode({"api-version": "2019-08-01", "resource": resource})
    separator = "&" if "?" in endpoint else "?"
    request = urllib.request.Request(f"{endpoint}{separator}{query}")
    request.add_header("X-IDENTITY-HEADER", header_value)
    request.add_header("Metadata", "true")

    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.loads(response.read().decode("utf-8"))
    return payload["access_token"]


def databricks_request(method: str, path: str, payload: dict | None = None) -> dict:
    host = get_setting("DATABRICKS_HOST").rstrip("/")
    workspace_resource_id = get_setting("DATABRICKS_AZURE_RESOURCE_ID")
    databricks_token = get_managed_identity_token(DATABRICKS_RESOURCE)
    management_token = get_managed_identity_token(AZURE_MANAGEMENT_RESOURCE)

    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(f"{host}{path}", data=body, method=method)
    request.add_header("Authorization", f"Bearer {databricks_token}")
    request.add_header("X-Databricks-Azure-SP-Management-Token", management_token)
    request.add_header("X-Databricks-Azure-Workspace-Resource-Id", workspace_resource_id)
    request.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            response_body = response.read().decode("utf-8")
            return json.loads(response_body) if response_body else {}
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Databricks API failed: {exc.code} {error_body}") from exc


def set_databricks_job_pause_status(pause_status: str) -> dict:
    job_id = int(get_setting("DATABRICKS_JOB_ID"))
    current_job = databricks_request("GET", f"/api/2.1/jobs/get?job_id={job_id}")
    schedule = dict(current_job["settings"]["schedule"])
    before = schedule.get("pause_status")
    schedule["pause_status"] = pause_status

    databricks_request(
        "POST",
        "/api/2.1/jobs/update",
        {"job_id": job_id, "new_settings": {"schedule": schedule}},
    )
    logging.info("Databricks job %s pause_status changed from %s to %s", job_id, before, pause_status)
    return {"job_id": job_id, "before": before, "after": pause_status}
