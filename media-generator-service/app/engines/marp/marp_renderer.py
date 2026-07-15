"""Marp renderer — HTML preview + PDF generation via the Node sidecar.

This module owns the **render** step of the Marp pipeline.  It takes a
Marp-flavoured markdown string (produced by
:func:`app.engines.marp.marp_markdown_builder.build_marp_markdown`) and
delegates the actual conversion to the long-running Node sidecar managed
by :class:`app.engines.marp.sidecar.sidecar_manager.SidecarManager`.

Responsibilities
----------------
* Load the custom CSS theme from disk (once, at construction time).
* Call ``sidecar.render_html(markdown, theme_css)`` → write self-contained
  HTML to *output_path*.
* Call ``sidecar.render_pdf(html)`` → write PDF bytes to *output_path*.
* Map transport/protocol errors (:class:`SidecarError`) to the domain
  error (:class:`GenerationError`) expected by the orchestrator layer.

Design notes
------------
* **Async** — The sidecar manager is ``asyncio``-based, so every public
  method here is ``async def``.  The caller (``marp_renderer.render_html``)
  awaits these from the request handler, which is already inside an
  ``asyncio`` event loop managed by ``uvicorn``.
* **Theme CSS as parameter** — The sidecar's ``render_html`` RPC method
  accepts a ``theme_css`` string; the Marp engine applies it via
  ``marp.themeSet.add(css)``.  We load the CSS once at init and reuse it
  for every render call, keeping per-request overhead minimal.
* **No markdown mutation** — The builder already emits correct Marp
  front matter (``marp: true``, ``theme: klass-default``, …).  This
  renderer does **not** modify the markdown; it passes it through as-is.
"""
from __future__ import annotations

import logging
from pathlib import Path

from app.errors import GenerationError
from app.engines.marp.sidecar.sidecar_manager import SidecarError, SidecarManager

logger = logging.getLogger("klass-media-generator")

_DEFAULT_THEME_PATH = Path(__file__).resolve().parent / "themes" / "klass-default.css"


class MarpRenderer:
    """Thin async wrapper that connects the Marp markdown builder to the Node sidecar.

    Parameters
    ----------
    sidecar:
        A started :class:`SidecarManager` instance (caller owns the lifecycle).
    theme_css_path:
        Path to a Marp-compatible CSS theme file.  Defaults to the built-in
        ``klass-default.css`` shipped with this package.
    """

    def __init__(
        self,
        sidecar: SidecarManager,
        theme_css_path: Path | None = None,
    ) -> None:
        self._sidecar = sidecar
        self._theme_css = _load_theme_css(theme_css_path or _DEFAULT_THEME_PATH)

    # ------------------------------------------------------------------ public API

    async def render_html(self, markdown: str, output_path: Path) -> None:
        """Render *markdown* to a self-contained HTML file at *output_path*.

        Raises
        ------
        GenerationError
            If the sidecar transport fails or returns an invalid response.
        """
        try:
            html = await self._sidecar.render_html(markdown, theme_css=self._theme_css)
        except SidecarError as exc:
            raise GenerationError(
                "marp_html_render_failed",
                f"Marp HTML rendering failed: {exc.message}",
                {"sidecar_error_code": exc.code},
            ) from exc

        output_path.write_text(html, encoding="utf-8")
        logger.debug("Marp HTML rendered to %s (%d bytes)", output_path, len(html))

    async def render_pdf(self, html: str, output_path: Path) -> None:
        """Render self-contained *html* to a PDF file at *output_path*.

        The caller is expected to first call :meth:`render_html` to obtain
        the self-contained HTML, then pass that HTML string here for PDF
        generation.  This two-step approach allows the caller to also serve
        the HTML as a preview artifact while generating the PDF in parallel.

        Raises
        ------
        GenerationError
            If the sidecar transport fails or returns an invalid response.
        """
        try:
            pdf_bytes = await self._sidecar.render_pdf(html)
        except SidecarError as exc:
            raise GenerationError(
                "marp_pdf_render_failed",
                f"Marp PDF rendering failed: {exc.message}",
                {"sidecar_error_code": exc.code},
            ) from exc

        output_path.write_bytes(pdf_bytes)
        logger.debug("Marp PDF rendered to %s (%d bytes)", output_path, len(pdf_bytes))

    async def render(self, markdown: str, html_path: Path, pdf_path: Path) -> None:
        """Convenience: render *markdown* to both HTML and PDF in sequence.

        Equivalent to ``await render_html(…)`` followed by
        ``await render_pdf(html, …)``.  Useful when both artifacts are
        needed from the same markdown source (e.g. preview + download).
        """
        try:
            html = await self._sidecar.render_html(markdown, theme_css=self._theme_css)
        except SidecarError as exc:
            raise GenerationError(
                "marp_html_render_failed",
                f"Marp HTML rendering failed: {exc.message}",
                {"sidecar_error_code": exc.code},
            ) from exc

        html_path.write_text(html, encoding="utf-8")
        logger.debug("Marp HTML rendered to %s (%d bytes)", html_path, len(html))

        try:
            pdf_bytes = await self._sidecar.render_pdf(html)
        except SidecarError as exc:
            raise GenerationError(
                "marp_pdf_render_failed",
                f"Marp PDF rendering failed: {exc.message}",
                {"sidecar_error_code": exc.code},
            ) from exc

        pdf_path.write_bytes(pdf_bytes)
        logger.debug("Marp PDF rendered to %s (%d bytes)", pdf_path, len(pdf_bytes))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _load_theme_css(path: Path) -> str:
    """Read a CSS theme file and return its content as a string.

    Raises
    ------
    GenerationError
        If the file does not exist or cannot be read.
    """
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise GenerationError(
            "marp_theme_not_found",
            f"Marp CSS theme file not found: {path}",
            {"theme_path": str(path)},
        ) from exc
    except OSError as exc:
        raise GenerationError(
            "marp_theme_read_error",
            f"Failed to read Marp CSS theme file: {path}",
            {"theme_path": str(path)},
        ) from exc
