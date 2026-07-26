from __future__ import annotations

import hashlib
import hmac
import mimetypes
import time
from pathlib import Path
from typing import Any

# pyrefly: ignore [missing-import]
from fastapi import Request

from app.errors import AuthenticationError, MediaGeneratorError
from app.settings import Settings


def media_type_for_filename(filename: str) -> str:
    guess, _ = mimetypes.guess_type(filename)
    return guess or "application/octet-stream"


def _compute_signature(
    generation_id: str,
    artifact_path: str,
    filename: str,
    expires: int,
    secret: str,
) -> str:
    path_str = str(Path(artifact_path).resolve())
    payload = "\n".join([
        generation_id,
        path_str,
        filename,
        str(expires),
    ]).encode("utf-8")
    return hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()


def normalize_downloadable_artifact_path(path: str) -> Path:
    p = Path(path).resolve()
    if p.name.startswith("klass_media_"):
        return p
    raise MediaGeneratorError(400, "invalid_artifact_path", "Path is not an allowed artifact path")


def build_signed_artifact_locator(
    request: Request,
    generation_id: str,
    artifact_metadata: dict[str, Any],
    settings: Settings,
) -> dict[str, Any]:
    artifact_path = str(artifact_metadata.get("artifact_locator", {}).get("value", ""))
    filename = str(artifact_metadata.get("filename", "artifact"))
    expires = int(time.time()) + 3600
    signature = _compute_signature(generation_id, artifact_path, filename, expires, settings.shared_secret)
    base_url = str(request.base_url).rstrip("/")
    url = f"{base_url}/v1/artifacts/download?generation_id={generation_id}&path={artifact_path}&filename={filename}&expires={expires}&signature={signature}"
    return {"kind": "signed_url", "value": url}


def verify_artifact_download_request(
    generation_id: str,
    artifact_path: str,
    filename: str,
    expires: int,
    signature: str,
    settings: Settings,
) -> Path:
    current_time = int(time.time())
    if expires != 0 and current_time > expires:
        raise AuthenticationError("signature_expired", "Download URL has expired")

    expected = _compute_signature(generation_id, artifact_path, filename, expires, settings.shared_secret)
    if not hmac.compare_digest(signature.lower(), expected.lower()):
        raise AuthenticationError("invalid_signature", "Download URL signature is invalid")

    return normalize_downloadable_artifact_path(artifact_path)
