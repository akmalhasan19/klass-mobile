"""Template-driven DOCX engine (Fase 1 — Task 1A).

Provides ``DocxTemplateEngine``, a ``docxtpl``-based renderer that consumes a
``SlideBlueprint`` and renders it through a ``.docx`` master template whose
placeholders (``{{ title }}``, ``{% for section in sections %}``, …) match
the context built by ``_build_context()``.

The engine mirrors the PPTX ``TemplateInjector`` architecture: both load a
master file at render time and inject a blueprint-derived context — the only
difference is the templating library (``docxtpl`` vs ``python-pptx`` + manifest).
"""

from app.engines.docx_template.engine import DocxTemplateEngine

__all__ = ["DocxTemplateEngine"]
