from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class HealthError(BaseModel):
    code: str
    message: str
    detail: str | None = None


class PostgresReadiness(BaseModel):
    configured: bool
    ready: bool
    driver: str | None = None
    host: str | None = None
    database: str | None = None
    error: HealthError | None = None


class ProviderReadiness(BaseModel):
    route: str
    provider: str
    configured: bool
    ready: bool
    supported_providers: list[str] = Field(default_factory=list)
    missing_settings: list[str] = Field(default_factory=list)
    error: HealthError | None = None


class ProviderDependencyReadiness(BaseModel):
    interpretation: ProviderReadiness
    delivery: ProviderReadiness


class DependencyReadiness(BaseModel):
    postgres: PostgresReadiness
    providers: ProviderDependencyReadiness


class AuthReadiness(BaseModel):
    ready: bool
    configured: bool
    rotation_enabled: bool
    accepted_secret_count: int
    max_request_age_seconds: int
    signature_algorithm: str


class HealthResponse(BaseModel):
    schema_version: str
    status: Literal["ready", "degraded"]
    ready: bool
    service_name: str
    service_version: str
    checked_at: str
    dependencies: DependencyReadiness
    auth: AuthReadiness
