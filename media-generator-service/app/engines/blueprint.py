"""SlideBlueprint — universal Pydantic schema for all rendering pipelines.

This module defines the **single source of truth** consumed by:

- **HTML Template pipeline** (preview HTML + PDF): ``SlideBlueprint`` → Jinja2
  HTML master (``app/templates/masters/*.html``) → Chromium PDF/preview
- **Template Injector** (PPTX): ``SlideBlueprint`` → master ``.pptx`` placeholder fill
- **Canvas Calculator** (PPTX fallback): ``SlideBlueprint`` → programmatic shapes
- **DOCX Template pipeline** (Fase 1): ``SlideBlueprint`` → ``.docx`` master

The models mirror the ``ConfigDict(extra="forbid", str_strip_whitespace=True)``
convention established in :pymod:`app.models` (:class:`StrictModel`).

Design decision — ``ContentBlock`` vs reusing ``document_model.RenderBlock``:

    ``RenderBlock`` is a frozen *dataclass* in the document-model layer.  Blueprint
    models are *Pydantic* ``StrictModel`` instances that participate in JSON
    (de)serialisation and schema validation.  Mixing a plain dataclass inside a
    Pydantic tree causes silent coercion and makes ``extra="forbid"`` impossible
    to enforce on the nested object.

    ``ContentBlock`` therefore re-declares the same two fields (``kind``,
    ``content``) as a proper Pydantic model.  The one-liner conversion lives in
    ``blueprint_builder.py`` (Task 1.2), keeping this module dependency-free from
    the document-model layer.
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


# ---------------------------------------------------------------------------
# Shared strict config — matches ``app.models.StrictModel``
# ---------------------------------------------------------------------------

class _BlueprintStrictModel(BaseModel):
    """Base for all blueprint models.

    Uses the same ``ConfigDict`` as :class:`app.models.StrictModel` to keep
    validation behaviour consistent across the service.
    """

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


# ---------------------------------------------------------------------------
# Leaf models
# ---------------------------------------------------------------------------

SlideType = Literal["title", "section", "content", "assessment"]
"""Discriminator for slide layout selection in both Marp and PPTX pipelines."""

LayoutSource = Literal["template", "canvas"]
"""Which engine rendered a given slide — set post-render by the orchestrator."""


class ContentBlock(_BlueprintStrictModel):
    """Atomic piece of slide body content.

    Structurally equivalent to :class:`app.document_model.RenderBlock` but
    expressed as a Pydantic model for composability inside the blueprint
    validation tree.

    Attributes:
        kind: Block semantic type — drives bullet/check/paragraph rendering.
        content: The textual payload.
    """

    kind: Literal["paragraph", "bullet", "checklist", "note"] = Field(
        description="Semantic type of the block — controls how renderers visualise it.",
    )
    content: str = Field(
        min_length=1,
        max_length=2000,
        description="Textual payload for this block.",
    )


class Card(_BlueprintStrictModel):
    """Visual grouping of related content blocks within a slide.

    A slide contains one or more cards. In the Marp pipeline each card maps
    to a distinct column or box; in the PPTX template pipeline each card is
    injected into a body placeholder (or into a canvas-calculated box on
    overflow).

    Attributes:
        heading: Optional bold heading rendered above the body blocks.
        body_blocks: Ordered content blocks that form the card body.
    """

    heading: str | None = Field(
        default=None,
        max_length=300,
        description="Optional heading rendered above body blocks.",
    )
    body_blocks: list[ContentBlock] = Field(
        min_length=1,
        description="Ordered content blocks that form the card body.",
    )


class Slide(_BlueprintStrictModel):
    """One slide in the deck.

    Attributes:
        slide_type: Layout discriminator consumed by manifest lookup and
            Marp CSS class assignment.
        title: Primary heading text for this slide.
        subtitle: Optional secondary heading.
        cards: Ordered visual groups of content.  The count drives the
            capacity gate in the Template Injector (fit-check against
            ``manifest.capacity.max_cards``).
        columns_hint: Preferred column count (``1``–``4``).  Renderers may
            override based on actual card count.
        speaker_notes: Free-text speaker notes (PPTX notes pane / Marp
            ``<!-- speaker_notes: ... -->``).
        layout_source: Set *after* rendering — not part of the input.
            Records whether a template or canvas engine handled this slide.
    """

    slide_type: SlideType = Field(
        description="Layout discriminator for manifest lookup and Marp CSS class.",
    )
    title: str = Field(
        min_length=1,
        max_length=300,
        description="Primary heading text for this slide.",
    )
    subtitle: str | None = Field(
        default=None,
        max_length=500,
        description="Optional secondary heading.",
    )
    cards: list[Card] = Field(
        min_length=1,
        description="Visual groups of content within this slide.",
    )
    columns_hint: int | None = Field(
        default=None,
        ge=1,
        le=4,
        description="Preferred column count (1–4); renderers may override.",
    )
    speaker_notes: str | None = Field(
        default=None,
        max_length=2000,
        description="Speaker notes for PPTX notes pane or Marp comment.",
    )
    layout_source: LayoutSource | None = Field(
        default=None,
        description="Set post-render: which engine handled this slide.",
    )


# ---------------------------------------------------------------------------
# Deck-level metadata
# ---------------------------------------------------------------------------

class DeckMeta(_BlueprintStrictModel):
    """Presentation-level metadata.

    Attributes:
        title: Deck title (also used on the title slide).
        summary: Brief summary shown under the title.
        language: BCP-47 language tag (e.g. ``"id"``, ``"en"``).
        audience_level: Target audience descriptor.
        tone: Tone descriptor (e.g. ``"encouraging"``).
        learning_objectives: Ordered list of learning objectives.
        subject: Optional subject label (e.g. ``"Matematika"``) used for
            header/footer branding and future subject-specific template
            variants.  **Additive** — ``None`` preserves backward compat.
        sub_subject: Optional sub-subject label (e.g. ``"Pecahan"``).
            **Additive** — ``None`` preserves backward compat.
    """

    title: str = Field(
        min_length=1,
        max_length=300,
        description="Deck title shown on the title slide.",
    )
    summary: str = Field(
        min_length=1,
        max_length=1000,
        description="Brief summary for the title slide.",
    )
    language: str = Field(
        min_length=1,
        max_length=32,
        description="BCP-47 language tag.",
    )
    audience_level: str = Field(
        min_length=1,
        max_length=100,
        description="Target audience descriptor.",
    )
    tone: str = Field(
        min_length=1,
        max_length=100,
        description="Tone descriptor (e.g. 'encouraging').",
    )
    learning_objectives: list[str] = Field(
        default_factory=list,
        description="Ordered list of learning objectives.",
    )
    subject: str | None = Field(
        default=None,
        max_length=200,
        description=(
            "Optional subject label for header/footer branding and "
            "subject-specific template variants. Additive — omit for default."
        ),
    )
    sub_subject: str | None = Field(
        default=None,
        max_length=200,
        description=(
            "Optional sub-subject label (e.g. 'Pecahan'). Additive — omit "
            "for default."
        ),
    )


# ---------------------------------------------------------------------------
# Root model
# ---------------------------------------------------------------------------

class SlideBlueprint(_BlueprintStrictModel):
    """Universal slide-deck specification consumed by all three engine pillars.

    This is the **single source of truth** — built once by
    ``blueprint_builder.build_slide_blueprint()`` from a ``RenderDocument``
    (which itself comes from the Gateway's ``GenerationSpec``).

    Attributes:
        deck_meta: Presentation-level metadata (title, summary, language, …).
        theme_id: Identifier selecting both the Marp CSS theme and the PPTX
            master template.  Defaults to ``"klass-educational-v1"``.
        slides: Ordered list of slides to render.
    """

    deck_meta: DeckMeta = Field(
        description="Presentation-level metadata.",
    )
    theme_id: str = Field(
        default="klass-educational-v1",
        min_length=1,
        max_length=100,
        description=(
            "Selects the Marp CSS theme and the PPTX master template. "
            "Defaults to the built-in educational template."
        ),
    )
    slides: list[Slide] = Field(
        min_length=1,
        description="Ordered list of slides to render.",
    )
