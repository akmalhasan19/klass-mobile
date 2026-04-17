import pytest
import json
from app.interpretation import decode_and_validate_interpretation_completion

def test_role_play_repair_as_claude():
    raw_completion = 'As Claude, here is the JSON: {"schema_version": "media_prompt_understanding.v1", "teacher_prompt": "test", "language": "id", "teacher_intent": {"type": "generate_learning_media", "goal": "test", "preferred_delivery_mode": "digital_download", "requires_clarification": false}, "learning_objectives": ["test"], "constraints": {"preferred_output_type": "pdf", "max_duration_minutes": 40, "must_include": ["test"], "avoid": ["test"], "tone": "test"}, "output_type_candidates": [{"type": "pdf", "score": 0.9, "reason": "test"}], "resolved_output_type_reasoning": "test", "document_blueprint": {"title": "test", "summary": "test", "sections": [{"title": "test", "purpose": "test", "bullets": ["test"], "estimated_length": "medium"}]}, "confidence": {"score": 0.9, "label": "high", "rationale": "test"}}'
    
    result = decode_and_validate_interpretation_completion(raw_completion)
    
    assert result["_meta_repairs"]["role_play_break"] is True
    assert "content_integrity" in result
    # It should have a violation for role_play_break
    assert any(v["pattern_name"] == "role_play_break" for v in result["content_integrity"]["violations"])
    # And integrity score should be reduced
    assert result["content_integrity"]["integrity_score"] < 1.0

def test_role_play_repair_as_an_ai():
    raw_completion = 'As an AI assistant, I have prepared the following: {"schema_version": "media_prompt_understanding.v1", "teacher_prompt": "test", "language": "id", "teacher_intent": {"type": "generate_learning_media", "goal": "test", "preferred_delivery_mode": "digital_download", "requires_clarification": false}, "learning_objectives": ["test"], "constraints": {"preferred_output_type": "pdf", "max_duration_minutes": 40, "must_include": ["test"], "avoid": ["test"], "tone": "test"}, "output_type_candidates": [{"type": "pdf", "score": 0.9, "reason": "test"}], "resolved_output_type_reasoning": "test", "document_blueprint": {"title": "test", "summary": "test", "sections": [{"title": "test", "purpose": "test", "bullets": ["test"], "estimated_length": "medium"}]}, "confidence": {"score": 0.9, "label": "high", "rationale": "test"}}'
    
    result = decode_and_validate_interpretation_completion(raw_completion)
    
    assert result["_meta_repairs"]["role_play_break"] is True
    assert "content_integrity" in result
    assert any(v["pattern_name"] == "role_play_break" for v in result["content_integrity"]["violations"])

def test_no_role_play_break():
    raw_completion = '{"schema_version": "media_prompt_understanding.v1", "teacher_prompt": "test", "language": "id", "teacher_intent": {"type": "generate_learning_media", "goal": "test", "preferred_delivery_mode": "digital_download", "requires_clarification": false}, "learning_objectives": ["test"], "constraints": {"preferred_output_type": "pdf", "max_duration_minutes": 40, "must_include": ["test"], "avoid": ["test"], "tone": "test"}, "output_type_candidates": [{"type": "pdf", "score": 0.9, "reason": "test"}], "resolved_output_type_reasoning": "test", "document_blueprint": {"title": "test", "summary": "test", "sections": [{"title": "test", "purpose": "test", "bullets": ["test"], "estimated_length": "medium"}]}, "confidence": {"score": 0.9, "label": "high", "rationale": "test"}}'
    
    result = decode_and_validate_interpretation_completion(raw_completion)
    
    # _meta_repairs might exist due to other repairs but not role_play_break
    if result.get("_meta_repairs"):
        assert result["_meta_repairs"].get("role_play_break") is not True
    assert "content_integrity" in result
    assert all(v["pattern_name"] != "role_play_break" for v in result["content_integrity"]["violations"])
