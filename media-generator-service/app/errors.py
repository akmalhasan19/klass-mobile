from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from app.contracts import (
    LARAVEL_ERROR_ARTIFACT_INVALID,
    LARAVEL_ERROR_PYTHON_SERVICE_UNAVAILABLE,
)


@dataclass
class MediaGeneratorError(Exception):
    status_code: int
    code: str
    message: str
    details: dict[str, Any] = field(default_factory=dict)
    retryable: bool = True
    laravel_error_code_hint: str = LARAVEL_ERROR_ARTIFACT_INVALID

    def __post_init__(self) -> None:
        super().__init__(self.message)


class AuthenticationError(MediaGeneratorError):
    def __init__(self, code: str, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(
            401,
            code,
            message,
            details or {},
            retryable=True,
            laravel_error_code_hint=LARAVEL_ERROR_PYTHON_SERVICE_UNAVAILABLE,
        )


class ContractValidationError(MediaGeneratorError):
    def __init__(self, code: str, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(
            422,
            code,
            message,
            details or {},
            retryable=True,
            laravel_error_code_hint=LARAVEL_ERROR_ARTIFACT_INVALID,
        )


class UnsupportedFormatError(MediaGeneratorError):
    def __init__(self, export_format: str, supported_formats: tuple[str, ...]) -> None:
        super().__init__(
            422,
            "unsupported_export_format",
            f"Export format '{export_format}' is not implemented by this service.",
            {
                "export_format": export_format,
                "supported_formats": list(supported_formats),
            },
            retryable=True,
            laravel_error_code_hint=LARAVEL_ERROR_ARTIFACT_INVALID,
        )


class GenerationError(MediaGeneratorError):
    def __init__(
        self,
        code: str,
        message: str,
        details: dict[str, Any] | None = None,
        *,
        retryable: bool = True,
        laravel_error_code_hint: str = LARAVEL_ERROR_ARTIFACT_INVALID,
    ) -> None:
        super().__init__(500, code, message, details or {}, retryable, laravel_error_code_hint)


class ServiceMisconfiguredError(MediaGeneratorError):
    def __init__(self, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(
            503,
            "service_misconfigured",
            message,
            details or {},
            retryable=True,
            laravel_error_code_hint=LARAVEL_ERROR_PYTHON_SERVICE_UNAVAILABLE,
        )
