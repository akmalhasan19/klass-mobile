"""Unit tests for ``HtmlTemplateEngine`` (Fase 2 / Task 2D).

Tests are organised in three sections:

1. **Context building** — the pure function ``build_html_context()`` from
   :mod:`app.engines.html_template.context_builder`.

2. **Full rendering** — the ``HtmlTemplateEngine.render()`` method with the
   real HTML master template (``klass-educational-v1.html``).  Verifies the
   output is a self-contained HTML string with expected content.

3. **Edge cases** — long content, unicode, special characters, empty slides,
   and multi-slide decks.

Design notes
------------
* Context-building tests construct ``SlideBlueprint`` instances programmatically
  (not through ``build_render_document``) for precise control over every field.
* Render tests use the real ``klass-educational-v1.html`` master template,
  mirroring how ``test_template_foundation.py`` and ``test_docx_template_engine.py``
  use their respective real masters.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from app.engines.blueprint import (
    Card,
    ContentBlock,
    DeckMeta,
    Slide,
    SlideBlueprint,
)
from app.engines.html_template import HtmlTemplateEngine
from app.engines.html_template.context_builder import build_html_context

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

_MASTERS_DIR = (
    Path(__file__).resolve().parent.parent
    / "app"
    / "templates"
    / "masters"
)
_MASTER_PATH = _MASTERS_DIR / "klass-educational-v1.html"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_engine() -> HtmlTemplateEngine:
    return HtmlTemplateEngine(master_path=_MASTER_PATH)


def _default_deck_meta(**overrides: object) -> DeckMeta:
    defaults: dict[str, object] = dict(
        title="Handout Pecahan Kelas 5",
        summary="Handout ringkas untuk memperkenalkan pecahan senilai.",
        language="id",
        audience_level="elementary",
        tone="encouraging",
        learning_objectives=[
            "Siswa mengenali pecahan senilai.",
            "Siswa mencoba latihan pecahan dasar.",
        ],
        subject="Matematika",
        sub_subject="Pecahan",
    )
    defaults.update(overrides)  # type: ignore[typeddict-item]
    return DeckMeta(**defaults)  # type: ignore[arg-type]


def _minimal_slides() -> list[Slide]:
    """One title slide + one content slide + one assessment slide."""
    return [
        Slide(
            slide_type="title",
            title="Handout Pecahan Kelas 5",
            cards=[Card(body_blocks=[ContentBlock(kind="paragraph", content="Ringkasan materi.")])],
        ),
        Slide(
            slide_type="content",
            title="Tujuan Belajar",
            cards=[
                Card(
                    body_blocks=[
                        ContentBlock(kind="bullet", content="Memahami pecahan senilai"),
                        ContentBlock(kind="bullet", content="Menyelesaikan latihan dasar"),
                    ],
                ),
            ],
        ),
        Slide(
            slide_type="assessment",
            title="Aktivitas dan Penilaian",
            cards=[
                Card(
                    heading="Latihan Mandiri",
                    body_blocks=[
                        ContentBlock(kind="paragraph", content="Kerjakan tiga soal."),
                    ],
                ),
            ],
        ),
    ]


# ===========================================================================
# 1. Context building (pure function)
# ===========================================================================


class TestBuildContext:
    """Exercise ``build_html_context()`` — pure logic, no file I/O."""

    def test_returns_deck_and_slides(self) -> None:
        """Context dict has exactly 'deck' and 'slides' keys."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(),
            slides=_minimal_slides(),
        )
        ctx = build_html_context(blueprint)

        assert set(ctx.keys()) == {"deck", "slides"}
        assert ctx["deck"] is blueprint.deck_meta
        assert ctx["slides"] is blueprint.slides

    def test_deck_meta_flowthrough(self) -> None:
        """All DeckMeta fields are accessible on the context."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(),
            slides=_minimal_slides(),
        )
        ctx = build_html_context(blueprint)

        meta = ctx["deck"]
        assert meta.title == "Handout Pecahan Kelas 5"
        assert meta.subject == "Matematika"
        assert meta.sub_subject == "Pecahan"
        assert meta.language == "id"

    def test_subject_none(self) -> None:
        """Subject and sub_subject can be None."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(subject=None, sub_subject=None),
            slides=_minimal_slides(),
        )
        ctx = build_html_context(blueprint)

        assert ctx["deck"].subject is None
        assert ctx["deck"].sub_subject is None

    def test_slides_have_expected_count_and_types(self) -> None:
        """The slides list in the context has the expected count and types."""
        slides = _minimal_slides()
        blueprint = SlideBlueprint(deck_meta=_default_deck_meta(), slides=slides)
        ctx = build_html_context(blueprint)

        assert len(ctx["slides"]) == 3
        assert all(isinstance(s, Slide) for s in ctx["slides"])
        assert ctx["slides"][0].slide_type == "title"
        assert ctx["slides"][1].slide_type == "content"
        assert ctx["slides"][2].slide_type == "assessment"

    def test_empty_learning_objectives(self) -> None:
        """Empty learning_objectives are forwarded as-is."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(learning_objectives=[]),
            slides=_minimal_slides(),
        )
        ctx = build_html_context(blueprint)

        assert ctx["deck"].learning_objectives == []


# ===========================================================================
# 2. Full rendering (real master template)
# ===========================================================================


class TestRender:
    """Exercise ``HtmlTemplateEngine.render()`` with the real HTML master."""

    def test_render_returns_html_string(self) -> None:
        """Output is a non-empty string starting with '<!DOCTYPE html>'."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(),
            slides=_minimal_slides(),
        )
        html = _make_engine().render(blueprint)

        assert isinstance(html, str)
        assert len(html) > 0
        assert html.lstrip().startswith("<!DOCTYPE html>")

    def test_render_contains_title(self) -> None:
        """Deck title appears in the rendered HTML."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(),
            slides=_minimal_slides(),
        )
        html = _make_engine().render(blueprint)

        assert "Handout Pecahan Kelas 5" in html

    def test_render_contains_one_section_per_slide(self) -> None:
        """Each slide produces one ``<section class=\"slide\">``."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(),
            slides=_minimal_slides(),
        )
        html = _make_engine().render(blueprint)

        assert html.count("<section") == len(blueprint.slides)

    def test_render_contains_content_blocks(self) -> None:
        """Content block text appears in the rendered HTML."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(),
            slides=_minimal_slides(),
        )
        html = _make_engine().render(blueprint)

        assert "Memahami pecahan senilai" in html
        assert "Menyelesaikan latihan dasar" in html
        assert "Latihan Mandiri" in html

    def test_render_self_contained(self) -> None:
        """No external resource references — safe for WebView."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(),
            slides=_minimal_slides(),
        )
        html = _make_engine().render(blueprint)

        assert "http://" not in html
        assert "https://" not in html
        assert 'src="' not in html

    def test_render_contains_design_tokens(self) -> None:
        """PPTX-parity CSS design tokens are present in the rendered HTML."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(),
            slides=_minimal_slides(),
        )
        html = _make_engine().render(blueprint)

        assert "#0B1F33" in html  # ink
        assert "#0F4C5C" in html  # accent
        assert "var(--ink)" in html

    def test_render_auto_escapes_xss(self) -> None:
        """HTML/JS injection payloads are escaped, not executed."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(
                title="<script>alert(1)</script>",
            ),
            slides=[
                Slide(
                    slide_type="content",
                    title="XSS",
                    cards=[
                        Card(
                            body_blocks=[
                                ContentBlock(
                                    kind="paragraph",
                                    content='<img src=x onerror="alert(1)">',
                                ),
                            ],
                        ),
                    ],
                ),
            ],
        )
        html = _make_engine().render(blueprint)

        assert "&lt;script&gt;" in html
        assert "<script>" not in html
        assert "&lt;img" in html
        assert "<img " not in html

    def test_render_subject_in_brand(self) -> None:
        """Subject and sub-subject appear in the brand header."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(subject="IPA", sub_subject="Fisika"),
            slides=_minimal_slides(),
        )
        html = _make_engine().render(blueprint)

        assert "IPA" in html
        assert "Fisika" in html

    def test_render_language_uppercase_in_brand(self) -> None:
        """Language code appears uppercased in the brand header."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(language="en"),
            slides=_minimal_slides(),
        )
        html = _make_engine().render(blueprint)

        assert "EN" in html

    def test_render_slide_footer_contains_deck_title_and_page(self) -> None:
        """Each slide footer shows the deck title and page number."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(),
            slides=_minimal_slides(),
        )
        html = _make_engine().render(blueprint)

        assert "Handout Pecahan Kelas 5" in html
        # Page number format: "1 / 3", "2 / 3", etc.
        assert "/ 3" in html

    def test_render_has_column_hint(self) -> None:
        """Grid column count reflects the slide's columns_hint."""
        slides = _minimal_slides()
        slides[0].columns_hint = 2
        blueprint = SlideBlueprint(deck_meta=_default_deck_meta(), slides=slides)
        html = _make_engine().render(blueprint)

        # The master template uses grid-template-columns: repeat(N, ...)
        assert "repeat(2" in html


