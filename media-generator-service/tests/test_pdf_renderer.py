"""Unit tests for ``PdfRenderer`` (Fase 2 / Task 2D).

Tests focus on the two responsibilities of :class:`PdfRenderer`:

1. **Error mapping** — ``SidecarError`` from the sidecar is caught and
   re-raised as ``GenerationError`` with the ``html_template_pdf_render_failed``
   error code.

2. **File writing** — PDF bytes returned by the sidecar are written to
   *output_path*.

The sidecar manager is **mocked** using an ``AsyncMock`` because the real
sidecar requires a Node.js + Chromium subprocess that is not available in
unit-test isolation.  The mock replaces ``sidecar_manager.html_to_pdf`` with
a coroutine that returns fake ``b\"%PDF-1.4\\nfake\"`` bytes (or raises
``SidecarError`` when testing the error path).

Design notes
------------
* ``unittest.mock.AsyncMock`` is used for the async ``html_to_pdf`` method.
* ``tmp_path`` provides isolated output directories — no artifact cleanup needed.
* The tests are **synchronous** — they use ``asyncio.run()`` to bridge the
  async ``PdfRenderer.render()`` call, mirroring the real ``_run_async``
  pattern in ``PdfGenerator``.
"""

from __future__ import annotations

import asyncio
from pathlib import Path
from unittest.mock import AsyncMock

import pytest

from app.engines.html_template.pdf_renderer import PdfRenderer
from app.engines.chromium_sidecar.sidecar.sidecar_manager import SidecarError

_FAKE_PDF_BYTES = b"%PDF-1.4\n1 0 obj<<>>endobj\n%%EOF\n"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _run(coro):
    """Bridge an async coroutine for synchronous test execution."""
    return asyncio.run(coro)


def _make_mock_sidecar(
    html_to_pdf_return: bytes | None = None,
    html_to_pdf_side_effect: type[Exception] | None = None,
) -> AsyncMock:
    """Create a mock sidecar manager with a controllable ``html_to_pdf``.

    Args:
        html_to_pdf_return: Bytes returned by ``html_to_pdf()``.
            Defaults to ``_FAKE_PDF_BYTES``.
        html_to_pdf_side_effect: If set, raises this exception (overrides
            *html_to_pdf_return*).

    Returns:
        An ``AsyncMock`` configured as a ``SidecarManager``-like object.
    """
    mock = AsyncMock()
    if html_to_pdf_side_effect is not None:
        mock.html_to_pdf.side_effect = html_to_pdf_side_effect
    else:
        mock.html_to_pdf.return_value = html_to_pdf_return or _FAKE_PDF_BYTES
    return mock


# ===========================================================================
# 1. Error mapping
# ===========================================================================


class TestErrorMapping:
    """SidecarError and transport failures map to GenerationError."""

    def test_sidecar_error_raises_generation_error(self) -> None:
        """A ``SidecarError`` from the sidecar is caught and re-raised."""
        mock_sidecar = _make_mock_sidecar(
            html_to_pdf_side_effect=SidecarError("chromium crashed", code="RENDER_CRASH"),
        )
        renderer = PdfRenderer(sidecar_manager=mock_sidecar)
        dummy_path = Path("/dev/null/output.pdf")

        with pytest.raises(Exception) as exc_info:
            _run(renderer.render("<html></html>", dummy_path))

        from app.errors import GenerationError
        assert type(exc_info.value) is GenerationError
        assert exc_info.value.code == "html_template_pdf_render_failed"
        assert "chromium crashed" in exc_info.value.message
        assert exc_info.value.details == {"sidecar_error_code": "RENDER_CRASH"}

    def test_sidecar_error_without_code(self) -> None:
        """SidecarError without a code still maps correctly."""
        mock_sidecar = _make_mock_sidecar(
            html_to_pdf_side_effect=SidecarError("unknown error"),
        )
        renderer = PdfRenderer(sidecar_manager=mock_sidecar)
        dummy_path = Path("/dev/null/output.pdf")

        with pytest.raises(Exception) as exc_info:
            _run(renderer.render("<html></html>", dummy_path))

        from app.errors import GenerationError
        assert exc_info.value.code == "html_template_pdf_render_failed"
        assert exc_info.value.details == {"sidecar_error_code": None}


