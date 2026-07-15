"""PDF renderer — self-contained HTML to PDF via the Chromium sidecar.

This module is the **PDF step** of the new template-driven pipeline (Fase 2C).
It takes a self-contained HTML string (produced by
:class:`app.engines.html_template.engine.HtmlTemplateEngine`) and delegates
the HTML-to-PDF conversion to the long-running Chromium sidecar managed by
:class:`app.engines.chromium_sidecar.sidecar.sidecar_manager.SidecarManager`.

Flow
----
1. ``HtmlTemplateEngine.render(blueprint)`` → self-contained HTML string.
2. ``PdfRenderer.render(html, output_path)`` → sidecar ``html_to_pdf()``
   → writes raw PDF bytes to *output_path*.

This replaces the old ``MarpRenderer`` (Fase 2B) which used
``@marp-team/marp-core`` for the HTML step — the Chromium PDF step is
unchanged (Playwright's ``page.setContent()`` + ``page.pdf()``).
"""

from __future__ import annotations

import logging
from pathlib import Path

from app.engines.chromium_sidecar.sidecar.sidecar_manager import SidecarError, SidecarManager
from app.errors import GenerationError

logger = logging.getLogger("klass-media-generator")


class PdfRenderer:
    """Render self-contained HTML to PDF bytes via the warm Chromium sidecar.

    This is a thin async wrapper around the sidecar's ``html_to_pdf`` RPC
    method.  It maps transport/protocol errors (:class:`SidecarError`) to the
    domain error (:class:`GenerationError`) expected by the orchestrator layer.

    Parameters
    ----------
    sidecar_manager:
        A started :class:`SidecarManager` instance (caller owns the lifecycle).
    """

    def __init__(self, sidecar_manager: SidecarManager) -> None:
        self._sidecar = sidecar_manager

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def render(self, html: str, output_path: Path) -> int | None:
        """Render self-contained *html* to a PDF file at *output_path*.

        Steps:
        1. Call ``sidecar.html_to_pdf(html)`` — Chromium renders the HTML
           via ``page.setContent()`` + ``page.pdf()``.
        2. Write the returned PDF bytes to *output_path*.

        Args:
            html: Complete, self-contained HTML string (produced by
                :class:`HtmlTemplateEngine`).
            output_path: Writable destination for the generated ``.pdf`` file.

        Returns:
            ``None`` — page count is not determined here (the caller may
            approximate it from the slide count).

        Raises:
            GenerationError: If the sidecar transport fails or the sidecar
                returns an invalid response.
        """
        try:
            pdf_bytes = await self._sidecar.html_to_pdf(html)
        except SidecarError as exc:
            raise GenerationError(
                "html_template_pdf_render_failed",
                f"PDF rendering via the HTML template engine failed: "
                f"{exc.message}",
                {"sidecar_error_code": exc.code},
            ) from exc

        output_path.write_bytes(pdf_bytes)
        logger.debug(
            "PDF rendered via HtmlTemplateEngine to %s (%d bytes)",
            output_path,
            len(pdf_bytes),
        )
        return None
