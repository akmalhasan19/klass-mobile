from __future__ import annotations

from pathlib import Path
from typing import cast
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
from reportlab.pdfgen.canvas import Canvas

from app.contracts import PDF_MIME_TYPE
from app.document_model import RenderAsset, RenderDocument, RenderSection, localized_label
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
        story.append(self._box_block(localized_label(render_document.language, "summary"), render_document.summary, styles))
        story.append(Spacer(1, 5 * mm))

        if render_document.context_rows:
            story.append(Paragraph(escape(localized_label(render_document.language, "context")), styles["section_heading"]))
            story.append(self._context_table(render_document, styles))
            story.append(Spacer(1, 4 * mm))

        if render_document.learning_objectives:
            story.append(Paragraph(escape(localized_label(render_document.language, "learning_objectives")), styles["section_heading"]))
            for objective in render_document.learning_objectives:
                story.append(Paragraph(f"- {escape(objective)}", styles["bullet"]))
            story.append(Spacer(1, 4 * mm))

        for section in render_document.sections:
            self._append_section(story, render_document, section, styles)

        if render_document.assets:
            story.append(Paragraph(escape(localized_label(render_document.language, "assets")), styles["section_heading"]))
            for asset in render_document.assets:
                story.append(Paragraph(escape(self._asset_line(render_document, asset)), styles["bullet"]))
            story.append(Spacer(1, 4 * mm))

        if render_document.activity_blocks:
            story.append(Paragraph(escape(localized_label(render_document.language, "activity_blocks")), styles["section_heading"]))
            for block in render_document.activity_blocks:
                story.append(Paragraph(escape(block.title), styles["sub_heading"]))
                story.append(Paragraph(escape(block.instructions), styles["body"]))
                story.append(Spacer(1, 2 * mm))

        story.append(
            self._box_block(
                localized_label(render_document.language, "teacher_notes"),
                render_document.teacher_delivery_summary,
                styles,
            )
        )

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
        story.append(Paragraph(escape(section.purpose), styles["purpose"]))

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

    def _box_block(
        self,
        heading: str,
        body: str,
        styles: dict[str, ParagraphStyle],
    ) -> Table:
        table = Table(
            [
                [Paragraph(escape(heading), styles["label"])],
                [Paragraph(escape(body), styles["body"])],
            ],
            colWidths=[178 * mm],
        )
        table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#D9E2EC")),
                    ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#F8FBFD")),
                    ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#BCCCDC")),
                    ("INNERPADDING", (0, 0), (-1, -1), 6),
                ]
            )
        )
        return table

    def _context_table(
        self,
        render_document: RenderDocument,
        styles: dict[str, ParagraphStyle],
    ) -> Table:
        rows = [
            [Paragraph(escape(label), styles["label"]), Paragraph(escape(value), styles["body"])]
            for label, value in render_document.context_rows
        ]
        table = Table(rows, colWidths=[45 * mm, 133 * mm])
        table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#EEF4F7")),
                    ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#BCCCDC")),
                    ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#D9E2EC")),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("INNERPADDING", (0, 0), (-1, -1), 5),
                ]
            )
        )
        return table

    def _asset_line(self, render_document: RenderDocument, asset: RenderAsset) -> str:
        requirement = localized_label(
            render_document.language,
            "required" if asset.required else "optional",
        )
        return f"{requirement} {asset.asset_type}: {asset.description}"
