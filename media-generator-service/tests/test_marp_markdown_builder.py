"""Unit tests for ``app.engines.marp.marp_markdown_builder``.

Tests follow the same conventions as the rest of the suite: plain ``pytest``
functions, reuse of ``tests.helpers.sample_request`` for backward-compat
validation, and small focused fixtures for edge cases.
"""
from __future__ import annotations

import pytest

from app.document_model import build_render_document
from app.engines.blueprint import (
    Card,
    ContentBlock,
    DeckMeta,
    Slide,
    SlideBlueprint,
    SlideType,
)
from app.engines.blueprint_builder import build_slide_blueprint
from app.engines.marp.marp_markdown_builder import build_marp_markdown
from tests.helpers import sample_request


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _minimal_blueprint(
    slides: list[Slide] | None = None,
    theme_id: str = "klass-educational-v1",
) -> SlideBlueprint:
    return SlideBlueprint(
        deck_meta=DeckMeta(
            title="Test Deck",
            summary="A test deck.",
            language="en",
            audience_level="general",
            tone="neutral",
        ),
        theme_id=theme_id,
        slides=slides or [
            Slide(
                slide_type="title",
                title="Hello",
                cards=[Card(body_blocks=[ContentBlock(kind="paragraph", content="world")])],
            )
        ],
    )


def _slide(
    slide_type: SlideType,
    title: str = "Slide Title",
    cards: list[Card] | None = None,
    subtitle: str | None = None,
    speaker_notes: str | None = None,
) -> Slide:
    return Slide(
        slide_type=slide_type,
        title=title,
        subtitle=subtitle,
        cards=cards or [Card(body_blocks=[ContentBlock(kind="paragraph", content="body")])],
        speaker_notes=speaker_notes,
    )


# ---------------------------------------------------------------------------
# 1. Front matter structure
# ---------------------------------------------------------------------------

def test_front_matter_contains_marp_true() -> None:
    md = build_marp_markdown(_minimal_blueprint())
    assert "---\nmarp: true\n" in md


def test_front_matter_contains_theme_from_blueprint() -> None:
    bp = _minimal_blueprint(theme_id="my-custom-theme")
    md = build_marp_markdown(bp)
    assert "theme: my-custom-theme" in md


def test_front_matter_contains_paginate_and_size() -> None:
    md = build_marp_markdown(_minimal_blueprint())
    assert "paginate: true" in md
    assert "size: 16:9" in md


def test_front_matter_is_first_section() -> None:
    md = build_marp_markdown(_minimal_blueprint())
    assert md.startswith("---\n")


# ---------------------------------------------------------------------------
# 2. Slide structure — all slide_type values
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("slide_type", ["title", "section", "content", "assessment"])
def test_slide_emits_class_directive(slide_type: SlideType) -> None:
    bp = _minimal_blueprint(slides=[_slide(slide_type)])
    md = build_marp_markdown(bp)
    assert f"<!-- _class: {slide_type} -->" in md


@pytest.mark.parametrize("slide_type", ["title", "section", "content", "assessment"])
def test_slide_emits_heading(slide_type: SlideType) -> None:
    bp = _minimal_blueprint(slides=[_slide(slide_type, title="My Title")])
    md = build_marp_markdown(bp)
    assert "My Title" in md


def test_title_slide_uses_h1() -> None:
    bp = _minimal_blueprint(slides=[_slide("title", title="Big Title")])
    md = build_marp_markdown(bp)
    assert "# Big Title" in md
    assert "## Big Title" not in md


def test_non_title_slide_uses_h2() -> None:
    bp = _minimal_blueprint(slides=[_slide("content", title="Section Title")])
    md = build_marp_markdown(bp)
    assert "## Section Title" in md


# ---------------------------------------------------------------------------
# 3. Subtitle handling
# ---------------------------------------------------------------------------

def test_subtitle_appears_after_heading() -> None:
    bp = _minimal_blueprint(slides=[_slide("title", title="T", subtitle="Sub text")])
    md = build_marp_markdown(bp)
    assert "Sub text" in md
    # Subtitle should come after the heading line.
    heading_pos = md.index("# T")
    subtitle_pos = md.index("Sub text")
    assert subtitle_pos > heading_pos


def test_no_subtitle_when_none() -> None:
    bp = _minimal_blueprint(slides=[_slide("content", title="T")])
    md = build_marp_markdown(bp)
    lines = md.split("\n")
    # Only the heading line and body — no subtitle paragraph.
    heading_lines = [l for l in lines if "T" in l and l.startswith("##")]
    assert len(heading_lines) == 1


