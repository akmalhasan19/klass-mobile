"""Unit tests for ``app.engines.marp.marp_renderer``.

Tests mock the ``SidecarManager`` to avoid requiring a live Node process.
Async test functions are wrapped with ``asyncio.run`` for compatibility
without requiring ``pytest-asyncio``.
"""
from __future__ import annotations

import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.errors import GenerationError
from app.engines.marp.marp_renderer import MarpRenderer, _load_theme_css
from app.engines.marp.sidecar.sidecar_manager import SidecarError, SidecarManager


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _mock_sidecar(
    html: str = "<html>mock</html>",
    pdf: bytes = b"%PDF-1.4 mock",
    *,
    html_error: SidecarError | None = None,
    pdf_error: SidecarError | None = None,
) -> SidecarManager:
    sidecar = MagicMock(spec=SidecarManager)
    if html_error:
        sidecar.render_html = AsyncMock(side_effect=html_error)
    else:
        sidecar.render_html = AsyncMock(return_value=html)
    if pdf_error:
        sidecar.render_pdf = AsyncMock(side_effect=pdf_error)
    else:
        sidecar.render_pdf = AsyncMock(return_value=pdf)
    return sidecar


def _write_theme(tmp_path: Path, content: str = "/* test theme */") -> Path:
    theme = tmp_path / "test-theme.css"
    theme.write_text(content, encoding="utf-8")
    return theme


# ---------------------------------------------------------------------------
# 1. render_html — happy path
# ---------------------------------------------------------------------------

def test_render_html_writes_file(tmp_path: Path) -> None:
    sidecar = _mock_sidecar(html="<html>hello</html>")
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))
    out = tmp_path / "out.html"

    asyncio.run(renderer.render_html("# md", out))

    assert out.read_text(encoding="utf-8") == "<html>hello</html>"


def test_render_html_passes_theme_css_to_sidecar(tmp_path: Path) -> None:
    sidecar = _mock_sidecar()
    theme_path = _write_theme(tmp_path, ".custom { color: red; }")
    renderer = MarpRenderer(sidecar, theme_path)

    asyncio.run(renderer.render_html("# md", tmp_path / "out.html"))

    sidecar.render_html.assert_awaited_once()
    call_kwargs = sidecar.render_html.call_args
    assert call_kwargs.kwargs.get("theme_css") == ".custom { color: red; }" or \
        (len(call_kwargs.args) > 1 and call_kwargs.args[1] == ".custom { color: red; }")


def test_render_html_passes_markdown_to_sidecar(tmp_path: Path) -> None:
    sidecar = _mock_sidecar()
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))
    md = "---\nmarp: true\n---\n\n# Hello"

    asyncio.run(renderer.render_html(md, tmp_path / "out.html"))

    call_args = sidecar.render_html.call_args
    assert call_args.args[0] == md or call_args.kwargs.get("markdown") == md


# ---------------------------------------------------------------------------
# 2. render_pdf — happy path
# ---------------------------------------------------------------------------

def test_render_pdf_writes_file(tmp_path: Path) -> None:
    sidecar = _mock_sidecar(pdf=b"%PDF-1.4 real")
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))
    out = tmp_path / "out.pdf"

    asyncio.run(renderer.render_pdf("<html>", out))

    assert out.read_bytes() == b"%PDF-1.4 real"


def test_render_pdf_passes_html_to_sidecar(tmp_path: Path) -> None:
    sidecar = _mock_sidecar()
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))

    html = "<html><body>test</body></html>"
    asyncio.run(renderer.render_pdf(html, tmp_path / "out.pdf"))

    sidecar.render_pdf.assert_awaited_once_with(html)


# ---------------------------------------------------------------------------
# 3. render — combined HTML + PDF
# ---------------------------------------------------------------------------

def test_render_writes_both_files(tmp_path: Path) -> None:
    sidecar = _mock_sidecar(html="<html>ok</html>", pdf=b"%PDF-combined")
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))
    html_out = tmp_path / "out.html"
    pdf_out = tmp_path / "out.pdf"

    asyncio.run(renderer.render("# md", html_out, pdf_out))

    assert html_out.read_text(encoding="utf-8") == "<html>ok</html>"
    assert pdf_out.read_bytes() == b"%PDF-combined"


def test_render_calls_html_then_pdf_in_order(tmp_path: Path) -> None:
    sidecar = _mock_sidecar(html="<html>sequential</html>")
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))

    asyncio.run(renderer.render("# md", tmp_path / "o.html", tmp_path / "o.pdf"))

    sidecar.render_html.assert_awaited_once()
    sidecar.render_pdf.assert_awaited_once()
    # PDF receives the HTML output from render_html.
    pdf_call_html = sidecar.render_pdf.call_args.args[0]
    assert pdf_call_html == "<html>sequential</html>"


