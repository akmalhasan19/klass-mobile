from __future__ import annotations

import hashlib
import hmac
import json
import time

from fastapi import Depends, FastAPI, Request
from fastapi.testclient import TestClient

from app.auth import verify_request_signature
from app.main import attach_request_id
from app.settings import clear_settings_cache


def build_signed_request(
    *,
    generation_id: str = "gen-123",
    request_id: str = "req-123",
    payload: dict[str, object] | None = None,
    secret: str = "test-shared-secret",
    timestamp: int | None = None,
) -> tuple[bytes, dict[str, str]]:
    body_payload = payload or {"request_type": "media_prompt_interpretation"}
    body = json.dumps(body_payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    issued_at = str(timestamp if timestamp is not None else int(time.time()))
    signature = hmac.new(
        secret.encode("utf-8"),
        issued_at.encode("utf-8") + b"." + body,
        hashlib.sha256,
    ).hexdigest()

    return body, {
        "Content-Type": "application/json",
        "X-Request-Id": request_id,
        "X-Klass-Generation-Id": generation_id,
        "X-Klass-Request-Timestamp": issued_at,
        "X-Klass-Signature-Algorithm": "hmac-sha256",
        "X-Klass-Signature": signature,
    }


def make_auth_client() -> TestClient:
    auth_app = FastAPI()
    auth_app.middleware("http")(attach_request_id)

    @auth_app.post("/v1/interpret")
    async def interpret(request: Request, _: None = Depends(verify_request_signature)) -> dict[str, object]:
        return {
            "request_id": request.state.request_id,
            "actor_metadata": request.state.actor_metadata,
            "trace_context": request.state.trace_context,
        }

    @auth_app.post("/v1/respond")
    async def respond(request: Request, _: None = Depends(verify_request_signature)) -> dict[str, object]:
        return {
            "request_id": request.state.request_id,
            "actor_metadata": request.state.actor_metadata,
            "trace_context": request.state.trace_context,
        }

    return TestClient(auth_app)


def test_signed_interpret_request_is_accepted_and_preserves_request_trace() -> None:
    client = make_auth_client()
    body, headers = build_signed_request(request_id="req-interpret-1")

    response = client.post("/v1/interpret", content=body, headers=headers)

    assert response.status_code == 200
    assert response.headers["X-Request-Id"] == "req-interpret-1"
    payload = response.json()
    assert payload["request_id"] == "req-interpret-1"
    assert payload["actor_metadata"] == {
        "request_id": "req-interpret-1",
        "generation_id": "gen-123",
        "route_type": "interpret",
    }
    assert payload["trace_context"]["generation_id"] == "gen-123"
    assert payload["trace_context"]["route_type"] == "interpret"
    assert payload["trace_context"]["signature_algorithm"] == "hmac-sha256"


def test_signed_delivery_request_accepts_previous_rotated_secret(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_SHARED_SECRET", "next-shared-secret")
    monkeypatch.setenv("LLM_ADAPTER_SHARED_SECRET_PREVIOUS", "legacy-shared-secret,test-shared-secret")
    clear_settings_cache()
    client = make_auth_client()
    body, headers = build_signed_request(
        request_id="req-delivery-1",
        payload={"request_type": "media_delivery_response"},
        secret="test-shared-secret",
    )

    response = client.post("/v1/respond", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["trace_context"]["route_type"] == "respond"
    assert payload["trace_context"]["request_id"] == "req-delivery-1"


def test_request_without_valid_signature_is_rejected() -> None:
    client = make_auth_client()
    body, headers = build_signed_request()
    headers["X-Klass-Signature"] = "0" * 64

    response = client.post("/v1/interpret", content=body, headers=headers)

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "signature_invalid"


def test_request_without_generation_id_header_is_rejected() -> None:
    client = make_auth_client()
    body, headers = build_signed_request()
    headers.pop("X-Klass-Generation-Id")

    response = client.post("/v1/interpret", content=body, headers=headers)

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "generation_id_header_missing"


def test_request_is_rejected_when_shared_secret_is_missing(monkeypatch) -> None:
    monkeypatch.delenv("LLM_ADAPTER_SHARED_SECRET", raising=False)
    monkeypatch.delenv("LLM_ADAPTER_SHARED_SECRET_PREVIOUS", raising=False)
    clear_settings_cache()
    client = make_auth_client()
    body, headers = build_signed_request(secret="test-shared-secret")

    response = client.post("/v1/interpret", content=body, headers=headers)

    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "shared_secret_missing"