# ---------------------------------------------------------------------------
# 4. Content block formatting
# ---------------------------------------------------------------------------

def test_bullet_block_renders_as_markdown_list() -> None:
    card = Card(body_blocks=[ContentBlock(kind="bullet", content="item one")])
    bp = _minimal_blueprint(slides=[_slide("content", cards=[card])])
    md = build_marp_markdown(bp)
    assert "- item one" in md


def test_checklist_block_renders_with_checkbox() -> None:
    card = Card(body_blocks=[ContentBlock(kind="checklist", content="do this")])
    bp = _minimal_blueprint(slides=[_slide("content", cards=[card])])
    md = build_marp_markdown(bp)
    assert "- [ ] do this" in md


def test_paragraph_block_renders_as_plain_text() -> None:
    card = Card(body_blocks=[ContentBlock(kind="paragraph", content="plain text")])
    bp = _minimal_blueprint(slides=[_slide("content", cards=[card])])
    md = build_marp_markdown(bp)
    assert "plain text" in md


def test_note_block_renders_as_blockquote() -> None:
    card = Card(body_blocks=[ContentBlock(kind="note", content="remember this")])
    bp = _minimal_blueprint(slides=[_slide("content", cards=[card])])
    md = build_marp_markdown(bp)
    assert "> remember this" in md


def test_multiple_blocks_in_order() -> None:
    card = Card(body_blocks=[
        ContentBlock(kind="bullet", content="first"),
        ContentBlock(kind="bullet", content="second"),
        ContentBlock(kind="paragraph", content="third"),
    ])
    bp = _minimal_blueprint(slides=[_slide("content", cards=[card])])
    md = build_marp_markdown(bp)
    first_pos = md.index("- first")
    second_pos = md.index("- second")
    third_pos = md.index("third")
    assert first_pos < second_pos < third_pos


# ---------------------------------------------------------------------------
# 5. Card heading
# ---------------------------------------------------------------------------

def test_card_heading_renders_as_h3() -> None:
    card = Card(heading="Card Title", body_blocks=[
        ContentBlock(kind="paragraph", content="body")
    ])
    bp = _minimal_blueprint(slides=[_slide("content", cards=[card])])
    md = build_marp_markdown(bp)
    assert "### Card Title" in md


def test_card_without_heading_has_no_h3() -> None:
    card = Card(body_blocks=[ContentBlock(kind="paragraph", content="body")])
    bp = _minimal_blueprint(slides=[_slide("content", cards=[card])])
    md = build_marp_markdown(bp)
    assert "###" not in md


# ---------------------------------------------------------------------------
# 6. Multi-card slides → HTML div wrapper
# ---------------------------------------------------------------------------

def test_single_card_emits_no_div_wrapper() -> None:
    card = Card(body_blocks=[ContentBlock(kind="paragraph", content="solo")])
    bp = _minimal_blueprint(slides=[_slide("content", cards=[card])])
    md = build_marp_markdown(bp)
    assert '<div class="cards">' not in md


def test_multiple_cards_emit_div_wrapper() -> None:
    cards = [
        Card(body_blocks=[ContentBlock(kind="paragraph", content="a")]),
        Card(body_blocks=[ContentBlock(kind="paragraph", content="b")]),
    ]
    bp = _minimal_blueprint(slides=[_slide("content", cards=cards)])
    md = build_marp_markdown(bp)
    assert '<div class="cards">' in md
    assert '<div class="card">' in md
    assert md.count('<div class="card">') == 2


def test_three_cards_produce_three_card_divs() -> None:
    cards = [
        Card(body_blocks=[ContentBlock(kind="paragraph", content=f"card {i}")])
        for i in range(3)
    ]
    bp = _minimal_blueprint(slides=[_slide("content", cards=cards)])
    md = build_marp_markdown(bp)
    assert md.count('<div class="card">') == 3


# ---------------------------------------------------------------------------
# 7. Speaker notes
# ---------------------------------------------------------------------------

def test_speaker_notes_rendered_as_html_comment() -> None:
    bp = _minimal_blueprint(slides=[
        _slide("content", title="T", speaker_notes="Don't forget to smile")
    ])
    md = build_marp_markdown(bp)
    assert "Don't forget to smile" in md
    assert "<!--\nDon't forget to smile\n-->" in md


