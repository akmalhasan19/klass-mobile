from __future__ import annotations

import json
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Annotated, Any, Literal

import psycopg
from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator, model_validator
from psycopg_pool import ConnectionPool

from app.cache import AdapterCacheService, CacheEntry, build_interpretation_cache_document
from app.contracts import (
    INTERPRET_REQUEST_TYPE,
    INTERPRET_ROUTE,
    INTERPRETATION_SCHEMA_VERSION,
    SUPPORTED_OUTPUT_FORMATS,
    SUPPORTED_PREFERRED_OUTPUT_TYPES,
)
from app.costs import AdapterCostService, LedgerFailureContext
from app.database import get_database_pool
from app.errors import AdapterError, ProviderConfigurationError, ProviderRequestError
from app.governance import AdapterGovernanceService
from app.models import InterpretationRequest
from app.providers.base import ProviderExecutionResult
from app.providers.routing import ProviderRouter
from app.response_headers import build_llm_response_headers
from app.settings import Settings, get_settings

OutputType = Literal["docx", "pdf", "pptx"]
PreferredOutputType = Literal["auto", "docx", "pdf", "pptx"]
VisualDensity = Literal["low", "medium", "high"]
ConfidenceLabel = Literal["low", "medium", "high"]
EstimatedLength = Literal["short", "medium", "long"]
AssetType = Literal["text", "image", "table", "chart", "diagram", "reference"]
AssessmentBlockType = Literal["assessment", "activity", "reflection", "quiz", "assignment"]

String32 = Annotated[str, Field(min_length=1, max_length=32)]
String100 = Annotated[str, Field(min_length=1, max_length=100)]
String200 = Annotated[str, Field(min_length=1, max_length=200)]
String300 = Annotated[str, Field(max_length=300)]
String500 = Annotated[str, Field(min_length=1, max_length=500)]
String1000 = Annotated[str, Field(min_length=1, max_length=1000)]
String5000 = Annotated[str, Field(min_length=1, max_length=5000)]


class InterpretationContractModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class InterpretationTeacherIntent(InterpretationContractModel):
    type: String100
    goal: String500
    preferred_delivery_mode: String100
    requires_clarification: bool


class InterpretationConstraints(InterpretationContractModel):
    preferred_output_type: PreferredOutputType = "auto"
    max_duration_minutes: int | None = Field(default=None, ge=1, le=1440)
    must_include: list[String300] = Field(default_factory=list)
    avoid: list[String300] = Field(default_factory=list)
    tone: Annotated[str, Field(max_length=100)] | None = None


class InterpretationOutputCandidate(InterpretationContractModel):
    type: OutputType
    score: float = Field(ge=0, le=1)
    reason: Annotated[str, Field(min_length=1, max_length=500)]

    @field_validator("score")
    @classmethod
    def round_score(cls, value: float) -> float:
        return round(float(value), 4)


class InterpretationBlueprintSection(InterpretationContractModel):
    title: String200
    purpose: String500
    bullets: list[String300]
    estimated_length: EstimatedLength


class InterpretationDocumentBlueprint(InterpretationContractModel):
    title: String200
    summary: String1000
    sections: list[InterpretationBlueprintSection] = Field(min_length=1)


class InterpretationSubjectContext(InterpretationContractModel):
    subject_name: String100
    subject_slug: Annotated[str, Field(max_length=100)] | None = None


class InterpretationSubSubjectContext(InterpretationContractModel):
    sub_subject_name: String100
    sub_subject_slug: Annotated[str, Field(max_length=100)] | None = None


class InterpretationTargetAudience(InterpretationContractModel):
    label: String100
    level: Annotated[str, Field(max_length=100)] | None = None
    age_range: Annotated[str, Field(max_length=100)] | None = None


class InterpretationRequestedMediaCharacteristics(InterpretationContractModel):
    tone: Annotated[str, Field(max_length=100)] | None = None
    format_preferences: list[Annotated[str, Field(max_length=100)]] = Field(default_factory=list)
    visual_density: VisualDensity | None = None


class InterpretationAsset(InterpretationContractModel):
    type: AssetType
    description: Annotated[str, Field(min_length=1, max_length=500)]
    required: bool


class InterpretationAssessmentBlock(InterpretationContractModel):
    title: String200
    type: AssessmentBlockType
    instructions: String1000


class InterpretationConfidence(InterpretationContractModel):
    score: float = Field(ge=0, le=1)
    label: ConfidenceLabel
    rationale: Annotated[str, Field(max_length=500)] | None = None


class InterpretationFallback(InterpretationContractModel):
    triggered: bool = False
    reason_code: Annotated[str, Field(max_length=100)] | None = None
    action: Annotated[str, Field(max_length=100)] | None = None


class InterpretationContentIntegrity(InterpretationContractModel):
    integrity_score: float = Field(ge=0, le=1)
    violations: list[dict[str, Any]] = Field(default_factory=list)
    classification_source: Annotated[str, Field(max_length=50)]
    metadata: dict[str, Any] | None = None


class InterpretationPayload(InterpretationContractModel):
    schema_version: Literal["media_prompt_understanding.v1"]
    teacher_prompt: String5000
    language: String32
    teacher_intent: InterpretationTeacherIntent
    learning_objectives: list[String300]
    constraints: InterpretationConstraints
    output_type_candidates: list[InterpretationOutputCandidate] = Field(min_length=1)
    resolved_output_type_reasoning: String1000
    document_blueprint: InterpretationDocumentBlueprint
    subject_context: InterpretationSubjectContext | None = None
    sub_subject_context: InterpretationSubSubjectContext | None = None
    target_audience: InterpretationTargetAudience | None = None
    requested_media_characteristics: InterpretationRequestedMediaCharacteristics = Field(
        default_factory=InterpretationRequestedMediaCharacteristics
    )
    assets: list[InterpretationAsset] = Field(default_factory=list)
    assessment_or_activity_blocks: list[InterpretationAssessmentBlock] = Field(default_factory=list)
    teacher_delivery_summary: String1000
    confidence: InterpretationConfidence
    fallback: InterpretationFallback = Field(default_factory=InterpretationFallback)
    content_integrity: InterpretationContentIntegrity | None = None
    meta_repairs: dict[str, Any] | None = Field(default=None, alias="_meta_repairs")

    @model_validator(mode="after")
    def sort_candidates(self) -> "InterpretationPayload":
        self.output_type_candidates = sorted(
            self.output_type_candidates,
            key=lambda candidate: candidate.score,
            reverse=True,
        )
        return self


@dataclass
class InterpretationContractValidationError(Exception):
    code: str
    message: str
    details: dict[str, Any]
    raw_completion: str

    def __post_init__(self) -> None:
        super().__init__(self.message)


