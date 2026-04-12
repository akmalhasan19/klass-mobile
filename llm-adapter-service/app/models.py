from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.contracts import DRAFT_REQUEST_TYPE, INTERPRET_REQUEST_TYPE, RESPOND_REQUEST_TYPE


class AdapterBaseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class NamedContext(AdapterBaseModel):
    id: int
    name: str = Field(min_length=1, max_length=100)
    slug: str | None = Field(default=None, max_length=100)


class InterpretationRequestInput(AdapterBaseModel):
    teacher_prompt: str = Field(min_length=1, max_length=5000)
    preferred_output_type: Literal["auto", "docx", "pdf", "pptx"]
    subject_context: NamedContext | None = None
    sub_subject_context: NamedContext | None = None


class InterpretationRequest(AdapterBaseModel):
    request_type: Literal[INTERPRET_REQUEST_TYPE]
    generation_id: str = Field(min_length=1, max_length=100)
    model: str = Field(min_length=1, max_length=200)
    instruction: str = Field(min_length=1, max_length=20000)
    input: InterpretationRequestInput


class DraftTaxonomyConfidence(AdapterBaseModel):
    score: float | None = Field(default=None, ge=0, le=1)
    label: str | None = Field(default=None, max_length=20)


class DraftTaxonomySubject(AdapterBaseModel):
    id: int | None = None
    name: str = Field(min_length=1, max_length=100)
    slug: str | None = Field(default=None, max_length=100)


class DraftTaxonomySubSubject(AdapterBaseModel):
    id: int | None = None
    subject_id: int | None = None
    name: str = Field(min_length=1, max_length=100)
    slug: str | None = Field(default=None, max_length=100)


class DraftTaxonomyGradeContext(AdapterBaseModel):
    jenjang: str | None = Field(default=None, max_length=100)
    kelas: str | None = Field(default=None, max_length=50)
    semester: str | None = Field(default=None, max_length=50)
    bab: str | None = Field(default=None, max_length=50)


class DraftTaxonomyContentGuidance(AdapterBaseModel):
    description: str | None = Field(default=None, max_length=500)
    structure: str | None = Field(default=None, max_length=1000)
    structure_items: list[str] = Field(default_factory=list)


class DraftTaxonomyHint(AdapterBaseModel):
    schema_version: Literal["media_draft_taxonomy_hint.v1"]
    source: Literal["submission_context", "prompt_inference", "interpretation_context"]
    confidence: DraftTaxonomyConfidence
    subject: DraftTaxonomySubject
    sub_subject: DraftTaxonomySubSubject | None = None
    grade_context: DraftTaxonomyGradeContext
    content_guidance: DraftTaxonomyContentGuidance
    matched_signals: list[str] = Field(default_factory=list)


class ContentDraftRequestInput(AdapterBaseModel):
    resolved_output_type: Literal["docx", "pdf", "pptx"]
    interpretation: dict[str, Any]
    taxonomy_hint: DraftTaxonomyHint | None = None


class ContentDraftRequest(AdapterBaseModel):
    request_type: Literal[DRAFT_REQUEST_TYPE]
    generation_id: str = Field(min_length=1, max_length=100)
    model: str = Field(min_length=1, max_length=200)
    instruction: str = Field(min_length=1, max_length=20000)
    input: ContentDraftRequestInput


class DeliveryArtifact(AdapterBaseModel):
    output_type: Literal["docx", "pdf", "pptx"]
    title: str = Field(min_length=1, max_length=200)
    file_url: str = Field(min_length=1, max_length=2048)
    thumbnail_url: str | None = Field(default=None, max_length=2048)
    mime_type: str = Field(min_length=1, max_length=255)
    filename: str | None = Field(default=None, max_length=255)


class DeliveryTopicNode(AdapterBaseModel):
    id: str = Field(min_length=1, max_length=100)
    title: str = Field(min_length=1, max_length=200)


class DeliveryContentNode(AdapterBaseModel):
    id: str = Field(min_length=1, max_length=100)
    title: str = Field(min_length=1, max_length=200)
    type: str | None = Field(default=None, max_length=100)
    media_url: str | None = Field(default=None, max_length=2048)


class DeliveryRecommendedProjectNode(AdapterBaseModel):
    id: str = Field(min_length=1, max_length=100)
    title: str = Field(min_length=1, max_length=200)
    project_file_url: str | None = Field(default=None, max_length=2048)


class DeliveryPublication(AdapterBaseModel):
    topic: DeliveryTopicNode | None = None
    content: DeliveryContentNode | None = None
    recommended_project: DeliveryRecommendedProjectNode | None = None