def test_no_speaker_notes_when_none() -> None:
    bp = _minimal_blueprint(slides=[_slide("content", title="T")])
    md = build_marp_markdown(bp)
    # Only the _class directive comment, no note comment.
    assert md.count("<!--") == 1


def test_speaker_notes_escape_closing_comment() -> None:
    bp = _minimal_blueprint(slides=[
        _slide("content", title="T", speaker_notes="a --> b")
    ])
    md = build_marp_markdown(bp)
    assert "a --&gt; b" in md
    # The raw --> should not appear inside the note comment.
    note_section = md.split("<!--\n")[1].split("\n-->")[0]
    assert "-->" not in note_section


# ---------------------------------------------------------------------------
# 8. Markdown escaping
# ---------------------------------------------------------------------------

def test_special_characters_in_heading_are_escaped() -> None:
    bp = _minimal_blueprint(slides=[_slide("title", title="C# Basics [Part 1]")])
    md = build_marp_markdown(bp)
    # Should contain escaped forms, not raw.
    assert "C\\# Basics \\[Part 1\\]" in md


def test_pipe_in_content_is_escaped() -> None:
    card = Card(body_blocks=[ContentBlock(kind="paragraph", content="A | B")])
    bp = _minimal_blueprint(slides=[_slide("content", cards=[card])])
    md = build_marp_markdown(bp)
    assert "A \\| B" in md


# ---------------------------------------------------------------------------
# 9. Full round-trip from sample_request
# ---------------------------------------------------------------------------

def test_builder_produces_valid_markdown_from_sample_request() -> None:
    render_document = build_render_document(sample_request("pptx").generation_spec)
    blueprint = build_slide_blueprint(render_document)

    md = build_marp_markdown(blueprint)

    # Must be a non-empty string.
    assert isinstance(md, str)
    assert len(md) > 0

    # Must contain front matter.
    assert md.startswith("---\n")
    assert "marp: true" in md

    # Must contain all slide types from the blueprint.
    for slide in blueprint.slides:
        assert f"<!-- _class: {slide.slide_type} -->" in md
        assert slide.title in md or _escape(slide.title) in md


def test_builder_produces_slides_for_every_blueprint_slide() -> None:
    render_document = build_render_document(sample_request("pptx").generation_spec)
    blueprint = build_slide_blueprint(render_document)

    md = build_marp_markdown(blueprint)

    # Count slide separators (--- between slides).  Front matter uses the
    # first --- block; each subsequent --- is a page break.
    # We count occurrences of the _class directive instead (more reliable).
    directive_count = md.count("<!-- _class:")
    assert directive_count == len(blueprint.slides)


def test_builder_deterministic() -> None:
    """Same blueprint must always produce identical markdown."""
    render_document = build_render_document(sample_request("pptx").generation_spec)
    blueprint = build_slide_blueprint(render_document)

    md1 = build_marp_markdown(blueprint)
    md2 = build_marp_markdown(blueprint)

    assert md1 == md2


# ---------------------------------------------------------------------------
# 10. Edge cases
# ---------------------------------------------------------------------------

def test_builder_with_empty_learning_objectives() -> None:
    payload = sample_request("pptx")
    payload.generation_spec.learning_objectives = []
    render_document = build_render_document(payload.generation_spec)
    blueprint = build_slide_blueprint(render_document)

    md = build_marp_markdown(blueprint)
    assert "marp: true" in md
    assert len(blueprint.slides) >= 1


def test_builder_with_no_activity_blocks() -> None:
    payload = sample_request("pptx")
    payload.generation_spec.assessment_or_activity_blocks = []
    render_document = build_render_document(payload.generation_spec)
    blueprint = build_slide_blueprint(render_document)

    md = build_marp_markdown(blueprint)
    assert "marp: true" in md
    # No assessment slide.
    assert "<!-- _class: assessment -->" not in md


def test_builder_with_no_sections() -> None:
    payload = sample_request("pptx")
    payload.generation_spec.sections = []
    render_document = build_render_document(payload.generation_spec)
    blueprint = build_slide_blueprint(render_document)

    md = build_marp_markdown(blueprint)
    assert "marp: true" in md
    # Title slide still present.
    assert "<!-- _class: title -->" in md


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _escape(text: str) -> str:
    """Mirror the builder's escaping for assertion matching."""
    return (
        text
        .replace("\\", "\\\\")
        .replace("[", "\\[")
        .replace("]", "\\]")
        .replace("#", "\\#")
        .replace("|", "\\|")
    )
