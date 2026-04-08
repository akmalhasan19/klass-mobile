from __future__ import annotations

import json
import time
from typing import Any
from urllib.parse import quote

import httpx

from app.errors import ProviderRequestError
from app.providers.base import (
    NormalizedProviderRequest,
    ProviderClient,
    ProviderCompletion,
    ProviderResponseReference,
    ProviderRoute,
    ProviderUsage,
)


class GeminiProviderClient(ProviderClient):
    name = "gemini"

    def resolve_model(self, route: ProviderRoute, requested_model: str) -> str:
        normalized_requested_model = requested_model.strip().lower()

        if normalized_requested_model.startswith("gemini"):
            return requested_model.strip()

        if route == "interpret":
            return self.settings.gemini_interpretation_model

        return self.settings.gemini_delivery_model

    async def complete(
        self,
        request: NormalizedProviderRequest,
        http_client: httpx.AsyncClient | None = None,
    ) -> ProviderCompletion:
        owns_client = http_client is None
        client = http_client or httpx.AsyncClient(timeout=self.settings.upstream_timeout_seconds)
        started_at = time.perf_counter()

        try:
            response = await client.post(
                self._endpoint_url(request.model),
                params={"key": self.settings.gemini_api_key},
                json=self._build_request_body(request),
                headers={"Content-Type": "application/json"},
            )
        except httpx.TimeoutException as exc:
            raise ProviderRequestError(
                code="provider_timeout",
                message="Gemini request timed out.",
                status_code=504,
                details={"provider": self.name, "model": request.model},
                retryable=True,
            ) from exc
        except httpx.HTTPError as exc:
            raise ProviderRequestError(
                code="provider_connection_failed",
                message="Could not reach Gemini.",
                status_code=503,
                details={"provider": self.name, "model": request.model, "exception": str(exc)},
                retryable=True,
            ) from exc
        finally:
            if owns_client:
                await client.aclose()

        latency_ms = round((time.perf_counter() - started_at) * 1000, 2)

        if response.is_error:
            raise self._map_http_error(response, request, latency_ms)

        payload = self._decode_response_json(response, request)
        raw_completion, candidate_index, finish_reason = self._extract_completion_text(payload, request)
        upstream_request_id = self._extract_upstream_request_id(response, payload)
        usage = self._normalize_usage(payload, latency_ms, upstream_request_id, finish_reason)
        response_reference = ProviderResponseReference(
            response_id=self._clean_string(payload.get("responseId")),
            model_version=self._clean_string(payload.get("modelVersion")),
            candidate_index=candidate_index,
        )

        return ProviderCompletion(
            provider=self.name,
            route=request.route,
            generation_id=request.generation_id,
            requested_model=request.requested_model,
            model=request.model,
            raw_completion=raw_completion,
            usage=usage,
            response_reference=response_reference,
            raw_response=payload,
        )

    def _endpoint_url(self, model: str) -> str:
        base_url = self.settings.gemini_base_url.rstrip("/")
        api_version = self.settings.gemini_api_version.strip("/")
        encoded_model = quote(model, safe="")

        return f"{base_url}/{api_version}/models/{encoded_model}:generateContent"

    def _build_request_body(self, request: NormalizedProviderRequest) -> dict[str, Any]:
        return {
            "systemInstruction": {
                "parts": [{"text": request.instruction}],
            },
            "contents": [
                {
                    "role": "user",
                    "parts": [{"text": request.serialize_prompt_payload()}],
                }
            ],
            "generationConfig": {
                "candidateCount": 1,
                "responseMimeType": "application/json",
            },
        }

    def _decode_response_json(
        self,
        response: httpx.Response,
        request: NormalizedProviderRequest,
    ) -> dict[str, Any]:
        try:
            payload = response.json()
        except ValueError as exc:
            raise ProviderRequestError(
                code="provider_response_invalid",
                message="Gemini returned a non-JSON response.",
                status_code=502,
                details={"provider": self.name, "model": request.model},
                retryable=True,
            ) from exc

        if not isinstance(payload, dict):
            raise ProviderRequestError(
                code="provider_response_invalid",
                message="Gemini returned an unexpected response shape.",
                status_code=502,
                details={"provider": self.name, "model": request.model},
                retryable=True,
            )

        return payload

    def _extract_completion_text(
        self,
        payload: dict[str, Any],
        request: NormalizedProviderRequest,
    ) -> tuple[str, int, str | None]:
        candidates = payload.get("candidates")

        if not isinstance(candidates, list):
            raise ProviderRequestError(
                code="provider_response_invalid",
                message="Gemini response did not include candidates.",
                status_code=502,
                details={"provider": self.name, "model": request.model},
                retryable=True,
            )

        for index, candidate in enumerate(candidates):
            if not isinstance(candidate, dict):
                continue

            content = candidate.get("content")
            if not isinstance(content, dict):
                continue

            parts = content.get("parts")
            if not isinstance(parts, list):
                continue

            text_fragments: list[str] = []

            for part in parts:
                if not isinstance(part, dict):
                    continue

                text = part.get("text")
                if isinstance(text, str) and text.strip() != "":
                    text_fragments.append(text)

            if text_fragments:
                return "".join(text_fragments).strip(), index, self._normalize_finish_reason(candidate.get("finishReason"))

        raise ProviderRequestError(
            code="provider_response_invalid",
            message="Gemini response did not contain any text completion.",
            status_code=502,
            details={"provider": self.name, "model": request.model},
            retryable=True,
        )

    def _normalize_usage(
        self,
        payload: dict[str, Any],
        latency_ms: float,
        upstream_request_id: str | None,
        finish_reason: str | None,
    ) -> ProviderUsage:
        usage_metadata = payload.get("usageMetadata")
        usage_payload = usage_metadata if isinstance(usage_metadata, dict) else {}
        input_tokens = self._coerce_int(usage_payload.get("promptTokenCount"))
        output_tokens = self._coerce_int(usage_payload.get("candidatesTokenCount"))
        total_tokens = self._coerce_int(usage_payload.get("totalTokenCount"))

        if total_tokens is None and input_tokens is not None and output_tokens is not None:
            total_tokens = input_tokens + output_tokens

        return ProviderUsage(
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            total_tokens=total_tokens,
            latency_ms=latency_ms,
            upstream_request_id=upstream_request_id,
            finish_reason=finish_reason,
        )

    def _extract_upstream_request_id(
        self,
        response: httpx.Response,
        payload: dict[str, Any],
    ) -> str | None:
        for header_name in ["x-request-id", "x-goog-request-id"]:
            header_value = self._clean_string(response.headers.get(header_name))
            if header_value is not None:
                return header_value

        return self._clean_string(payload.get("responseId"))

    def _map_http_error(
        self,
        response: httpx.Response,
        request: NormalizedProviderRequest,
        latency_ms: float,
    ) -> ProviderRequestError:
        payload = self._safe_error_payload(response)
        error_payload = payload.get("error") if isinstance(payload, dict) else None
        provider_status = None
        provider_message = None
        provider_code = None

        if isinstance(error_payload, dict):
            provider_status = self._clean_string(error_payload.get("status"))
            provider_message = self._clean_string(error_payload.get("message"))
            provider_code = self._clean_string(error_payload.get("code"))

        details = {
            "provider": self.name,
            "model": request.model,
            "http_status": response.status_code,
            "latency_ms": latency_ms,
            "upstream_request_id": self._extract_upstream_request_id(response, payload),
            "provider_status": provider_status,
            "provider_message": provider_message,
            "provider_code": provider_code,
        }

        if response.status_code in (401, 403):
            return ProviderRequestError(
                code="provider_auth_failed",
                message="Gemini rejected the request due to invalid credentials or permissions.",
                status_code=503,
                details=self._compact_details(details),
                retryable=False,
            )

        if response.status_code == 429:
            return ProviderRequestError(
                code="provider_rate_limited",
                message="Gemini rate limit was exceeded.",
                status_code=429,
                details=self._compact_details(details),
                retryable=True,
            )

        if response.status_code == 400:
            return ProviderRequestError(
                code="provider_request_invalid",
                message="Gemini rejected the normalized request payload.",
                status_code=502,
                details=self._compact_details(details),
                retryable=False,
            )

        if response.status_code >= 500:
            return ProviderRequestError(
                code="provider_unavailable",
                message="Gemini is currently unavailable.",
                status_code=503,
                details=self._compact_details(details),
                retryable=True,
            )

        return ProviderRequestError(
            code="provider_upstream_failed",
            message="Gemini returned an unexpected error response.",
            status_code=502,
            details=self._compact_details(details),
            retryable=False,
        )

    def _safe_error_payload(self, response: httpx.Response) -> dict[str, Any]:
        try:
            payload = response.json()
        except ValueError:
            return {}

        return payload if isinstance(payload, dict) else {}

    def _normalize_finish_reason(self, value: Any) -> str | None:
        normalized = self._clean_string(value)
        return normalized.lower() if normalized is not None else None

    def _coerce_int(self, value: Any) -> int | None:
        if isinstance(value, bool):
            return None

        if isinstance(value, int):
            return value

        if isinstance(value, str) and value.strip().isdigit():
            return int(value.strip())

        return None

    def _clean_string(self, value: Any) -> str | None:
        if not isinstance(value, str):
            return None

        normalized = value.strip()
        return normalized or None

    def _compact_details(self, details: dict[str, Any]) -> dict[str, Any]:
        return {key: value for key, value in details.items() if value is not None}