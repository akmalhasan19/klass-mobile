"""Unit tests for Phase 1 of the Hybrid AI PPT Generation Engine.

Phase 1 delivers the universal schema layer consumed by every downstream
pipeline (Marp preview, Template Injector, Canvas Calculator):

* ``app.engines.blueprint``  — ``SlideBlueprint`` / ``Slide`` / ``Card`` models
* ``app.engines.blueprint_builder`` — ``RenderDocument`` → ``SlideBlueprint``
* ``app.engines.pptx_injector.manifest`` — ``TemplateManifest`` schema + loader

These tests follow the same conventions as the rest of the suite: plain
``pytest`` functions, ``pydantic`` validation assertions, and reuse of
``tests.helpers.sample_request`` so the builder is exercised against the real
``media_generation_spec.v1`` contract (backward-compatibility gate).
"""
from __future__ import annotations

from pathlib import Path

import pytest
from pydantic import ValidationError

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
from app.engines.pptx_injector.manifest import (
    Capacity,
    LayoutManifest,
    PlaceholderSpec,
    TemplateManifest,
    load_manifest,
)
from tests.helpers import sample_request


# ---------------------------------------------------------------------------
# Fixtures / shared builders
# ---------------------------------------------------------------------------

def _minimal_card() -> Card:
    return Card(body_blocks=[ContentBlock(kind="paragraph", content="x")])


def _minimal_slide(slide_type: SlideType) -> Slide:
    return Slide(
        slide_type=slide_type,
        title="Judul",
        cards=[_minimal_card()],
    )


# ---------------------------------------------------------------------------
# 1. Builder round-trip from sample_request("pptx")
# ---------------------------------------------------------------------------

def test_builder_round_trip_from_pptx_sample_request() -> None:
    request_payload = sample_request("pptx")
    render_document = build_render_document(request_payload.generation_spec)

    blueprint = build_slide_blueprint(render_document)

    assert isinstance(blueprint, SlideBlueprint)
    assert blueprint.theme_id == "klass-educational-v1"
    assert blueprint.deck_meta.title == "Handout Pecahan Kelas 5"
    assert blueprint.deck_meta.summary == render_document.summary
    assert blueprint.deck_meta.language == "id"
    assert blueprint.deck_meta.audience_level == "elementary"
    assert blueprint.deck_meta.tone == "encouraging"
    assert blueprint.deck_meta.learning_objectives == [
        "Siswa mengenali pecahan senilai.",
        "Siswa mencoba latihan pecahan dasar.",
    ]


def test_builder_emits_expected_slide_sequence() -> None:
    request_payload = sample_request("pptx")
    render_document = build_render_document(request_payload.generation_spec)

    blueprint = build_slide_blueprint(render_document)

    # 1 title + 2 content (one per section) + 1 assessment (activity block).
    assert len(blueprint.slides) == 4
    assert [s.slide_type for s in blueprint.slides] == [
        "title",
        "content",
        "content",
        "assessment",
    ]


def test_builder_maps_learning_objectives_to_title_cards() -> None:
    render_document = build_render_document(sample_request("pptx").generation_spec)
    blueprint = build_slide_blueprint(render_document)

    title_slide = blueprint.slides[0]
    card = title_slide.cards[0]
    bullet_texts = [b.content for b in card.body_blocks if b.kind == "bullet"]

    assert title_slide.subtitle == render_document.summary
    assert "Siswa mengenali pecahan senilai." in bullet_texts
    assert "Siswa mencoba latihan pecahan dasar." in bullet_texts


def test_builder_maps_sections_to_content_cards() -> None:
    render_document = build_render_document(sample_request("pptx").generation_spec)
    blueprint = build_slide_blueprint(render_document)

    content_slides = [s for s in blueprint.slides if s.slide_type == "content"]
    content_titles = {s.title for s in content_slides}

    assert "Tujuan Belajar" in content_titles
    assert "Contoh dan Latihan" in content_titles
    # Each section's body blocks become ContentBlock models on a single card.
    for slide in content_slides:
        assert len(slide.cards) == 1
        for block in slide.cards[0].body_blocks:
            assert isinstance(block, ContentBlock)


def test_builder_maps_activity_blocks_to_assessment_slide() -> None:
    render_document = build_render_document(sample_request("pptx").generation_spec)
    blueprint = build_slide_blueprint(render_document)

    assessment = blueprint.slides[-1]
    assert assessment.slide_type == "assessment"
    assert assessment.title == "Aktivitas dan Penilaian"
    assert assessment.cards[0].heading == "Latihan Mandiri"
    assert "Kerjakan tiga soal pecahan senilai" in assessment.cards[0].body_blocks[0].content


def test_builder_omits_assessment_when_no_activity_blocks() -> None:
    payload = sample_request("pptx")
    payload.generation_spec.assessment_or_activity_blocks = []
    render_document = build_render_document(payload.generation_spec)

    blueprint = build_slide_blueprint(render_document)

    assert all(s.slide_type != "assessment" for s in blueprint.slides)
    # 1 title + 2 content, no assessment.
    assert len(blueprint.slides) == 3


# ---------------------------------------------------------------------------
# 2. Blueprint is a stable JSON single-source-of-truth
# ---------------------------------------------------------------------------

def test_blueprint_json_round_trip_is_stable() -> None:
    render_document = build_render_document(sample_request("pptx").generation_spec)
    blueprint = build_slide_blueprint(render_document)

    restored = SlideBlueprint.model_validate_json(blueprint.model_dump_json())

    assert restored == blueprint
    assert restored.model_dump() == blueprint.model_dump()


