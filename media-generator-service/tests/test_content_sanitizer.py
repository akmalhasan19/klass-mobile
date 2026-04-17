import pytest
from app.content_sanitizer import PedagogicalContentSanitizer
from app.document_model import RenderBlock

@pytest.fixture
def patterns():
    return {
        "procedural_instruction": [
            r"follow these steps:?",
            r"implement this"
        ],
        "conversational_filler": [
            r"here is your material for today's lesson\.?",
            r"according to my analysis\.?"
        ],
        "structural_scaffolding": [
            r"this section is designed to teach quadratic equations\.?",
            r"the purpose of this\.?"
        ]
    }

def test_procedural_pattern_stripping(patterns):
    sanitizer = PedagogicalContentSanitizer(patterns)
    input_text = "Follow these steps: 1. start the lesson..."
    text, log = sanitizer._strip_procedural_markers(input_text)
    assert "1. start the lesson" in text
    assert "Follow these steps:" not in text

def test_conversational_filler_removal(patterns):
    sanitizer = PedagogicalContentSanitizer(patterns)
    input_text = "Here is your material for today's lesson. Students will..."
    text, log = sanitizer._strip_conversational_wrappers(input_text)
    assert "Students will..." in text
    assert "Here is your material" not in text

def test_structural_scaffolding_removal(patterns):
    sanitizer = PedagogicalContentSanitizer(patterns)
    input_text = "This section is designed to teach quadratic equations. Students will learn..."
    text, log = sanitizer._strip_scaffolding_prose(input_text)
    assert "Students will learn..." in text
    assert "This section is designed" not in text

def test_mathematical_notation_preservation(patterns):
    sanitizer = PedagogicalContentSanitizer(patterns)
    input_text = "To solve x² + 2x + 1 = 0, use the quadratic formula: x = (-b ± √(b²-4ac)) / 2a"
    text, log = sanitizer._strip_procedural_markers(input_text)
    assert text == input_text

def test_format_specific_rules(patterns):
    sanitizer = PedagogicalContentSanitizer(patterns)
    
    # DOCX format HTML preservation
    input_html = "<b>Follow these steps:</b> Read carefully."
    clean_blocks, _ = sanitizer.sanitize_body_blocks([RenderBlock(kind="text", content=input_html)], export_format="docx")
    assert "<b></b> Read carefully." == clean_blocks[0].content or "<b></b>" in clean_blocks[0].content

    # PPTX format speaker notes
    blocks = [
        RenderBlock(kind="speaker_notes", content="Follow these steps: Ensure students understand."),
        RenderBlock(kind="text", content="Follow these steps: Activity 1.")
    ]
    clean_blocks, _ = sanitizer.sanitize_body_blocks(blocks, export_format="pptx")
    assert "Ensure students understand" in clean_blocks[0].content
    assert "Follow these steps" not in clean_blocks[0].content
    assert "Activity 1" in clean_blocks[1].content
    assert "Follow these steps" not in clean_blocks[1].content
