from __future__ import annotations

import time
from typing import Any

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


class OpenAIProviderClient(ProviderClient):
    name = "openai"

    def resolve_model(self, route: ProviderRoute, requested_model: str) -> str:
        normalized_requested_model = requested_model.strip().lower()

        if normalized_requested_model.startswith(("gpt", "o", "chatgpt")):
            return requested_model.strip()

        if route == "interpret":
            return self.settings.openai_interpretation_model

        return self.settings.openai_delivery_model

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
                self._endpoint_url(),
                json=self._build_request_body(request),
                headers=self._request_headers(),
            )
        except httpx.TimeoutException as exc:
            raise ProviderRequestError(
                code="provider_timeout",
                message="OpenAI request timed out.",
                status_code=504,
                details={"provider": self.name, "model": request.model},
                retryable=True,
            ) from exc
        except httpx.HTTPError as exc:
            raise ProviderRequestError(
                code="provider_connection_failed",
                message="Could not reach OpenAI.",
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
            response_id=self._clean_string(payload.get("id")),
            model_version=self._clean_string(payload.get("model")),
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

    def _endpoint_url(self) -> str:
        return self.settings.openai_base_url.rstrip("/") + "/v1/responses"

    def _request_headers(self) -> dict[str, str]:
        headers = {
            "Authorization": f"Bearer {self.settings.openai_api_key}",
            "Content-Type": "application/json",
        }

        if self.settings.openai_organization != "":
            headers["OpenAI-Organization"] = self.settings.openai_organization

        if self.settings.openai_project != "":
            headers["OpenAI-Project"] = self.settings.openai_project

        return headers

    def _build_request_body(self, request: NormalizedProviderRequest) -> dict[str, Any]:
        return {
            "model": request.model,
            "input": [
                {
                    "role": "system",
                    "content": [{"type": "input_text", "text": request.instruction}],
                },
                {
                    "role": "user",
                    "content": [{"type": "input_text", "text": request.serialize_prompt_payload()}],
                },
            ],
            "text": {
                "format": {"type": "json_object"},
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
                message="OpenAI returned a non-JSON response.",
                status_code=502,
                details={"provider": self.name, "model": request.model},
                retryable=True,
            ) from exc

        if not isinstance(payload, dict):
            raise ProviderRequestError(
                code="provider_response_invalid",
                message="OpenAI returned an unexpected response shape.",
                status_code=502,
                details={"provider": self.name, "model": request.model},
                retryable=True,
            )

        return payload

    def _extract_completion_text(
        self,
        payload: dict[str, Any],
        request: NormalizedProviderRequest,
    ) -> tuple[str, int | None, str | None]:
        top_level_text = self._clean_string(payload.get("output_text"))
        if top_level_text is not None:
            return top_level_text, 0, self._extract_finish_reason(payload)

        outputs = payload.get("output")
        if isinstance(outputs, list):
            for index, item in enumerate(outputs):
                if not isinstance(item, dict):
                    continue

                content_items = item.get("content")
                if not isinstance(content_items, list):
                    continue

                text_fragments: list[str] = []
                for content_item in content_items:
                    if not isinstance(content_item, dict):
                        continue

                    text = self._clean_string(content_item.get("text"))
                    if text is not None and content_item.get("type") in {"output_text", "text"}:
                        text_fragments.append(text)

                if text_fragments:
                    return "".join(text_fragments).strip(), index, self._extract_finish_reason(payload, item)

        choice_text = self._extract_choice_text(payload)
        if choice_text is not None:
            return choice_text[0], choice_text[1], choice_text[2]

        raise ProviderRequestError(
            code="provider_response_invalid",
            message="OpenAI response did not contain any text completion.",
            status_code=502,
            details={"provider": self.name, "model": request.model},
            retryable=True,
        )

    def _extract_choice_text(
        self,
        payload: dict[str, Any],
    ) -> tuple[str, int, str | None] | None:
        choices = payload.get("choices")
        if not isinstance(choices, list):
            return None

        for index, choice in enumerate(choices):
            if not isinstance(choice, dict):
                continue

            message = choice.get("message")
            if isinstance(message, dict):
                content = message.get("content")

                if isinstance(content, str) and content.strip() != "":
                    return content.strip(), index, self._normalize_finish_reason(choice.get("finish_reason"))

                if isinstance(content, list):
                    fragments: list[str] = []
                    for item in content:
                        if not isinstance(item, dict):
                            continue

                        text = self._clean_string(item.get("text"))
                        if text is not None:
                            fragments.append(text)

                    if fragments:
                        return "".join(fragments).strip(), index, self._normalize_finish_reason(choice.get("finish_reason"))

            text = self._clean_string(choice.get("text"))
            if text is not None:
                return text, index, self._normalize_finish_reason(choice.get("finish_reason"))

        return None

    def _normalize_usage(
        self,
        payload: dict[str, Any],
        latency_ms: float,
        upstream_request_id: str | None,
        finish_reason: str | None,
    ) -> ProviderUsage:
        usage_payload = payload.get("usage") if isinstance(payload.get("usage"), dict) else {}
        input_tokens = self._coerce_int(
            usage_payload.get("input_tokens", usage_payload.get("prompt_tokens"))
        )
        output_tokens = self._coerce_int(
            usage_payload.get("output_tokens", usage_payload.get("completion_tokens"))
        )
        total_tokens = self._coerce_int(usage_payload.get("total_tokens"))

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
        header_value = self._clean_string(response.headers.get("x-request-id"))
        if header_value is not None:
            return header_value

        return self._clean_string(payload.get("id"))

    def _extract_finish_reason(
        self,
        payload: dict[str, Any],
        output_item: dict[str, Any] | None = None,
    ) -> str | None:
        if isinstance(output_item, dict):
            finish_reason = self._normalize_finish_reason(output_item.get("finish_reason"))
            if finish_reason is not None:
                return finish_reason

        finish_reason = self._normalize_finish_reason(payload.get("status"))
        if finish_reason is not None:
            return finish_reason

        incomplete_details = payload.get("incomplete_details")
        if isinstance(incomplete_details, dict):
            return self._normalize_finish_reason(incomplete_details.get("reason"))

        return None

    def _map_http_error(
        self,
        response: httpx.Response,
        request: NormalizedProviderRequest,
        latency_ms: float,
    ) -> ProviderRequestError:
        payload = self._safe_error_payload(response)
        error_payload = payload.get("error") if isinstance(payload, dict) else None
        provider_type = None
        provider_message = None
        provider_code = None

        if isinstance(error_payload, dict):
            provider_type = self._clean_string(error_payload.get("type"))
            provider_message = self._clean_string(error_payload.get("message"))
            provider_code = self._clean_string(error_payload.get("code"))

        details = {
            "provider": self.name,
            "model": request.model,
            "http_status": response.status_code,
            "latency_ms": latency_ms,
            "upstream_request_id": self._extract_upstream_request_id(response, payload),
            "provider_type": provider_type,
            "provider_message": provider_message,
            "provider_code": provider_code,
        }

        if response.status_code in (401, 403):
            return ProviderRequestError(
                code="provider_auth_failed",
                message="OpenAI rejected the request due to invalid credentials or permissions.",
                status_code=503,
                details=self._compact_details(details),
                retryable=False,
            )

        if response.status_code == 429:
            return ProviderRequestError(
                code="provider_rate_limited",
                message="OpenAI rate limit was exceeded.",
                status_code=429,
                details=self._compact_details(details),
                retryable=True,
            )

        if response.status_code == 400:
            return ProviderRequestError(
                code="provider_request_invalid",
                message="OpenAI rejected the normalized request payload.",
                status_code=502,
                details=self._compact_details(details),
                retryable=False,
            )

        if response.status_code >= 500:
            return ProviderRequestError(
                code="provider_unavailable",
                message="OpenAI is currently unavailable.",
                status_code=503,
                details=self._compact_details(details),
                retryable=True,
            )

        return ProviderRequestError(
            code="provider_upstream_failed",
            message="OpenAI returned an unexpected error response.",
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