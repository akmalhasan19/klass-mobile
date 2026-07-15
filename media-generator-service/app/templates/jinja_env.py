"""Jinja2 environment for HTML master templates (PDF + preview pipeline).

Creates a single, process-wide ``jinja2.Environment`` rooted at
``app/templates/masters/``.  The HTML template engine (Fase 2) renders the
self-contained educational HTML for both the PDF artifact and the WebView
preview from a :class:`app.engines.blueprint.SlideBlueprint` context.

Why a shared environment?
--------------------------
* **Single source of truth for master files.** ``masters/`` already holds the
  PPTX ``.pptx`` masters and (from Fase 0B) the ``.docx`` masters, all keyed by
  the same ``template_id`` (which equals ``SlideBlueprint.theme_id``).  Pointing
  the ``FileSystemLoader`` here keeps HTML masters discoverable by the same
  convention instead of introducing a parallel directory.
* **Autoescaping is on for ``.html``.**  Titles, card text, notes and subject
  labels are user-generated; autoescaping prevents markup injection into the
  PDF/preview surface.
* **Compiled once, reused across requests.**  Template compilation is the only
  meaningful cost, and the cached environment amortises it.

The :class:`app.templates.registry.TemplateRegistry` (extended in Fase 0C) is
the authority that maps a ``template_id`` to the concrete master filename —
this module only knows how to *render* a master once its filename is known.
"""
from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

from app.errors import ServiceMisconfiguredError

TEMPLATES_DIR = Path(__file__).resolve().parent
MASTERS_DIR = TEMPLATES_DIR / "masters"

DEFAULT_HTML_MASTER = "klass-educational-v1.html"


@lru_cache(maxsize=1)
def get_jinja_environment() -> Environment:
    """Return the shared Jinja2 ``Environment`` for HTML master templates.

    The environment is cached process-wide.  ``FileSystemLoader`` is rooted at
    ``masters/`` so template names are bare master filenames
    (e.g. ``"klass-educational-v1.html"``).
    """
    if not MASTERS_DIR.is_dir():
        raise ServiceMisconfiguredError(
            "Jinja2 masters directory not found.",
            {"masters_dir": str(MASTERS_DIR)},
        )

    return Environment(
        loader=FileSystemLoader(str(MASTERS_DIR)),
        autoescape=select_autoescape(["html", "htm", "xml"]),
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )


def render_master_html(template_name: str, context: dict) -> str:
    """Render an HTML master *template_name* with *context*.

    Convenience wrapper used by the HTML template engine (Fase 2).  Raises
    ``jinja2.TemplateNotFound`` if the master is missing, and Jinja2 template
    errors on malformed masters.
    """
    template = get_jinja_environment().get_template(template_name)
    return template.render(**context)


def validate_html_master(template_name: str = DEFAULT_HTML_MASTER) -> Path:
    """Fail-fast check that the HTML master exists and parses.

    Called at startup so a missing or syntactically broken master fails loudly
    before any request reaches the renderer.  Returns the resolved master path.
    """
    master_path = MASTERS_DIR / template_name
    if not master_path.is_file():
        raise ServiceMisconfiguredError(
            "HTML master template not found.",
            {"template_name": template_name, "expected_path": str(master_path)},
        )

    # Force-compile the template to surface syntax errors immediately.
    get_jinja_environment().get_template(template_name)
    return master_path
