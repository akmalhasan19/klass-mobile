import re
from typing import Dict, Any, List

class ContentIntegrityClassifier:
    def __init__(self):
        # Category A: Procedural Meta-Instructions
        self.procedural_pattern = re.compile(
            r"(follow these steps|implement this|set up|ensure (?:teachers?|students?|that|you) have|prepare (?:the|students|a))", 
            re.IGNORECASE
        )
        # Category B: Conversational Filler
        self.conversational_pattern = re.compile(
            r"(here is your|i have (?:generated|created|prepared)|i\'ve|as (?:an ai|a language model|claude|chatgpt)|according to my analysis)", 
            re.IGNORECASE
        )
        # Category C: Structural Scaffolding Prose
        self.scaffolding_pattern = re.compile(
            r"(this (?:section|lesson|activity) (?:is designed to|aims to|will|focuses on)|focus on the following|be sure to|the purpose of this)", 
            re.IGNORECASE
        )
        
    def _extract_text_fields(self, data: Any) -> List[str]:
        texts = []
        if isinstance(data, dict):
            for k, v in data.items():
                texts.extend(self._extract_text_fields(v))
        elif isinstance(data, list):
            for item in data:
                texts.extend(self._extract_text_fields(item))
        elif isinstance(data, str):
            texts.append(data)
        return texts

    def classify_payload(self, payload: dict, output_type: str) -> dict:
        violations = []
        text_fields = self._extract_text_fields(payload)
        
        for text in text_fields:
            if not isinstance(text, str):
                continue
                
            # Check Category A
            for match in self.procedural_pattern.finditer(text):
                violations.append({
                    "pattern_name": "procedural_instruction",
                    "matched_text": match.group(0),
                })
                
            # Check Category B
            for match in self.conversational_pattern.finditer(text):
                violations.append({
                    "pattern_name": "conversational_filler",
                    "matched_text": match.group(0),
                })
                
            # Check Category C
            for match in self.scaffolding_pattern.finditer(text):
                violations.append({
                    "pattern_name": "structural_scaffolding",
                    "matched_text": match.group(0),
                })
        
        # Calculate integrity score
        # Base score 1.0. Deduct 0.1 for each category of violation, bounded to 0.0.
        integrity_score = 1.0
        if any(v["pattern_name"] == "procedural_instruction" for v in violations):
            integrity_score -= 0.1
        if any(v["pattern_name"] == "conversational_filler" for v in violations):
            integrity_score -= 0.1
        if any(v["pattern_name"] == "structural_scaffolding" for v in violations):
            integrity_score -= 0.1
            
        # Additional deduction for sheer volume of violations
        if len(violations) > 0:
            integrity_score -= 0.05 * min(10, len(violations))
        
        integrity_score = max(0.0, min(1.0, round(integrity_score, 4)))
        
        # "Low violations + no role-play breaks = high score (0.85-1.0)"
        # Note: role-play breaks are handled/flagged during interpretation parsing but those patterns overlap with conversational_filler.
        if "role_play_break" in payload.get("_meta_repairs", {}):
            integrity_score -= 0.2
            integrity_score = max(0.0, round(integrity_score, 4))
            violations.append({
                "pattern_name": "role_play_break",
                "matched_text": "Role play break detected and pre-emptively repaired."
            })

        return {
            "integrity_score": integrity_score,
            "violations": violations,
            "classification_source": "adapter",
            "metadata": {
                "total_text_nodes_checked": len(text_fields),
                "output_type_context": output_type
            }
        }
