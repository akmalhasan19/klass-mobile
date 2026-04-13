from __future__ import annotations

from pathlib import Path
from typing import cast
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer
from reportlab.pdfgen.canvas import Canvas

from app.contracts import PDF_MIME_TYPE
from app.document_model import RenderDocument, RenderSection, localized_label
from app.generators.base import BaseGenerator, RenderSummary


class PageCountingCanvas(Canvas):
    def __init__(self, *args, title: str, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self._saved_page_states: list[dict[str, object]] = []
        self.page_count = 0
        self._title = title

    def showPage(self) -> None:
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self) -> None:
        self._saved_page_states.append(dict(self.__dict__))
        self.page_count = len(self._saved_page_states)

        for state in self._saved_page_states:
            self.__dict__.update(state)
            self._draw_footer()
            super().showPage()

        super().save()

    def _draw_footer(self) -> None:
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#57606A"))
        self.drawString(18 * mm, 10 * mm, self._title[:90])
        self.drawRightString(192 * mm, 10 * mm, f"Page {self._pageNumber} of {self.page_count}")


class PdfGenerator(BaseGenerator):
    export_format = "pdf"
    mime_type = PDF_MIME_TYPE

    def render(self, render_document: RenderDocument, output_path: Path) -> RenderSummary:
        styles = self._styles()
        story: list[object] = []

        story.append(Paragraph(escape(render_document.title), styles["title"]))
        story.append(Spacer(1, 6 * mm))
        story.append(Paragraph(escape(render_document.summary), styles["body"]))
        story.append(Spacer(1, 5 * mm))

        if render_document.learning_objectives:
            story.append(Paragraph(escape(localized_label(render_document.language, "learning_objectives")), styles["section_heading"]))
            for objective in render_document.learning_objectives:
                story.append(Paragraph(f"- {escape(objective)}", styles["bullet"]))
            story.append(Spacer(1, 4 * mm))

        for section in render_document.sections:
            self._append_section(story, render_document, section, styles)

        if render_document.activity_blocks:
            story.append(Paragraph(escape(localized_label(render_document.language, "activity_blocks")), styles["section_heading"]))
            for block in render_document.activity_blocks:
                story.append(Paragraph(escape(block.title), styles["sub_heading"]))
                story.append(Paragraph(escape(block.instructions), styles["body"]))
                story.append(Spacer(1, 2 * mm))

        template = SimpleDocTemplate(
            str(output_path),
            pagesize=A4,
            leftMargin=16 * mm,
            rightMargin=16 * mm,
            topMargin=18 * mm,
            bottomMargin=18 * mm,
            title=render_document.title,
        )

        canvas_holder: dict[str, PageCountingCanvas] = {}

        def canvas_factory(*args, **kwargs):
            canvas = PageCountingCanvas(*args, title=render_document.title, **kwargs)
            canvas_holder["canvas"] = canvas
            return canvas

        template.build(story, canvasmaker=canvas_factory)
        page_count = cast(PageCountingCanvas, canvas_holder["canvas"]).page_count

        return RenderSummary(page_count=max(1, page_count))

    def _styles(self) -> dict[str, ParagraphStyle]:
        sample = getSampleStyleSheet()

        return {
            "title": ParagraphStyle(
                "KlassTitle",
                parent=sample["Title"],
                fontName="Helvetica-Bold",
                fontSize=20,
                leading=24,
                textColor=colors.HexColor("#0B1F33"),
                alignment=TA_CENTER,
                spaceAfter=10,
            ),
            "section_heading": ParagraphStyle(
                "KlassSectionHeading",
                parent=sample["Heading2"],
                fontName="Helvetica-Bold",
                fontSize=13,
                leading=16,
                textColor=colors.HexColor("#0F4C5C"),
                spaceBefore=8,
                spaceAfter=4,
            ),
            "sub_heading": ParagraphStyle(
                "KlassSubHeading",
                parent=sample["Heading3"],
                fontName="Helvetica-Bold",
                fontSize=11,
                leading=14,
                textColor=colors.HexColor("#0B1F33"),
                spaceBefore=4,
                spaceAfter=2,
            ),
            "body": ParagraphStyle(
                "KlassBody",
                parent=sample["BodyText"],
                fontName="Helvetica",
                fontSize=10,
                leading=14,
                textColor=colors.HexColor("#1F2933"),
                spaceAfter=3,
            ),
            "purpose": ParagraphStyle(
                "KlassPurpose",
                parent=sample["BodyText"],
                fontName="Helvetica-Oblique",
                fontSize=9.5,
                leading=13,
                textColor=colors.HexColor("#52606D"),
                spaceAfter=4,
            ),
            "bullet": ParagraphStyle(
                "KlassBullet",
                parent=sample["BodyText"],
                fontName="Helvetica",
                fontSize=10,
                leading=14,
                leftIndent=10,
                firstLineIndent=0,
                spaceAfter=2,
                textColor=colors.HexColor("#1F2933"),
            ),
            "label": ParagraphStyle(
                "KlassLabel",
                parent=sample["BodyText"],
                fontName="Helvetica-Bold",
                fontSize=9,
                leading=12,
                textColor=colors.HexColor("#0B1F33"),
            ),
        }

    def _append_section(
        self,
        story: list[object],
        render_document: RenderDocument,
        section: RenderSection,
        styles: dict[str, ParagraphStyle],
    ) -> None:
        story.append(Paragraph(escape(section.title), styles["section_heading"]))

        for block in section.blocks:
            if block.kind == "paragraph":
                story.append(Paragraph(escape(block.content), styles["body"]))
                continue

            if block.kind == "bullet":
                story.append(Paragraph(f"- {escape(block.content)}", styles["bullet"]))
                continue

            prefix = "[ ] " if block.kind == "checklist" else "Note: "
            story.append(Paragraph(escape(prefix + block.content), styles["bullet"]))

        story.append(Spacer(1, 3 * mm))
