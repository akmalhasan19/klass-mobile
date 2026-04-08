from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class AdapterError(Exception):
    code: str
    message: str
    status_code: int
    details: dict[str, Any] = field(default_factory=dict)
    retryable: bool = False

    def __post_init__(self) -> None:
        super().__init__(self.message)


class ProviderConfigurationError(AdapterError):
    pass


class ProviderRequestError(AdapterError):
    pass