# ===========================================================================
# 3. Edge cases
# ===========================================================================


class TestEdgeCases:
    """Edge cases for the HTML template engine."""

    def test_long_content_renders_without_error(self) -> None:
        """Very long content (up to 2000 chars) renders without error."""
        long_text = "X" * 1800
        slides: list[Slide] = [
            Slide(
                slide_type="content",
                title="Panjang",
                cards=[Card(body_blocks=[ContentBlock(kind="paragraph", content=long_text)])],
            ),
        ]
        blueprint = SlideBlueprint(deck_meta=_default_deck_meta(), slides=slides)
        html = _make_engine().render(blueprint)

        assert long_text in html

    def test_unicode_preserved(self) -> None:
        """Unicode characters are preserved in the rendered output."""
        slides: list[Slide] = [
            Slide(
                slide_type="content",
                title="Unicode",
                cards=[
                    Card(
                        body_blocks=[
                            ContentBlock(kind="paragraph", content="Pecahan ⅓ dan ¼ — sains"),
                        ],
                    ),
                ],
            ),
        ]
        blueprint = SlideBlueprint(deck_meta=_default_deck_meta(), slides=slides)
        html = _make_engine().render(blueprint)

        assert "⅓" in html
        assert "¼" in html

    def test_special_chars_escaped(self) -> None:
        """HTML special characters are autoescaped."""
        slides: list[Slide] = [
            Slide(
                slide_type="content",
                title="Spesial",
                cards=[
                    Card(
                        body_blocks=[
                            ContentBlock(
                                kind="paragraph",
                                content='Harga Rp 5.000 < 10% diskon > "MURAH!"',
                            ),
                        ],
                    ),
                ],
            ),
        ]
        blueprint = SlideBlueprint(deck_meta=_default_deck_meta(), slides=slides)
        html = _make_engine().render(blueprint)

        assert "&lt;" in html
        assert "&gt;" in html
        assert "&quot;" in html or "&#34;" in html
        assert "< 10%" not in html  # raw < should not appear

    def test_multiple_content_slides(self) -> None:
        """Multiple content slides each produce their own <section>."""
        slides: list[Slide] = [
            Slide(
                slide_type="content",
                title=f"Slide {i}",
                cards=[
                    Card(body_blocks=[ContentBlock(kind="paragraph", content=f"Konten slide {i}")]),
                ],
            )
            for i in range(5)
        ]
        blueprint = SlideBlueprint(deck_meta=_default_deck_meta(), slides=slides)
        html = _make_engine().render(blueprint)

        assert html.count("<section") == 5
        for i in range(5):
            assert f"Slide {i}" in html

    def test_no_assessment_slide(self) -> None:
        """Blueprint with only content slides still renders correctly."""
        slides: list[Slide] = [
            Slide(
                slide_type="title",
                title="Judul",
                cards=[Card(body_blocks=[ContentBlock(kind="paragraph", content="Pendahuluan.")])],
            ),
            Slide(
                slide_type="content",
                title="Konten",
                cards=[Card(body_blocks=[ContentBlock(kind="bullet", content="Poin A.")])],
            ),
        ]
        blueprint = SlideBlueprint(deck_meta=_default_deck_meta(), slides=slides)
        html = _make_engine().render(blueprint)

        assert "Judul" in html
        assert "Konten" in html
        assert html.count("<section") == 2

    def test_each_block_kind_renders_without_error(self) -> None:
        """Every supported ``ContentBlock.kind`` renders without crashing."""
        for kind in ("paragraph", "bullet", "checklist", "note"):
            slides: list[Slide] = [
                Slide(
                    slide_type="content",
                    title=f"Kind {kind}",
                    cards=[
                        Card(
                            body_blocks=[
                                ContentBlock(kind=kind, content=f"Test konten {kind}."),
                            ],
                        ),
                    ],
                ),
            ]
            blueprint = SlideBlueprint(deck_meta=_default_deck_meta(), slides=slides)
            html = _make_engine().render(blueprint)

            assert f"Test konten {kind}" in html

    def test_render_idempotent(self) -> None:
        """Rendering the same blueprint twice produces identical output."""
        blueprint = SlideBlueprint(
            deck_meta=_default_deck_meta(),
            slides=_minimal_slides(),
        )
        engine = _make_engine()

        html1 = engine.render(blueprint)
        html2 = engine.render(blueprint)

        assert html1 == html2