class DeliveryRequestInput(AdapterBaseModel):
    artifact: DeliveryArtifact
    publication: DeliveryPublication
    preview_summary: str = Field(min_length=1, max_length=1000)
    teacher_delivery_summary: str | None = Field(default=None, max_length=1000)
    generation_summary: str | None = Field(default=None, max_length=2000)


class DeliveryRequest(AdapterBaseModel):
    request_type: Literal[RESPOND_REQUEST_TYPE]
    generation_id: str = Field(min_length=1, max_length=100)
    model: str = Field(min_length=1, max_length=200)
    instruction: str = Field(min_length=1, max_length=20000)
    input: DeliveryRequestInput


class HealthError(AdapterBaseModel):
    code: str
    message: str
    detail: str | None = None


class PostgresReadiness(AdapterBaseModel):
    configured: bool
    ready: bool
    driver: str | None = None
    host: str | None = None
    database: str | None = None
    error: HealthError | None = None


class ProviderReadiness(AdapterBaseModel):
    route: str
    provider: str
    configured: bool
    ready: bool
    supported_providers: list[str] = Field(default_factory=list)
    missing_settings: list[str] = Field(default_factory=list)
    error: HealthError | None = None


class ProviderDependencyReadiness(AdapterBaseModel):
    interpretation: ProviderReadiness
    delivery: ProviderReadiness


class DependencyReadiness(AdapterBaseModel):
    postgres: PostgresReadiness
    providers: ProviderDependencyReadiness


class AuthReadiness(AdapterBaseModel):
    ready: bool
    configured: bool
    rotation_enabled: bool
    accepted_secret_count: int
    max_request_age_seconds: int
    signature_algorithm: str


class GovernanceRouteStatus(AdapterBaseModel):
    route: Literal["interpret", "respond"]
    enabled: bool
    exhausted_action: Literal["deny", "degrade"]
    request_limit_per_minute: int = Field(ge=0)
    request_limit_per_hour: int = Field(ge=0)
    daily_budget_usd: str
    spent_budget_usd: str | None = None
    remaining_budget_usd: str | None = None
    projected_next_request_cost_usd: str
    utilization_ratio: float | None = None
    budget_status: Literal["healthy", "warning", "exhausted", "disabled", "unavailable"]
    next_request_would_exhaust_budget: bool | None = None


class GovernanceReadiness(AdapterBaseModel):
    ready: bool
    budget_warning_ratio: float = Field(ge=0, le=1)
    routes: list[GovernanceRouteStatus] = Field(default_factory=list)
    error: HealthError | None = None


class HealthResponse(AdapterBaseModel):
    schema_version: str
    status: Literal["ready", "degraded"]
    ready: bool
    service_name: str
    service_version: str
    checked_at: str
    dependencies: DependencyReadiness
    auth: AuthReadiness
    governance: GovernanceReadiness


class OperatorSummaryWindow(AdapterBaseModel):
    from_date: str
    to_date: str
    days: int = Field(ge=1)


class OperatorActiveRoute(AdapterBaseModel):
    route: Literal["interpret", "respond"]
    provider: str = Field(min_length=1)
    default_model: str = Field(min_length=1)
    fallback_provider: str | None = None


class OperatorRouteMetric(AdapterBaseModel):
    route: Literal["interpret", "respond"]
    request_count: int = Field(ge=0)
    cache_hit_ratio: float = Field(ge=0, le=1)
    deny_count: int = Field(ge=0)
    deny_rate: float = Field(ge=0, le=1)
    average_latency_ms: float | None = Field(default=None, ge=0)
    retry_volume: int = Field(ge=0)
    fallback_count: int = Field(ge=0)
    error_count: int = Field(ge=0)
    input_tokens: int = Field(ge=0)
    output_tokens: int = Field(ge=0)
    total_tokens: int = Field(ge=0)
    total_estimated_cost_usd: str
    last_request_at: str | None = None


class OperatorProviderModelMetric(AdapterBaseModel):
    route: Literal["interpret", "respond"]
    provider: str = Field(min_length=1)
    model: str = Field(min_length=1)
    request_count: int = Field(ge=0)
    cache_hit_ratio: float = Field(ge=0, le=1)
    average_latency_ms: float | None = Field(default=None, ge=0)
    fallback_count: int = Field(ge=0)
    error_count: int = Field(ge=0)
    total_estimated_cost_usd: str
    last_request_at: str | None = None


class OperatorSummaryResponse(AdapterBaseModel):
    schema_version: str
    service_name: str
    service_version: str
    generated_at: str
    window: OperatorSummaryWindow
    active_routes: list[OperatorActiveRoute] = Field(default_factory=list)
    routes: list[OperatorRouteMetric] = Field(default_factory=list)
    provider_models: list[OperatorProviderModelMetric] = Field(default_factory=list)
