"""Master template registry for all generation formats.

Provides the ``TemplateRegistry`` which loads master templates for every
format at startup, keyed by a single ``template_id`` (== ``SlideBlueprint.theme_id``):

- ``.pptx`` + manifest — Template Injector pipeline (PPTX)
- ``.html`` — Jinja2 master for the PDF + WebView preview pipeline (Fase 2)
- ``.docx`` — master with ``docxtpl`` placeholders for the DOCX pipeline (Fase 1)

The Jinja2 environment that renders the HTML masters lives in
``app.templates.jinja_env``.
"""