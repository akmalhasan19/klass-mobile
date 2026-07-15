from __future__ import annotations

from pathlib import Path

from pptx import Presentation

import app.templates as templates_pkg
from app.contracts import MIME_TYPES
from app.document_model import RenderDocument
from app.engines.blueprint_builder import build_slide_blueprint
from app.engines.canvas_calculator.layout_engine import CanvasLayoutEngine
from app.engines.canvas_calculator.shape_renderer import CanvasShapeRenderer
from app.engines.pptx_injector.injector import TemplateInjector
from app.generators.base import BaseGenerator, RenderSummary
from app.templates.registry import TemplateRegistry

DEFAULT_TEMPLATE_ID = "klass-educational-v1"


class PptxGenerator(BaseGenerator):
    """Generate a native, editable PPTX by delegating to the Hybrid Engine.

    The generator is now a thin orchestrator (per the plan's modularisation
    rule): it builds the :class:`SlideBlueprint` from the ``RenderDocument`` and
    hands it to :class:`TemplateInjector`, which fills the master ``.pptx`` via
    the manifest. Slides that exceed a layout's capacity are automatically
    rendered by the :class:`CanvasLayoutEngine` fallback — the injector owns
    that capacity gate (it already delegates to its ``canvas_engine`` Protocol),
    so the orchestrator does not re-implement fallback routing.

    The ``template_registry`` is injectable (wired in a later task from the
    app-level lifespan registry). When omitted, a registry is built lazily from
    the bundled ``app/templates`` directory, keeping ``PptxGenerator()`` usable
    in tests and the generator registry without external DI.
    """

    export_format = "pptx"
    mime_type = MIME_TYPES["pptx"]

    def __init__(
        self,
        template_registry: TemplateRegistry | None = None,
        template_id: str = DEFAULT_TEMPLATE_ID,
    ) -> None:
        self._template_registry = template_registry
        self._template_id = template_id

    def render(self, render_document: RenderDocument, output_path: Path) -> RenderSummary:
        blueprint = build_slide_blueprint(render_document)
        registry = self._resolve_registry()
        entry = registry.get(self._template_id)

        # Read the master template's slide dimensions so the canvas fallback
        # engine uses the same geometry as the master — without this the
        # canvas-calculated card grid could misalign with template-injected
        # slides when the master has non-default dimensions.
        master_prs = Presentation(str(entry.master_path))
        canvas_engine = CanvasLayoutEngine(
            slide_width=master_prs.slide_width,
            slide_height=master_prs.slide_height,
            renderer=CanvasShapeRenderer(),
        )
        # master_prs is discarded; injector opens its own copy per request

        injector = TemplateInjector(
            master_path=entry.master_path,
            manifest=entry.manifest,
            canvas_engine=canvas_engine,
        )

        result = injector.inject(blueprint, output_path)

        # Collect per-slide layout sources from the blueprint (set by the
        # injector during _fill_slide / _delegate_canvas).
        layout_sources = [s.layout_source for s in blueprint.slides if s.layout_source]

        return RenderSummary(
            slide_count=result.slide_count,
            warnings=list(result.warnings),
            layout_sources=layout_sources or None,
        )

    def _resolve_registry(self) -> TemplateRegistry:
        if self._template_registry is not None:
            return self._template_registry
        registry = TemplateRegistry()
        templates_dir = Path(templates_pkg.__file__).resolve().parent
        registry.load_templates(templates_dir)
        return registry
