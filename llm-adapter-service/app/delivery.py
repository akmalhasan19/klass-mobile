from __future__ import annotations

import json
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Annotated, Any, Literal

import psycopg
from pydantic import BaseModel, ConfigDict, Field, ValidationError
from psycopg_pool import ConnectionPool

from app.cache import AdapterCacheService, CacheEntry, build_delivery_cache_document
from app.contracts import DELIVERY_RESPONSE_SCHEMA_VERSION, RESPOND_REQUEST_TYPE, RESPOND_ROUTE
from app.costs import AdapterCostService, LedgerFailureContext
from app.database import get_database_pool
from app.errors import AdapterError, ProviderConfigurationError, ProviderRequestError
from app.governance import AdapterGovernanceService
from app.models import DeliveryRequest
from app.providers.base import ProviderExecutionResult
from app.providers.routing import ProviderRouter
from app.response_headers import build_llm_response_headers
from app.settings import Settings, get_settings

OutputType = Literal["docx", "pdf", "pptx"]

String100 = Annotated[str, Field(min_length=1, max_length=100)]
String200 = Annotated[str, Field(min_length=1, max_length=200)]
String255 = Annotated[str, Field(min_length=1, max_length=255)]
String1000 = Annotated[str, Field(min_length=1, max_length=1000)]
String2000 = Annotated[str, Field(min_length=1, max_length=2000)]
String2048 = Annotated[str, Field(min_length=1, max_length=2048)]
OptionalString100 = Annotated[str, Field(max_length=100)] | None
OptionalString255 = Annotated[str, Field(max_length=255)] | None
OptionalString2048 = Annotated[str, Field(max_length=2048)] | None
ArrayString300 = Annotated[str, Field(max_length=300)]


class DeliveryContractModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class DeliveryResponseArtifact(DeliveryContractModel):
    output_type: OutputType
    title: String200
    file_url: String2048
    thumbnail_url: OptionalString2048 = None
    mime_type: String255
    filename: OptionalString255 = None


class DeliveryResponseTopicNode(DeliveryContractModel):
    id: String100
    title: String200


class DeliveryResponseContentNode(DeliveryContractModel):
    id: String100
    title: String200
    type: OptionalString100 = None
    media_url: OptionalString2048 = None


class DeliveryResponseRecommendedProjectNode(DeliveryContractModel):
    id: String100
    title: String200
    project_file_url: OptionalString2048 = None


class DeliveryResponsePublication(DeliveryContractModel):
    topic: DeliveryResponseTopicNode | None = None
    content: DeliveryResponseContentNode | None = None
    recommended_project: DeliveryResponseRecommendedProjectNode | None = None


class DeliveryResponseMeta(DeliveryContractModel):
    generated_at: String100
    llm_used: bool
    provider: OptionalString100 = None
    model: OptionalString100 = None


class DeliveryResponseFallback(DeliveryContractModel):
    triggered: bool = False
    reason_code: OptionalString100 = None
    action: OptionalString100 = None


class DeliveryResponsePayload(DeliveryContractModel):
    schema_version: Literal["media_delivery_response.v1"]
    title: String200
    preview_summary: String1000
    teacher_message: String2000
    recommended_next_steps: list[ArrayString300] = Field(default_factory=list)
    classroom_tips: list[ArrayString300] = Field(default_factory=list)
    artifact: DeliveryResponseArtifact
    publication: DeliveryResponsePublication
    response_meta: DeliveryResponseMeta
    fallback: DeliveryResponseFallback = Field(default_factory=DeliveryResponseFallback)


@dataclass(frozen=True)
class DeliveryContractValidationError(Exception):
    code: str
    message: str
    details: dict[str, Any]
    raw_completion: str

    def __post_init__(self) -> None:
        super().__init__(self.message)


