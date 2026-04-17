import pytest
from app.content_sanitizer import PedagogicalContentSanitizer
from app.document_model import RenderDocument, RenderSection, RenderBlock, RenderActivity

@pytest.fixture
def pattern_config():
    return {
        'procedural_instruction': [
            r'follow these steps',
            r'implement this',
            r'set up the classroom',
            r'ensure (teachers?|students?) have'
        ],
        'conversational_filler': [
            r'here is your material',
            r'i have (generated|created|prepared)',
            r'as an ai'
        ],
        'structural_scaffolding': [
            r'this section is designed to',
            r'in this lesson you will learn',
            r'focus on the following'
        ]
    }

@pytest.fixture
def sanitizer(pattern_config):
    return PedagogicalContentSanitizer(pattern_config)

def test_strip_procedural_markers(sanitizer):
    text = "Follow these steps to teach the lesson. Students will learn algebra."
    clean_text, log = sanitizer._strip_procedural_markers(text)
    assert "Follow these steps" not in clean_text
    assert "Students will learn algebra." in clean_text
    assert len(log) > 0

def test_strip_conversational_wrappers(sanitizer):
    text = "Here is your material for today. Photosynthesis is important."
    clean_text, log = sanitizer._strip_conversational_wrappers(text)
    assert "Here is your material" not in clean_text
    assert "Photosynthesis is important." in clean_text
    assert len(log) > 0

def test_strip_scaffolding_prose(sanitizer):
    text = "This section is designed to teach quadratic equations. Use the formula."
    clean_text, log = sanitizer._strip_scaffolding_prose(text)
    assert "This section is designed to" not in clean_text
    assert "Use the formula." in clean_text
    assert len(log) > 0

def test_mathematical_notation_preservation(sanitizer):
    text = "To solve x² + 2x + 1 = 0, use the quadratic formula: x = (-b ± √(b²-4ac)) / 2a"
    clean_text, log = sanitizer._strip_procedural_markers(text)
    assert clean_text == text
    assert len(log) == 0

def test_sanitize_render_document(sanitizer):
    doc = RenderDocument(
        title="Test Doc",
        export_format="docx",
        language="id",
        summary="Summary here.",
        tone="academic",
        audience_level="middle_school",
        visual_density="medium",
        format_preferences=["pdf"],
        learning_objectives=["Obj 1"],
        sections=[
            RenderSection(
                title="S1",
                purpose="This section is designed to teach.",
                emphasis="medium",
                blocks=[
                    RenderBlock(kind="paragraph", content="Follow these steps: 1. Do something. Content here.")
                ]
            )
        ],
        assets=[],
        activity_blocks=[
            RenderActivity(title="A1", activity_type="quiz", instructions="As an AI, I suggest doing this.")
        ],
        teacher_delivery_summary="I have generated this for you."
    )
    
    clean_doc, log = sanitizer.sanitize_render_document(doc)
    
    # Check Section Purpose
    assert "This section is designed to" not in clean_doc.sections[0].purpose
    
    # Check Section Block
    assert "Follow these steps" not in clean_doc.sections[0].blocks[0].content
    assert "Content here." in clean_doc.sections[0].blocks[0].content
    
    # Check Activity
    assert "As an AI" not in clean_doc.activity_blocks[0].instructions
    
    # Check Teacher Summary
    assert "I have generated" not in clean_doc.teacher_delivery_summary
    
    assert len(log) >= 4

def test_pptx_speaker_notes_lighter_sanitization(sanitizer):
    # Currently _strip_scaffolding_prose is NOT called for speaker notes in sanitize_body_blocks implementation
    # Let's verify this behavior
    blocks = [
        RenderBlock(kind="speaker_notes", content="This section is designed to explain why this is important.")
    ]
    clean_blocks, log = sanitizer.sanitize_body_blocks(blocks, export_format="pptx")
    
    # Should NOT remove scaffolding prose from speaker notes based on current implementation
    assert "This section is designed to" in clean_blocks[0].content
    assert len(log) == 0
