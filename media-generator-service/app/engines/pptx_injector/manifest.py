"""TemplateManifest — Pydantic schema for master ``.pptx`` manifest files.

A manifest is a JSON file that describes the placeholder structure of a master
``.pptx`` template.  It maps each slide layout to a set of named placeholders
with capacity constraints, enabling the Template Injector to perform
deterministic content fill and capacity-based fit-check.

Schema overview::

    {
      "template_id": "klass-educational-v1",
      "version": "1.0.0",
      "slide_layouts": [
        {
          "layout_id": "title",
          "slide_type": "title",
          "slide_index": 0,
          "placeholders": [
            { "placeholder_id": "title", "shape_name": "Title 1", "kind": "text" },
            { "placeholder_id": "subtitle", "shape_name": "Subtitle 2", "kind": "text" },
            { "placeholder_id": "body", "shape_name": "Content Placeholder 3", "kind": "text",
              "capacity": { "max_cards": 4, "max_chars": 500 } }
          ]
        }
      ]
    }

Design notes
------------
- ``slide_index`` is the index into ``Presentation.slide_layouts`` in the
  master ``.pptx`` file.  The actual ``SlideLayout`` object is **not** stored
  in the Pydantic model (it is not serialisable).  The registry layer
  (:class:`app.templates.registry.TemplateRegistry`) resolves the index to a
  live object at startup and passes it to the injector at render time.
- ``PlaceholderKind`` is intentionally narrow (``"text"`` | ``"image"``).
  All current ``ContentBlock`` kinds (paragraph, bullet, checklist, note)
  are text-based; ``"image"`` is reserved for future image placeholders.
- ``Capacity`` fields are both optional.  ``None`` means "no limit".
"""
from __future__ import annotations

from pathlib import Path
from typing import Literal

from pydantic import Field

from app.engines.blueprint import SlideType, _BlueprintStrictModel


# ---------------------------------------------------------------------------
# Capacity
# ---------------------------------------------------------------------------

PlaceholderKind = Literal["text", "image"]
"""What a placeholder accepts — text covers all block kinds; image is future use."""


class Capacity(_BlueprintStrictModel):
    """Fit-check thresholds for a body placeholder.

    Both fields are optional.  ``None`` means "no limit enforced".
    The injector compares these against the incoming ``Slide`` to decide
    whether to use template injection or fall back to canvas layout.
    """

    max_cards: int | None = Field(
        default=None,
        ge=1,
        description=(
            "Maximum number of cards this placeholder can hold. "
            "If the slide has more cards, the injector falls back to canvas."
        ),
    )
    max_chars: int | None = Field(
        default=None,
        ge=1,
        description=(
            "Maximum total characters (headings + body blocks) this placeholder "
            "can hold.  Exceeding this triggers canvas fallback."
        ),
    )


# ---------------------------------------------------------------------------
# Placeholder specification
# ---------------------------------------------------------------------------

class PlaceholderSpec(_BlueprintStrictModel):
    """Describes one named placeholder in a slide layout.

    Attributes:
        placeholder_id: Logical ID used by the injector to map blueprint
            fields (``title``, ``subtitle``, ``body``, ``notes``) to
            physical shapes.  Convention: lowercase, underscored.
        shape_name: The ``shape.name`` value in the master ``.pptx`` that
            corresponds to this placeholder.  The resolver searches
            ``slide.shapes`` by this name.
        kind: Whether the placeholder accepts text or images.
        capacity: Optional fit-check thresholds (only meaningful for
            body placeholders).
    """

    placeholder_id: str = Field(
        min_length=1,
        max_length=100,
        description="Logical ID for injector binding (e.g. 'title', 'body').",
    )
    shape_name: str = Field(
        min_length=1,
        max_length=200,
        description="shape.name in the master .pptx to resolve against.",
    )
    kind: PlaceholderKind = Field(
        description="What this placeholder accepts: 'text' or 'image'.",
    )
    capacity: Capacity | None = Field(
        default=None,
        description="Fit-check thresholds; only meaningful for body placeholders.",
    )


# ---------------------------------------------------------------------------
# Layout manifest
# ---------------------------------------------------------------------------

class LayoutManifest(_BlueprintStrictModel):
    """Manifest entry for a single slide layout in the master template.

    Attributes:
        layout_id: Stable identifier for this layout (e.g. ``"title"``,
            ``"content-two-col"``).  Used in warnings and debug output.
        slide_type: The ``SlideType`` this layout serves.  The injector
            calls :meth:`TemplateManifest.pick_layout` with a slide's type
            to find the matching layout.
        slide_index: Index into ``Presentation.slide_layouts`` in the master
            ``.pptx``.  Resolved to a live ``SlideLayout`` object by the
            registry at startup.
        placeholders: Ordered list of placeholder specs for this layout.
    """

    layout_id: str = Field(
        min_length=1,
        max_length=100,
        description="Stable identifier for this layout (e.g. 'title', 'content').",
    )
    slide_type: SlideType = Field(
        description="Which SlideType this layout handles.",
    )
    slide_index: int = Field(
        ge=0,
        description="Index into Presentation.slide_layouts in the master .pptx.",
    )
    placeholders: list[PlaceholderSpec] = Field(
        default_factory=list,
        description="Ordered placeholder specs for this layout.",
    )

    def placeholder(self, placeholder_id: str) -> PlaceholderSpec | None:
        """Look up a placeholder by its logical ID.

        Returns ``None`` if no placeholder with the given ID exists in this
        layout.  The injector uses this to resolve ``"title"``, ``"body"``,
        etc. before writing content into shapes.
        """
        for spec in self.placeholders:
            if spec.placeholder_id == placeholder_id:
                return spec
        return None


# ---------------------------------------------------------------------------
# Root manifest
# ---------------------------------------------------------------------------

class TemplateManifest(_BlueprintStrictModel):
    """Top-level manifest for a master ``.pptx`` template.

    Loaded from a JSON file at startup by the template registry.  The
    injector receives a ``TemplateManifest`` (or a ``LayoutManifest`` from
    :meth:`pick_layout`) to drive placeholder-based content fill.

    Attributes:
        template_id: Unique identifier for the template (matches ``theme_id``
            in ``SlideBlueprint``).
        version: Semantic version of the manifest (for cache invalidation).
        slide_layouts: Ordered list of layout definitions.
    """

    template_id: str = Field(
        min_length=1,
        max_length=100,
        description="Unique template identifier, matches SlideBlueprint.theme_id.",
    )
    version: str = Field(
        min_length=1,
        max_length=50,
        description="Semantic version of the manifest.",
    )
    slide_layouts: list[LayoutManifest] = Field(
        min_length=1,
        description="Ordered layout definitions for this template.",
    )

    def pick_layout(self, slide_type: SlideType) -> LayoutManifest | None:
        """Return the first layout matching *slide_type*, or ``None``.

        The injector calls this per-slide to decide which master layout to
        use.  If no layout matches (e.g. the manifest doesn't define an
        ``"assessment"`` layout), the injector falls back to canvas rendering.
        """
        for layout in self.slide_layouts:
            if layout.slide_type == slide_type:
                return layout
        return None


# ---------------------------------------------------------------------------
# Loader utility
# ---------------------------------------------------------------------------

def load_manifest(path: Path) -> TemplateManifest:
    """Load and validate a manifest JSON file into a ``TemplateManifest``.

    Raises:
        FileNotFoundError: If *path* does not exist.
        pydantic.ValidationError: If the JSON fails schema validation.
    """
    import json

    data = json.loads(path.read_text(encoding="utf-8"))
    return TemplateManifest.model_validate(data)
