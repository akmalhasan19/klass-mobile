from __future__ import annotations

from dataclasses import dataclass

from app.errors import ProviderConfigurationError, ProviderRequestError
from app.models import ContentDraftRequest, DeliveryRequest, InterpretationRequest
from app.providers.base import ProviderClient, ProviderExecutionResult, ProviderRoute
from app.providers.registry import ProviderRegistry
from app.settings import Settings


@dataclass(frozen=True)
class RouteProviderPolicy:
    route: ProviderRoute
    primary_provider: str
    fallback_provider: str | None
    allow_route_divergence: bool
    fallback_error_codes: tuple[str, ...]

    @property
    def supports_fallback(self) -> bool:
        return self.fallback_provider is not None and self.fallback_provider != self.primary_provider

    def should_attempt_fallback(self, error: ProviderRequestError) -> bool:
        return self.supports_fallback and error.code in self.fallback_error_codes

    def providers_in_order(self) -> tuple[str, ...]:
        if self.supports_fallback:
            return (self.primary_provider, self.fallback_provider)

        return (self.primary_provider,)


class ProviderRouter:
    def __init__(
        self,
        settings: Settings,
        registry: ProviderRegistry | None = None,
    ) -> None:
        self.settings = settings
        self.registry = registry or ProviderRegistry()

    def policy_for_route(self, route: ProviderRoute) -> RouteProviderPolicy:
        interpretation_provider = self.settings.active_interpretation_provider
        delivery_provider = self.settings.active_delivery_provider

        if (
            not self.settings.allow_route_provider_divergence
            and interpretation_provider != delivery_provider
        ):
            raise ProviderConfigurationError(
                code="provider_route_divergence_disallowed",
                message="Interpretation and delivery providers must match when route divergence is disabled.",
                status_code=503,
                details={
                    "interpretation_provider": interpretation_provider,
                    "delivery_provider": delivery_provider,
                },
                retryable=False,
            )

        if route == "interpret":
            return RouteProviderPolicy(
                route=route,
                primary_provider=interpretation_provider,
                fallback_provider=self.settings.interpretation_fallback_provider,
                allow_route_divergence=self.settings.allow_route_provider_divergence,
                fallback_error_codes=self.settings.provider_fallback_error_codes,
            )

        if route == "respond":
            return RouteProviderPolicy(
                route=route,
                primary_provider=delivery_provider,
                fallback_provider=self.settings.delivery_fallback_provider,
                allow_route_divergence=self.settings.allow_route_provider_divergence,
                fallback_error_codes=self.settings.provider_fallback_error_codes,
            )

        raise ProviderConfigurationError(
            code="provider_route_unsupported",
            message="The requested provider route is not supported.",
            status_code=500,
            details={"route": route},
            retryable=False,
        )

    def build_client_for_route(self, route: ProviderRoute, use_fallback: bool = False) -> ProviderClient:
        policy = self.policy_for_route(route)
        provider_name = policy.fallback_provider if use_fallback else policy.primary_provider

        if provider_name is None:
            raise ProviderConfigurationError(
                code="provider_fallback_missing",
                message="Fallback provider is not configured for this route.",
                status_code=503,
                details={"route": route},
                retryable=False,
            )

        return self.registry.build_client(provider_name, self.settings)

    async def execute_interpretation(
        self,
        payload: InterpretationRequest,
    ) -> ProviderExecutionResult:
        return await self._execute(route="interpret", payload=payload)

    async def execute_delivery(
        self,
        payload: DeliveryRequest,
    ) -> ProviderExecutionResult:
        return await self._execute(route="respond", payload=payload)

    async def execute_content_draft(
        self,
        payload: ContentDraftRequest,
    ) -> ProviderExecutionResult:
        return await self._execute(route="respond", payload=payload)

    async def _execute(
        self,
        *,
        route: ProviderRoute,
        payload: InterpretationRequest | DeliveryRequest | ContentDraftRequest,
    ) -> ProviderExecutionResult:
        policy = self.policy_for_route(route)
        primary_client = self.registry.build_client(policy.primary_provider, self.settings)
        primary_request = self._normalize_request(primary_client, route, payload)

        try:
            completion = await primary_client.complete(primary_request)
        except ProviderRequestError as exc:
            primary_error = _augment_provider_request_error(
                exc,
                primary_provider=policy.primary_provider,
                attempted_providers=(policy.primary_provider,),
                fallback_used=False,
                fallback_reason=None,
            )

            if not policy.should_attempt_fallback(primary_error):
                raise primary_error

            fallback_provider = policy.fallback_provider
            if fallback_provider is None:
                raise primary_error

            fallback_client = self.registry.build_client(fallback_provider, self.settings)
            fallback_request = self._normalize_request(fallback_client, route, payload)
            try:
                completion = await fallback_client.complete(fallback_request)
            except ProviderRequestError as fallback_exc:
                raise _augment_provider_request_error(
                    fallback_exc,
                    primary_provider=policy.primary_provider,
                    attempted_providers=policy.providers_in_order(),
                    fallback_used=True,
                    fallback_reason=primary_error.code,
                ) from fallback_exc

            return ProviderExecutionResult(
                completion=completion,
                primary_provider=policy.primary_provider,
                fallback_used=True,
                fallback_reason=exc.code,
                attempted_providers=policy.providers_in_order(),
            )

        return ProviderExecutionResult(
            completion=completion,
            primary_provider=policy.primary_provider,
            fallback_used=False,
            fallback_reason=None,
            attempted_providers=(policy.primary_provider,),
        )

    def _normalize_request(
        self,
        client: ProviderClient,
        route: ProviderRoute,
        payload: InterpretationRequest | DeliveryRequest | ContentDraftRequest,
    ):
        if route == "interpret":
            if not isinstance(payload, InterpretationRequest):
                raise ProviderConfigurationError(
                    code="provider_route_payload_invalid",
                    message="Interpretation route requires an interpretation payload.",
                    status_code=500,
                    details={"route": route},
                    retryable=False,
                )

            return client.normalize_interpretation_request(payload)

        if isinstance(payload, DeliveryRequest):
            return client.normalize_delivery_request(payload)

        if isinstance(payload, ContentDraftRequest):
            return client.normalize_content_draft_request(payload)

        if not isinstance(payload, DeliveryRequest):
            raise ProviderConfigurationError(
                code="provider_route_payload_invalid",
                message="Delivery route requires a delivery payload.",
                status_code=500,
                details={"route": route},
                retryable=False,
            )

        return client.normalize_delivery_request(payload)


def _augment_provider_request_error(
    error: ProviderRequestError,
    *,
    primary_provider: str,
    attempted_providers: tuple[str, ...],
    fallback_used: bool,
    fallback_reason: str | None,
) -> ProviderRequestError:
    details = dict(error.details)
    details.update(
        {
            "primary_provider": primary_provider,
            "attempted_providers": list(attempted_providers),
            "fallback_used": fallback_used,
            "fallback_reason": fallback_reason,
        }
    )

    return ProviderRequestError(
        code=error.code,
        message=error.message,
        status_code=error.status_code,
        details=details,
        retryable=error.retryable,
    )