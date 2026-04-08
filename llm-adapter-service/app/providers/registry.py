from __future__ import annotations

from app.contracts import SUPPORTED_PROVIDERS
from app.providers.base import ProviderDefinition
from app.settings import Settings


class ProviderRegistry:
    def __init__(self) -> None:
        self._providers = {
            "gemini": ProviderDefinition(
                name="gemini",
                required_env_fields=("LLM_ADAPTER_GEMINI_API_KEY",),
            ),
            "openai": ProviderDefinition(
                name="openai",
                required_env_fields=("LLM_ADAPTER_OPENAI_API_KEY",),
            ),
        }

    def get(self, provider_name: str) -> ProviderDefinition | None:
        return self._providers.get(provider_name.strip().lower())

    def supported_provider_names(self) -> list[str]:
        return list(SUPPORTED_PROVIDERS)

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
        ready = missing_settings == []

        return {
            "route": route,
            "provider": provider.name,
            "configured": ready,
            "ready": ready,
            "supported_providers": self.supported_provider_names(),
            "missing_settings": missing_settings,
            "error": None
            if ready
            else {
                "code": "provider_config_missing",
                "message": "The active provider is missing required configuration.",
                "detail": None,
            },
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
