"""Build Marp-flavoured markdown from a ``SlideBlueprint``.

This module is the deterministic bridge between the universal blueprint
(:class:`app.engines.blueprint.SlideBlueprint`) and the Marp rendering
pipeline (HTML preview + PDF).

The output is a plain ``str`` of Marp-flavoured markdown that the Node
sidecar (``sidecar/marp_sidecar.js``) can render directly via
``@marp-team/marp-core``.

Output structure
----------------
1. **YAML front matter** — ``marp: true``, ``theme``, ``paginate: true``,
   ``size: 16:9``.
2. **Per-slide section** — separated by ``---`` (Marp page break).
   Each slide starts with an HTML comment directive block (``_class``,
   ``_backgroundColor``, speaker notes), followed by heading + card body.

Multi-card slides
-----------------
When a slide contains more than one ``Card``, the builder emits an HTML
``<div class="cards">`` wrapper with per-card ``<div class="card">``
children.  The CSS theme (``klass-default.css``) is responsible for
laying these out as a horizontal grid (``display: grid``).  This keeps
the builder purely structural and the theme purely visual.
"""
from __future__ import annotations

from app.engines.blueprint import Card, ContentBlock, Slide, SlideBlueprint


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def build_marp_markdown(blueprint: SlideBlueprint) -> str:
    """Convert a validated ``SlideBlueprint`` into Marp-flavoured markdown.

    The function is **pure** — it reads from *blueprint* and returns a string
    with no side-effects.  It is intentionally deterministic so that the same
    blueprint always produces the same markdown (useful for snapshot tests).
    """
    sections: list[str] = [_build_front_matter(blueprint)]
    for slide in blueprint.slides:
        sections.append(_build_slide(slide))
    return "\n\n".join(sections) + "\n"


# ---------------------------------------------------------------------------
# Front matter
# ---------------------------------------------------------------------------

def _build_front_matter(blueprint: SlideBlueprint) -> str:
    lines = [
        "---",
        "marp: true",
        f"theme: {blueprint.theme_id}",
        "paginate: true",
        "size: 16:9",
        "---",
    ]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Per-slide rendering
# ---------------------------------------------------------------------------

def _build_slide(slide: Slide) -> str:
    parts: list[str] = []

    # Slide directives (HTML comment block).
    directives = _build_directives(slide)
    if directives:
        parts.append(directives)

    # Heading — always present.
    heading_level = 1 if slide.slide_type == "title" else 2
    parts.append(f"{'#' * heading_level} {_escape_markdown_text(slide.title)}")

    # Subtitle (title slide only).
    if slide.subtitle:
        parts.append(f"\n{_escape_markdown_text(slide.subtitle)}")

    # Card body.
    if slide.cards:
        parts.append(_build_cards(slide.cards))

    return "\n\n".join(parts)


def _build_directives(slide: Slide) -> str:
    """Build the HTML-comment directive block that precedes slide content."""
    lines: list[str] = []

    # Marp class directive for CSS targeting.
    lines.append(f"<!-- _class: {slide.slide_type} -->")

    # Speaker notes — Marp uses ``<!-- speaker_notes: ... -->`` or
    # ``<!--\nnote text\n-->``.  The per-slide ``_class`` comment must come
    # first; notes go in a separate comment block immediately after.
    if slide.speaker_notes:
        escaped = slide.speaker_notes.replace("-->", "--&gt;")
        lines.append(f"<!--\n{escaped}\n-->")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Card rendering
# ---------------------------------------------------------------------------

def _build_cards(cards: list[Card]) -> str:
    """Render one or more cards into Marp markdown.

    * **Single card** — emitted as plain markdown (no wrapper div).
    * **Multiple cards** — wrapped in ``<div class="cards">`` with per-card
      ``<div class="card">`` children so the CSS theme can apply a grid
      layout.
    """
    if len(cards) == 1:
        return _build_single_card_body(cards[0])

    inner = "\n".join(
        f'<div class="card">\n\n{_build_single_card_body(card)}\n\n</div>'
        for card in cards
    )
    return f'<div class="cards">\n\n{inner}\n\n</div>'


def _build_single_card_body(card: Card) -> str:
    """Render a single card's heading + body blocks into markdown."""
    parts: list[str] = []

    if card.heading:
        parts.append(f"### {_escape_markdown_text(card.heading)}")

    body_lines: list[str] = []
    for block in card.body_blocks:
        formatted = _format_content_block(block)
        if formatted:
            body_lines.append(formatted)

    if body_lines:
        parts.append("\n".join(body_lines))

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Content block formatting
# ---------------------------------------------------------------------------

def _format_content_block(block: ContentBlock) -> str:
    """Map a ``ContentBlock`` to its Marp markdown representation."""
    text = _escape_markdown_text(block.content)

    if block.kind == "bullet":
        return f"- {text}"
    if block.kind == "checklist":
        return f"- [ ] {text}"
    if block.kind == "note":
        return f"> {text}"
    # "paragraph" and any future kinds fall through as plain text.
    return text


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _escape_markdown_text(text: str) -> str:
    """Escape characters that Marp's markdown parser would interpret.

    Only escapes characters that commonly cause unintended formatting inside
    headings and paragraphs.  List markers (``-``, ``*``) are **not** escaped
    because they are intentional in ``_format_content_block``.
    """
    return (
        text
        .replace("\\", "\\\\")
        .replace("[", "\\[")
        .replace("]", "\\]")
        .replace("#", "\\#")
        .replace("|", "\\|")
    )
