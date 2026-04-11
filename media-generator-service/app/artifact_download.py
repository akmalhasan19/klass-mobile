from __future__ import annotations

import hashlib
import hmac
import mimetypes
import tempfile
import time
from pathlib import Path
from secrets import compare_digest
from typing import Any
from urllib.parse import urlencode

from fastapi import Request

from app.errors import AuthenticationError, MediaGeneratorError
from app.settings import Settings


def build_signed_artifact_locator(
    request: Request,
    *,
    generation_id: str,
    artifact_metadata: dict[str, Any],
    settings: Settings,
) -> dict[str, str]:
    artifact_path = normalize_downloadable_artifact_path(
        str(artifact_metadata["artifact_locator"]["value"])
    )
    filename = str(artifact_metadata.get("filename") or artifact_path.name).strip() or artifact_path.name
    expires_at = int(time.time()) + settings.artifact_url_ttl_seconds
    signature = _build_artifact_signature(
        generation_id=generation_id,
        artifact_path=str(artifact_path),
        filename=filename,
        expires_at=expires_at,
        shared_secret=settings.shared_secret,
    )
    route_path = str(request.app.url_path_for("download_artifact"))
    base_url = settings.public_base_url.rstrip("/") if settings.public_base_url != "" else str(request.base_url).rstrip("/")
    query = urlencode(
        {
            "generation_id": generation_id,
            "path": str(artifact_path),
            "filename": filename,
            "expires": str(expires_at),
            "signature": signature,
        }
    )

    return {
        "kind": "signed_url",
        "value": f"{base_url}{route_path}?{query}",
    }


def verify_artifact_download_request(
    *,
    generation_id: str,
    artifact_path: str,
    filename: str,
    expires: int,
    signature: str,
    settings: Settings,
) -> Path:
    normalized_generation_id = generation_id.strip()
    normalized_filename = filename.strip()
    normalized_signature = signature.strip().lower()

    if normalized_generation_id == "":
        raise AuthenticationError(
            "artifact_generation_id_missing",
            "Artifact download generation_id is required.",
        )

    if normalized_filename == "":
        raise AuthenticationError(
            "artifact_filename_missing",
            "Artifact download filename is required.",
        )

    if expires < int(time.time()):
        raise AuthenticationError(
            "artifact_url_expired",
            "Artifact download URL has expired.",
        )

    resolved_artifact_path = normalize_downloadable_artifact_path(artifact_path)
    expected_signatures = [
        _build_artifact_signature(
            generation_id=normalized_generation_id,
            artifact_path=str(resolved_artifact_path),
            filename=normalized_filename,
            expires_at=expires,
            shared_secret=shared_secret,
        )
        for shared_secret in settings.accepted_shared_secrets
    ]

    if normalized_signature == "" or not any(
        compare_digest(expected_signature, normalized_signature)
        for expected_signature in expected_signatures
    ):
        raise AuthenticationError(
            "artifact_url_signature_invalid",
            "Artifact download signature is invalid.",
        )

    if not resolved_artifact_path.is_file():
        raise MediaGeneratorError(
            404,
            "artifact_not_found",
            "Requested artifact is no longer available.",
            {"path": str(resolved_artifact_path)},
            retryable=True,
            laravel_error_code_hint="python_service_unavailable",
        )

    return resolved_artifact_path


def normalize_downloadable_artifact_path(path_value: str) -> Path:
    normalized_path = path_value.strip()

    if normalized_path == "":
        raise AuthenticationError(
            "artifact_path_missing",
            "Artifact download path is required.",
        )

    artifact_path = Path(normalized_path).expanduser().resolve(strict=False)
    temp_root = Path(tempfile.gettempdir()).resolve(strict=False)

    try:
        artifact_path.relative_to(temp_root)
    except ValueError as exc:
        raise AuthenticationError(
            "artifact_path_invalid",
            "Artifact download path is outside the allowed temporary directory.",
            {"path": normalized_path},
        ) from exc

    if not artifact_path.name.startswith("klass_media_"):
        raise AuthenticationError(
            "artifact_path_invalid",
            "Artifact download path does not match the expected generator prefix.",
            {"path": normalized_path},
        )

    return artifact_path


def media_type_for_filename(filename: str) -> str:
    media_type, _ = mimetypes.guess_type(filename)
    return media_type or "application/octet-stream"


def _build_artifact_signature(
    *,
    generation_id: str,
    artifact_path: str,
    filename: str,
    expires_at: int,
    shared_secret: str,
) -> str:
    payload = "\n".join([generation_id, artifact_path, filename, str(expires_at)]).encode("utf-8")
    return hmac.new(shared_secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()