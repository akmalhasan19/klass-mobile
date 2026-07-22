from __future__ import annotations

import asyncio
from pathlib import Path
from typing import TYPE_CHECKING, Any

from app.contracts import MIME_TYPES
from app.document_model import RenderDocument
from app.engines.blueprint import SlideBlueprint
from app.engines.blueprint_builder import build_slide_blueprint
from app.errors import GenerationError
from app.generators.base import BaseGenerator, RenderSummary

if TYPE_CHECKING:
    from app.engines.chromium_sidecar.sidecar.sidecar_manager import SidecarManager
    from app.templates.registry import TemplateRegistry

DEFAULT_TEMPLATE_ID = "klass-educational-v1"


class PptxGenerator(BaseGenerator):
    """Generate a native, editable PPTX by delegating to the Node.js PptxGenJS Layout Engine.

    The generator maps the universal ``SlideBlueprint`` to a structured Presentation JSON
    and hands it to the warm Chromium/Node sidecar for high-end dynamic coordinates rendering.
    """

    export_format = "pptx"
    mime_type = MIME_TYPES["pptx"]

    def __init__(
        self,
        template_registry: TemplateRegistry | None = None,
        template_id: str = DEFAULT_TEMPLATE_ID,
        sidecar_manager: SidecarManager | None = None,
        event_loop: asyncio.AbstractEventLoop | None = None,
    ) -> None:
        self._template_registry = template_registry
        self._template_id = template_id
        self._sidecar_manager = sidecar_manager
        self._event_loop = event_loop

    def render(self, render_document: RenderDocument, output_path: Path) -> RenderSummary:
        sidecar_manager = self._require_sidecar()
        blueprint = build_slide_blueprint(render_document)
        spec = self._map_blueprint_to_spec(blueprint)

        # Delegate PPTX generation to the Node.js sidecar
        pptx_bytes = self._run_async(sidecar_manager.generate_pptx(spec), self._event_loop)

        # Write output file
        output_path.write_bytes(pptx_bytes)

        return RenderSummary(
            slide_count=len(blueprint.slides),
            warnings=[],
            layout_sources=["canvas"] * len(blueprint.slides),
        )

    def _require_sidecar(self):
        manager = self._sidecar_manager
        if manager is None:
            from app.main import sidecar_manager as _global_sidecar
            manager = _global_sidecar

        if manager is None or not manager.is_ready:
            raise GenerationError(
                "chromium_sidecar_unavailable",
                "The Chromium sidecar is not available; PPTX generation requires it.",
                {},
            )
        return manager

    def _map_blueprint_to_spec(self, blueprint: SlideBlueprint) -> dict[str, Any]:
        theme_id = blueprint.theme_id or self._template_id
        # Default theme colors
        theme = {
            "primary_color": "0B1F33",
            "secondary_color": "0F4C5C",
            "bg_color": "F8FAFC",
            "text_color": "1F2933",
            "font_heading": "Helvetica",
            "font_body": "Arial"
        }
        if theme_id == "warm" or theme_id == "sunset":
            theme.update({
                "primary_color": "7C2D12",
                "secondary_color": "EA580C",
                "bg_color": "FFF7ED",
                "text_color": "431407"
            })
        elif theme_id == "forest" or theme_id == "eco":
            theme.update({
                "primary_color": "064E3B",
                "secondary_color": "10B981",
                "bg_color": "F0FDF4",
                "text_color": "062F21"
            })
        elif theme_id == "dark" or theme_id == "tech":
            theme.update({
                "primary_color": "F8FAFC",
                "secondary_color": "3B82F6",
                "bg_color": "0F172A",
                "text_color": "E2E8F0"
            })
        # ── New theme palettes from LLM slide designer ──
        elif theme_id == "dark_executive":
            theme.update({
                "primary_color": "F1F5F9",
                "secondary_color": "6366F1",
                "bg_color": "0F172A",
                "text_color": "CBD5E1",
                "font_heading": "Helvetica",
                "font_body": "Arial"
            })
        elif theme_id == "clean_light":
            theme.update({
                "primary_color": "1E293B",
                "secondary_color": "0EA5E9",
                "bg_color": "FFFFFF",
                "text_color": "334155",
                "font_heading": "Helvetica",
                "font_body": "Arial"
            })
        elif theme_id == "modern_blue":
            theme.update({
                "primary_color": "1E3A5F",
                "secondary_color": "2563EB",
                "bg_color": "F0F4FF",
                "text_color": "1E293B",
                "font_heading": "Helvetica",
                "font_body": "Arial"
            })

        slides = []
        for i, slide in enumerate(blueprint.slides):
            # Check for explicit layout_type marker from PPTX slides mode
            explicit_layout = None
            if slide.speaker_notes and slide.speaker_notes.startswith("layout_type:"):
                explicit_layout = slide.speaker_notes.split(":", 1)[1]

            if explicit_layout:
                layout_type = explicit_layout
            else:
                # Legacy heuristic layout detection
                layout_type = "one_column"
                if slide.slide_type == "title":
                    layout_type = "title_hero"
                elif slide.slide_type == "assessment":
                    layout_type = "two_columns"
                elif slide.slide_type == "content":
                    if len(slide.cards) == 2:
                        layout_type = "two_columns"
                    elif len(slide.cards) == 3:
                        layout_type = "three_columns"
                    elif len(slide.cards) >= 4:
                        layout_type = "metric_highlight"
                    else:
                        layout_type = "one_column"

            content_items = []
            for card in slide.cards:
                body_lines = []
                for block in card.body_blocks:
                    if block.kind in ["bullet", "checklist"]:
                        body_lines.append(f"- {block.content}")
                    else:
                        body_lines.append(block.content)
                body_text = "\n".join(body_lines)
                
                content_items.append({
                    "heading": card.heading,
                    "body": body_text
                })

            slides.append({
                "slide_number": i + 1,
                "layout_type": layout_type,
                "title": slide.title,
                "subtitle": slide.subtitle,
                "content": content_items
            })

        return {
            "meta": {
                "title": blueprint.deck_meta.title,
                "theme": theme
            },
            "slides": slides
        }

    @staticmethod
    def _run_async(coro, loop: asyncio.AbstractEventLoop | None = None):
        if loop is not None:
            future = asyncio.run_coroutine_threadsafe(coro, loop)
            return future.result(timeout=60)

        try:
            running = asyncio.get_running_loop()
        except RuntimeError:
            return asyncio.run(coro)

        future = asyncio.run_coroutine_threadsafe(coro, running)
        return future.result(timeout=60)
