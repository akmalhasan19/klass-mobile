import re
from app.document_model import RenderDocument, RenderSection, RenderActivity, RenderBlock

class PedagogicalContentSanitizer:
    def __init__(self, pattern_config: dict):
        self.patterns = pattern_config

    def sanitize_render_document(self, doc: RenderDocument) -> tuple[RenderDocument, list[str]]:
        sanitization_log = []
        
        clean_sections = []
        for sec in doc.sections:
            clean_blocks, log1 = self.sanitize_body_blocks(sec.blocks, doc.export_format)
            sanitization_log.extend(log1)
            
            clean_purpose, log2 = self._strip_scaffolding_prose(sec.purpose)
            sanitization_log.extend(log2)
            
            clean_sections.append(RenderSection(
                title=sec.title,
                purpose=clean_purpose,
                emphasis=sec.emphasis,
                blocks=clean_blocks
            ))
            
        clean_activities = []
        for act in doc.activity_blocks:
            clean_instructions, log3 = self.sanitize_assessment_instructions(act.instructions)
            sanitization_log.extend(log3)
            clean_activities.append(RenderActivity(
                title=act.title,
                activity_type=act.activity_type,
                instructions=clean_instructions
            ))
            
        clean_teacher_summary, log4 = self.sanitize_teacher_delivery_summary(doc.teacher_delivery_summary)
        sanitization_log.extend(log4)

        clean_doc = RenderDocument(
            title=doc.title,
            export_format=doc.export_format,
            language=doc.language,
            summary=doc.summary,
            tone=doc.tone,
            audience_level=doc.audience_level,
            visual_density=doc.visual_density,
            format_preferences=doc.format_preferences,
            learning_objectives=doc.learning_objectives,
            sections=clean_sections,
            assets=doc.assets,
            activity_blocks=clean_activities,
            teacher_delivery_summary=clean_teacher_summary
        )

        return clean_doc, sanitization_log

    def sanitize_body_blocks(self, blocks: list[RenderBlock], export_format: str = "docx") -> tuple[list[RenderBlock], list[str]]:
        clean_blocks = []
        log = []
        for b in blocks:
            text = b.content
            
            if export_format in ["pptx", "ppt"] and b.kind == "speaker_notes":
                text, log1 = self._strip_procedural_markers(text)
                text, log2 = self._strip_conversational_wrappers(text)
                # Intentionally lighter scaffolding prose stripping for speaker notes
                log.extend(log1)
                log.extend(log2)
            else:
                text, log1 = self._strip_procedural_markers(text)
                text, log2 = self._strip_conversational_wrappers(text)
                log.extend(log1)
                log.extend(log2)
                
            text = self._restore_mathematical_formatting(text)
            log.extend(log1)
            log.extend(log2)
            clean_blocks.append(RenderBlock(kind=b.kind, content=text))
        return clean_blocks, log

    def sanitize_teacher_delivery_summary(self, summary: str) -> tuple[str, list[str]]:
        text, log1 = self._strip_procedural_markers(summary)
        text, log2 = self._strip_conversational_wrappers(text)
        return text, log1 + log2

    def sanitize_assessment_instructions(self, instructions: str) -> tuple[str, list[str]]:
        text, log1 = self._strip_procedural_markers(instructions)
        text, log2 = self._strip_conversational_wrappers(text)
        return text, log1 + log2

    def _strip_procedural_markers(self, text: str) -> tuple[str, list[str]]:
        log = []
        proc_patterns = self.patterns.get('procedural_instruction', [])
        for p in proc_patterns:
            if re.search(p, text, re.IGNORECASE):
                log.append(f"Removed procedural marker: {p}")
                text = re.sub(p, '', text, flags=re.IGNORECASE).strip()
        return text, log

    def _strip_conversational_wrappers(self, text: str) -> tuple[str, list[str]]:
        log = []
        conv_patterns = self.patterns.get('conversational_filler', [])
        for p in conv_patterns:
            if re.search(p, text, re.IGNORECASE):
                log.append(f"Removed conversational filler: {p}")
                text = re.sub(p, '', text, flags=re.IGNORECASE).strip()
        return text, log

    def _strip_scaffolding_prose(self, text: str) -> tuple[str, list[str]]:
        log = []
        scaff_patterns = self.patterns.get('structural_scaffolding', [])
        for p in scaff_patterns:
            if re.search(p, text, re.IGNORECASE):
                log.append(f"Removed scaffolding prose: {p}")
                text = re.sub(p, '', text, flags=re.IGNORECASE).strip()
        return text, log

    def _restore_mathematical_formatting(self, text: str) -> str:
        # Simplistic stub for maintaining LaTeX syntax untouched
        return text