class InterpretationWorkflowService:
    def __init__(
        self,
        settings: Settings | None = None,
        *,
        pool: ConnectionPool | None = None,
        provider_router: ProviderRouter | None = None,
        cache_service: AdapterCacheService | None = None,
        governance_service: AdapterGovernanceService | None = None,
        cost_service: AdapterCostService | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.pool = pool
        self.provider_router = provider_router or ProviderRouter(self.settings)
        self.cache_service = cache_service or AdapterCacheService(self.settings, pool=pool)
        self.governance_service = governance_service or AdapterGovernanceService(self.settings, pool=pool)
        self.cost_service = cost_service or AdapterCostService(self.settings, pool=pool)
        self.response_headers: dict[str, str] = {}

    async def interpret(
        self,
        payload: InterpretationRequest,
        *,
        request_id: str,
    ) -> dict[str, Any]:
        self.response_headers = {}

        try:
            policy, primary_model = self._prepare_primary_route(payload)
        except ProviderConfigurationError as exc:
            with self._connection_scope() as connection:
                self._record_failure(
                    payload=payload,
                    request_id=request_id,
                    error=exc,
                    primary_provider=self.settings.active_interpretation_provider,
                    primary_model=self._default_model_for_provider(self.settings.active_interpretation_provider, payload.model),
                    cache_status="bypass",
                    connection=connection,
                )
            raise

        cache_key = self.cache_service.build_interpretation_cache_key(
            payload,
            provider=policy.primary_provider,
            model=primary_model,
        )
        cache_request_document = build_interpretation_cache_document(
            payload,
            provider=policy.primary_provider,
            model=primary_model,
            schema_version=self.settings.cache_key_schema_version,
        )

        with self._connection_scope() as connection:
            decision = self.governance_service.preflight_check(
                route=INTERPRET_ROUTE,
                provider=policy.primary_provider,
                model=primary_model,
                request_id=request_id,
                generation_id=payload.generation_id,
                connection=connection,
            )
            if not decision.allowed:
                return self._handle_preflight_decision(
                    payload=payload,
                    request_id=request_id,
                    decision=decision,
                    primary_provider=policy.primary_provider,
                    primary_model=primary_model,
                    cache_key=cache_key,
                    connection=connection,
                )

            cached_entry = self.cache_service.lookup_entry(
                INTERPRET_ROUTE,
                cache_key,
                connection=connection,
            )
            if cached_entry is not None:
                return self._handle_cached_entry(
                    cached_entry,
                    request_id=request_id,
                    generation_id=payload.generation_id,
                    requested_model=payload.model,
                    primary_provider=policy.primary_provider,
                    primary_model=primary_model,
                    cache_key=cache_key,
                    connection=connection,
                )

            lock = self.cache_service.try_acquire_inflight_lock(
                INTERPRET_ROUTE,
                cache_key,
                connection=connection,
            )
            if not lock.acquired:
                waited_entry = self.cache_service.wait_for_inflight_entry(
                    INTERPRET_ROUTE,
                    cache_key,
                    connection=connection,
                )
                if waited_entry is not None:
                    return self._handle_cached_entry(
                        waited_entry,
                        request_id=request_id,
                        generation_id=payload.generation_id,
                        requested_model=payload.model,
                        primary_provider=policy.primary_provider,
                        primary_model=primary_model,
                        cache_key=cache_key,
                        connection=connection,
                    )

                timeout_error = AdapterError(
                    code="interpretation_inflight_timeout",
                    message="A matching interpretation request is already running and no cached result became available before the wait timeout.",
                    status_code=503,
                    details={
                        "route": INTERPRET_ROUTE,
                        "cache_key": cache_key,
                        "provider": policy.primary_provider,
                        "model": primary_model,
                    },
                    retryable=True,
                )
                self._record_failure(
                    payload=payload,
                    request_id=request_id,
                    error=timeout_error,
                    primary_provider=policy.primary_provider,
                    primary_model=primary_model,
                    cache_status="bypass",
                    cache_key=cache_key,
                    connection=connection,
                )
                raise timeout_error

            try:
                execution_result = await self.provider_router.execute_interpretation(payload)
                return self._handle_provider_result(
                    payload=payload,
                    request_id=request_id,
                    execution_result=execution_result,
                    primary_provider=policy.primary_provider,
                    primary_model=primary_model,
                    cache_key=cache_key,
                    cache_request_document=cache_request_document,
                    connection=connection,
                )
            except ProviderRequestError as exc:
                self._record_failure(
                    payload=payload,
                    request_id=request_id,
                    error=exc,
                    primary_provider=policy.primary_provider,
                    primary_model=primary_model,
                    cache_status="miss",
                    cache_key=cache_key,
                    connection=connection,
                )
                raise
            except ProviderConfigurationError as exc:
                self._record_failure(
                    payload=payload,
                    request_id=request_id,
                    error=exc,
                    primary_provider=policy.primary_provider,
                    primary_model=primary_model,
                    cache_status="miss",
                    cache_key=cache_key,
                    connection=connection,
                )
                raise
            finally:
                self.cache_service.release_inflight_lock(lock, connection=connection)

    def _prepare_primary_route(self, payload: InterpretationRequest) -> tuple[Any, str]:
        policy = self.provider_router.policy_for_route(INTERPRET_ROUTE)
        primary_client = self.provider_router.registry.build_client(policy.primary_provider, self.settings)
        normalized_request = primary_client.normalize_interpretation_request(payload)
        return policy, normalized_request.model

    def _handle_preflight_decision(
        self,
        *,
        payload: InterpretationRequest,
        request_id: str,
        decision: Any,
        primary_provider: str,
        primary_model: str,
        cache_key: str,
        connection: psycopg.Connection,
    ) -> dict[str, Any]:
        if not decision.fallback_allowed:
            decision.raise_for_violation()

        error = AdapterError(
            code=decision.code or "governance_blocked",
            message=decision.message or "Interpretation request is blocked by governance policy.",
            status_code=decision.status_code or 429,
            details=decision.details,
            retryable=False,
        )
        self._record_failure(
            payload=payload,
            request_id=request_id,
            error=error,
            primary_provider=primary_provider,
            primary_model=primary_model,
            cache_status="bypass",
            cache_key=cache_key,
            connection=connection,
        )
        self._set_response_headers(
            provider=primary_provider,
            model=primary_model,
            primary_provider=primary_provider,
            fallback_used=False,
            fallback_reason=None,
        )
        return build_interpretation_fallback_trigger_response(
            request_id=request_id,
            generation_id=payload.generation_id,
            requested_model=payload.model,
            provider=primary_provider,
            primary_provider=primary_provider,
            model=primary_model,
            attempted_providers=(primary_provider,),
            raw_completion="{}",
            error_code=error.code,
            error_message=error.message,
            error_details=error.details,
        )

    def _handle_cached_entry(
        self,
        cached_entry: CacheEntry,
        *,
        request_id: str,
        generation_id: str,
        requested_model: str,
        primary_provider: str,
        primary_model: str,
        cache_key: str,
        connection: psycopg.Connection,
    ) -> dict[str, Any]:
        payload, metadata = extract_cached_interpretation_envelope(
            cached_entry.response_payload,
            requested_model=requested_model,
            default_provider=primary_provider,
            default_primary_provider=primary_provider,
            default_model=primary_model,
        )
        self.cost_service.record_cache_hit(
            request_id=request_id,
            generation_id=generation_id,
            route=INTERPRET_ROUTE,
            request_type=INTERPRET_REQUEST_TYPE,
            provider=str(metadata["provider"]),
            model=str(metadata["model"]),
            requested_model=str(metadata["requested_model"]),
            cache_key=cache_key,
            metadata={
                "primary_provider": metadata["primary_provider"],
                "fallback_used": metadata["fallback_used"],
                "fallback_reason": metadata.get("fallback_reason"),
                "attempted_providers": metadata.get("attempted_providers", []),
                "cache_source": "interpretation_cache",
            },
            connection=connection,
        )
        self._set_response_headers(
            provider=str(metadata["provider"]),
            model=str(metadata["model"]),
            primary_provider=str(metadata["primary_provider"]),
            fallback_used=bool(metadata["fallback_used"]),
            fallback_reason=_normalize_optional_string(metadata.get("fallback_reason")),
        )
        return payload

    def _handle_provider_result(
        self,
        *,
        payload: InterpretationRequest,
        request_id: str,
        execution_result: ProviderExecutionResult,
        primary_provider: str,
        primary_model: str,
        cache_key: str,
        cache_request_document: dict[str, Any],
        connection: psycopg.Connection,
    ) -> dict[str, Any]:
        completion = execution_result.completion

        try:
            normalized_payload = decode_and_validate_interpretation_completion(
                completion.raw_completion,
                request=payload,
            )
        except InterpretationContractValidationError as exc:
            ledger_entry = self.cost_service.record_execution_result(
                request_id=request_id,
                request_type=payload.request_type,
                result=execution_result,
                final_status="failed",
                error_class=exc.__class__.__name__,
                error_code=exc.code,
                cache_key=cache_key,
                metadata={
                    "validation_errors": exc.details.get("errors"),
                    "validation_source": "MediaPromptInterpretationSchema",
                },
                connection=connection,
            )
            self.governance_service.record_usage(
                route=INTERPRET_ROUTE,
                provider=completion.provider,
                model=completion.model,
                request_id=request_id,
                generation_id=payload.generation_id,
                usage=completion.usage,
                estimated_cost_usd=ledger_entry.estimated_cost_usd,
                connection=connection,
            )
            self._set_response_headers(
                provider=completion.provider,
                model=completion.model,
                primary_provider=execution_result.primary_provider,
                fallback_used=execution_result.fallback_used,
                fallback_reason=execution_result.fallback_reason,
            )
            return build_interpretation_fallback_trigger_response(
                request_id=request_id,
                generation_id=payload.generation_id,
                requested_model=payload.model,
                provider=completion.provider,
                primary_provider=execution_result.primary_provider,
                model=completion.model,
                attempted_providers=execution_result.attempted_providers,
                raw_completion=exc.raw_completion,
                error_code=exc.code,
                error_message=exc.message,
                error_details=exc.details,
                fallback_used=execution_result.fallback_used,
                fallback_reason=execution_result.fallback_reason,
                upstream_request_id=completion.usage.upstream_request_id,
            )

        cache_entry = self.cache_service.store_entry(
            INTERPRET_ROUTE,
            cache_key,
            request_payload=cache_request_document,
            response_payload=build_cached_interpretation_envelope(normalized_payload, execution_result),
            connection=connection,
        )
        ledger_entry = self.cost_service.record_execution_result(
            request_id=request_id,
            request_type=payload.request_type,
            result=execution_result,
            cache_key=cache_entry.cache_key,
            metadata={
                "cache_provider_key": primary_provider,
                "cache_model_key": primary_model,
            },
            connection=connection,
        )
        self.governance_service.record_usage(
            route=INTERPRET_ROUTE,
            provider=completion.provider,
            model=completion.model,
            request_id=request_id,
            generation_id=payload.generation_id,
            usage=completion.usage,
            estimated_cost_usd=ledger_entry.estimated_cost_usd,
            connection=connection,
        )
        self._set_response_headers(
            provider=completion.provider,
            model=completion.model,
            primary_provider=execution_result.primary_provider,
            fallback_used=execution_result.fallback_used,
            fallback_reason=execution_result.fallback_reason,
        )
        return normalized_payload

    def _set_response_headers(
        self,
        *,
        provider: str,
        model: str,
        primary_provider: str,
        fallback_used: bool,
        fallback_reason: str | None,
    ) -> None:
        self.response_headers = build_llm_response_headers(
            provider=provider,
            model=model,
            primary_provider=primary_provider,
            fallback_used=fallback_used,
            fallback_reason=fallback_reason,
        )

    def _record_failure(
        self,
        *,
        payload: InterpretationRequest,
        request_id: str,
        error: AdapterError,
        primary_provider: str,
        primary_model: str,
        cache_status: Literal["miss", "bypass"],
        connection: psycopg.Connection,
        cache_key: str | None = None,
    ) -> None:
        details = error.details if isinstance(error.details, dict) else {}
        attempted_providers = _normalize_attempted_providers(
            details.get("attempted_providers"),
            fallback=[primary_provider],
        )
        provider = _normalize_optional_string(details.get("provider")) or attempted_providers[-1]
        model = _normalize_optional_string(details.get("model")) or primary_model
        fallback_reason = _normalize_optional_string(details.get("fallback_reason"))
        fallback_used = bool(details.get("fallback_used"))

        self.cost_service.record_failure(
            LedgerFailureContext(
                request_id=request_id,
                generation_id=payload.generation_id,
                route=INTERPRET_ROUTE,
                request_type=payload.request_type,
                provider=provider,
                primary_provider=primary_provider,
                model=model,
                requested_model=payload.model,
                cache_status=cache_status,
                fallback_used=fallback_used,
                fallback_reason=fallback_reason,
                attempted_providers=tuple(attempted_providers),
                error_class=error.__class__.__name__,
                error_code=error.code,
                cache_key=cache_key,
                metadata={
                    "error_details": _compact_dict(details),
                },
            ),
            connection=connection,
        )

    @contextmanager
    def _connection_scope(self):
        if self.settings.database_url == "":
            raise AdapterError(
                code="database_url_missing",
                message="Adapter state database is not configured.",
                status_code=503,
                details={"config": "LLM_ADAPTER_DATABASE_URL"},
                retryable=False,
            )

        try:
            pool = self.pool or get_database_pool(self.settings)
            with pool.connection() as connection:
                yield connection
        except AdapterError:
            raise
        except Exception as exc:
            raise AdapterError(
                code="adapter_state_unavailable",
                message="Adapter state database is unavailable.",
                status_code=503,
                details={"error_class": exc.__class__.__name__},
                retryable=True,
            ) from exc

    def _default_model_for_provider(self, provider: str, requested_model: str) -> str:
        normalized_provider = provider.strip().lower()
        if normalized_provider == "gemini":
            return self.settings.gemini_interpretation_model
        if normalized_provider == "openai":
            return self.settings.openai_interpretation_model
        return requested_model.strip()


def validate_interpretation_request_payload(
    payload: object,
    *,
    authenticated_generation_id: str | None = None,
) -> InterpretationRequest:
    if not isinstance(payload, dict):
        raise AdapterError(
            code="request_body_invalid",
            message="Interpretation request body must be a JSON object.",
            status_code=422,
            details={"received_type": type(payload).__name__},
            retryable=False,
        )

    normalized_payload = _normalize_strings(payload)
    request_type = normalized_payload.get("request_type")
    if request_type != INTERPRET_REQUEST_TYPE:
        raise AdapterError(
            code="interpret_request_type_invalid",
            message="Interpretation request_type is invalid.",
            status_code=422,
            details={
                "expected": INTERPRET_REQUEST_TYPE,
                "received": request_type,
            },
            retryable=False,
        )

    input_payload = normalized_payload.get("input")
    if not isinstance(input_payload, dict):
        raise AdapterError(
            code="interpret_input_invalid",
            message="Interpretation input payload must be a JSON object.",
            status_code=422,
            details={"path": "input"},
            retryable=False,
        )

    teacher_prompt = input_payload.get("teacher_prompt")
    if not isinstance(teacher_prompt, str) or teacher_prompt == "":
        raise AdapterError(
            code="teacher_prompt_missing",
            message="Interpretation input.teacher_prompt is required.",
            status_code=422,
            details={"path": "input.teacher_prompt"},
            retryable=False,
        )

    preferred_output_type = input_payload.get("preferred_output_type")
    if not isinstance(preferred_output_type, str) or preferred_output_type == "":
        raise AdapterError(
            code="preferred_output_type_missing",
            message="Interpretation input.preferred_output_type is required.",
            status_code=422,
            details={"path": "input.preferred_output_type"},
            retryable=False,
        )

    if preferred_output_type not in SUPPORTED_PREFERRED_OUTPUT_TYPES:
        raise AdapterError(
            code="preferred_output_type_unsupported",
            message="Interpretation preferred_output_type is not supported.",
            status_code=422,
            details={
                "path": "input.preferred_output_type",
                "allowed": list(SUPPORTED_PREFERRED_OUTPUT_TYPES),
                "received": preferred_output_type,
            },
            retryable=False,
        )

    try:
        request = InterpretationRequest.model_validate(normalized_payload)
    except ValidationError as exc:
        raise AdapterError(
            code="interpret_request_invalid",
            message="Interpretation request payload failed validation.",
            status_code=422,
            details={"errors": exc.errors()},
            retryable=False,
        ) from exc

    if authenticated_generation_id is not None and request.generation_id != authenticated_generation_id:
        raise AdapterError(
            code="generation_id_mismatch",
            message="Interpretation generation_id does not match the authenticated request headers.",
            status_code=401,
            details={
                "header_generation_id": authenticated_generation_id,
                "body_generation_id": request.generation_id,
            },
            retryable=False,
        )

    return request


def decode_and_validate_interpretation_completion(
    raw_completion: str,
    *,
    request: InterpretationRequest | None = None,
) -> dict[str, Any]:
    trimmed_completion = raw_completion.strip()
    if trimmed_completion == "":
        raise InterpretationContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion was empty.",
            details={"reason": "empty_completion"},
            raw_completion=raw_completion,
        )

    from app.content_integrity_classifier import ContentIntegrityClassifier
    import re
    
    # Detect and repair role play breaks before interpretation
    pattern = re.compile(r"\b(as claude|as an ai|i'm chatgpt|i am chatgpt|as a language model)\b", re.IGNORECASE)
    cleaned_completion = pattern.sub("", trimmed_completion)
    role_play_detected = cleaned_completion != trimmed_completion

    decoded = _decode_json_object_completion(cleaned_completion)
    normalized_payload = _decode_embedded_json(_normalize_strings(decoded))
    repaired_payload = _repair_interpretation_payload(normalized_payload, request=request)

    if role_play_detected:
        repaired_payload["_meta_repairs"] = repaired_payload.get("_meta_repairs", {})
        repaired_payload["_meta_repairs"]["role_play_break"] = True
        
    classifier = ContentIntegrityClassifier()
    output_type = "pdf"
    if request is not None and hasattr(request, "input") and request.input is not None:
        output_type = getattr(request.input, "preferred_output_type", "pdf")
        
    integrity_result = classifier.classify_payload(repaired_payload, output_type)
    repaired_payload["content_integrity"] = integrity_result

    try:
        validated_payload = InterpretationPayload.model_validate(repaired_payload)
    except ValidationError as exc:
        raise InterpretationContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion failed MediaPromptInterpretationSchema validation.",
            details={"errors": exc.errors()},
            raw_completion=raw_completion,
        ) from exc

    normalized = validated_payload.model_dump(mode="python", by_alias=True)
    normalized["output_type_candidates"] = sorted(
        normalized["output_type_candidates"],
        key=lambda candidate: candidate["score"],
        reverse=True,
    )
    return normalized


