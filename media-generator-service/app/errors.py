from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class MediaGeneratorError(Exception):
    status_code: int
    code: str
    message: str
    details: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        super().__init__(self.message)


class AuthenticationError(MediaGeneratorError):
    def __init__(self, code: str, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(401, code, message, details or {})


class ContractValidationError(MediaGeneratorError):
    def __init__(self, code: str, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(422, code, message, details or {})


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
        )


class GenerationError(MediaGeneratorError):
    def __init__(self, code: str, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(500, code, message, details or {})


class ServiceMisconfiguredError(MediaGeneratorError):
    def __init__(self, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(503, "service_misconfigured", message, details or {})
