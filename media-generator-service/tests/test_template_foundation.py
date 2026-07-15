"""Foundation tests for FASE 0 (Fondasi & Desain Template).

These tests lock in the Fase 0 gate — *all master templates + Jinja2
infrastructure ready* — independently of the later engine migrations:

* The ``TemplateRegistry`` discovers the PPTX ``.pptx`` + manifest **and** the
  HTML ``.html`` + DOCX ``.docx`` masters keyed by the same ``template_id``.
* The Jinja2 environment renders the HTML master self-contained from a
  ``SlideBlueprint`` context (no external resources).
* The additive ``DeckMeta.subject`` / ``sub_subject`` fields flow from the
  ``GenerationSpec.content_context`` through to the blueprint without breaking
  the frozen ``media_generation_spec.v1`` contract.

They intentionally do not exercise the Fase 1 (DOCX) or Fase 2 (PDF) engines —
those are separate phases with their own gates.
"""
from __future__ import annotations

from pathlib import Path

import pytest

from app.document_model import build_render_document
from app.engines.blueprint import DeckMeta
from app.engines.blueprint_builder import build_slide_blueprint
from app.templates.jinja_env import (
    MASTERS_DIR,
    get_jinja_environment,
    render_master_html,
    validate_html_master,
)
from app.templates.registry import TemplateRegistry
from tests.helpers import sample_request

_TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "app" / "templates"
_TEMPLATE_ID = "klass-educational-v1"


# ---------------------------------------------------------------------------
# 1. Registry discovers all three format masters under one template_id
# ---------------------------------------------------------------------------

def _load_registry() -> TemplateRegistry:
    registry = TemplateRegistry()
    registry.load_templates(_TEMPLATES_DIR)
    return registry


def test_registry_discovers_html_and_docx_masters() -> None:
    registry = _load_registry()
    entry = registry.get(_TEMPLATE_ID)

    assert entry.manifest is not None
    assert entry.master_path.name == f"{_TEMPLATE_ID}.pptx"
    assert entry.html_master_path is not None
    assert entry.html_master_path.name == f"{_TEMPLATE_ID}.html"
    assert entry.docx_master_path is not None
    assert entry.docx_master_path.name == f"{_TEMPLATE_ID}.docx"


def test_registry_html_and_docx_accessors() -> None:
    registry = _load_registry()

    html_path = registry.get_html_master(_TEMPLATE_ID)
    docx_path = registry.get_docx_master(_TEMPLATE_ID)

    assert html_path.is_file()
    assert docx_path.is_file()
    assert html_path == registry.get(_TEMPLATE_ID).html_master_path


def test_registry_html_accessor_raises_for_unknown_template() -> None:
    registry = _load_registry()
    with pytest.raises(KeyError):
        registry.get_html_master("does-not-exist")


# ---------------------------------------------------------------------------
# 2. Jinja2 environment + HTML master rendering
# ---------------------------------------------------------------------------

def test_jinja_environment_is_cached_and_rooted_at_masters() -> None:
    env = get_jinja_environment()
    assert get_jinja_environment() is env  # lru_cached singleton
    assert MASTERS_DIR.is_dir()


def test_validate_html_master_fails_fast_on_missing() -> None:
    # A clearly absent master must raise loudly rather than render garbage.
    with pytest.raises(Exception):
        validate_html_master("nonexistent-template.html")


def test_html_master_renders_self_contained_from_blueprint() -> None:
    blueprint = build_slide_blueprint(
        build_render_document(sample_request("pdf").generation_spec)
    )
    html = render_master_html(
        "klass-educational-v1.html",
        {"deck": blueprint.deck_meta, "slides": blueprint.slides},
    )

    # One <section> per slide, and the deck title appears.
    assert html.count("<section") == len(blueprint.slides)
    assert blueprint.deck_meta.title in html

    # Design tokens parity with the PPTX master.
    assert "#0B1F33" in html
    assert "#0F4C5C" in html

    # Self-contained: no external resource references.
    assert "http://" not in html
    assert "https://" not in html
    assert 'src="' not in html


def test_html_master_escapes_user_content() -> None:
    # XSS-style payload in a card must be escaped (autoescape is on).
    from app.engines.blueprint import Card, ContentBlock, Slide, SlideBlueprint

    malicious = SlideBlueprint(
        deck_meta=DeckMeta(
            title="<script>alert(1)</script>",
            summary="s", language="id", audience_level="a", tone="t",
        ),
        slides=[
            Slide(
                slide_type="content",
                title="X",
                cards=[Card(body_blocks=[ContentBlock(kind="paragraph",
                                                       content="<img src=x onerror=alert(1)>")])],
            )
        ],
    )
    html = render_master_html(
        "klass-educational-v1.html",
        {"deck": malicious.deck_meta, "slides": malicious.slides},
    )
    # The malicious text is escaped into inert text, never live markup.
    assert "&lt;script&gt;" in html
    assert "<script>" not in html
    assert "&lt;img" in html
    assert "<img " not in html


# ---------------------------------------------------------------------------
# 3. Additive blueprint fields (DeckMeta.subject / sub_subject)
# ---------------------------------------------------------------------------

def test_blueprint_carries_subject_from_content_context() -> None:
    blueprint = build_slide_blueprint(
        build_render_document(sample_request("pdf").generation_spec)
    )
    # sample_request wires subject_context.subject_name = "Matematika".
    assert blueprint.deck_meta.subject == "Matematika"
    assert blueprint.deck_meta.sub_subject == "Pecahan"


def test_blueprint_subject_is_optional_and_backward_compatible() -> None:
    # A spec without content_context subject info must not break the contract.
    payload = sample_request("docx")
    payload.generation_spec.content_context = None  # type: ignore[assignment]
    blueprint = build_slide_blueprint(build_render_document(payload.generation_spec))

    assert blueprint.deck_meta.subject is None
    assert blueprint.deck_meta.sub_subject is None
    # Existing fields untouched.
    assert blueprint.deck_meta.title == payload.generation_spec.title
    assert len(blueprint.slides) >= 1


def test_deck_meta_accepts_subject_as_keyword_without_contract_break() -> None:
    meta = DeckMeta(
        title="t", summary="s", language="id",
        audience_level="a", tone="n",
        subject="IPS", sub_subject="Sejarah",
    )
    assert meta.subject == "IPS"
    assert meta.sub_subject == "Sejarah"
    # Still serialises/validates as the same StrictModel family.
    assert DeckMeta.model_validate(meta.model_dump()) == meta
