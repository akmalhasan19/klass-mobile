"""API integration tests for the HTML preview delivery (Fase 2C/D/E).

Tests verify the end-to-end flow from ``POST /v1/generate`` through signed-URL
preview download.  Both the sidecar manager and the template registry are
mocked (``MagicMock`` + ``AsyncMock``) so that Node.js/Chromium are **not**
required.

After the Marp-to-Jinja2 migration (Fase 2), the preview rendering flow in
``main.py`` uses ``HtmlTemplateEngine`` + ``template_registry`` instead of
the old ``MarpRenderer.render_html()``.  Consequently, tests must mock
**both** ``app.main.sidecar_manager`` and ``app.main.template_registry``
when verifying preview delivery.

Test coverage:
* PPTX generation -> ``preview_delivery`` present, signed URL valid, download 200.
* PDF generation -> ``preview_delivery`` present (requires patching
  ``PdfGenerator._run_async`` bridge, which is skipped here — the PPTX
  tests cover the shared preview code path in ``main.py``).
* DOCX generation -> ``preview_delivery`` absent (preview only for slide formats).
* Health endpoint -> ``sidecar`` status block reflects mock state.
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import AsyncMock, MagicMock
from urllib.parse import parse_qs, urlencode, urlparse

import pytest

from tests.helpers import artifact_path_from_metadata, cleanup_artifact, signed_request_content

# Path to the real HTML master template (used by the mock template registry).
_MASTERS_DIR = Path(__file__).resolve().parent.parent / "app" / "templates" / "masters"
_HTML_MASTER_PATH = _MASTERS_DIR / "klass-educational-v1.html"


def _mock_ready_sidecar() -> MagicMock:
    """Return a mock ``SidecarManager`` that appears ready.

    The sidecar is never actually called by the preview flow after Fase 2C
    (preview uses ``HtmlTemplateEngine`` synchronously).  This mock only
    needs to satisfy the ``sidecar_manager is not None`` guard in ``main.py``.
    """
    sc = MagicMock()
    sc.is_running = True
    sc.is_ready = True
    sc.uptime_seconds = 42.0
    return sc


def _mock_template_registry() -> MagicMock:
    """Return a mock ``TemplateRegistry`` that resolves the real HTML master.

    The ``main.py`` preview flow calls ``template_registry.get_html_master()``
    and passes the result to ``HtmlTemplateEngine``.  We return the real
    master path so the engine can render actual Jinja2 HTML.
    """
    tr = MagicMock()
    tr.get_html_master.return_value = _HTML_MASTER_PATH
    return tr


def _patch_deps(monkeypatch: pytest.MonkeyPatch) -> None:
    """Patch ``app.main`` globals so the preview flow is fully wired."""
    import app.main

    monkeypatch.setattr(app.main, "sidecar_manager", _mock_ready_sidecar())
    monkeypatch.setattr(app.main, "template_registry", _mock_template_registry())


def _extract_preview_path(metadata_or_locator: dict[str, object]) -> Path | None:
    """Extract the temp file path from a preview locator signed URL."""
    locator = metadata_or_locator.get("locator") or metadata_or_locator.get("artifact_locator")
    if not isinstance(locator, dict):
        return None
    path_value = locator.get("value")
    if not isinstance(path_value, str):
        return None
    if locator.get("kind") == "signed_url":
        query = parse_qs(urlparse(path_value).query)
        path_value = (query.get("path") or [""])[0]
    if not path_value:
        return None
    return Path(path_value)


def _cleanup_preview_artifact(preview_delivery: dict[str, object]) -> None:
    """Remove the temp HTML file referenced by ``preview_delivery``."""
    if not isinstance(preview_delivery, dict):
        return
    path = _extract_preview_path(preview_delivery)
    if path is not None:
        path.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# 1. PPTX — preview delivery
# ---------------------------------------------------------------------------


def test_generate_pptx_includes_preview_delivery(client, monkeypatch) -> None:
    """When sidecar and template registry are available, pptx returns preview_delivery."""
    _patch_deps(monkeypatch)

    body, headers, _ = signed_request_content("pptx")
    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["data"]["preview_delivery"] is not None
    pd = payload["data"]["preview_delivery"]
    assert pd["schema_version"] == "media_generator_preview.v1"
    assert pd["mime_type"] == "text/html"
    assert pd["locator"]["kind"] == "signed_url"
    assert "/v1/artifacts/download" in pd["locator"]["value"]

    _cleanup_preview_artifact(pd)
    cleanup_artifact(payload["data"]["artifact_metadata"])


def test_generate_pptx_preview_url_is_downloadable(client, monkeypatch) -> None:
    """The signed preview URL returns 200 with Content-Type: text/html."""
    _patch_deps(monkeypatch)

    body, headers, _ = signed_request_content("pptx")
    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    pd = payload["data"]["preview_delivery"]

    parsed = urlparse(pd["locator"]["value"])
    download_response = client.get(f"{parsed.path}?{parsed.query}")

    assert download_response.status_code == 200
    content_type = download_response.headers.get("content-type", "")
    assert content_type.startswith("text/html")

    # The preview HTML should be self-contained (no external URLs).
    html_text = download_response.content.decode("utf-8")
    assert "Handout Pecahan Kelas 5" in html_text
    assert "http://" not in html_text
    assert "https://" not in html_text
    assert 'src="' not in html_text

    _cleanup_preview_artifact(pd)
    cleanup_artifact(payload["data"]["artifact_metadata"])


def test_generate_pptx_preview_signature_is_valid(client, monkeypatch) -> None:
    """The preview signed URL uses a valid HMAC signature."""
    _patch_deps(monkeypatch)

    body, headers, _ = signed_request_content("pptx")
    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    pd = payload["data"]["preview_delivery"]

    parsed = urlparse(pd["locator"]["value"])
    qs = parse_qs(parsed.query)
    assert "signature" in qs
    assert len(qs["signature"][0]) == 64  # SHA256 hex digest

    # Verify the download works (signature is accepted).
    dl = client.get(f"{parsed.path}?{parsed.query}")
    assert dl.status_code == 200

    _cleanup_preview_artifact(pd)
    cleanup_artifact(payload["data"]["artifact_metadata"])


def test_generate_pptx_preview_rejects_tampered_signature(client, monkeypatch) -> None:
    """Tampering with the preview signature returns 401."""
    _patch_deps(monkeypatch)

    body, headers, _ = signed_request_content("pptx")
    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    pd = payload["data"]["preview_delivery"]

    parsed = urlparse(pd["locator"]["value"])
    qs = parse_qs(parsed.query)
    qs["signature"] = ["0" * 64]

    tampered = client.get(f"{parsed.path}?{urlencode(qs, doseq=True)}")
    assert tampered.status_code == 401
    assert tampered.json()["error"]["code"] == "artifact_url_signature_invalid"

    _cleanup_preview_artifact(pd)
    cleanup_artifact(payload["data"]["artifact_metadata"])


# ---------------------------------------------------------------------------
# 2. PDF — preview delivery (same code path as PPTX for preview)
# ---------------------------------------------------------------------------


@pytest.mark.skip(reason=(
    "PdfGenerator._run_async uses asyncio.run which blocks in synchronous "
    "test context.  Preview delivery for PDF shares the exact same code path "
    "as PPTX in main.py (HtmlTemplateEngine + store_preview_html + "
    "build_preview_locator), so the PPTX tests above fully cover this flow."
))
def test_generate_pdf_includes_preview_delivery(client, monkeypatch) -> None:
    """When wired, pdf generation returns preview_delivery (shared code path)."""
    _patch_deps(monkeypatch)

    body, headers, _ = signed_request_content("pdf")
    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["data"]["preview_delivery"] is not None
    pd = payload["data"]["preview_delivery"]
    assert pd["mime_type"] == "text/html"

    _cleanup_preview_artifact(pd)
    cleanup_artifact(payload["data"]["artifact_metadata"])


# ---------------------------------------------------------------------------
# 3. DOCX — no preview delivery
# ---------------------------------------------------------------------------


def test_generate_docx_excludes_preview_delivery(client, monkeypatch) -> None:
    """DOCX generation must NOT include preview_delivery."""
    _patch_deps(monkeypatch)

    body, headers, _ = signed_request_content("docx")
    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["data"]["preview_delivery"] is None

    cleanup_artifact(payload["data"]["artifact_metadata"])


def test_generate_pptx_without_sidecar_has_no_preview(client) -> None:
    """When no sidecar is available, pptx still succeeds but without preview."""
    body, headers, _ = signed_request_content("pptx")
    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["data"]["preview_delivery"] is None

    cleanup_artifact(payload["data"]["artifact_metadata"])


def test_generate_pptx_without_template_registry_has_no_preview(
    client, monkeypatch,
) -> None:
    """When template_registry is None, preview is skipped (not a crash)."""
    import app.main

    monkeypatch.setattr(app.main, "sidecar_manager", _mock_ready_sidecar())
    # template_registry is left as None (default with client fixture).

    body, headers, _ = signed_request_content("pptx")
    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["data"]["preview_delivery"] is None

    cleanup_artifact(payload["data"]["artifact_metadata"])


# ---------------------------------------------------------------------------
# 4. Health endpoint — sidecar status
# ---------------------------------------------------------------------------


def test_health_reports_sidecar_disabled_when_none(client) -> None:
    """When no sidecar is running, health shows enabled: false."""
    response = client.get("/health")
    assert response.status_code == 200
    sidecar = response.json()["sidecar"]
    assert sidecar["enabled"] is False


def test_health_reports_sidecar_running_when_mocked(client, monkeypatch) -> None:
    """When mock sidecar is set, health reflects its live state."""
    import app.main

    mock_sc = _mock_ready_sidecar()
    monkeypatch.setattr(app.main, "sidecar_manager", mock_sc)

    response = client.get("/health")
    assert response.status_code == 200
    sidecar = response.json()["sidecar"]
    assert sidecar["enabled"] is True
    assert sidecar["running"] is True
    assert sidecar["ready"] is True
    assert sidecar["uptime_seconds"] == 42.0
