"""Context builder for the HTML Template Engine.

Maps the SlideBlueprint into the Jinja2 context variables expected by
the HTML master template.
"""

from __future__ import annotations

from app.engines.blueprint import SlideBlueprint


def build_html_context(blueprint: SlideBlueprint) -> dict:
    """Build the Jinja2 context dict from ``SlideBlueprint``.

    The HTML master template expects two top-level variables:

    +------------+------------------------------------------+
    | Variable   | Source in ``SlideBlueprint``             |
    +------------+------------------------------------------+
    | ``deck``   | ``blueprint.deck_meta`` (``DeckMeta``)   |
    | ``slides`` | ``blueprint.slides`` (``list[Slide]``)   |
    +------------+------------------------------------------+

    Unlike the DOCX engine (which linearises slides into sections /
    activities to match the ``.docx`` master's flat placeholders), the
    HTML master template iterates ``slides`` directly via
    ``{% for slide in slides %}`` and accesses nested ``card`` /
    ``body_block`` properties inline.  The context is therefore a
    **near-direct passthrough** of the ``SlideBlueprint`` model tree.

    This design keeps the HTML template the single source of visual
    truth: every CSS class, grid layout, and conditional block is
    expressed in the master rather than being reconstructed in Python
    code.
    """
    return {
        "deck": blueprint.deck_meta,
        "slides": blueprint.slides,
    }
