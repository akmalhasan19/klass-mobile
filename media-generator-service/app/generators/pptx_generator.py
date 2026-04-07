from __future__ import annotations

from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_AUTO_SHAPE_TYPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Inches, Pt

from app.contracts import MIME_TYPES
from app.document_model import RenderDocument, localized_label
from app.generators.base import BaseGenerator, RenderSummary


class PptxGenerator(BaseGenerator):
    export_format = "pptx"
    mime_type = MIME_TYPES["pptx"]

    def render(self, render_document: RenderDocument, output_path: Path) -> RenderSummary:
        presentation = Presentation()
        presentation.slide_width = Inches(13.333)
        presentation.slide_height = Inches(7.5)

        self._add_title_slide(presentation, render_document)

        for section in render_document.sections:
            self._add_section_slide(presentation, render_document, section.title, section.purpose, [
                self._normalize_block(block.kind, block.content) for block in section.blocks
            ])

        if render_document.activity_blocks:
            activity_lines = [
                f"{block.title}: {block.instructions}"
                for block in render_document.activity_blocks
            ]
            self._add_section_slide(
                presentation,
                render_document,
                localized_label(render_document.language, "activity_blocks"),
                render_document.teacher_delivery_summary,
                activity_lines,
                accent_rgb=RGBColor(56, 88, 152),
            )

        presentation.save(output_path)

        return RenderSummary(slide_count=len(presentation.slides))

    def _add_title_slide(self, presentation: Presentation, render_document: RenderDocument) -> None:
        slide = presentation.slides.add_slide(presentation.slide_layouts[6])
        self._paint_background(slide, RGBColor(236, 244, 247))

        title_box = slide.shapes.add_textbox(Inches(0.75), Inches(0.55), Inches(7.5), Inches(1.25))
        title_frame = title_box.text_frame
        title_frame.word_wrap = True
        title_frame.vertical_anchor = MSO_ANCHOR.MIDDLE
        title_paragraph = title_frame.paragraphs[0]
        title_paragraph.alignment = PP_ALIGN.LEFT
        title_run = title_paragraph.add_run()
        title_run.text = render_document.title
        title_run.font.bold = True
        title_run.font.size = Pt(28)
        title_run.font.color.rgb = RGBColor(11, 31, 51)

        summary_box = slide.shapes.add_textbox(Inches(0.78), Inches(1.8), Inches(7.15), Inches(1.55))
        summary_frame = summary_box.text_frame
        summary_frame.word_wrap = True
        summary_paragraph = summary_frame.paragraphs[0]
        summary_paragraph.alignment = PP_ALIGN.LEFT
        summary_run = summary_paragraph.add_run()
        summary_run.text = render_document.summary
        summary_run.font.size = Pt(16)
        summary_run.font.color.rgb = RGBColor(31, 41, 51)

        context_shape = slide.shapes.add_shape(
            MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE,
            Inches(8.45), Inches(0.7), Inches(4.1), Inches(5.5)
        )
        context_shape.fill.solid()
        context_shape.fill.fore_color.rgb = RGBColor(255, 255, 255)
        context_shape.line.color.rgb = RGBColor(188, 204, 220)

        context_frame = context_shape.text_frame
        context_frame.clear()
        context_frame.word_wrap = True
        context_frame.margin_left = Inches(0.18)
        context_frame.margin_right = Inches(0.18)
        context_frame.margin_top = Inches(0.15)

        heading = context_frame.paragraphs[0]
        heading.alignment = PP_ALIGN.LEFT
        heading_run = heading.add_run()
        heading_run.text = localized_label(render_document.language, "context")
        heading_run.font.bold = True
        heading_run.font.size = Pt(16)
        heading_run.font.color.rgb = RGBColor(15, 76, 92)

        for label, value in render_document.context_rows:
            paragraph = context_frame.add_paragraph()
            paragraph.alignment = PP_ALIGN.LEFT
            label_run = paragraph.add_run()
            label_run.text = f"{label}: "
            label_run.font.bold = True
            label_run.font.size = Pt(11)
            label_run.font.color.rgb = RGBColor(11, 31, 51)
            value_run = paragraph.add_run()
            value_run.text = value
            value_run.font.size = Pt(11)
            value_run.font.color.rgb = RGBColor(31, 41, 51)

        if render_document.assets:
            assets_text = "; ".join(asset.description for asset in render_document.assets[:2])
            ribbon = slide.shapes.add_shape(
                MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE,
                Inches(0.78), Inches(5.85), Inches(7.15), Inches(0.7)
            )
            ribbon.fill.solid()
            ribbon.fill.fore_color.rgb = RGBColor(217, 226, 236)
            ribbon.line.color.rgb = RGBColor(217, 226, 236)
            ribbon_frame = ribbon.text_frame
            ribbon_frame.clear()
            ribbon_frame.word_wrap = True
            ribbon_frame.margin_left = Inches(0.18)
            ribbon_paragraph = ribbon_frame.paragraphs[0]
            ribbon_run = ribbon_paragraph.add_run()
            ribbon_run.text = f"{localized_label(render_document.language, 'assets')}: {assets_text}"
            ribbon_run.font.size = Pt(11)
            ribbon_run.font.color.rgb = RGBColor(11, 31, 51)

    def _add_section_slide(
        self,
        presentation: Presentation,
        render_document: RenderDocument,
        title: str,
        subtitle: str,
        lines: list[str],
        accent_rgb: RGBColor | None = None,
    ) -> None:
        slide = presentation.slides.add_slide(presentation.slide_layouts[6])
        accent = accent_rgb or RGBColor(15, 76, 92)
        self._paint_background(slide, RGBColor(248, 251, 253))

        title_box = slide.shapes.add_textbox(Inches(0.75), Inches(0.45), Inches(8.4), Inches(0.85))
        title_frame = title_box.text_frame
        title_frame.word_wrap = True
        title_run = title_frame.paragraphs[0].add_run()
        title_run.text = title
        title_run.font.bold = True
        title_run.font.size = Pt(24)
        title_run.font.color.rgb = RGBColor(11, 31, 51)

        accent_bar = slide.shapes.add_shape(
            MSO_AUTO_SHAPE_TYPE.RECTANGLE,
            Inches(0.75), Inches(1.35), Inches(11.8), Inches(0.12)
        )
        accent_bar.fill.solid()
        accent_bar.fill.fore_color.rgb = accent
        accent_bar.line.color.rgb = accent

        subtitle_box = slide.shapes.add_textbox(Inches(0.78), Inches(1.55), Inches(11.6), Inches(0.7))
        subtitle_frame = subtitle_box.text_frame
        subtitle_frame.word_wrap = True
        subtitle_paragraph = subtitle_frame.paragraphs[0]
        subtitle_run = subtitle_paragraph.add_run()
        subtitle_run.text = subtitle
        subtitle_run.font.size = Pt(14)
        subtitle_run.font.color.rgb = RGBColor(82, 96, 109)

        content_shape = slide.shapes.add_shape(
            MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE,
            Inches(0.78), Inches(2.35), Inches(8.2), Inches(4.5)
        )
        content_shape.fill.solid()
        content_shape.fill.fore_color.rgb = RGBColor(255, 255, 255)
        content_shape.line.color.rgb = RGBColor(188, 204, 220)
        text_frame = content_shape.text_frame
        text_frame.clear()
        text_frame.word_wrap = True
        text_frame.margin_left = Inches(0.18)
        text_frame.margin_right = Inches(0.18)
        text_frame.margin_top = Inches(0.15)

        first = True
        for line in lines[:6]:
            paragraph = text_frame.paragraphs[0] if first else text_frame.add_paragraph()
            first = False
            paragraph.level = 0
            paragraph.text = line
            paragraph.font.size = Pt(18)
            paragraph.font.color.rgb = RGBColor(31, 41, 51)
            paragraph.space_after = Pt(8)

        if len(lines) > 6:
            paragraph = text_frame.add_paragraph()
            paragraph.text = "..."
            paragraph.font.size = Pt(18)
            paragraph.font.color.rgb = RGBColor(82, 96, 109)

        objective_shape = slide.shapes.add_shape(
            MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE,
            Inches(9.25), Inches(2.35), Inches(3.3), Inches(4.5)
        )
        objective_shape.fill.solid()
        objective_shape.fill.fore_color.rgb = RGBColor(236, 244, 247)
        objective_shape.line.color.rgb = RGBColor(188, 204, 220)
        objective_frame = objective_shape.text_frame
        objective_frame.clear()
        objective_frame.word_wrap = True
        objective_frame.margin_left = Inches(0.16)
        objective_frame.margin_right = Inches(0.16)
        objective_heading = objective_frame.paragraphs[0]
        objective_heading_run = objective_heading.add_run()
        objective_heading_run.text = localized_label(render_document.language, "learning_objectives")
        objective_heading_run.font.bold = True
        objective_heading_run.font.size = Pt(14)
        objective_heading_run.font.color.rgb = accent

        for objective in render_document.learning_objectives[:4]:
            paragraph = objective_frame.add_paragraph()
            paragraph.text = objective
            paragraph.font.size = Pt(11)
            paragraph.font.color.rgb = RGBColor(31, 41, 51)
            paragraph.level = 0

    def _paint_background(self, slide, rgb: RGBColor) -> None:
        fill = slide.background.fill
        fill.solid()
        fill.fore_color.rgb = rgb

    def _normalize_block(self, kind: str, content: str) -> str:
        if kind == "paragraph":
            return content

        if kind == "bullet":
            return f"• {content}"

        if kind == "checklist":
            return f"□ {content}"

        return f"Catatan: {content}"