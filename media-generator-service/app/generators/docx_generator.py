from __future__ import annotations

from pathlib import Path

from app.contracts import DOCX_MIME_TYPE
from app.document_model import RenderDocument
from app.engines.blueprint_builder import build_slide_blueprint
from app.engines.docx_template.engine import DocxTemplateEngine
from app.generators.base import BaseGenerator, RenderSummary
from app.templates.registry import TemplateRegistry

import app.templates as templates_pkg

DEFAULT_TEMPLATE_ID = "klass-educational-v1"


class DocxGenerator(BaseGenerator):
    """Generate a native, editable DOCX via the template-driven ``DocxTemplateEngine``.

    The generator is now a thin orchestrator (per the plan's modularisation
    rule): it builds the ``SlideBlueprint`` from the ``RenderDocument`` and
    hands it to :class:`DocxTemplateEngine`, which fills the master ``.docx``
    via ``docxtpl``.  This mirrors the PPTX generator's delegation to
    :class:`TemplateInjector`.

    The ``template_registry`` is injectable (wired from the app-level
    lifespan registry). When omitted, a registry is built lazily from the
    bundled ``app/templates`` directory, keeping ``DocxGenerator()`` usable
    in tests and the generator registry without external DI.
    """

    export_format = "docx"
    mime_type = DOCX_MIME_TYPE

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
        docx_master_path = registry.get_docx_master(self._template_id)

        engine = DocxTemplateEngine(master_path=docx_master_path)
        engine.render(blueprint, output_path)

        return RenderSummary(page_count=None)

    def _resolve_registry(self) -> TemplateRegistry:
        if self._template_registry is not None:
            return self._template_registry
        registry = TemplateRegistry()
        templates_dir = Path(templates_pkg.__file__).resolve().parent
        registry.load_templates(templates_dir)
        return registry