class DeliveryWorkflowService:
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

    async def respond(
        self,
        payload: DeliveryRequest,
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
                    primary_provider=self.settings.active_delivery_provider,
                    primary_model=self._default_model_for_provider(
                        self.settings.active_delivery_provider,
                        payload.model,
                    ),
                    cache_status="bypass",
                    connection=connection,
                )
            raise

        cache_key = self.cache_service.build_delivery_cache_key(
            payload,
            provider=policy.primary_provider,
            model=primary_model,
        )
        cache_request_document = build_delivery_cache_document(
            payload,
            provider=policy.primary_provider,
            model=primary_model,
            schema_version=self.settings.cache_key_schema_version,
        )

        with self._connection_scope() as connection:
            decision = self.governance_service.preflight_check(
                route=RESPOND_ROUTE,
                provider=policy.primary_provider,
                model=primary_model,
                request_id=request_id,
                generation_id=payload.generation_id,
                connection=connection,
            )
            if not decision.allowed:
                self._raise_preflight_failure(
                    payload=payload,
                    request_id=request_id,
                    decision=decision,
                    primary_provider=policy.primary_provider,
                    primary_model=primary_model,
                    cache_key=cache_key,
                    connection=connection,
                )

            cached_entry = self.cache_service.lookup_entry(
                RESPOND_ROUTE,
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
                RESPOND_ROUTE,
                cache_key,
                connection=connection,
            )
            if not lock.acquired:
                waited_entry = self.cache_service.wait_for_inflight_entry(
                    RESPOND_ROUTE,
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
                    code="delivery_inflight_timeout",
                    message="A matching delivery request is already running and no cached result became available before the wait timeout.",
                    status_code=503,
                    details={
                        "route": RESPOND_ROUTE,
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
                execution_result = await self.provider_router.execute_delivery(payload)
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

    def _prepare_primary_route(self, payload: DeliveryRequest) -> tuple[Any, str]:
        policy = self.provider_router.policy_for_route(RESPOND_ROUTE)
        primary_client = self.provider_router.registry.build_client(policy.primary_provider, self.settings)
        normalized_request = primary_client.normalize_delivery_request(payload)
        return policy, normalized_request.model

    def _raise_preflight_failure(
        self,
        *,
        payload: DeliveryRequest,
        request_id: str,
        decision: Any,
        primary_provider: str,
        primary_model: str,
        cache_key: str,
        connection: psycopg.Connection,
    ) -> None:
        error = AdapterError(
            code=decision.code or "governance_blocked",
            message=decision.message or "Delivery request is blocked by governance policy.",
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
        raise error

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
        payload, metadata = extract_cached_delivery_envelope(
            cached_entry.response_payload,
            requested_model=requested_model,
            default_provider=primary_provider,
            default_primary_provider=primary_provider,
            default_model=primary_model,
        )
        self.cost_service.record_cache_hit(
            request_id=request_id,
            generation_id=generation_id,
            route=RESPOND_ROUTE,
            request_type=RESPOND_REQUEST_TYPE,
            provider=str(metadata["provider"]),
            model=str(metadata["model"]),
            requested_model=str(metadata["requested_model"]),
            cache_key=cache_key,
            metadata={
                "primary_provider": metadata["primary_provider"],
                "fallback_used": metadata["fallback_used"],
                "fallback_reason": metadata.get("fallback_reason"),
                "attempted_providers": metadata.get("attempted_providers", []),
                "cache_source": "delivery_cache",
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
        payload: DeliveryRequest,
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
            normalized_payload = decode_and_validate_delivery_completion(
                completion.raw_completion,
                provider=completion.provider,
                model=completion.model,
            )
        except DeliveryContractValidationError as exc:
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
                    "validation_source": "MediaDeliveryResponseSchema",
                },
                connection=connection,
            )
            self.governance_service.record_usage(
                route=RESPOND_ROUTE,
                provider=completion.provider,
                model=completion.model,
                request_id=request_id,
                generation_id=payload.generation_id,
                usage=completion.usage,
                estimated_cost_usd=ledger_entry.estimated_cost_usd,
                connection=connection,
            )
            raise AdapterError(
                code=exc.code,
                message=exc.message,
                status_code=502,
                details=_compact_dict(
                    {
                        **exc.details,
                        "route": RESPOND_ROUTE,
                        "provider": completion.provider,
                        "primary_provider": execution_result.primary_provider,
                        "model": completion.model,
                        "requested_model": completion.requested_model,
                        "attempted_providers": list(execution_result.attempted_providers),
                        "fallback_used": execution_result.fallback_used,
                        "fallback_reason": execution_result.fallback_reason,
                        "upstream_request_id": completion.usage.upstream_request_id,
                    }
                ),
                retryable=False,
            ) from exc

        cache_entry = self.cache_service.store_entry(
            RESPOND_ROUTE,
            cache_key,
            request_payload=cache_request_document,
            response_payload=build_cached_delivery_envelope(normalized_payload, execution_result),
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
            route=RESPOND_ROUTE,
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
        payload: DeliveryRequest,
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
                route=RESPOND_ROUTE,
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
            return self.settings.gemini_delivery_model
        if normalized_provider == "openai":
            return self.settings.openai_delivery_model
        return requested_model.strip()


def validate_delivery_request_payload(
    payload: object,
    *,
    authenticated_generation_id: str | None = None,
) -> DeliveryRequest:
    if not isinstance(payload, dict):
        raise AdapterError(
            code="request_body_invalid",
            message="Delivery request body must be a JSON object.",
            status_code=422,
            details={"received_type": type(payload).__name__},
            retryable=False,
        )

    normalized_payload = _normalize_strings(payload)
    request_type = normalized_payload.get("request_type")
    if request_type != RESPOND_REQUEST_TYPE:
        raise AdapterError(
            code="delivery_request_type_invalid",
            message="Delivery request_type is invalid.",
            status_code=422,
            details={
                "expected": RESPOND_REQUEST_TYPE,
                "received": request_type,
            },
            retryable=False,
        )

    input_payload = normalized_payload.get("input")
    if not isinstance(input_payload, dict):
        raise AdapterError(
            code="delivery_input_invalid",
            message="Delivery input payload must be a JSON object.",
            status_code=422,
            details={"path": "input"},
            retryable=False,
        )

    artifact_payload = input_payload.get("artifact")
    if not isinstance(artifact_payload, dict):
        raise AdapterError(
            code="delivery_artifact_invalid",
            message="Delivery input.artifact must be a JSON object.",
            status_code=422,
            details={"path": "input.artifact"},
            retryable=False,
        )

    publication_payload = input_payload.get("publication")
    if not isinstance(publication_payload, dict):
        raise AdapterError(
            code="delivery_publication_invalid",
            message="Delivery input.publication must be a JSON object.",
            status_code=422,
            details={"path": "input.publication"},
            retryable=False,
        )

    preview_summary = input_payload.get("preview_summary")
    if not isinstance(preview_summary, str) or preview_summary == "":
        raise AdapterError(
            code="preview_summary_missing",
            message="Delivery input.preview_summary is required.",
            status_code=422,
            details={"path": "input.preview_summary"},
            retryable=False,
        )

    try:
        request = DeliveryRequest.model_validate(normalized_payload)
    except ValidationError as exc:
        raise AdapterError(
            code="delivery_request_invalid",
            message="Delivery request payload failed validation.",
            status_code=422,
            details={"errors": exc.errors()},
            retryable=False,
        ) from exc

    if authenticated_generation_id is not None and request.generation_id != authenticated_generation_id:
        raise AdapterError(
            code="generation_id_mismatch",
            message="Delivery generation_id does not match the authenticated request headers.",
            status_code=401,
            details={
                "header_generation_id": authenticated_generation_id,
                "body_generation_id": request.generation_id,
            },
            retryable=False,
        )

    return request


def decode_and_validate_delivery_completion(
    raw_completion: str,
    *,
    provider: str,
    model: str,
    generated_at: datetime | None = None,
) -> dict[str, Any]:
    trimmed_completion = raw_completion.strip()
    if trimmed_completion == "":
        raise DeliveryContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion was empty.",
            details={"reason": "empty_completion"},
            raw_completion=raw_completion,
        )

    try:
        decoded = json.loads(trimmed_completion)
    except json.JSONDecodeError as exc:
        raise DeliveryContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion was not valid JSON.",
            details={"json_error": str(exc)},
            raw_completion=raw_completion,
        ) from exc

    if not isinstance(decoded, dict):
        raise DeliveryContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion must decode to a JSON object.",
            details={"received_type": type(decoded).__name__},
            raw_completion=raw_completion,
        )

    normalized_payload = _normalize_strings(decoded)
    payload_with_defaults = _apply_delivery_response_defaults(
        normalized_payload,
        provider=provider,
        model=model,
        generated_at=generated_at,
    )

    try:
        validated_payload = DeliveryResponsePayload.model_validate(payload_with_defaults)
    except ValidationError as exc:
        raise DeliveryContractValidationError(
            code="provider_response_contract_invalid",
            message="Provider completion failed MediaDeliveryResponseSchema validation.",
            details={"errors": exc.errors()},
            raw_completion=raw_completion,
        ) from exc

    return validated_payload.model_dump(mode="python")


def build_cached_delivery_envelope(
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


def extract_cached_delivery_envelope(
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


def _apply_delivery_response_defaults(
    payload: dict[str, Any],
    *,
    provider: str,
    model: str,
    generated_at: datetime | None = None,
) -> dict[str, Any]:
    normalized_generated_at = _normalize_datetime(generated_at or datetime.now(timezone.utc)).isoformat()
    merged_payload = _merge_nested_dicts(
        {
            "schema_version": DELIVERY_RESPONSE_SCHEMA_VERSION,
            "recommended_next_steps": [],
            "classroom_tips": [],
            "artifact": {
                "thumbnail_url": None,
                "filename": None,
            },
            "publication": {
                "topic": None,
                "content": None,
                "recommended_project": None,
            },
            "response_meta": {
                "generated_at": normalized_generated_at,
                "llm_used": True,
                "provider": provider,
                "model": model,
            },
            "fallback": {
                "triggered": False,
                "reason_code": None,
                "action": None,
            },
        },
        payload,
    )

    existing_response_meta = merged_payload.get("response_meta")
    if isinstance(existing_response_meta, dict):
        existing_response_meta = dict(existing_response_meta)
    else:
        existing_response_meta = {}
    existing_response_meta.update(
        {
            "generated_at": normalized_generated_at,
            "llm_used": True,
            "provider": provider,
            "model": model,
        }
    )
    merged_payload["response_meta"] = existing_response_meta

    existing_fallback = merged_payload.get("fallback")
    if isinstance(existing_fallback, dict):
        existing_fallback = dict(existing_fallback)
    else:
        existing_fallback = {}
    existing_fallback.update(
        {
            "triggered": False,
            "reason_code": None,
            "action": None,
        }
    )
    merged_payload["fallback"] = existing_fallback

    return merged_payload


def _merge_nested_dicts(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged: dict[str, Any] = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = _merge_nested_dicts(dict(merged[key]), value)
            continue
        merged[key] = value
    return merged


def _normalize_strings(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _normalize_strings(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_normalize_strings(item) for item in value]
    if isinstance(value, str):
        return value.strip()
    return value


def _normalize_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


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