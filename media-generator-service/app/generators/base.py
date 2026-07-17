from __future__ import annotations

import hashlib
import re
import unicodedata
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from app.contracts import ARTIFACT_METADATA_VERSION
from app.document_model import RenderDocument
from app.errors import GenerationError
from app.models import ArtifactMetadata, GenerateRequest
from app.settings import Settings


@dataclass(frozen=True)
class RenderSummary:
    page_count: int | None = None
    slide_count: int | None = None
    warnings: list[str] = field(default_factory=list)
    layout_sources: list[str] | None = None


class BaseGenerator(ABC):
    export_format: str
    mime_type: str

    def generate(
        self,
        request_payload: GenerateRequest,
        render_document: RenderDocument,
        settings: Settings,
        output_path: Path,
    ) -> dict[str, Any]:
        try:
            summary = self.render(render_document, output_path)
            self._assert_artifact(output_path)

            metadata = ArtifactMetadata.model_validate(
                {
                    "schema_version": ARTIFACT_METADATA_VERSION,
                    "export_format": self.export_format,
                    "title": render_document.title,
                    "filename": self._filename(render_document.title),
                    "extension": self.export_format,
                    "mime_type": self.mime_type,
                    "size_bytes": output_path.stat().st_size,
                    "checksum_sha256": hashlib.sha256(output_path.read_bytes()).hexdigest(),
                    "page_count": summary.page_count,
                    "slide_count": summary.slide_count,
                    "artifact_locator": {
                        "kind": "storage_object",
                        "value": str(output_path),
                    },
                    "generator": {
                        "name": settings.service_name,
                        "version": settings.service_version,
                    },
                    "warnings": summary.warnings,
                    "layout_sources": summary.layout_sources,
                }
            )

            return metadata.model_dump(mode="python")
        except Exception as exc:

            if isinstance(exc, GenerationError):
                raise

            raise GenerationError(
                "artifact_generation_failed",
                f"Failed to render {self.export_format} artifact.",
                {"export_format": self.export_format},
            ) from exc

    @abstractmethod
    def render(self, render_document: RenderDocument, output_path: Path) -> RenderSummary:
        raise NotImplementedError

    def _assert_artifact(self, output_path: Path) -> None:
        if not output_path.is_file():
            raise GenerationError(
                "artifact_not_created",
                "Generator did not produce an artifact file.",
                {"path": str(output_path)},
            )

        if output_path.stat().st_size <= 0:
            raise GenerationError(
                "artifact_empty",
                "Generator produced an empty artifact file.",
                {"path": str(output_path)},
            )

    def _filename(self, title: str) -> str:
        return f"{self._slugify(title) or 'generated-media'}.{self.export_format}"

    def _slugify(self, value: str) -> str:
        normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
        normalized = normalized.lower().strip()
        normalized = re.sub(r"[^a-z0-9]+", "-", normalized)
        return normalized.strip("-")
