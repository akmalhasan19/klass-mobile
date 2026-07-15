from __future__ import annotations

import asyncio
import logging
from pathlib import Path
from typing import TYPE_CHECKING

from app.contracts import PDF_MIME_TYPE
from app.document_model import RenderDocument
from app.engines.blueprint_builder import build_slide_blueprint
from app.engines.marp.marp_markdown_builder import build_marp_markdown
from app.engines.marp.marp_renderer import MarpRenderer
from app.errors import GenerationError
from app.generators.base import BaseGenerator, RenderSummary

if TYPE_CHECKING:
    from app.engines.marp.sidecar.sidecar_manager import SidecarManager

logger = logging.getLogger("klass-media-generator")

# PDF generation is delegated to the warm Chromium sidecar, which is also the
# render budget ceiling for the whole request (Gateway → MediaGen = 60s).
_SIDECAR_TIMEOUT_SECONDS = 60


class PdfGenerator(BaseGenerator):
    """Generate a PDF artifact by delegating to the Marp + Chromium sidecar.

    The generator is a thin orchestrator: it builds the universal
    ``SlideBlueprint``, converts it to Marp markdown, and hands it to the sidecar
    (running warm Chromium) for HTML-then-PDF rendering.

    The ``sidecar_manager`` is injectable. When omitted (e.g. in tests or before
    the lifespan has wired the real manager), a lazy fallback reads the
    module-level global from ``app.main`` — the same workaround as the previous
    ``_require_sidecar`` pattern, but exposed as an explicit field for clarity.
    """

    export_format = "pdf"
    mime_type = PDF_MIME_TYPE

    def __init__(
        self,
        sidecar_manager: SidecarManager | None = None,
    ) -> None:
        """
        Args:
            sidecar_manager: Injected Marp sidecar instance. When ``None``, a
                lazy fallback reads the module-level global from ``app.main``,
                keeping ``PdfGenerator()`` usable in tests without DI.
        """
        self._sidecar_manager = sidecar_manager

    def render(self, render_document: RenderDocument, output_path: Path) -> RenderSummary:
        sidecar_manager = self._require_sidecar()

        # Reuse the universal blueprint + Marp markdown so the PDF is produced
        # from the exact same source as the HTML preview (structural parity).
        blueprint = build_slide_blueprint(render_document)
        markdown = build_marp_markdown(blueprint)

        renderer = MarpRenderer(sidecar_manager)

        # Marp derives the PDF from its self-contained HTML: render the HTML
        # string first, then hand it to the warm Chromium PDF path. The HTML is
        # only an intermediate here (the preview artifact is produced elsewhere),
        # so we keep it in a sibling temp file and discard it afterwards.
        html_path = output_path.with_suffix(".preview.html")
        try:
            self._run_async(renderer.render_html(markdown, html_path))
            html = html_path.read_text(encoding="utf-8")
            self._run_async(renderer.render_pdf(html, output_path))
        except GenerationError:
            raise
        except Exception as exc:
            raise GenerationError(
                "pdf_marp_render_failed",
                "Failed to render the PDF artifact via the Marp pipeline.",
                {"export_format": self.export_format},
            ) from exc
        finally:
            html_path.unlink(missing_ok=True)

        # Marp emits exactly one page per slide, so the deck slide count is the
        # PDF page count. This avoids taking a hard dependency on a PDF parser.
        return RenderSummary(page_count=len(blueprint.slides))

    def _require_sidecar(self):
        # Use the injected sidecar if available; otherwise fall back to the
        # module-level global (for backward compat before lifespan wiring).
        manager = self._sidecar_manager
        if manager is None:
            from app.main import sidecar_manager as _global_sidecar
            manager = _global_sidecar

        if manager is None or not manager.is_ready:
            raise GenerationError(
                "marp_sidecar_unavailable",
                "The Marp sidecar is not available; PDF generation requires it.",
                {},
            )

        return manager

    @staticmethod
    def _run_async(coro):
        """Bridge a coroutine into the running event loop (or a fresh one).

        ``MarpRenderer`` is async and the sidecar is bound to the uvicorn event
        loop (futures/subprocess created on the running loop). ``render`` itself
        is called synchronously from ``BaseGenerator.generate``, so we schedule
        the coroutine on the already-running loop via
        ``run_coroutine_threadsafe`` and block on the resulting future. Outside
        an event loop (e.g. a plain unit test) we fall back to ``asyncio.run``.
        """
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            return asyncio.run(coro)

        future = asyncio.run_coroutine_threadsafe(coro, loop)
        return future.result(timeout=_SIDECAR_TIMEOUT_SECONDS)
