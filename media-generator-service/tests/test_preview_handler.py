"""Unit tests for ``app.preview.preview_handler``.

Tests verify that:
* HTML preview files are stored with the correct prefix and content.
* Signed URLs generated for previews are accepted by the download endpoint.
* The download response has ``Content-Type: text/html`` and correct body.
"""
from __future__ import annotations

import hashlib
import hmac
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse

from fastapi import Depends, FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.testclient import TestClient

from app.artifact_download import (
    media_type_for_filename,
    verify_artifact_download_request,
)
from app.errors import MediaGeneratorError
from app.preview.preview_handler import build_preview_locator, store_preview_html
from app.settings import Settings, get_settings


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _settings() -> Settings:
    return get_settings()


def _build_test_app(preview_path: Path, generation_id: str, title: str) -> TestClient:
    """Create a minimal FastAPI app with preview-signing + download endpoints."""
    app = FastAPI()

    @app.exception_handler(MediaGeneratorError)
    async def _error_handler(request: Request, exc: MediaGeneratorError):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": {
                    "code": exc.code,
                    "message": exc.message,
                    "retryable": exc.retryable,
                    "details": exc.details,
                },
            },
        )

    @app.get("/test/sign-preview", name="sign_preview")
    async def sign_preview(request: Request, settings: Settings = Depends(get_settings)):
        locator = build_preview_locator(
            request,
            generation_id=generation_id,
            preview_path=preview_path,
            title=title,
            settings=settings,
        )
        return JSONResponse(locator)

    @app.get("/v1/artifacts/download", name="download_artifact")
    async def download_artifact(
        generation_id: str,
        path: str,
        filename: str,
        expires: int,
        signature: str,
        settings: Settings = Depends(get_settings),
    ) -> FileResponse:
        artifact_path = verify_artifact_download_request(
            generation_id=generation_id,
            artifact_path=path,
            filename=filename,
            expires=expires,
            signature=signature,
            settings=settings,
        )
        return FileResponse(
            path=str(artifact_path),
            media_type=media_type_for_filename(filename),
            filename=filename,
        )

    return TestClient(app)


# ---------------------------------------------------------------------------
# 1. store_preview_html
# ---------------------------------------------------------------------------

def test_store_preview_html_creates_file_with_correct_prefix() -> None:
    path = store_preview_html("<html>test</html>", "gen-001", "My Title")
    try:
        assert path.name.startswith("klass_media_html_")
        assert path.name.endswith(".html")
        assert path.is_file()
    finally:
        path.unlink(missing_ok=True)


def test_store_preview_html_writes_correct_content() -> None:
    html = "<!DOCTYPE html><html><body><h1>Hello</h1></body></html>"
    path = store_preview_html(html, "gen-002", "Test Deck")
    try:
        assert path.read_text(encoding="utf-8") == html
    finally:
        path.unlink(missing_ok=True)


def test_store_preview_html_includes_generation_id_in_name() -> None:
    path = store_preview_html("<html/>", "gen-abc-123", "Title")
    try:
        assert "gen-abc-123" in path.name
    finally:
        path.unlink(missing_ok=True)


def test_store_preview_html_includes_slug_in_name() -> None:
    path = store_preview_html("<html/>", "gen-001", "Pecahan Kelas 5")
    try:
        assert "pecahan-kelas-5" in path.name
    finally:
        path.unlink(missing_ok=True)


def test_store_preview_html_handles_empty_title() -> None:
    path = store_preview_html("<html/>", "gen-001", "")
    try:
        assert path.name.startswith("klass_media_html_")
        assert "preview" in path.name
    finally:
        path.unlink(missing_ok=True)


def test_store_preview_html_handles_unicode_title() -> None:
    path = store_preview_html("<html/>", "gen-001", "Pecahan Senilai — Matematika")
    try:
        assert path.is_file()
        assert path.name.endswith(".html")
    finally:
        path.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# 2. build_preview_locator (via test endpoint with proper request context)
# ---------------------------------------------------------------------------

