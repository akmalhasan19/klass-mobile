from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.contracts import (
    ARTIFACT_METADATA_VERSION,
    GENERATION_SPEC_VERSION,
    INTERPRETATION_SCHEMA_VERSION,
    RESPONSE_SCHEMA_VERSION,
    SUPPORTED_EXPORT_FORMATS,
)


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class BodyBlock(StrictModel):
    type: Literal["paragraph", "bullet", "checklist", "note"]
    content: str = Field(min_length=1, max_length=1000)


class Section(StrictModel):
    title: str = Field(min_length=1, max_length=200)
    purpose: str = Field(min_length=1, max_length=500)
    body_blocks: list[BodyBlock] = Field(min_length=1)
    emphasis: Literal["short", "medium", "long"]


class LayoutHints(StrictModel):
    document_mode: Literal["document", "slide_deck"]
    visual_density: Literal["low", "medium", "high"]
    section_count: int = Field(ge=1)
    asset_count: int = Field(ge=0)
    assessment_block_count: int = Field(ge=0)


class StyleHints(StrictModel):
    tone: str = Field(min_length=1, max_length=100)
    audience_level: str = Field(min_length=1, max_length=100)
    format_preferences: list[str] = Field(min_length=1)


class PageOrSlideStructure(StrictModel):
    unit_type: Literal["page", "slide"]
    total_units: int = Field(ge=1)
    opening_unit: bool
    section_units: int = Field(ge=1)
    closing_unit: bool


class ContentContext(StrictModel):
    subject_context: dict[str, Any] | None = None
    sub_subject_context: dict[str, Any] | None = None
    target_audience: dict[str, Any] | None = None


class Asset(StrictModel):
    type: Literal["text", "image", "table", "chart", "diagram", "reference"]
    description: str = Field(min_length=1, max_length=500)
    required: bool


class AssessmentBlock(StrictModel):
    title: str = Field(min_length=1, max_length=200)
    type: Literal["assessment", "activity", "reflection", "quiz", "assignment"]
    instructions: str = Field(min_length=1, max_length=1000)


class ContractVersions(StrictModel):
    generator_output_metadata: Literal[ARTIFACT_METADATA_VERSION]


class GenerationSpec(StrictModel):
    schema_version: Literal[GENERATION_SPEC_VERSION]
    source_interpretation_schema_version: Literal[INTERPRETATION_SCHEMA_VERSION]
    export_format: Literal[SUPPORTED_EXPORT_FORMATS]
    title: str = Field(min_length=1, max_length=200)
    language: str = Field(min_length=1, max_length=32)
    summary: str = Field(min_length=1, max_length=1000)
    learning_objectives: list[str] = Field(default_factory=list)
    sections: list[Section] = Field(min_length=1)
    layout_hints: LayoutHints
    style_hints: StyleHints
    page_or_slide_structure: PageOrSlideStructure
    content_context: ContentContext
    assets: list[Asset] = Field(default_factory=list)
    assessment_or_activity_blocks: list[AssessmentBlock] = Field(default_factory=list)
    teacher_delivery_summary: str = Field(min_length=1, max_length=1000)
    contract_versions: ContractVersions
    content_integrity: dict[str, Any] | None = Field(default=None)

    @model_validator(mode="after")
    def validate_consistency(self) -> "GenerationSpec":
        if self.layout_hints.section_count != len(self.sections):
            raise ValueError("layout_hints.section_count must equal the number of sections")

        if self.layout_hints.asset_count != len(self.assets):
            raise ValueError("layout_hints.asset_count must equal the number of assets")

        if self.layout_hints.assessment_block_count != len(self.assessment_or_activity_blocks):
            raise ValueError(
                "layout_hints.assessment_block_count must equal the number of assessment blocks"
            )

        if self.page_or_slide_structure.section_units != len(self.sections):
            raise ValueError(
                "page_or_slide_structure.section_units must equal the number of sections"
            )

        expected_unit_type = "slide" if self.export_format == "pptx" else "page"
        if self.page_or_slide_structure.unit_type != expected_unit_type:
            raise ValueError("page_or_slide_structure.unit_type does not match export_format")

        expected_mode = "slide_deck" if self.export_format == "pptx" else "document"
        if self.layout_hints.document_mode != expected_mode:
            raise ValueError("layout_hints.document_mode does not match export_format")

        return self


class RequestContracts(StrictModel):
    generation_spec: Literal[GENERATION_SPEC_VERSION]
    artifact_metadata: Literal[ARTIFACT_METADATA_VERSION]


class GenerateRequest(StrictModel):
    generation_id: str = Field(min_length=1, max_length=100)
    generation_spec: GenerationSpec
    contracts: RequestContracts


class ArtifactLocator(StrictModel):
    kind: Literal["temporary_path", "signed_url", "storage_object"]
    value: str = Field(min_length=1, max_length=2048)


class GeneratorIdentity(StrictModel):
    name: str = Field(min_length=1, max_length=100)
    version: str = Field(min_length=1, max_length=50)


class ArtifactMetadata(StrictModel):
    schema_version: Literal[ARTIFACT_METADATA_VERSION]
    export_format: Literal[SUPPORTED_EXPORT_FORMATS]
    title: str = Field(min_length=1, max_length=200)
    filename: str = Field(min_length=1, max_length=255)
    extension: Literal[SUPPORTED_EXPORT_FORMATS]
    mime_type: str = Field(min_length=1, max_length=255)
    size_bytes: int = Field(gt=0)
    checksum_sha256: str = Field(pattern=r"^[A-Fa-f0-9]{64}$")
    page_count: int | None = Field(default=None, ge=1)
    slide_count: int | None = Field(default=None, ge=1)
    artifact_locator: ArtifactLocator
    generator: GeneratorIdentity
    warnings: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_cross_fields(self) -> "ArtifactMetadata":
        if self.export_format != self.extension:
            raise ValueError("extension must match export_format")

        if self.export_format == "pptx" and self.slide_count is None:
            raise ValueError("slide_count is required for pptx artifacts")

        if self.export_format != "pptx" and self.slide_count is not None:
            raise ValueError("slide_count is only allowed for pptx artifacts")

        return self


class ResponseContracts(StrictModel):
    artifact_metadata: Literal[ARTIFACT_METADATA_VERSION]


class GenerateResponseData(StrictModel):
    generation_id: str = Field(min_length=1, max_length=100)
    artifact_delivery: ArtifactLocator
    artifact_metadata: ArtifactMetadata
    contracts: ResponseContracts


class GenerateSuccessResponse(StrictModel):
    schema_version: Literal[RESPONSE_SCHEMA_VERSION]
    request_id: str = Field(min_length=1, max_length=100)
    status: Literal["completed"]
    data: GenerateResponseData


class ResponseError(StrictModel):
    code: str = Field(min_length=1, max_length=100)
    message: str = Field(min_length=1, max_length=500)
    retryable: bool
    laravel_error_code_hint: str = Field(min_length=1, max_length=100)
    details: dict[str, Any] = Field(default_factory=dict)


class GenerateErrorResponse(StrictModel):
    schema_version: Literal[RESPONSE_SCHEMA_VERSION]
    request_id: str = Field(min_length=1, max_length=100)
    status: Literal["failed"]
    error: ResponseError
