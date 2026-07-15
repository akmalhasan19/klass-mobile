"""Base engine ABC for the Hybrid AI PPT Generation Engine.

Every rendering pipeline (Marp, Template Injector, Canvas Calculator) implements
this contract so that the orchestrator in ``generators/`` can delegate uniformly.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

from app.engines.blueprint import SlideBlueprint


@dataclass(frozen=True)
class EngineRenderResult:
    """Outcome of a single engine render pass.

    Attributes:
        output_path: Location of the rendered artifact on disk.
        slide_count: Total slides produced.
        layout_sources: Per-slide annotation of which engine rendered each
            slide (``"template"`` or ``"canvas"``).
        warnings: Non-fatal issues encountered during rendering
            (e.g. capacity overflow, missing placeholder).
    """

    output_path: Path
    slide_count: int
    layout_sources: list[Literal["template", "canvas"]] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


class BaseEngine(ABC):
    """Abstract interface for a rendering engine.

    Subclasses implement ``render`` which takes a validated
    :class:`SlideBlueprint` and writes an artifact to *output_path*.
    """

    @abstractmethod
    def render(
        self,
        blueprint: SlideBlueprint,
        output_path: Path,
    ) -> EngineRenderResult:
        """Render *blueprint* to an artifact file at *output_path*.

        Raises:
            app.errors.GenerationError: On unrecoverable rendering failures.
        """
        raise NotImplementedError
