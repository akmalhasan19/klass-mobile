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

    @model_validator(mode="after")
    def sort_candidates(self) -> "InterpretationPayload":
        self.output_type_candidates = sorted(
            self.output_type_candidates,
            key=lambda candidate: candidate.score,
            reverse=True,
        )
        return self


@dataclass(frozen=True)
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
            normalized_payload = decode_and_validate_interpretation_completion(completion.raw_completion)
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


def decode_and_validate_interpretation_completion(raw_completion: str) -> dict[str, Any]:
    trimmed_completion = raw_completion.strip()
    if trimmed_completion == "":
        raise InterpretationContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion was empty.",
            details={"reason": "empty_completion"},
            raw_completion=raw_completion,
        )

    try:
        decoded = json.loads(trimmed_completion)
    except json.JSONDecodeError as exc:
        raise InterpretationContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion was not valid JSON.",
            details={"json_error": str(exc)},
            raw_completion=raw_completion,
        ) from exc

    if not isinstance(decoded, dict):
        raise InterpretationContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion must decode to a JSON object.",
            details={"received_type": type(decoded).__name__},
            raw_completion=raw_completion,
        )

    normalized_payload = _normalize_strings(decoded)

    try:
        validated_payload = InterpretationPayload.model_validate(normalized_payload)
    except ValidationError as exc:
        raise InterpretationContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion failed MediaPromptInterpretationSchema validation.",
            details={"errors": exc.errors()},
            raw_completion=raw_completion,
        ) from exc

    normalized = validated_payload.model_dump(mode="python")
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
