from __future__ import annotations

from typing import TYPE_CHECKING

from app.contracts import IMPLEMENTED_EXPORT_FORMATS
from app.errors import UnsupportedFormatError
from app.generators.docx_generator import DocxGenerator
from app.generators.pdf_generator import PdfGenerator
from app.generators.pptx_generator import PptxGenerator

if TYPE_CHECKING:
    from app.templates.registry import TemplateRegistry
    from app.engines.chromium_sidecar.sidecar.sidecar_manager import SidecarManager


class GeneratorRegistry:
    """Registry of all available artifact generators.

    Dependencies (template_registry, sidecar_manager) are injectable so the
    app lifespan can wire them after bootstrapping. When omitted, each
    generator falls back to its own lazy resolution strategy, keeping
    ``GeneratorRegistry()`` usable in tests and module-level construction.
    """

    def __init__(
        self,
        template_registry: TemplateRegistry | None = None,
        sidecar_manager: SidecarManager | None = None,
    ) -> None:
        self._generators = {
            "docx": DocxGenerator(
                template_registry=template_registry,
            ),
            "pdf": PdfGenerator(
                sidecar_manager=sidecar_manager,
                template_registry=template_registry,
            ),
            "pptx": PptxGenerator(
                template_registry=template_registry,
            ),
        }

    def get(self, export_format: str):
        generator = self._generators.get(export_format)
        if generator is None:
            raise UnsupportedFormatError(export_format, IMPLEMENTED_EXPORT_FORMATS)

        return generator
