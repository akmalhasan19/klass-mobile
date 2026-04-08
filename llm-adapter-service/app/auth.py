from __future__ import annotations

import hashlib
import hmac
import time
from secrets import compare_digest

from fastapi import HTTPException, Request, status

from app.contracts import (
    GENERATION_ID_HEADER,
    REQUEST_ID_HEADER,
    SIGNATURE_ALGORITHM,
    SIGNATURE_ALGORITHM_HEADER,
    SIGNATURE_HEADER,
    TIMESTAMP_HEADER,
)
from app.settings import Settings, get_settings


def auth_readiness_payload(settings: Settings) -> dict[str, object]:
    configured = settings.shared_secret != ""

    return {
        "ready": configured,
        "configured": configured,
        "rotation_enabled": settings.rotation_enabled,
        "accepted_secret_count": len(settings.accepted_shared_secrets),
        "max_request_age_seconds": settings.request_max_age_seconds,
        "signature_algorithm": SIGNATURE_ALGORITHM,
    }


def resolve_route_type(path: str) -> str | None:
    normalized_path = path.rstrip("/") or "/"

    if normalized_path.endswith("/v1/interpret"):
        return "interpret"

    if normalized_path.endswith("/v1/respond"):
        return "respond"

    return None


def _auth_error(status_code: int, code: str, message: str, details: dict[str, object] | None = None) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail={
            "code": code,
            "message": message,
            "details": details or {},
        },
    )


async def verify_request_signature(request: Request) -> None:
    settings = get_settings()
    generation_id = (request.headers.get(GENERATION_ID_HEADER) or "").strip()
    timestamp = (request.headers.get(TIMESTAMP_HEADER) or "").strip()
    signature_algorithm = (request.headers.get(SIGNATURE_ALGORITHM_HEADER) or "").strip().lower()
    signature = (request.headers.get(SIGNATURE_HEADER) or "").strip().lower()
    request_id = (getattr(request.state, "request_id", None) or request.headers.get(REQUEST_ID_HEADER) or "").strip() or None
    route_type = resolve_route_type(request.url.path)

    request.state.actor_metadata = {
        "request_id": request_id,
        "generation_id": generation_id or None,
        "route_type": route_type,
    }

    if settings.shared_secret == "":
        raise _auth_error(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "shared_secret_missing",
            "LLM adapter shared secret is not configured.",
            {"config": "LLM_ADAPTER_SHARED_SECRET"},
        )

    if generation_id == "":
        raise _auth_error(
            status.HTTP_401_UNAUTHORIZED,
            "generation_id_header_missing",
            f"{GENERATION_ID_HEADER} header is required.",
        )

    if signature_algorithm != SIGNATURE_ALGORITHM:
        raise _auth_error(
            status.HTTP_401_UNAUTHORIZED,
            "signature_algorithm_invalid",
            "Request signature algorithm is invalid.",
            {"expected": SIGNATURE_ALGORITHM, "received": signature_algorithm or None},
        )

    try:
        issued_at = int(timestamp)
    except ValueError as exc:
        raise _auth_error(
            status.HTTP_401_UNAUTHORIZED,
            "timestamp_invalid",
            f"{TIMESTAMP_HEADER} must be a UNIX timestamp.",
        ) from exc

    if abs(int(time.time()) - issued_at) > settings.request_max_age_seconds:
        raise _auth_error(
            status.HTTP_401_UNAUTHORIZED,
            "timestamp_out_of_range",
            "Request timestamp is outside the accepted range.",
            {"allowed_age_seconds": settings.request_max_age_seconds},
        )

    body = await request.body()
    expected_signatures = [
        hmac.new(
            shared_secret.encode("utf-8"),
            timestamp.encode("utf-8") + b"." + body,
            hashlib.sha256,
        ).hexdigest()
        for shared_secret in settings.accepted_shared_secrets
    ]

    if signature == "" or not any(compare_digest(expected_signature, signature) for expected_signature in expected_signatures):
        raise _auth_error(
            status.HTTP_401_UNAUTHORIZED,
            "signature_invalid",
            "Request signature is invalid.",
        )

    request.state.authenticated_generation_id = generation_id
    request.state.trace_context = {
        "request_id": request_id,
        "generation_id": generation_id,
        "route_type": route_type,
        "signature_algorithm": SIGNATURE_ALGORITHM,
    }
