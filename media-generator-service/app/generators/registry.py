from __future__ import annotations

from app.contracts import IMPLEMENTED_EXPORT_FORMATS
from app.errors import UnsupportedFormatError
from app.generators.docx_generator import DocxGenerator
from app.generators.pdf_generator import PdfGenerator


class GeneratorRegistry:
    def __init__(self) -> None:
        self._generators = {
            "docx": DocxGenerator(),
            "pdf": PdfGenerator(),
        }

    def get(self, export_format: str):
        generator = self._generators.get(export_format)
        if generator is None:
            raise UnsupportedFormatError(export_format, IMPLEMENTED_EXPORT_FORMATS)

        return generator
