from __future__ import annotations

import hashlib
import hmac
import time
from secrets import compare_digest

from fastapi import Request

from app.contracts import SIGNATURE_ALGORITHM
from app.errors import AuthenticationError, ServiceMisconfiguredError
from app.settings import get_settings


async def verify_request_signature(request: Request) -> None:
    settings = get_settings()

    if settings.shared_secret == "":
        raise ServiceMisconfiguredError(
            "Python media generator shared secret is not configured.",
            {"config": "MEDIA_GENERATION_PYTHON_SHARED_SECRET"},
        )

    generation_id = (request.headers.get("X-Klass-Generation-Id") or "").strip()
    timestamp = (request.headers.get("X-Klass-Request-Timestamp") or "").strip()
    signature_algorithm = (request.headers.get("X-Klass-Signature-Algorithm") or "").strip().lower()
    signature = (request.headers.get("X-Klass-Signature") or "").strip().lower()

    if generation_id == "":
        raise AuthenticationError(
            "generation_id_header_missing",
            "X-Klass-Generation-Id header is required.",
        )

    if signature_algorithm != SIGNATURE_ALGORITHM:
        raise AuthenticationError(
            "signature_algorithm_invalid",
            "Request signature algorithm is invalid.",
            {"expected": SIGNATURE_ALGORITHM, "received": signature_algorithm or None},
        )

    try:
        issued_at = int(timestamp)
    except ValueError as exc:
        raise AuthenticationError(
            "timestamp_invalid",
            "X-Klass-Request-Timestamp must be a UNIX timestamp.",
        ) from exc

    current_time = int(time.time())
    if abs(current_time - issued_at) > settings.request_max_age_seconds:
        raise AuthenticationError(
            "timestamp_out_of_range",
            "Request timestamp is outside the accepted range.",
            {"allowed_age_seconds": settings.request_max_age_seconds},
        )

    body = await request.body()
    expected_signature = hmac.new(
        settings.shared_secret.encode("utf-8"),
        timestamp.encode("utf-8") + b"." + body,
        hashlib.sha256,
    ).hexdigest()

    if signature == "" or not compare_digest(expected_signature, signature):
        raise AuthenticationError(
            "signature_invalid",
            "Request signature is invalid.",
        )

    request.state.authenticated_generation_id = generation_id
