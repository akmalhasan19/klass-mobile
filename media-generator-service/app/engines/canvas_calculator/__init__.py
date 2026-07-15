"""Dynamic Canvas Layout — programmatic PPTX fallback engine.

Used by the orchestrator when a ``SlideBlueprint`` slide exceeds a master
template's capacity: instead of failing, it computes slide coordinates and
renders cards as rounded-rectangle shapes via ``python-pptx``.
"""

from app.engines.canvas_calculator.font_metrics import estimate_box
from app.engines.canvas_calculator.layout_engine import (
    Box,
    CanvasLayoutEngine,
    ShapeRenderer,
    SlideLayout,
)
from app.engines.canvas_calculator.shape_renderer import CanvasShapeRenderer

__all__ = [
    "estimate_box",
    "Box",
    "CanvasLayoutEngine",
    "ShapeRenderer",
    "SlideLayout",
    "CanvasShapeRenderer",
]