def build_cached_interpretation_envelope(
    payload: dict[str, Any],
    execution_result: ProviderExecutionResult,
) -> dict[str, Any]:
    completion = execution_result.completion
    return {
        "payload": payload,
        "_meta": {
            "provider": completion.provider,
            "primary_provider": execution_result.primary_provider,
            "model": completion.model,
            "requested_model": completion.requested_model,
            "fallback_used": execution_result.fallback_used,
            "fallback_reason": execution_result.fallback_reason,
            "attempted_providers": list(execution_result.attempted_providers),
            "upstream_request_id": completion.usage.upstream_request_id,
        },
    }


def extract_cached_interpretation_envelope(
    response_payload: dict[str, Any],
    *,
    requested_model: str,
    default_provider: str,
    default_primary_provider: str,
    default_model: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    cached_payload = response_payload.get("payload") if isinstance(response_payload, dict) else None
    cached_meta = response_payload.get("_meta") if isinstance(response_payload, dict) else None

    if not isinstance(cached_payload, dict):
        return response_payload, {
            "provider": default_provider,
            "primary_provider": default_primary_provider,
            "model": default_model,
            "requested_model": requested_model,
            "fallback_used": False,
            "fallback_reason": None,
            "attempted_providers": [default_provider],
        }

    metadata = cached_meta if isinstance(cached_meta, dict) else {}
    return cached_payload, {
        "provider": _normalize_optional_string(metadata.get("provider")) or default_provider,
        "primary_provider": _normalize_optional_string(metadata.get("primary_provider")) or default_primary_provider,
        "model": _normalize_optional_string(metadata.get("model")) or default_model,
        "requested_model": _normalize_optional_string(metadata.get("requested_model")) or requested_model,
        "fallback_used": bool(metadata.get("fallback_used")),
        "fallback_reason": _normalize_optional_string(metadata.get("fallback_reason")),
        "attempted_providers": _normalize_attempted_providers(
            metadata.get("attempted_providers"),
            fallback=[default_provider],
        ),
    }


def build_interpretation_fallback_trigger_response(
    *,
    request_id: str,
    generation_id: str,
    requested_model: str,
    provider: str,
    primary_provider: str,
    model: str,
    attempted_providers: tuple[str, ...] | list[str],
    raw_completion: str,
    error_code: str,
    error_message: str,
    error_details: dict[str, Any] | None = None,
    fallback_used: bool = False,
    fallback_reason: str | None = None,
    upstream_request_id: str | None = None,
) -> dict[str, Any]:
    normalized_completion = raw_completion.strip() or "{}"
    normalized_attempted_providers = _normalize_attempted_providers(
        attempted_providers,
        fallback=[primary_provider],
    )

    return {
        "output_text": normalized_completion,
        "error": {
            "code": error_code,
            "message": error_message,
            "details": _compact_dict(error_details or {}),
            "retryable": False,
        },
        "response_meta": _compact_dict(
            {
                "request_id": request_id,
                "generation_id": generation_id,
                "route": INTERPRET_ROUTE,
                "provider": provider,
                "primary_provider": primary_provider,
                "model": model,
                "requested_model": requested_model,
                "attempted_providers": normalized_attempted_providers,
                "fallback_used": fallback_used,
                "fallback_reason": fallback_reason,
                "upstream_request_id": upstream_request_id,
                "validation_failed": True,
            }
        ),
    }


def _normalize_strings(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _normalize_strings(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_normalize_strings(item) for item in value]
    if isinstance(value, str):
        return value.strip()
    return value


def _decode_json_object_completion(raw_completion: str) -> dict[str, Any]:
    trimmed_completion = raw_completion.strip()
    candidates = [trimmed_completion]
    extracted_object = _extract_first_json_object(trimmed_completion)
    if extracted_object is not None and extracted_object != trimmed_completion:
        candidates.append(extracted_object)

    last_json_error: str | None = None
    last_received_type: str | None = None

    for candidate in candidates:
        try:
            decoded = json.loads(candidate)
        except json.JSONDecodeError as exc:
            last_json_error = str(exc)
            continue

        if isinstance(decoded, dict):
            return decoded

        last_received_type = type(decoded).__name__

    if last_received_type is not None:
        raise InterpretationContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion must decode to a JSON object.",
            details={"received_type": last_received_type},
            raw_completion=raw_completion,
        )

    raise InterpretationContractValidationError(
        code="provider_response_contract_invalid",
        message="Provider completion was not valid JSON.",
        details={"json_error": last_json_error or "No JSON object found in provider completion."},
        raw_completion=raw_completion,
    )


def _extract_first_json_object(value: str) -> str | None:
    start_index = value.find("{")
    if start_index < 0:
        return None

    depth = 0
    in_string = False
    escaping = False

    for index in range(start_index, len(value)):
        character = value[index]

        if in_string:
            if escaping:
                escaping = False
            elif character == "\\":
                escaping = True
            elif character == '"':
                in_string = False
            continue

        if character == '"':
            in_string = True
            continue

        if character == "{":
            depth += 1
            continue

        if character == "}":
            depth -= 1
            if depth == 0:
                return value[start_index : index + 1]

    return None


def _decode_embedded_json(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _decode_embedded_json(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_decode_embedded_json(item) for item in value]
    if isinstance(value, str):
        normalized = value.strip()
        if normalized.startswith("{") and normalized.endswith("}"):
            try:
                return _decode_embedded_json(json.loads(normalized))
            except ValueError:
                return normalized
        if normalized.startswith("[") and normalized.endswith("]"):
            try:
                return _decode_embedded_json(json.loads(normalized))
            except ValueError:
                return normalized
        return normalized
    return value


def _repair_interpretation_payload(
    payload: dict[str, Any],
    *,
    request: InterpretationRequest | None = None,
) -> dict[str, Any]:
    allow_synthesis = _payload_has_repairable_signal(payload)
    request_input = request.input if request is not None else None
    teacher_prompt = _truncate_string(
        _first_non_empty_string(
            _first_present_value(payload, "teacher_prompt", "prompt"),
            request_input.teacher_prompt if request_input is not None and allow_synthesis else None,
        ),
        5000,
    )
    preferred_output_type = _resolve_preferred_output_type(
        payload,
        request=request,
        allow_synthesis=allow_synthesis,
    )
    teacher_intent = _coerce_teacher_intent(
        _first_present_value(payload, "teacher_intent", "intent"),
        teacher_prompt=teacher_prompt,
        allow_synthesis=allow_synthesis,
    )
    learning_objectives = _coerce_string_list(
        _first_present_value(payload, "learning_objectives", "objectives", "learning_goals"),
        max_length=300,
        allow_synthesis=allow_synthesis,
    )
    constraints = _coerce_constraints(
        _first_present_value(payload, "constraints", "constraint"),
        payload=payload,
        preferred_output_type=preferred_output_type,
        allow_synthesis=allow_synthesis,
    )
    output_type_candidates = _coerce_output_type_candidates(
        _first_present_value(payload, "output_type_candidates", "candidate_output_types", "output_formats"),
        payload=payload,
        preferred_output_type=preferred_output_type,
        allow_synthesis=allow_synthesis,
    )
    resolved_output_type_reasoning = _truncate_string(
        _first_non_empty_string(
            _first_present_value(
                payload,
                "resolved_output_type_reasoning",
                "output_type_reasoning",
                "output_reasoning",
            )
        ),
        1000,
    )
    if resolved_output_type_reasoning is None and allow_synthesis and output_type_candidates:
        resolved_output_type_reasoning = _format_output_type_reasoning(output_type_candidates[0]["type"])

    teacher_delivery_summary = _truncate_string(
        _first_non_empty_string(
            _first_present_value(payload, "teacher_delivery_summary", "delivery_summary", "summary_for_teacher")
        ),
        1000,
    )
    if teacher_delivery_summary is None and allow_synthesis:
        teacher_delivery_summary = _format_teacher_delivery_summary(teacher_intent, teacher_prompt)

    document_blueprint = _coerce_document_blueprint(
        _first_present_value(payload, "document_blueprint", "blueprint", "outline"),
        payload=payload,
        teacher_prompt=teacher_prompt,
        teacher_intent=teacher_intent,
        learning_objectives=learning_objectives,
        constraints=constraints,
        teacher_delivery_summary=teacher_delivery_summary,
        allow_synthesis=allow_synthesis,
    )
    requested_media_characteristics = _coerce_requested_media_characteristics(
        _first_present_value(payload, "requested_media_characteristics", "media_characteristics"),
        payload=payload,
        preferred_output_type=preferred_output_type,
        allow_synthesis=allow_synthesis,
    )
    assets = _coerce_assets(_first_present_value(payload, "assets", "required_assets"))
    assessment_blocks = _coerce_assessment_blocks(
        _first_present_value(payload, "assessment_or_activity_blocks", "assessment_blocks", "activities")
    )
    confidence = _coerce_confidence(
        _first_present_value(payload, "confidence", "confidence_score", "confidence_label"),
        allow_synthesis=allow_synthesis,
    )
    fallback = _coerce_fallback(_first_present_value(payload, "fallback"))

    repaired_payload: dict[str, Any] = {
        "schema_version": INTERPRETATION_SCHEMA_VERSION,
    }

    if teacher_prompt is not None:
        repaired_payload["teacher_prompt"] = teacher_prompt

    language = _truncate_string(
        _first_non_empty_string(_first_present_value(payload, "language", "locale")),
        32,
    )
    if language is None and allow_synthesis and teacher_prompt is not None:
        language = _infer_language_from_prompt(teacher_prompt)
    if language is not None:
        repaired_payload["language"] = language

    if teacher_intent is not None:
        repaired_payload["teacher_intent"] = teacher_intent
    if learning_objectives is not None:
        repaired_payload["learning_objectives"] = learning_objectives
    if constraints is not None:
        repaired_payload["constraints"] = constraints
    if output_type_candidates is not None:
        repaired_payload["output_type_candidates"] = output_type_candidates
    if resolved_output_type_reasoning is not None:
        repaired_payload["resolved_output_type_reasoning"] = resolved_output_type_reasoning
    if document_blueprint is not None:
        repaired_payload["document_blueprint"] = document_blueprint

    subject_context = _coerce_context_object(
        _first_present_value(payload, "subject_context"),
        label_key="subject_name",
        fallback_name=request_input.subject_context.name if request_input is not None and request_input.subject_context is not None and allow_synthesis else None,
        fallback_slug=request_input.subject_context.slug if request_input is not None and request_input.subject_context is not None and allow_synthesis else None,
    )
    if subject_context is not None:
        repaired_payload["subject_context"] = subject_context

    sub_subject_context = _coerce_context_object(
        _first_present_value(payload, "sub_subject_context", "subtopic_context"),
        label_key="sub_subject_name",
        fallback_name=request_input.sub_subject_context.name if request_input is not None and request_input.sub_subject_context is not None and allow_synthesis else None,
        fallback_slug=request_input.sub_subject_context.slug if request_input is not None and request_input.sub_subject_context is not None and allow_synthesis else None,
    )
    if sub_subject_context is not None:
        repaired_payload["sub_subject_context"] = sub_subject_context

    target_audience = _coerce_target_audience(_first_present_value(payload, "target_audience", "audience"))
    if target_audience is not None:
        repaired_payload["target_audience"] = target_audience
    if requested_media_characteristics is not None:
        repaired_payload["requested_media_characteristics"] = requested_media_characteristics
    if assets is not None:
        repaired_payload["assets"] = assets
    if assessment_blocks is not None:
        repaired_payload["assessment_or_activity_blocks"] = assessment_blocks
    if teacher_delivery_summary is not None:
        repaired_payload["teacher_delivery_summary"] = teacher_delivery_summary
    if confidence is not None:
        repaired_payload["confidence"] = confidence
    if fallback is not None:
        repaired_payload["fallback"] = fallback

    return repaired_payload


def _payload_has_repairable_signal(payload: dict[str, Any]) -> bool:
    signal_values = [
        _first_present_value(payload, "teacher_intent", "intent"),
        _first_present_value(payload, "learning_objectives", "objectives", "learning_goals"),
        _first_present_value(payload, "constraints", "preferred_output_type", "must_include", "avoid"),
        _first_present_value(payload, "output_type_candidates", "candidate_output_types", "output_formats"),
        _first_present_value(payload, "resolved_output_type_reasoning", "output_type_reasoning", "output_reasoning"),
        _first_present_value(payload, "document_blueprint", "blueprint", "title", "summary", "sections"),
        _first_present_value(payload, "teacher_delivery_summary", "delivery_summary"),
        _first_present_value(payload, "confidence", "confidence_score", "confidence_label"),
    ]
    return sum(1 for value in signal_values if _has_nonempty_value(value)) >= 3


def _resolve_preferred_output_type(
    payload: dict[str, Any],
    *,
    request: InterpretationRequest | None,
    allow_synthesis: bool,
) -> str | None:
    constraints_payload = payload.get("constraints")
    if isinstance(constraints_payload, dict):
        normalized = _normalize_output_type(
            _first_present_value(
                constraints_payload,
                "preferred_output_type",
                "preferred_format",
                "output_type",
                "format",
            ),
            allow_auto=True,
        )
        if normalized is not None:
            return normalized

    normalized = _normalize_output_type(
        _first_present_value(payload, "preferred_output_type", "output_type", "format"),
        allow_auto=True,
    )
    if normalized is not None:
        return normalized

    if allow_synthesis and request is not None:
        normalized = _normalize_output_type(request.input.preferred_output_type, allow_auto=True)
        if normalized is not None:
            return normalized

    return None


def _coerce_teacher_intent(
    value: object,
    *,
    teacher_prompt: str | None,
    allow_synthesis: bool,
) -> dict[str, Any] | None:
    if isinstance(value, dict):
        goal = _truncate_string(
            _first_non_empty_string(
                _first_present_value(value, "goal", "summary", "description", "intent")
            ),
            500,
        )
        intent_type = _truncate_string(
            _first_non_empty_string(_first_present_value(value, "type", "intent_type", "category")),
            100,
        )
        preferred_delivery_mode = _truncate_string(
            _first_non_empty_string(
                _first_present_value(value, "preferred_delivery_mode", "delivery_mode", "delivery", "mode")
            ),
            100,
        )
        requires_clarification = _coerce_bool(
            _first_present_value(value, "requires_clarification", "clarification_required", "needs_clarification"),
            default=False,
        )

        if goal is None and intent_type is not None and "_" not in intent_type and " " in intent_type:
            goal = _truncate_string(intent_type, 500)
            intent_type = None

        if goal is None and not allow_synthesis:
            return None

        return {
            "type": intent_type or "generate_learning_media",
            "goal": goal or _truncate_string(teacher_prompt, 500) or "Create a classroom-ready learning resource.",
            "preferred_delivery_mode": preferred_delivery_mode or "digital_download",
            "requires_clarification": requires_clarification,
        }

    if isinstance(value, str) and value.strip() != "":
        goal = _truncate_string(value, 500)
        return {
            "type": "generate_learning_media",
            "goal": goal,
            "preferred_delivery_mode": "digital_download",
            "requires_clarification": goal.endswith("?"),
        }

    if not allow_synthesis:
        return None

    synthesized_goal = _truncate_string(teacher_prompt, 500)
    if synthesized_goal is None:
        return None

    return {
        "type": "generate_learning_media",
        "goal": synthesized_goal,
        "preferred_delivery_mode": "digital_download",
        "requires_clarification": False,
    }


def _coerce_constraints(
    value: object,
    *,
    payload: dict[str, Any],
    preferred_output_type: str | None,
    allow_synthesis: bool,
) -> dict[str, Any] | None:
    raw_constraints = value if isinstance(value, dict) else {}
    resolved_preferred_output_type = _normalize_output_type(
        _first_present_value(
            raw_constraints,
            "preferred_output_type",
            "preferred_format",
            "output_type",
            "format",
        ),
        allow_auto=True,
    ) or preferred_output_type
    if resolved_preferred_output_type is None and not allow_synthesis:
        return None

    if isinstance(value, str) and resolved_preferred_output_type is None:
        resolved_preferred_output_type = _normalize_output_type(value, allow_auto=True)

    if resolved_preferred_output_type is None:
        resolved_preferred_output_type = "auto"

    max_duration_minutes = _coerce_int(
        _first_present_value(
            raw_constraints,
            "max_duration_minutes",
            "duration_minutes",
            "estimated_duration_minutes",
        )
    )
    must_include = _coerce_string_list(
        _first_present_value(raw_constraints, "must_include", "include", "requirements", "required_elements"),
        max_length=300,
        allow_synthesis=True,
    ) or []
    avoid = _coerce_string_list(
        _first_present_value(raw_constraints, "avoid", "avoid_terms", "exclude"),
        max_length=300,
        allow_synthesis=True,
    ) or []
    tone = _truncate_string(
        _first_non_empty_string(_first_present_value(raw_constraints, "tone", "style")),
        100,
    )

    return {
        "preferred_output_type": resolved_preferred_output_type,
        "max_duration_minutes": max_duration_minutes,
        "must_include": must_include,
        "avoid": avoid,
        "tone": tone,
    }


def _coerce_output_type_candidates(
    value: object,
    *,
    payload: dict[str, Any],
    preferred_output_type: str | None,
    allow_synthesis: bool,
) -> list[dict[str, Any]] | None:
    raw_candidates: list[dict[str, Any]] = []

    if isinstance(value, list):
        for item in value:
            normalized_candidate = _coerce_output_candidate(item)
            if normalized_candidate is not None:
                raw_candidates.append(normalized_candidate)
    elif isinstance(value, dict):
        nested_candidates = _first_present_value(value, "candidates", "items", "values")
        if nested_candidates is not None and nested_candidates is not value:
            return _coerce_output_type_candidates(
                nested_candidates,
                payload=payload,
                preferred_output_type=preferred_output_type,
                allow_synthesis=allow_synthesis,
            )

        for key, item in value.items():
            candidate_type = _normalize_output_type(key, allow_auto=False)
            if candidate_type is None:
                continue

            score: float | None = None
            reason: str | None = None
            if isinstance(item, dict):
                score = _coerce_float(_first_present_value(item, "score", "confidence", "probability"))
                reason = _truncate_string(
                    _first_non_empty_string(_first_present_value(item, "reason", "explanation", "why")),
                    500,
                )
            else:
                score = _coerce_float(item)

            raw_candidates.append({
                "type": candidate_type,
                "score": score,
                "reason": reason,
            })
    elif isinstance(value, str) and value.strip() != "":
        candidate_tokens = value.replace("|", ",").replace(";", ",").split(",")
        for token in candidate_tokens:
            candidate_type = _normalize_output_type(token, allow_auto=False)
            if candidate_type is not None:
                raw_candidates.append({"type": candidate_type, "score": None, "reason": None})

    if not raw_candidates and allow_synthesis:
        if preferred_output_type is not None and preferred_output_type != "auto":
            raw_candidates = [{"type": preferred_output_type, "score": 0.82, "reason": None}]
        else:
            raw_candidates = [
                {"type": candidate_type, "score": None, "reason": None}
                for candidate_type in SUPPORTED_OUTPUT_FORMATS
            ]

    if not raw_candidates:
        return None

    ordered_types: list[str] = []
    if preferred_output_type in SUPPORTED_OUTPUT_FORMATS:
        ordered_types.append(preferred_output_type)

    unique_candidates: dict[str, dict[str, Any]] = {}
    for candidate in raw_candidates:
        candidate_type = candidate["type"]
        if candidate_type not in ordered_types:
            ordered_types.append(candidate_type)

        existing_candidate = unique_candidates.get(candidate_type)
        if existing_candidate is None:
            unique_candidates[candidate_type] = candidate
            continue

        if existing_candidate.get("score") is None and candidate.get("score") is not None:
            unique_candidates[candidate_type] = candidate

    default_scores = [0.82, 0.64, 0.46]
    normalized_candidates: list[dict[str, Any]] = []
    for index, candidate_type in enumerate(ordered_types):
        candidate = unique_candidates[candidate_type]
        score = candidate.get("score")
        if score is None:
            score = default_scores[index] if index < len(default_scores) else max(0.1, round(0.46 - ((index - 2) * 0.1), 4))
        score = min(max(round(float(score), 4), 0.0), 1.0)
        reason = candidate.get("reason") or _format_candidate_reason(candidate_type, preferred_output_type)
        normalized_candidates.append(
            {
                "type": candidate_type,
                "score": score,
                "reason": _truncate_string(reason, 500) or "Matches the interpreted request.",
            }
        )

    return sorted(normalized_candidates, key=lambda candidate: candidate["score"], reverse=True)


def _coerce_output_candidate(value: object) -> dict[str, Any] | None:
    if isinstance(value, dict):
        candidate_type = _normalize_output_type(
            _first_present_value(value, "type", "output_type", "format", "name"),
            allow_auto=False,
        )
        if candidate_type is None:
            return None
        return {
            "type": candidate_type,
            "score": _coerce_float(_first_present_value(value, "score", "confidence", "probability")),
            "reason": _truncate_string(
                _first_non_empty_string(_first_present_value(value, "reason", "explanation", "why")),
                500,
            ),
        }

    if isinstance(value, str) and value.strip() != "":
        candidate_type = _normalize_output_type(value, allow_auto=False)
        if candidate_type is None:
            return None
        return {
            "type": candidate_type,
            "score": None,
            "reason": None,
        }

    return None


def _coerce_document_blueprint(
    value: object,
    *,
    payload: dict[str, Any],
    teacher_prompt: str | None,
    teacher_intent: dict[str, Any] | None,
    learning_objectives: list[str] | None,
    constraints: dict[str, Any] | None,
    teacher_delivery_summary: str | None,
    allow_synthesis: bool,
) -> dict[str, Any] | None:
    raw_blueprint = value if isinstance(value, dict) else {}
    title = _truncate_string(
        _first_non_empty_string(
            _first_present_value(raw_blueprint, "title", "name"),
            _first_present_value(payload, "title", "document_title"),
        ),
        200,
    )
    summary = _truncate_string(
        _first_non_empty_string(
            _first_present_value(raw_blueprint, "summary", "description", "overview"),
            _first_present_value(payload, "summary", "document_summary"),
            teacher_delivery_summary,
            teacher_intent.get("goal") if isinstance(teacher_intent, dict) else None,
        ),
        1000,
    )
    sections = _coerce_blueprint_sections(
        _first_present_value(raw_blueprint, "sections", "outline", "blocks")
        if isinstance(raw_blueprint, dict)
        else None,
        payload=payload,
        teacher_intent=teacher_intent,
        learning_objectives=learning_objectives,
        constraints=constraints,
        teacher_prompt=teacher_prompt,
        allow_synthesis=allow_synthesis,
    )

    if title is None and allow_synthesis:
        title = _title_from_prompt(teacher_prompt)
    if summary is None and allow_synthesis:
        summary = _truncate_string(
            teacher_delivery_summary
            or (teacher_intent.get("goal") if isinstance(teacher_intent, dict) else None)
            or teacher_prompt,
            1000,
        )

    if sections is None and allow_synthesis:
        section_bullets = learning_objectives or (constraints or {}).get("must_include") or []
        if not section_bullets and teacher_prompt is not None:
            section_bullets = [_truncate_string(teacher_prompt, 300) or "Teacher request received."]
        sections = [
            {
                "title": "Requested Content",
                "purpose": _truncate_string(
                    (teacher_intent.get("goal") if isinstance(teacher_intent, dict) else None)
                    or teacher_delivery_summary
                    or "Deliver the requested learning material clearly.",
                    500,
                )
                or "Deliver the requested learning material clearly.",
                "bullets": section_bullets[:3],
                "estimated_length": "medium",
            }
        ]

    if title is None or summary is None or sections is None:
        return None

    return {
        "title": title,
        "summary": summary,
        "sections": sections,
    }


def _coerce_blueprint_sections(
    value: object,
    *,
    payload: dict[str, Any],
    teacher_intent: dict[str, Any] | None,
    learning_objectives: list[str] | None,
    constraints: dict[str, Any] | None,
    teacher_prompt: str | None,
    allow_synthesis: bool,
) -> list[dict[str, Any]] | None:
    section_source = value if value is not None else _first_present_value(payload, "sections", "outline", "blocks")
    normalized_sections: list[dict[str, Any]] = []

    if isinstance(section_source, list):
        for item in section_source:
            section = _coerce_blueprint_section(
                item,
                teacher_intent=teacher_intent,
                learning_objectives=learning_objectives,
                constraints=constraints,
                teacher_prompt=teacher_prompt,
                allow_synthesis=allow_synthesis,
            )
            if section is not None:
                normalized_sections.append(section)
    elif isinstance(section_source, str) and section_source.strip() != "":
        section = _coerce_blueprint_section(
            section_source,
            teacher_intent=teacher_intent,
            learning_objectives=learning_objectives,
            constraints=constraints,
            teacher_prompt=teacher_prompt,
            allow_synthesis=allow_synthesis,
        )
        if section is not None:
            normalized_sections.append(section)

    return normalized_sections or None


def _coerce_blueprint_section(
    value: object,
    *,
    teacher_intent: dict[str, Any] | None,
    learning_objectives: list[str] | None,
    constraints: dict[str, Any] | None,
    teacher_prompt: str | None,
    allow_synthesis: bool,
) -> dict[str, Any] | None:
    if isinstance(value, dict):
        title = _truncate_string(
            _first_non_empty_string(_first_present_value(value, "title", "name", "heading")),
            200,
        )
        purpose = _truncate_string(
            _first_non_empty_string(_first_present_value(value, "purpose", "summary", "description", "objective")),
            500,
        )
        bullets = _coerce_string_list(
            _first_present_value(value, "bullets", "items", "key_points", "objectives"),
            max_length=300,
            allow_synthesis=True,
        ) or []
        estimated_length = _normalize_estimated_length(
            _first_present_value(value, "estimated_length", "length", "size")
        )
        if title is None and not allow_synthesis:
            return None
        return {
            "title": title or "Requested Content",
            "purpose": purpose
            or _truncate_string(
                (teacher_intent.get("goal") if isinstance(teacher_intent, dict) else None)
                or "Deliver the requested learning material clearly.",
                500,
            )
            or "Deliver the requested learning material clearly.",
            "bullets": bullets,
            "estimated_length": estimated_length or "medium",
        }

    if isinstance(value, str) and value.strip() != "":
        title = _truncate_string(value, 200) or "Requested Content"
        bullets = learning_objectives or (constraints or {}).get("must_include") or []
        if not bullets and teacher_prompt is not None:
            bullets = [_truncate_string(teacher_prompt, 300) or "Teacher request received."]
        return {
            "title": title,
            "purpose": _truncate_string(
                (teacher_intent.get("goal") if isinstance(teacher_intent, dict) else None)
                or title,
                500,
            )
            or title,
            "bullets": bullets[:3],
            "estimated_length": "medium",
        }

    return None


def _coerce_context_object(
    value: object,
    *,
    label_key: str,
    fallback_name: str | None,
    fallback_slug: str | None,
) -> dict[str, Any] | None:
    if isinstance(value, dict):
        name = _truncate_string(
            _first_non_empty_string(_first_present_value(value, label_key, "name", "label")),
            100,
        )
        if name is None:
            return None
        return {
            label_key: name,
            label_key.replace("name", "slug"): _truncate_string(
                _first_non_empty_string(_first_present_value(value, label_key.replace("name", "slug"), "slug")),
                100,
            ),
        }

    if isinstance(value, str) and value.strip() != "":
        return {
            label_key: _truncate_string(value, 100),
            label_key.replace("name", "slug"): None,
        }

    if fallback_name is None:
        return None

    return {
        label_key: _truncate_string(fallback_name, 100),
        label_key.replace("name", "slug"): _truncate_string(fallback_slug, 100),
    }


def _coerce_target_audience(value: object) -> dict[str, Any] | None:
    if isinstance(value, dict):
        label = _truncate_string(
            _first_non_empty_string(_first_present_value(value, "label", "name", "audience")),
            100,
        )
        if label is None:
            return None
        return {
            "label": label,
            "level": _truncate_string(_first_non_empty_string(_first_present_value(value, "level", "grade_level")), 100),
            "age_range": _truncate_string(_first_non_empty_string(_first_present_value(value, "age_range", "ages")), 100),
        }

    if isinstance(value, str) and value.strip() != "":
        return {
            "label": _truncate_string(value, 100),
            "level": None,
            "age_range": None,
        }

    return None


def _coerce_requested_media_characteristics(
    value: object,
    *,
    payload: dict[str, Any],
    preferred_output_type: str | None,
    allow_synthesis: bool,
) -> dict[str, Any] | None:
    raw_value = value if isinstance(value, dict) else {}
    tone = _truncate_string(
        _first_non_empty_string(_first_present_value(raw_value, "tone", "style")),
        100,
    )
    format_preferences = _coerce_string_list(
        _first_present_value(raw_value, "format_preferences", "formats", "preferences"),
        max_length=100,
        allow_synthesis=allow_synthesis,
    )
    if format_preferences is None and isinstance(value, str) and value.strip() != "":
        format_preferences = _coerce_string_list(value, max_length=100, allow_synthesis=True)
    if (format_preferences is None or format_preferences == []) and allow_synthesis and preferred_output_type not in {None, "auto"}:
        format_preferences = [preferred_output_type]

    visual_density = _normalize_visual_density(_first_present_value(raw_value, "visual_density", "density"))
    if tone is None and format_preferences is None and visual_density is None and not allow_synthesis:
        return None

    return {
        "tone": tone,
        "format_preferences": format_preferences or [],
        "visual_density": visual_density,
    }


def _coerce_assets(value: object) -> list[dict[str, Any]] | None:
    if not isinstance(value, list):
        return None

    normalized_assets: list[dict[str, Any]] = []
    for item in value:
        normalized_asset = _coerce_asset(item)
        if normalized_asset is not None:
            normalized_assets.append(normalized_asset)

    return normalized_assets


def _coerce_asset(value: object) -> dict[str, Any] | None:
    if isinstance(value, dict):
        description = _truncate_string(
            _first_non_empty_string(_first_present_value(value, "description", "text", "label", "name")),
            500,
        )
        if description is None:
            return None
        return {
            "type": _normalize_asset_type(_first_present_value(value, "type", "kind")) or "text",
            "description": description,
            "required": _coerce_bool(_first_present_value(value, "required", "mandatory"), default=False),
        }

    if isinstance(value, str) and value.strip() != "":
        return {
            "type": "text",
            "description": _truncate_string(value, 500) or "Requested asset.",
            "required": False,
        }

    return None


def _coerce_assessment_blocks(value: object) -> list[dict[str, Any]] | None:
    if not isinstance(value, list):
        return None

    normalized_blocks: list[dict[str, Any]] = []
    for item in value:
        normalized_block = _coerce_assessment_block(item)
        if normalized_block is not None:
            normalized_blocks.append(normalized_block)

    return normalized_blocks


def _coerce_assessment_block(value: object) -> dict[str, Any] | None:
    if isinstance(value, dict):
        title = _truncate_string(
            _first_non_empty_string(_first_present_value(value, "title", "name", "label")),
            200,
        )
        instructions = _truncate_string(
            _first_non_empty_string(_first_present_value(value, "instructions", "description", "summary")),
            1000,
        )
        if title is None or instructions is None:
            return None
        return {
            "title": title,
            "type": _normalize_assessment_block_type(_first_present_value(value, "type", "kind")) or "activity",
            "instructions": instructions,
        }

    if isinstance(value, str) and value.strip() != "":
        return {
            "title": _truncate_string(value, 200) or "Classroom Activity",
            "type": "activity",
            "instructions": _truncate_string(value, 1000) or "Run the described classroom activity.",
        }

    return None


def _coerce_confidence(value: object, *, allow_synthesis: bool) -> dict[str, Any] | None:
    score: float | None = None
    label: str | None = None
    rationale: str | None = None

    if isinstance(value, dict):
        score = _coerce_float(_first_present_value(value, "score", "value"))
        label = _normalize_confidence_label(_first_present_value(value, "label", "level"))
        rationale = _truncate_string(
            _first_non_empty_string(_first_present_value(value, "rationale", "reason", "explanation")),
            500,
        )
    elif isinstance(value, str) and value.strip() != "":
        numeric_score = _coerce_float(value)
        if numeric_score is not None:
            score = numeric_score
        else:
            label = _normalize_confidence_label(value)
    else:
        score = _coerce_float(value)

    if label is None and score is not None:
        if score >= 0.75:
            label = "high"
        elif score >= 0.45:
            label = "medium"
        else:
            label = "low"

    if score is None and label is not None:
        score = {"low": 0.25, "medium": 0.6, "high": 0.85}[label]

    if score is None and label is None and allow_synthesis:
        score = 0.6
        label = "medium"

    if score is None or label is None:
        return None

    return {
        "score": min(max(round(score, 4), 0.0), 1.0),
        "label": label,
        "rationale": rationale,
    }


def _coerce_fallback(value: object) -> dict[str, Any] | None:
    if not isinstance(value, dict):
        return None

    return {
        "triggered": _coerce_bool(_first_present_value(value, "triggered"), default=False),
        "reason_code": _truncate_string(_first_non_empty_string(_first_present_value(value, "reason_code", "reason")), 100),
        "action": _truncate_string(_first_non_empty_string(_first_present_value(value, "action")), 100),
    }


def _coerce_string_list(
    value: object,
    *,
    max_length: int,
    allow_synthesis: bool,
) -> list[str] | None:
    if isinstance(value, dict):
        return _coerce_string_list(
            _first_present_value(value, "items", "values", "list", "bullets", "objectives"),
            max_length=max_length,
            allow_synthesis=allow_synthesis,
        )

    if isinstance(value, list):
        normalized_items: list[str] = []
        for item in value:
            if isinstance(item, str):
                normalized_items.extend(_split_text_items(item, max_length=max_length))
                continue
            if isinstance(item, dict):
                text = _truncate_string(
                    _first_non_empty_string(_first_present_value(item, "text", "label", "name", "title")),
                    max_length,
                )
                if text is not None:
                    normalized_items.append(text)
        return normalized_items

    if isinstance(value, str) and value.strip() != "":
        return _split_text_items(value, max_length=max_length)

    if allow_synthesis:
        return []

    return None


def _split_text_items(value: str, *, max_length: int) -> list[str]:
    normalized = value.replace("\r", "\n")
    separators = ["\n", ";", "|", "•"]
    items = [normalized]
    for separator in separators:
        next_items: list[str] = []
        for item in items:
            next_items.extend(item.split(separator))
        items = next_items
    return [
        _truncate_string(item.strip(" -*\t"), max_length)
        for item in items
        if item.strip(" -*\t") != ""
    ]


def _first_present_value(payload: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in payload:
            return payload[key]
    return None


def _first_non_empty_string(*values: object) -> str | None:
    for value in values:
        if not isinstance(value, str):
            continue
        normalized = value.strip()
        if normalized != "":
            return normalized
    return None


def _normalize_output_type(value: object, *, allow_auto: bool) -> str | None:
    if not isinstance(value, str):
        return None
    normalized = value.strip().lower()
    if normalized == "":
        return None
    if allow_auto and normalized == "auto":
        return "auto"
    if normalized in SUPPORTED_OUTPUT_FORMATS:
        return normalized
    if normalized in {"ppt", "powerpoint", "slides", "slide deck", "presentation"}:
        return "pptx"
    if normalized in {"doc", "word", "word document", "document"}:
        return "docx"
    if normalized in {"printable", "worksheet", "handout"} or "pdf" in normalized:
        return "pdf"
    return None


def _normalize_estimated_length(value: object) -> str | None:
    normalized = _normalize_optional_string(value)
    if normalized is None:
        return None
    lowered = normalized.lower()
    if lowered in {"short", "brief", "concise"}:
        return "short"
    if lowered in {"medium", "normal", "moderate"}:
        return "medium"
    if lowered in {"long", "detailed", "comprehensive"}:
        return "long"
    return None


def _normalize_visual_density(value: object) -> str | None:
    normalized = _normalize_optional_string(value)
    if normalized is None:
        return None
    lowered = normalized.lower()
    if lowered in {"low", "light", "minimal"}:
        return "low"
    if lowered in {"medium", "balanced", "moderate"}:
        return "medium"
    if lowered in {"high", "dense", "rich"}:
        return "high"
    return None


def _normalize_confidence_label(value: object) -> str | None:
    normalized = _normalize_optional_string(value)
    if normalized is None:
        return None
    lowered = normalized.lower()
    if lowered in {"low", "uncertain"}:
        return "low"
    if lowered in {"medium", "moderate", "mixed"}:
        return "medium"
    if lowered in {"high", "very high", "confident"}:
        return "high"
    return None


def _normalize_asset_type(value: object) -> str | None:
    normalized = _normalize_optional_string(value)
    if normalized is None:
        return None
    lowered = normalized.lower()
    if lowered in {"text", "image", "table", "chart", "diagram", "reference"}:
        return lowered
    if lowered in {"graphic", "illustration", "photo"}:
        return "image"
    return None


def _normalize_assessment_block_type(value: object) -> str | None:
    normalized = _normalize_optional_string(value)
    if normalized is None:
        return None
    lowered = normalized.lower()
    if lowered in {"assessment", "activity", "reflection", "quiz", "assignment"}:
        return lowered
    if lowered in {"exercise", "task"}:
        return "activity"
    return None


def _coerce_bool(value: object, *, default: bool) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return bool(value)
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes", "required"}:
            return True
        if lowered in {"false", "0", "no", "optional"}:
            return False
    return default


def _coerce_int(value: object) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        normalized = value.strip()
        if normalized == "":
            return None
        try:
            return int(float(normalized))
        except ValueError:
            return None
    return None


def _coerce_float(value: object) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        normalized = float(value)
        if normalized > 1 and normalized <= 100:
            normalized /= 100
        return normalized
    if isinstance(value, str):
        normalized = value.strip().rstrip("%")
        if normalized == "":
            return None
        try:
            parsed = float(normalized)
        except ValueError:
            return None
        if value.strip().endswith("%") or (parsed > 1 and parsed <= 100):
            parsed /= 100
        return parsed
    return None


def _has_nonempty_value(value: object) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return value.strip() != ""
    if isinstance(value, list):
        return any(_has_nonempty_value(item) for item in value)
    if isinstance(value, dict):
        return any(_has_nonempty_value(item) for item in value.values())
    return True


def _format_candidate_reason(candidate_type: str, preferred_output_type: str | None) -> str:
    if preferred_output_type == candidate_type:
        return f"{candidate_type.upper()} aligns with the preferred output type and classroom delivery needs."
    return f"{candidate_type.upper()} remains a viable format for the interpreted classroom material."


def _format_output_type_reasoning(candidate_type: str) -> str:
    return f"{candidate_type.upper()} best matches the interpreted classroom material and delivery context."


def _format_teacher_delivery_summary(
    teacher_intent: dict[str, Any] | None,
    teacher_prompt: str | None,
) -> str | None:
    if isinstance(teacher_intent, dict):
        goal = _truncate_string(_first_non_empty_string(teacher_intent.get("goal")), 1000)
        if goal is not None:
            return goal
    return _truncate_string(teacher_prompt, 1000)


def _title_from_prompt(teacher_prompt: str | None) -> str | None:
    if teacher_prompt is None:
        return None
    first_sentence = teacher_prompt.split(".", 1)[0].strip()
    return _truncate_string(first_sentence or teacher_prompt, 200)


def _truncate_string(value: str | None, limit: int) -> str | None:
    if value is None:
        return None
    normalized = value.strip()
    if normalized == "":
        return None
    if len(normalized) <= limit:
        return normalized
    return normalized[: limit - 3].rstrip() + "..."


def _infer_language_from_prompt(prompt: str) -> str:
    lowered = prompt.lower()
    indonesian_markers = ["buatkan", "kelas", "siswa", "materi", "untuk", "dan"]
    english_markers = ["create", "grade", "students", "lesson", "for", "and"]
    indonesian_score = sum(1 for marker in indonesian_markers if marker in lowered)
    english_score = sum(1 for marker in english_markers if marker in lowered)
    if indonesian_score > english_score:
        return "id"
    if english_score > indonesian_score:
        return "en"
    return "und"


def _normalize_optional_string(value: object | None) -> str | None:
    if not isinstance(value, str):
        return None
    normalized = value.strip()
    return normalized or None


def _normalize_attempted_providers(
    value: object,
    *,
    fallback: list[str],
) -> list[str]:
    if isinstance(value, (list, tuple)):
        providers = [
            candidate.strip().lower()
            for candidate in value
            if isinstance(candidate, str) and candidate.strip() != ""
        ]
        if providers:
            return providers

    return [candidate.strip().lower() for candidate in fallback if candidate.strip() != ""]


def _compact_dict(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        key: value
        for key, value in payload.items()
        if value is not None
    }