def test_blueprint_rejects_unknown_fields() -> None:
    with pytest.raises(ValidationError):
        SlideBlueprint(
            deck_meta=DeckMeta(
                title="t", summary="s", language="id",
                audience_level="a", tone="n",
            ),
            slides=[_minimal_slide("title")],
            # pyrefly: ignore [unexpected-keyword]
            unknown_field="should be forbidden",
        )


# ---------------------------------------------------------------------------
# 3. Manifest validation (extra="forbid") + loader
# ---------------------------------------------------------------------------

def _sample_manifest_dict() -> dict:
    return {
        "template_id": "klass-educational-v1",
        "version": "1.0.0",
        "slide_layouts": [
            {
                "layout_id": "title",
                "slide_type": "title",
                "slide_index": 0,
                "placeholders": [
                    {"placeholder_id": "title", "shape_name": "Title 1", "kind": "text"},
                    {"placeholder_id": "subtitle", "shape_name": "Subtitle 2", "kind": "text"},
                ],
            },
            {
                "layout_id": "content",
                "slide_type": "content",
                "slide_index": 1,
                "placeholders": [
                    {"placeholder_id": "title", "shape_name": "Title 1", "kind": "text"},
                    {
                        "placeholder_id": "body",
                        "shape_name": "Content Placeholder 3",
                        "kind": "text",
                        "capacity": {"max_cards": 4, "max_chars": 500},
                    },
                ],
            },
            {
                "layout_id": "assessment",
                "slide_type": "assessment",
                "slide_index": 2,
                "placeholders": [
                    {"placeholder_id": "title", "shape_name": "Title 1", "kind": "text"},
                    {"placeholder_id": "body", "shape_name": "Content Placeholder 3", "kind": "text"},
                ],
            },
        ],
    }


def test_manifest_validates_from_dict() -> None:
    manifest = TemplateManifest.model_validate(_sample_manifest_dict())

    assert manifest.template_id == "klass-educational-v1"
    assert len(manifest.slide_layouts) == 3


def test_manifest_rejects_unknown_fields() -> None:
    data = _sample_manifest_dict()
    data["extra_root_field"] = "forbidden"

    with pytest.raises(ValidationError):
        TemplateManifest.model_validate(data)


def test_manifest_placeholder_rejects_unknown_fields() -> None:
    data = _sample_manifest_dict()
    data["slide_layouts"][0]["placeholders"][0]["unknown"] = "forbidden"

    with pytest.raises(ValidationError):
        TemplateManifest.model_validate(data)


def test_manifest_capacity_rejects_zero_and_negative() -> None:
    data = _sample_manifest_dict()
    data["slide_layouts"][1]["placeholders"][1]["capacity"] = {"max_cards": 0}

    with pytest.raises(ValidationError):
        TemplateManifest.model_validate(data)


def test_load_manifest_reads_real_json_file(tmp_path: Path) -> None:
    manifest_file = tmp_path / "klass-educational-v1.json"
    manifest_file.write_text(
        __import__("json").dumps(_sample_manifest_dict()),
        encoding="utf-8",
    )

    manifest = load_manifest(manifest_file)

    assert isinstance(manifest, TemplateManifest)
    assert manifest.template_id == "klass-educational-v1"


def test_load_manifest_missing_file_raises() -> None:
    with pytest.raises(FileNotFoundError):
        load_manifest(Path("/nonexistent/manifest.json"))


# ---------------------------------------------------------------------------
# 4. All slide_type values are covered by the schema
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("slide_type", ["title", "section", "content", "assessment"])
def test_every_slide_type_validates(slide_type: SlideType) -> None:
    slide = _minimal_slide(slide_type)
    assert slide.slide_type == slide_type


def test_builder_and_manifest_use_shared_slide_type_literal() -> None:
    # The manifest's pick_layout discriminator must accept exactly the same
    # set of slide types the blueprint can produce.
    manifest = TemplateManifest.model_validate(_sample_manifest_dict())
    covered: set[str] = {layout.slide_type for layout in manifest.slide_layouts}

    for slide_type in ["title", "content", "assessment"]:
        assert slide_type in covered
        assert manifest.pick_layout(slide_type) is not None


def test_manifest_pick_layout_returns_none_for_undefined_type() -> None:
    manifest = TemplateManifest.model_validate(_sample_manifest_dict())
    # "section" is a valid SlideType but no layout defines it in this manifest.
    assert manifest.pick_layout("section") is None


def test_manifest_placeholder_lookup() -> None:
    manifest = TemplateManifest.model_validate(_sample_manifest_dict())
    content_layout = manifest.pick_layout("content")

    assert content_layout is not None
    assert content_layout.placeholder("title") is not None
    assert content_layout.placeholder("body") is not None
    body = content_layout.placeholder("body")
    assert body is not None and body.capacity is not None
    assert body.capacity.max_cards == 4
    assert body.capacity.max_chars == 500
    assert content_layout.placeholder("missing") is None


# ---------------------------------------------------------------------------
# 5. Backward-compatibility gate: builder keeps working on v1 spec shape
# ---------------------------------------------------------------------------

def test_builder_accepts_v1_spec_for_all_export_formats() -> None:
    # The blueprint layer is built from RenderDocument, which itself comes
    # from the frozen v1 GenerationSpec. It must not depend on export_format.
    for export_format in ("pptx", "pdf", "docx"):
        request_payload = sample_request(export_format)
        render_document = build_render_document(request_payload.generation_spec)
        blueprint = build_slide_blueprint(render_document)

        assert blueprint.deck_meta.title == request_payload.generation_spec.title
        assert len(blueprint.slides) >= 1
        assert blueprint.slides[0].slide_type == "title"
