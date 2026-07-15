"""Template-driven HTML engine using Jinja2 (Fase 2 / Task 2A).

Renders a ``SlideBlueprint`` through a self-contained HTML master template
(``.html``) that contains Jinja2 placeholders (``{{ }}``, ``{% %}``).

The master template (``app/templates/masters/klass-educational-v1.html``)
was hand-written in Fase 0A and is the design authority for the PDF + preview
pipeline — just as the ``.pptx`` + manifest pair is the authority for the
PPTX pipeline, and the ``.docx`` master is the authority for the DOCX pipeline.

Usage::

    from pathlib import Path
    from app.engines.html_template import HtmlTemplateEngine

    engine = HtmlTemplateEngine(
        master_path=Path("app/templates/masters/klass-educational-v1.html"),
    )
    html: str = engine.render(blueprint)
"""

from __future__ import annotations

from pathlib import Path

from app.engines.blueprint import SlideBlueprint
from app.engines.html_template.context_builder import build_html_context
from app.templates.jinja_env import render_master_html


class HtmlTemplateEngine:
    """Template-driven HTML engine.

    Builds a Jinja2 context dict from a ``SlideBlueprint`` and renders it
    through the self-contained HTML master.  The output is a complete HTML
    ``<html>`` string with inline CSS — ready for:

    * Chromium ``page.setContent(html)`` + ``page.pdf()`` (PDF pipeline).
    * Saved to disk for the signed-URL preview (WebView pipeline).

    The engine is stateless — the master template path is stored at init and
    reused across ``.render()`` calls.

    References
    ----------
    * ``DocxTemplateEngine`` (:mod:`app.engines.docx_template.engine`) follows
      the same architecture (``_build_context`` + ``render``) for the DOCX
      pipeline.
    * ``render_master_html`` (:func:`app.templates.jinja_env.render_master_html`)
      performs the actual Jinja2 rendering from a cached environment.
    """

    def __init__(self, master_path: Path) -> None:
        """Store *master_path*.

        Args:
            master_path: Absolute path to the HTML master template
                (e.g. ``app/templates/masters/klass-educational-v1.html``).
                The filename stem (``template_id + ".html"``) is extracted
                for ``render_master_html`` lookup via the Jinja2 environment.
        """
        self._template_name = master_path.name

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def render(self, blueprint: SlideBlueprint) -> str:
        """Render *blueprint* through the HTML master template.

        Returns a self-contained HTML ``<html>`` string suitable for
        Chromium PDF rendering or WebView preview — **no file I/O** is
        performed by this method.

        Args:
            blueprint: Validated ``SlideBlueprint`` produced by
                :func:`app.engines.blueprint_builder.build_slide_blueprint`.

        Returns:
            Complete, self-contained HTML string.
        """
        context = build_html_context(blueprint)
        return render_master_html(self._template_name, context)
