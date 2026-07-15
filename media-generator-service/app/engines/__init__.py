"""Hybrid AI PPT Generation Engine — three-pillar architecture.

This package contains the core engine modules:
- ``blueprint``: SlideBlueprint universal Pydantic schema (single source of truth)
- ``blueprint_builder``: RenderDocument → SlideBlueprint conversion
- ``base``: BaseEngine ABC for engine implementations
- ``marp/``: Marp preview + PDF pipeline
- ``pptx_injector/``: Master template injection pipeline
- ``canvas_calculator/``: Dynamic canvas layout fallback
"""