# ---------------------------------------------------------------------------
# 4. Error mapping — SidecarError → GenerationError
# ---------------------------------------------------------------------------

def test_render_html_maps_sidecar_error_to_generation_error(tmp_path: Path) -> None:
    sidecar = _mock_sidecar(html_error=SidecarError("chromium crashed", code="CRASH"))
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))

    with pytest.raises(GenerationError) as exc_info:
        asyncio.run(renderer.render_html("# md", tmp_path / "out.html"))

    assert exc_info.value.code == "marp_html_render_failed"
    assert "chromium crashed" in exc_info.value.message
    assert exc_info.value.details["sidecar_error_code"] == "CRASH"


def test_render_pdf_maps_sidecar_error_to_generation_error(tmp_path: Path) -> None:
    sidecar = _mock_sidecar(pdf_error=SidecarError("timeout", code="TIMEOUT"))
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))

    with pytest.raises(GenerationError) as exc_info:
        asyncio.run(renderer.render_pdf("<html>", tmp_path / "out.pdf"))

    assert exc_info.value.code == "marp_pdf_render_failed"
    assert "timeout" in exc_info.value.message


def test_render_maps_html_error_before_pdf(tmp_path: Path) -> None:
    """If HTML rendering fails, PDF is never attempted."""
    sidecar = _mock_sidecar(html_error=SidecarError("fail early"))
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))

    with pytest.raises(GenerationError):
        asyncio.run(renderer.render("# md", tmp_path / "o.html", tmp_path / "o.pdf"))

    sidecar.render_pdf.assert_not_awaited()


# ---------------------------------------------------------------------------
# 5. Theme CSS loading
# ---------------------------------------------------------------------------

def test_load_theme_css_reads_file(tmp_path: Path) -> None:
    theme = tmp_path / "my.css"
    theme.write_text("body { margin: 0; }", encoding="utf-8")

    css = _load_theme_css(theme)

    assert css == "body { margin: 0; }"


def test_load_theme_css_missing_file_raises_generation_error(tmp_path: Path) -> None:
    with pytest.raises(GenerationError) as exc_info:
        _load_theme_css(tmp_path / "nonexistent.css")

    assert exc_info.value.code == "marp_theme_not_found"


def test_load_theme_css_uses_default_when_none(tmp_path: Path) -> None:
    """Passing None to MarpRenderer should use the built-in theme."""
    sidecar = _mock_sidecar()
    renderer = MarpRenderer(sidecar, theme_css_path=None)

    # The renderer should have loaded the default theme without error.
    # We verify by checking that render_html works (theme_css is passed to sidecar).
    asyncio.run(renderer.render_html("# md", tmp_path / "out.html"))
    sidecar.render_html.assert_awaited_once()


def test_default_theme_file_exists() -> None:
    """The built-in klass-default.css must be present."""
    default_theme = Path(__file__).resolve().parent.parent / "app" / "engines" / "marp" / "themes" / "klass-default.css"
    # This test runs from the tests/ directory; the path resolves relative to this file.
    # We just check the canonical path used by the renderer.
    from app.engines.marp.marp_renderer import _DEFAULT_THEME_PATH
    assert _DEFAULT_THEME_PATH.is_file(), f"Default theme not found: {_DEFAULT_THEME_PATH}"


# ---------------------------------------------------------------------------
# 6. Edge cases
# ---------------------------------------------------------------------------

def test_render_html_empty_markdown(tmp_path: Path) -> None:
    sidecar = _mock_sidecar(html="")
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))
    out = tmp_path / "empty.html"

    asyncio.run(renderer.render_html("", out))

    assert out.read_text(encoding="utf-8") == ""


def test_render_pdf_empty_bytes(tmp_path: Path) -> None:
    sidecar = _mock_sidecar(pdf=b"")
    renderer = MarpRenderer(sidecar, _write_theme(tmp_path))
    out = tmp_path / "empty.pdf"

    asyncio.run(renderer.render_pdf("<html>", out))

    assert out.read_bytes() == b""


def test_renderer_works_with_real_default_theme(tmp_path: Path) -> None:
    """Integration-style: use the actual klass-default.css theme file."""
    sidecar = _mock_sidecar(html="<html>themed</html>")
    renderer = MarpRenderer(sidecar)  # default theme path

    asyncio.run(renderer.render_html("---\nmarp: true\n---\n\n# Test", tmp_path / "out.html"))

    # Theme CSS should contain @theme klass-educational-v1 (matches theme_id).
    call_kwargs = sidecar.render_html.call_args
    theme_css = call_kwargs.kwargs.get("theme_css") or (call_kwargs.args[1] if len(call_kwargs.args) > 1 else None)
    assert theme_css is not None
    assert "@theme klass-educational-v1" in theme_css