# ===========================================================================
# 2. File writing
# ===========================================================================


class TestRender:
    """Verifies PDF bytes are written to the output path."""

    def test_writes_pdf_bytes_to_output_path(self, tmp_path: Path) -> None:
        """Bytes returned by the sidecar are written to *output_path*."""
        mock_sidecar = _make_mock_sidecar(html_to_pdf_return=_FAKE_PDF_BYTES)
        renderer = PdfRenderer(sidecar_manager=mock_sidecar)
        output_path = tmp_path / "artifact.pdf"

        _run(renderer.render("<html><body>Test</body></html>", output_path))

        assert output_path.is_file()
        assert output_path.read_bytes() == _FAKE_PDF_BYTES

    def test_returns_none(self, tmp_path: Path) -> None:
        """``render()`` returns ``None`` (page count is caller's concern)."""
        mock_sidecar = _make_mock_sidecar(html_to_pdf_return=_FAKE_PDF_BYTES)
        renderer = PdfRenderer(sidecar_manager=mock_sidecar)
        output_path = tmp_path / "artifact.pdf"

        result = _run(renderer.render("<html><body>Test</body></html>", output_path))

        assert result is None

    def test_calls_sidecar_with_html(self, tmp_path: Path) -> None:
        """The sidecar's ``html_to_pdf`` is called with the exact input HTML."""
        mock_sidecar = _make_mock_sidecar(html_to_pdf_return=_FAKE_PDF_BYTES)
        renderer = PdfRenderer(sidecar_manager=mock_sidecar)
        output_path = tmp_path / "artifact.pdf"
        input_html = "<html><body><h1>Hello PDF</h1></body></html>"

        _run(renderer.render(input_html, output_path))

        mock_sidecar.html_to_pdf.assert_awaited_once_with(input_html)


# ===========================================================================
# 3. Sidecar availability
# ===========================================================================


class TestSidecarNotReady:
    """Behaviour when the sidecar is None or not running.

    ``PdfRenderer.__init__`` expects a ``SidecarManager`` (not Optional), so
    the caller (``PdfGenerator._require_sidecar``) is responsible for
    ensuring the sidecar is alive before creating a ``PdfRenderer``.  These
    tests verify that if a broken sidecar *does* slip through, the error
    is handled gracefully.
    """

    def test_sidecar_method_not_found(self, tmp_path: Path) -> None:
        """Sidecar responds with 'method not found' — mapped to GenerationError."""
        mock_sidecar = _make_mock_sidecar(
            html_to_pdf_side_effect=SidecarError(
                "method not found: html_to_pdf",
                code=-32601,
            ),
        )
        renderer = PdfRenderer(sidecar_manager=mock_sidecar)
        output_path = tmp_path / "artifact.pdf"

        with pytest.raises(Exception) as exc_info:
            _run(renderer.render("<html></html>", output_path))

        from app.errors import GenerationError
        assert "method not found" in exc_info.value.message

    def test_sidecar_returns_missing_pdf_field(self, tmp_path: Path) -> None:
        """Sidecar response lacks 'pdf' field — raised as SidecarError first."""
        mock_sidecar = _make_mock_sidecar()
        # Override to simulate the sidecar manager's validation raising.
        mock_sidecar.html_to_pdf.side_effect = SidecarError(
            "sidecar html_to_pdf returned no pdf field",
        )
        renderer = PdfRenderer(sidecar_manager=mock_sidecar)
        output_path = tmp_path / "artifact.pdf"

        with pytest.raises(Exception) as exc_info:
            _run(renderer.render("<html></html>", output_path))

        from app.errors import GenerationError
        assert exc_info.value.code == "html_template_pdf_render_failed"
