"""HTML template engine for PDF + Preview pipeline (Fase 2).

Provides:

- :class:`HtmlTemplateEngine` — renders a ``SlideBlueprint`` through a
  self-contained HTML master template via Jinja2.
- :class:`PdfRenderer` — renders the resulting HTML string to PDF bytes
  via the Chromium sidecar's ``html_to_pdf()``.
"""

from app.engines.html_template.engine import HtmlTemplateEngine
from app.engines.html_template.pdf_renderer import PdfRenderer

__all__ = ["HtmlTemplateEngine", "PdfRenderer"]
