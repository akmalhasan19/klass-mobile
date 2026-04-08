from __future__ import annotations

from app.errors import ProviderConfigurationError
from app.contracts import SUPPORTED_PROVIDERS
from app.providers.base import ProviderClient, ProviderDefinition
from app.providers.gemini import GeminiProviderClient
from app.providers.openai import OpenAIProviderClient
from app.settings import Settings


class ProviderRegistry:
    def __init__(self) -> None:
        self._providers = {
            "gemini": ProviderDefinition(
                name="gemini",
                required_env_fields=("LLM_ADAPTER_GEMINI_API_KEY",),
                client_factory=GeminiProviderClient,
            ),
            "openai": ProviderDefinition(
                name="openai",
                required_env_fields=("LLM_ADAPTER_OPENAI_API_KEY",),
                client_factory=OpenAIProviderClient,
            ),
        }

    def get(self, provider_name: str) -> ProviderDefinition | None:
        return self._providers.get(provider_name.strip().lower())

    def supported_provider_names(self) -> list[str]:
        return list(SUPPORTED_PROVIDERS)

    def build_client(self, provider_name: str, settings: Settings) -> ProviderClient:
        normalized_provider = provider_name.strip().lower()
        provider = self.get(normalized_provider)

        if provider is None:
            raise ProviderConfigurationError(
                code="provider_unsupported",
                message="The active provider is not supported by this adapter build.",
                status_code=503,
                details={
                    "provider": normalized_provider,
                    "supported_providers": self.supported_provider_names(),
                },
                retryable=False,
            )

        missing_settings = provider.missing_settings(settings)
        if missing_settings:
            raise ProviderConfigurationError(
                code="provider_config_missing",
                message="The active provider is missing required configuration.",
                status_code=503,
                details={
                    "provider": provider.name,
                    "missing_settings": missing_settings,
                },
                retryable=False,
            )

        if not provider.implemented:
            raise ProviderConfigurationError(
                code="provider_not_implemented",
                message="The active provider is declared but not implemented in this adapter build.",
                status_code=503,
                details={"provider": provider.name},
                retryable=False,
            )

        return provider.build_client(settings)

    def build_client_for_route(self, route: str, settings: Settings) -> ProviderClient:
        if route == "interpret":
            return self.build_client(settings.active_interpretation_provider, settings)

        if route == "respond":
            return self.build_client(settings.active_delivery_provider, settings)

        raise ProviderConfigurationError(
            code="provider_route_unsupported",
            message="The requested provider route is not supported.",
            status_code=500,
            details={"route": route},
            retryable=False,
        )

    def readiness(self, route: str, provider_name: str, settings: Settings) -> dict[str, object]:
        normalized_provider = provider_name.strip().lower()
        provider = self.get(normalized_provider)

        if provider is None:
            return {
                "route": route,
                "provider": normalized_provider,
                "configured": False,
                "ready": False,
                "supported_providers": self.supported_provider_names(),
                "missing_settings": [],
                "error": {
                    "code": "provider_unsupported",
                    "message": "The active provider is not supported by this adapter build.",
                    "detail": normalized_provider or None,
                },
            }

        missing_settings = provider.missing_settings(settings)
        configured = missing_settings == []
        ready = configured and provider.implemented

        if missing_settings:
            error = {
                "code": "provider_config_missing",
                "message": "The active provider is missing required configuration.",
                "detail": None,
            }
        elif not provider.implemented:
            error = {
                "code": "provider_not_implemented",
                "message": "The active provider is declared but not implemented in this adapter build.",
                "detail": provider.name,
            }
        else:
            error = None

        return {
            "route": route,
            "provider": provider.name,
            "configured": configured,
            "ready": ready,
            "supported_providers": self.supported_provider_names(),
            "missing_settings": missing_settings,
            "error": error,
        }


def get_provider_readiness(settings: Settings) -> dict[str, object]:
    registry = ProviderRegistry()

    return {
        "interpretation": registry.readiness(
            "interpret",
            settings.active_interpretation_provider,
            settings,
        ),
        "delivery": registry.readiness(
            "respond",
            settings.active_delivery_provider,
            settings,
        ),
    }
