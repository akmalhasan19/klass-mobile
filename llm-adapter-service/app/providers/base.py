from __future__ import annotations

import json
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any, Callable, Literal

import httpx

from app.models import DeliveryRequest, InterpretationRequest
from app.settings import Settings

ProviderRoute = Literal["interpret", "respond"]


@dataclass(frozen=True)
class ProviderDefinition:
    name: str
    required_env_fields: tuple[str, ...]
    client_factory: Callable[[Settings], "ProviderClient"] | None = None

    def missing_settings(self, settings: Settings) -> list[str]:
        env_values = {
            "LLM_ADAPTER_GEMINI_API_KEY": settings.gemini_api_key,
            "LLM_ADAPTER_OPENAI_API_KEY": settings.openai_api_key,
        }

        return [
            env_name
            for env_name in self.required_env_fields
            if env_values.get(env_name, "").strip() == ""
        ]

    @property
    def implemented(self) -> bool:
        return self.client_factory is not None

    def build_client(self, settings: Settings) -> "ProviderClient":
        if self.client_factory is None:
            raise RuntimeError(f"Provider {self.name} is not implemented.")

        return self.client_factory(settings)


@dataclass(frozen=True)
class NormalizedProviderRequest:
    route: ProviderRoute
    request_type: str
    generation_id: str
    requested_model: str
    model: str
    instruction: str
    input_payload: dict[str, Any]

    def prompt_payload(self) -> dict[str, Any]:
        return {
            "request_type": self.request_type,
            "generation_id": self.generation_id,
            "route": self.route,
            "input": self.input_payload,
        }

    def serialize_prompt_payload(self) -> str:
        return json.dumps(
            self.prompt_payload(),
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )


@dataclass(frozen=True)
class ProviderUsage:
    input_tokens: int | None
    output_tokens: int | None
    total_tokens: int | None
    latency_ms: float | None
    upstream_request_id: str | None
    finish_reason: str | None


@dataclass(frozen=True)
class ProviderResponseReference:
    response_id: str | None
    model_version: str | None
    candidate_index: int | None


@dataclass(frozen=True)
class ProviderCompletion:
    provider: str
    route: ProviderRoute
    generation_id: str
    requested_model: str
    model: str
    raw_completion: str
    usage: ProviderUsage
    response_reference: ProviderResponseReference
    raw_response: dict[str, Any]


@dataclass(frozen=True)
class ProviderExecutionResult:
    completion: ProviderCompletion
    primary_provider: str
    fallback_used: bool
    fallback_reason: str | None
    attempted_providers: tuple[str, ...]


class ProviderClient(ABC):
    name: str

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def normalize_interpretation_request(self, payload: InterpretationRequest) -> NormalizedProviderRequest:
        return self._normalize_request(
            route="interpret",
            request_type=payload.request_type,
            generation_id=payload.generation_id,
            requested_model=payload.model,
            instruction=payload.instruction,
            input_payload=payload.input.model_dump(mode="python"),
        )

    def normalize_delivery_request(self, payload: DeliveryRequest) -> NormalizedProviderRequest:
        return self._normalize_request(
            route="respond",
            request_type=payload.request_type,
            generation_id=payload.generation_id,
            requested_model=payload.model,
            instruction=payload.instruction,
            input_payload=payload.input.model_dump(mode="python"),
        )

    def _normalize_request(
        self,
        *,
        route: ProviderRoute,
        request_type: str,
        generation_id: str,
        requested_model: str,
        instruction: str,
        input_payload: dict[str, Any],
    ) -> NormalizedProviderRequest:
        normalized_requested_model = requested_model.strip()

        return NormalizedProviderRequest(
            route=route,
            request_type=request_type.strip(),
            generation_id=generation_id.strip(),
            requested_model=normalized_requested_model,
            model=self.resolve_model(route, normalized_requested_model),
            instruction=instruction.strip(),
            input_payload=input_payload,
        )

    @abstractmethod
    def resolve_model(self, route: ProviderRoute, requested_model: str) -> str:
        raise NotImplementedError

    @abstractmethod
    async def complete(
        self,
        request: NormalizedProviderRequest,
        http_client: httpx.AsyncClient | None = None,
    ) -> ProviderCompletion:
        raise NotImplementedError
