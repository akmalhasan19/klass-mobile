import pytest
from app.content_integrity_classifier import ContentIntegrityClassifier

@pytest.fixture
def classifier():
    return ContentIntegrityClassifier()

def test_clean_pedagogical_content(classifier):
    payload = {
        "title": "Introduction to Algebra",
        "content": "Algebra is a branch of mathematics dealing with symbols and the rules for manipulating those symbols.",
        "example": "For instance, x + 2 = 5."
    }
    result = classifier.classify_payload(payload, "pdf")
    # Clean pedagogical content (no violations) → integrity_score ≥ 0.90
    assert result["integrity_score"] >= 0.95
    assert len(result["violations"]) == 0
    assert result["classification_source"] == "adapter"

def test_score_assignment_one_minor_violation(classifier):
    # 1 minor violation (e.g., one scaffolding phrase) → 0.70-0.85
    # Base 1.0 - 0.1 (category) - 0.05 (one violation) = 0.85
    payload = {
        "content": "This section is designed to introduce the topic."
    }
    result = classifier.classify_payload(payload, "pdf")
    assert 0.70 <= result["integrity_score"] <= 0.85
    assert len(result["violations"]) == 1
    assert result["violations"][0]["pattern_name"] == "structural_scaffolding"

def test_score_assignment_multiple_violations(classifier):
    # 2+ violations → <0.70
    # Base 1.0 - 0.1 (Cat A) - 0.1 (Cat B) - 0.1 (Cat C) - (3 * 0.05) = 0.55
    payload = {
        "introduction": "Here is your material.",
        "body": "Follow these steps to teach the class.",
        "conclusion": "This section is designed to wrap up."
    }
    result = classifier.classify_payload(payload, "pdf")
    assert result["integrity_score"] < 0.70
    assert len(result["violations"]) == 3

def test_violation_detection_procedural(classifier):
    payload = {"content": "Follow these steps to teach the lesson."}
    result = classifier.classify_payload(payload, "pdf")
    assert any(v["pattern_name"] == "procedural_instruction" for v in result["violations"])

def test_violation_detection_conversational(classifier):
    payload = {"content": "Here is your material. I have generated a complete lesson plan."}
    result = classifier.classify_payload(payload, "pdf")
    assert any(v["pattern_name"] == "conversational_filler" for v in result["violations"])

def test_violation_detection_scaffolding(classifier):
    payload = {"content": "This section is designed to introduce the topic."}
    result = classifier.classify_payload(payload, "pdf")
    assert any(v["pattern_name"] == "structural_scaffolding" for v in result["violations"])

def test_role_play_detection_meta(classifier):
    # The classifier reacts to the meta flag set by the interpretation layer
    payload = {
        "content": "Valid pedagogical content.",
        "_meta_repairs": {
            "role_play_break": True
        }
    }
    result = classifier.classify_payload(payload, "pdf")
    assert result["integrity_score"] <= 0.8
    assert any(v["pattern_name"] == "role_play_break" for v in result["violations"])

def test_complex_payload_extraction(classifier):
    # Test that it finds violations deep in nested structures
    payload = {
        "document": {
            "sections": [
                {"title": "Intro", "text": "Clean text"},
                {"title": "Body", "blocks": [
                    {"type": "text", "content": "Follow these steps to teach."}
                ]}
            ]
        }
    }
    result = classifier.classify_payload(payload, "pdf")
    assert any(v["pattern_name"] == "procedural_instruction" for v in result["violations"])