def test_build_preview_locator_returns_signed_url() -> None:
    path = store_preview_html("<html>locator</html>", "gen-loc-001", "Deck")
    try:
        client = _build_test_app(path, "gen-loc-001", "Deck")
        response = client.get("/test/sign-preview")

        assert response.status_code == 200
        locator = response.json()
        assert locator["kind"] == "signed_url"
        assert "/v1/artifacts/download" in locator["value"]

        parsed = urlparse(locator["value"])
        qs = parse_qs(parsed.query)
        assert qs["generation_id"][0] == "gen-loc-001"
        assert qs["filename"][0].endswith(".html")
        assert "signature" in qs
        assert len(qs["signature"][0]) == 64
    finally:
        path.unlink(missing_ok=True)


def test_build_preview_locator_signature_is_valid() -> None:
    path = store_preview_html("<html>sig</html>", "gen-sig-001", "Title")
    try:
        client = _build_test_app(path, "gen-sig-001", "Title")
        response = client.get("/test/sign-preview")
        locator = response.json()

        parsed = urlparse(locator["value"])
        qs = parse_qs(parsed.query)

        from app.artifact_download import normalize_downloadable_artifact_path

        resolved_path = normalize_downloadable_artifact_path(qs["path"][0])
        payload = "\n".join([
            "gen-sig-001",
            str(resolved_path),
            qs["filename"][0],
            qs["expires"][0],
        ]).encode("utf-8")
        expected_sig = hmac.new(
            _settings().shared_secret.encode("utf-8"),
            payload,
            hashlib.sha256,
        ).hexdigest()

        assert qs["signature"][0] == expected_sig
    finally:
        path.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# 3. End-to-end: store → sign → download
# ---------------------------------------------------------------------------

def test_preview_download_returns_html_content() -> None:
    html = "<!DOCTYPE html><html><head><title>Preview</title></head><body><h1>Slide 1</h1></body></html>"
    path = store_preview_html(html, "gen-e2e-001", "E2E Deck")
    try:
        client = _build_test_app(path, "gen-e2e-001", "E2E Deck")
        sign_response = client.get("/test/sign-preview")
        locator = sign_response.json()

        parsed = urlparse(locator["value"])
        download_response = client.get(f"{parsed.path}?{parsed.query}")

        assert download_response.status_code == 200
        assert download_response.headers["content-type"].startswith("text/html")
        assert b"<h1>Slide 1</h1>" in download_response.content
    finally:
        path.unlink(missing_ok=True)


def test_preview_download_rejects_tampered_signature() -> None:
    path = store_preview_html("<html>tamper</html>", "gen-tamper-001", "Tamper")
    try:
        client = _build_test_app(path, "gen-tamper-001", "Tamper")
        sign_response = client.get("/test/sign-preview")
        locator = sign_response.json()

        parsed = urlparse(locator["value"])
        qs = parse_qs(parsed.query)
        qs["signature"] = ["0" * 64]

        download_response = client.get(f"{parsed.path}?{urlencode(qs, doseq=True)}")

        assert download_response.status_code == 401
        assert download_response.json()["error"]["code"] == "artifact_url_signature_invalid"
    finally:
        path.unlink(missing_ok=True)


def test_preview_download_serves_same_content_that_was_stored() -> None:
    html = "<!DOCTYPE html><html><body><p>Exact content match</p></body></html>"
    path = store_preview_html(html, "gen-exact-001", "Exact")
    try:
        client = _build_test_app(path, "gen-exact-001", "Exact")
        sign_response = client.get("/test/sign-preview")
        locator = sign_response.json()

        parsed = urlparse(locator["value"])
        download_response = client.get(f"{parsed.path}?{parsed.query}")

        assert download_response.content == html.encode("utf-8")
    finally:
        path.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# 4. media_type_for_filename for .html
# ---------------------------------------------------------------------------

def test_media_type_for_filename_returns_text_html() -> None:
    assert media_type_for_filename("preview.html") == "text/html"


def test_media_type_for_filename_returns_text_html_with_full_name() -> None:
    assert media_type_for_filename("klass_media_html_gen-001_deck_preview.html") == "text/html"
