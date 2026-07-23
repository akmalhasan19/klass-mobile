"""Build a signed preview URL for a self-contained HTML artifact.

This module is the bridge between the HTML template engine (which
produces self-contained HTML via :class:`HtmlTemplateEngine`) and the
existing signed-URL artifact-download infrastructure
(``app.artifact_download``).

Flow
----
1. ``store_preview_html`` writes the HTML string to a temporary file with
   the ``klass_media_html_`` prefix expected by the download endpoint.
2. ``build_preview_locator`` constructs a signed URL that points to
   ``GET /v1/artifacts/download`` — reusing the same HMAC-SHA256 mechanism
   used for ``.pptx``, ``.pdf``, and ``.docx`` artifacts.

No changes to ``artifact_download.py`` are required because:

* ``normalize_downloadable_artifact_path`` already accepts any path whose
  name starts with ``klass_media_`` (``klass_media_html_`` matches).
* ``media_type_for_filename`` delegates to ``mimetypes.guess_type``,
  which returns ``text/html`` for ``.html`` files.

After the Marp-to-Jinja2 migration (Fase 2), the HTML string input comes
from :class:`app.engines.html_template.engine.HtmlTemplateEngine` instead
of the old ``SidecarManager.render_html()``.
"""
from __future__ import annotations

import hashlib
import os
import tempfile
from pathlib import Path
from typing import Any

# pyrefly: ignore [missing-import]
from fastapi import Request

from app.settings import Settings

_HTML_MIME_TYPE = "text/html"


def store_preview_html(html: str, generation_id: str, title: str) -> Path:
    """Persist *html* to a temporary file and return its ``Path``.

    The file is created with the ``klass_media_html_`` prefix so that
    ``normalize_downloadable_artifact_path`` accepts it for signed-URL
    generation and download.

    Parameters
    ----------
    html:
        Self-contained HTML string (the output of
        ``HtmlTemplateEngine.render()``).
    generation_id:
        Opaque generation identifier — embedded in the filename for traceability.
    title:
        Human-readable title — used to derive a slug for the filename.
    """
    slug = _slugify(title)[:48] or "preview"
    prefix = f"klass_media_html_{generation_id}_{slug}_"
    file_descriptor, path_str = tempfile.mkstemp(prefix=prefix, suffix=".html")
    try:
        os.write(file_descriptor, html.encode("utf-8"))
    finally:
        os.close(file_descriptor)
    return Path(path_str)



def _slugify(value: str) -> str:
    """Mirror of ``BaseGenerator._slugify`` — kept local to avoid coupling."""
    import re
    import unicodedata

    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    normalized = normalized.lower().strip()
    normalized = re.sub(r"[^a-z0-9]+", "-", normalized)
    return normalized.strip("-")
