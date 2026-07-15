"""Master Template Injection pipeline.

Maps ``SlideBlueprint`` slides onto pre-designed ``.pptx`` master templates
via placeholder-based content injection, with capacity-aware fit-check
before each fill.
"""

from app.engines.pptx_injector.injector import (
    CanvasRenderer,
    InjectionResult,
    TemplateInjector,
)
from app.engines.pptx_injector.manifest import (
    Capacity,
    LayoutManifest,
    PlaceholderKind,
    PlaceholderSpec,
    TemplateManifest,
    load_manifest,
)
from app.engines.pptx_injector.placeholder_resolver import (
    resolve_placeholder,
    resolve_shape,
)

__all__ = [
    "CanvasRenderer",
    "InjectionResult",
    "TemplateInjector",
    "Capacity",
    "LayoutManifest",
    "PlaceholderKind",
    "PlaceholderSpec",
    "TemplateManifest",
    "load_manifest",
    "resolve_placeholder",
    "resolve_shape",
]
