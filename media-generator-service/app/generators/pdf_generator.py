from __future__ import annotations

import asyncio
import logging
from pathlib import Path
from typing import TYPE_CHECKING

from app.contracts import PDF_MIME_TYPE
from app.document_model import RenderDocument
from app.engines.blueprint_builder import build_slide_blueprint
from app.engines.html_template import HtmlTemplateEngine
from app.engines.html_template.pdf_renderer import PdfRenderer
from app.errors import GenerationError
from app.generators.base import BaseGenerator, RenderSummary

if TYPE_CHECKING:
    from app.engines.chromium_sidecar.sidecar.sidecar_manager import SidecarManager
    from app.templates.registry import TemplateRegistry

import app.templates as templates_pkg

logger = logging.getLogger("klass-media-generator")

# PDF generation is delegated to the warm Chromium sidecar, which is also the
# render budget ceiling for the whole request (Gateway -> MediaGen = 60s).
_SIDECAR_TIMEOUT_SECONDS = 60

DEFAULT_TEMPLATE_ID = "klass-educational-v1"


class PdfGenerator(BaseGenerator):
    """Generate a PDF artifact via the template-driven HTML + Chromium pipeline.

    The generator is a thin orchestrator in the new Fase 2 architecture:

    1. Build the universal ``SlideBlueprint`` from the ``RenderDocument``.
    2. Render it to a self-contained HTML string via :class:`HtmlTemplateEngine`.
    3. Delegate HTML-to-PDF conversion to the warm Chromium sidecar
       via :class:`PdfRenderer`.

    The ``sidecar_manager`` and ``template_registry`` are injectable.  When
    omitted, each falls back to its own lazy resolution strategy, keeping
    ``PdfGenerator()`` usable in tests without full DI wiring.
    """

    export_format = "pdf"
    mime_type = PDF_MIME_TYPE

    def __init__(
        self,
        sidecar_manager: SidecarManager | None = None,
        template_registry: TemplateRegistry | None = None,
        template_id: str = DEFAULT_TEMPLATE_ID,
    ) -> None:
        """
        Args:
            sidecar_manager: Injected Chromium sidecar instance. When ``None``,
                a lazy fallback reads the module-level global from ``app.main``.
            template_registry: Injected template registry. When ``None``, a
                lazy fallback builds a registry from the bundled templates.
            template_id: Selects the HTML master template (defaults to
                ``klass-educational-v1``).
        """
        self._sidecar_manager = sidecar_manager
        self._template_registry = template_registry
        self._template_id = template_id

    def render(self, render_document: RenderDocument, output_path: Path) -> RenderSummary:
        sidecar_manager = self._require_sidecar()

        # Build the universal blueprint — shared across all format pipelines.
        blueprint = build_slide_blueprint(render_document)

        # Step 1: Render self-contained HTML via the Jinja2 template engine.
        registry = self._resolve_registry()
        html_master = registry.get_html_master(self._template_id)
        html_engine = HtmlTemplateEngine(master_path=html_master)
        html = html_engine.render(blueprint)

        # Step 2: Render PDF via the warm Chromium sidecar.
        pdf_renderer = PdfRenderer(sidecar_manager=sidecar_manager)
        self._run_async(pdf_renderer.render(html, output_path))

        # Each <section> in the HTML master maps to one PDF page (Chromium's
        # @page + page-break-after).  The slide count is therefore an accurate
        # page-count proxy, avoiding a hard dependency on a PDF parser.
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
                "chromium_sidecar_unavailable",
                "The Chromium sidecar is not available; PDF generation requires it.",
                {},
            )

        return manager

    def _resolve_registry(self) -> TemplateRegistry:
        """Build or return the cached template registry.

        Mirrors the pattern in :class:`DocxGenerator._resolve_registry` so
        that ``PdfGenerator()`` works without explicit DI in tests.
        """
        if self._template_registry is not None:
            return self._template_registry
        from app.templates.registry import TemplateRegistry

        registry = TemplateRegistry()
        templates_dir = Path(templates_pkg.__file__).resolve().parent
        registry.load_templates(templates_dir)
        return registry

    @staticmethod
    def _run_async(coro):
        """Bridge a coroutine into the running event loop (or a fresh one).

        ``PdfRenderer.render`` is async and the sidecar is bound to the uvicorn
        event loop (futures/subprocess created on the running loop). ``render``
        itself is called synchronously from ``BaseGenerator.generate``.

        The caller (``app.main.generate_artifact``) runs this generator from a
        thread-pool executor, so there is **no running loop** on the calling
        thread — we therefore use ``asyncio.run``.  (Running the coroutine on a
        fresh loop is safe because the sidecar communicates over its stdin/stdout
        pipes, not loop-bound futures.)  If a loop were somehow running on the
        calling thread we would fall back to ``run_coroutine_threadsafe`` and
        block on the future.
        """
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            return asyncio.run(coro)

        future = asyncio.run_coroutine_threadsafe(coro, loop)
        return future.result(timeout=_SIDECAR_TIMEOUT_SECONDS)
