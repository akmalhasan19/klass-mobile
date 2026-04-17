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
    assert result["integrity_score"] >= 0.95
    assert len(result["violations"]) == 0
    assert result["classification_source"] == "adapter"

def test_score_reduction_procedural(classifier):
    payload = {
        "content": "Follow these steps to teach the lesson."
    }
    result = classifier.classify_payload(payload, "pdf")
    assert result["integrity_score"] < 0.95
    assert any(v["pattern_name"] == "procedural_instruction" for v in result["violations"])

def test_score_reduction_conversational_filler(classifier):
    payload = {
        "content": "Here is your material. I have generated a complete lesson plan."
    }
    result = classifier.classify_payload(payload, "pdf")
    assert result["integrity_score"] < 0.95
    assert any(v["pattern_name"] == "conversational_filler" for v in result["violations"])

def test_score_reduction_structural_scaffolding(classifier):
    payload = {
        "content": "This section is designed to introduce the topic."
    }
    result = classifier.classify_payload(payload, "pdf")
    assert result["integrity_score"] < 0.95
    assert any(v["pattern_name"] == "structural_scaffolding" for v in result["violations"])

def test_multiple_violations(classifier):
    payload = {
        "introduction": "Here is your material.",
        "body": "Follow these steps to teach the class.",
        "conclusion": "This section is designed to wrap up."
    }
    result = classifier.classify_payload(payload, "pdf")
    assert result["integrity_score"] < 0.8
    assert len(result["violations"]) == 3
    pattern_names = [v["pattern_name"] for v in result["violations"]]
    assert "procedural_instruction" in pattern_names
    assert "conversational_filler" in pattern_names
    assert "structural_scaffolding" in pattern_names

def test_role_play_break_meta(classifier):
    payload = {
        "content": "Valid pedagogical content.",
        "_meta_repairs": {
            "role_play_break": True
        }
    }
    result = classifier.classify_payload(payload, "pdf")
    assert result["integrity_score"] <= 0.8
    assert len(result["violations"]) > 0
    assert any(v["pattern_name"] == "role_play_break" for v in result["violations"])
