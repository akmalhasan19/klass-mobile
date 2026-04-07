from __future__ import annotations

from app.contracts import IMPLEMENTED_EXPORT_FORMATS
from app.errors import UnsupportedFormatError
from app.generators.docx_generator import DocxGenerator
from app.generators.pdf_generator import PdfGenerator
from app.generators.pptx_generator import PptxGenerator


class GeneratorRegistry:
    def __init__(self) -> None:
        self._generators = {
            "docx": DocxGenerator(),
            "pdf": PdfGenerator(),
            "pptx": PptxGenerator(),
        }

    def get(self, export_format: str):
        generator = self._generators.get(export_format)
        if generator is None:
            raise UnsupportedFormatError(export_format, IMPLEMENTED_EXPORT_FORMATS)

        return generator
