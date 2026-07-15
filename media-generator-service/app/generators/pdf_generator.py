from __future__ import annotations

import asyncio
import logging
from pathlib import Path

from app.contracts import PDF_MIME_TYPE
from app.document_model import RenderDocument
from app.engines.blueprint_builder import build_slide_blueprint
from app.engines.marp.marp_markdown_builder import build_marp_markdown
from app.engines.marp.marp_renderer import MarpRenderer
from app.errors import GenerationError
from app.generators.base import BaseGenerator, RenderSummary

logger = logging.getLogger("klass-media-generator")

# PDF generation is delegated to the warm Chromium sidecar, which is also the
# render budget ceiling for the whole request (Gateway → MediaGen = 60s).
_SIDECAR_TIMEOUT_SECONDS = 60


class PdfGenerator(BaseGenerator):
    export_format = "pdf"
    mime_type = PDF_MIME_TYPE

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

    @staticmethod
    def _require_sidecar():
        # Lazy import avoids a circular import: ``app.main`` imports the
        # generator registry (which imports this module) at startup, but the
        # sidecar global is only populated once the lifespan has started.
        from app.main import sidecar_manager

        if sidecar_manager is None or not sidecar_manager.is_ready:
            raise GenerationError(
                "marp_sidecar_unavailable",
                "The Marp sidecar is not available; PDF generation requires it.",
                {},
            )

        return sidecar_manager

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
