from __future__ import annotations

from dataclasses import dataclass

from app.settings import Settings


@dataclass(frozen=True)
class ProviderDefinition:
    name: str
    required_env_fields: tuple[str, ...]

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
