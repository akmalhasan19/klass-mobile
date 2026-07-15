"""Template-driven DOCX engine using docxtpl (Fase 1 / Task 1A).

Renders a ``SlideBlueprint`` through a ``.docx`` master template that
contains ``docxtpl`` Jinja2-style placeholders (``{{ }}``, ``{% %}``).

The master template (``app/templates/masters/klass-educational-v1.docx``)
was built by ``_generate_docx_master.py`` (Fase 0B) and is the design
authority for the DOCX pipeline — just as the ``.pptx`` + manifest pair is
the authority for the PPTX pipeline.

Usage::

    engine = DocxTemplateEngine(master_path)
    engine.render(blueprint, output_path)
"""

from __future__ import annotations

from pathlib import Path

from docxtpl import DocxTemplate

from app.engines.blueprint import SlideBlueprint


class DocxTemplateEngine:
    """Template-driven DOCX engine.

    Wraps ``docxtpl.DocxTemplate`` and builds a flat context dict from a
    ``SlideBlueprint`` that matches the placeholders in the ``.docx`` master.

    The context is built once per render call — there is no state shared
    across renders, keeping the engine thread-safe and stateless (the
    ``master_path`` itself is immutable).
    """

    def __init__(self, master_path: Path) -> None:
        """Store *master_path* — not opened until :meth:`render` is called.

        Args:
            master_path: Absolute path to the ``.docx`` master template.
        """
        self._master_path = master_path

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def render(self, blueprint: SlideBlueprint, output_path: Path) -> None:
        """Render *blueprint* through the master template to *output_path*.

        Steps:
        1. Build a flat context dict from the ``SlideBlueprint``.
        2. Open the master ``.docx`` with ``docxtpl.DocxTemplate``.
        3. Call ``.render(context)`` which fills every ``{{ }}`` placeholder
           and expands ``{% for %}`` / ``{% if %}`` blocks.
        4. Persist the filled document to *output_path*.

        Args:
            blueprint: Validated ``SlideBlueprint`` produced by
                :func:`app.engines.blueprint_builder.build_slide_blueprint`.
            output_path: Writable destination for the rendered ``.docx``.
        """
        context = self._build_context(blueprint)
        doc = DocxTemplate(str(self._master_path))
        doc.render(context)
        doc.save(str(output_path))

    # ------------------------------------------------------------------
    # Context builder
    # ------------------------------------------------------------------

    def _build_context(self, blueprint: SlideBlueprint) -> dict:
        """Build a flat context dict from ``SlideBlueprint`` for docxtpl.

        The context keys match the placeholders embedded in the ``.docx``
        master template by ``_generate_docx_master.py``:

        +------------------------+------------------------------------------+
        | Context key            | Source in ``SlideBlueprint``              |
        +------------------------+------------------------------------------+
        | ``title``              | ``deck_meta.title``                       |
        | ``summary``            | ``deck_meta.summary``                     |
        | ``subject``            | ``deck_meta.subject`` (may be ``None``)   |
        | ``sub_subject``        | ``deck_meta.sub_subject`` (may be ``None``)|
        | ``learning_objectives``| ``deck_meta.learning_objectives`` (list)   |
        | ``sections``           | Content slides linearised (see below)     |
        | ``activities``         | Assessment slide cards (see below)        |
        +------------------------+------------------------------------------+

        **Section mapping** (``slides → sections``):
        Each content ``Slide`` becomes one dict in the ``sections`` list with:
        - ``title``: ``slide.title``
        - ``blocks``: a flat list of dicts ``{"kind": ..., "content": ...}``
          aggregated from **all** cards on that slide (``card.body_blocks``).

        **Activity mapping** (``assessment-slide → activities``):
        The single assessment slide's cards become ``activities`` entries with:
        - ``title``: ``card.heading`` (or ``"Aktivitas"`` fallback)
        - ``instructions``: first block's ``content`` (or ``""`` fallback)

        When no assessment slide is present the ``activities`` list is empty,
        so ``{% for activity in activities %}`` renders nothing — the master
        template handles this gracefully via the empty-loop convention.
        """
        meta = blueprint.deck_meta

        # -- Sections: each content slide → one section -------------------
        sections: list[dict] = []
        for slide in blueprint.slides:
            if slide.slide_type != "content":
                continue
            blocks: list[dict] = []
            for card in slide.cards:
                for block in card.body_blocks:
                    blocks.append({
                        "kind": block.kind,
                        "content": block.content,
                    })
            sections.append({
                "title": slide.title,
                "blocks": blocks,
            })

        # -- Activities: each assessment card → one activity ---------------
        activities: list[dict] = []
        for slide in blueprint.slides:
            if slide.slide_type != "assessment":
                continue
            for card in slide.cards:
                instructions = (
                    card.body_blocks[0].content if card.body_blocks else ""
                )
                activities.append({
                    "title": card.heading or "Aktivitas",
                    "instructions": instructions,
                })

        return {
            "title": meta.title,
            "summary": meta.summary,
            "subject": meta.subject,
            "sub_subject": meta.sub_subject,
            "learning_objectives": list(meta.learning_objectives),
            "sections": sections,
            "activities": activities,
        }
