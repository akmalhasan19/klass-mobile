---
title: Klass LLM Adapter
sdk: docker
app_port: 7860
pinned: false
---

# Klass LLM Adapter Service

FastAPI-based adapter service that will become the single LLM boundary for the Klass media generation flow.

Current capabilities in this provider phase:

- Provides the new deployable `llm-adapter-service/` structure.
- Boots a FastAPI app from `app.main:app`.
- Exposes `GET /health` and `GET /v1/health`.
- Enforces shared-secret signed request verification helpers for future interpretation and delivery routes.
- Adds structured JSON logging and per-request `X-Request-Id` headers.
- Reports readiness for Postgres connectivity, active provider configuration, and inter-service auth configuration.
- Normalizes interpretation and delivery payloads into a vendor-neutral internal provider request shape.
- Implements the Gemini provider client for `generateContent` calls, response text extraction, stable error mapping, and usage metadata capture.
- Adds an OpenAI-ready provider client for `responses`-style JSON generation and a route-level provider router with per-route primary/fallback policy.
- Adds adapter-owned Postgres migrations, cache tables, and deterministic cache-key utilities for future semantic caching.
- Adds fixed-window rate-limit policy and bucket tables, request ledger tables, price catalog state, and daily cost aggregation views for future governance and observability.
- Adds configurable Postgres pooling and optional startup auto-migration for Docker or Hugging Face deployment.
- Prepares `auth`, `database`, `routes`, and `providers` modules for the next implementation phases.

This service is prepared to be deployed as a Docker-based Hugging Face Space.

## Local Run

```bash
pip install -r requirements.txt
python -m app.database migrate
uvicorn app.main:app --reload
```

This service should point to its own Postgres database. Do not reuse the Laravel backend database as the adapter operational state store.

## Hugging Face Spaces

Deploy this folder as a Docker Space.

Suggested Space secrets and variables for the baseline:

- `LLM_ADAPTER_DATABASE_URL`
- `LLM_ADAPTER_DATABASE_CONNECT_TIMEOUT_SECONDS=3`
- `LLM_ADAPTER_DATABASE_POOL_MIN_SIZE=1`
- `LLM_ADAPTER_DATABASE_POOL_MAX_SIZE=5`
- `LLM_ADAPTER_DATABASE_POOL_MAX_IDLE_SECONDS=300`
- `LLM_ADAPTER_DATABASE_AUTO_MIGRATE=false`
- `LLM_ADAPTER_UPSTREAM_TIMEOUT_SECONDS=30`
- `LLM_ADAPTER_SHARED_SECRET`
- `LLM_ADAPTER_SHARED_SECRET_PREVIOUS` optional comma-separated rotation secrets
- `LLM_ADAPTER_REQUEST_MAX_AGE_SECONDS=300`
- `LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER=gemini`
- `LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER=gemini`
- `LLM_ADAPTER_ALLOW_ROUTE_PROVIDER_DIVERGENCE=true`
- `LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER=` optional secondary provider for `/v1/interpret`
- `LLM_ADAPTER_DELIVERY_FALLBACK_PROVIDER=` optional secondary provider for `/v1/respond`
- `LLM_ADAPTER_PROVIDER_FALLBACK_ERROR_CODES=provider_timeout,provider_connection_failed,provider_rate_limited,provider_unavailable`
- `LLM_ADAPTER_GEMINI_API_KEY`
- `LLM_ADAPTER_GEMINI_BASE_URL=https://generativelanguage.googleapis.com`
- `LLM_ADAPTER_GEMINI_API_VERSION=v1beta`
- `LLM_ADAPTER_GEMINI_INTERPRET_MODEL=gemini-2.0-flash`
- `LLM_ADAPTER_GEMINI_DELIVERY_MODEL=gemini-2.0-flash`
- `LLM_ADAPTER_OPENAI_API_KEY` optional until OpenAI is enabled
- `LLM_ADAPTER_OPENAI_BASE_URL=https://api.openai.com`
- `LLM_ADAPTER_OPENAI_INTERPRET_MODEL=gpt-5.4`
- `LLM_ADAPTER_OPENAI_DELIVERY_MODEL=gpt-5.4`
- `LLM_ADAPTER_OPENAI_ORGANIZATION=` optional
- `LLM_ADAPTER_OPENAI_PROJECT=` optional
- `LLM_ADAPTER_SERVICE_NAME=klass-llm-adapter`
- `LLM_ADAPTER_SERVICE_VERSION=0.1.0`
- `LLM_ADAPTER_LOG_LEVEL=info`
- `PORT=7860`

Smoke test endpoints:

- `GET /health`
- `GET /v1/health`

## Environment Variables

- `LLM_ADAPTER_DATABASE_URL`: Postgres DSN used for readiness checks and future adapter state.
- `LLM_ADAPTER_DATABASE_CONNECT_TIMEOUT_SECONDS`: Postgres connection timeout in seconds. Default `3`.
- `LLM_ADAPTER_DATABASE_POOL_MIN_SIZE`: minimum pooled Postgres connections kept by the adapter process. Default `1`.
- `LLM_ADAPTER_DATABASE_POOL_MAX_SIZE`: maximum pooled Postgres connections opened by the adapter process. Default `5`.
- `LLM_ADAPTER_DATABASE_POOL_MAX_IDLE_SECONDS`: idle lifetime for pooled Postgres connections. Default `300`.
- `LLM_ADAPTER_DATABASE_AUTO_MIGRATE`: when `true`, the adapter tries to apply pending SQL migrations during startup and logs failures without crashing the process. Default `false`.
- `LLM_ADAPTER_UPSTREAM_TIMEOUT_SECONDS`: timeout for Gemini or future provider calls. Default `30`.
- `LLM_ADAPTER_SHARED_SECRET`: shared secret placeholder for future signed request auth readiness.
- `LLM_ADAPTER_SHARED_SECRET_PREVIOUS`: optional comma-separated previous secrets accepted during rotation.
- `LLM_ADAPTER_REQUEST_MAX_AGE_SECONDS`: placeholder max age used by future signed auth. Default `300`.
- `LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER`: active provider alias for `/v1/interpret`. Default `gemini`.
- `LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER`: active provider alias for `/v1/respond`. Default `gemini`.
- `LLM_ADAPTER_ALLOW_ROUTE_PROVIDER_DIVERGENCE`: when `true`, interpretation and delivery may use different active providers. Default `true`.
- `LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER`: optional fallback provider alias for interpretation when the primary provider is unavailable, times out, or gets rate-limited.
- `LLM_ADAPTER_DELIVERY_FALLBACK_PROVIDER`: optional fallback provider alias for delivery when the primary provider is unavailable, times out, or gets rate-limited.
- `LLM_ADAPTER_PROVIDER_FALLBACK_ERROR_CODES`: comma-separated adapter error codes that trigger provider fallback. Default `provider_timeout,provider_connection_failed,provider_rate_limited,provider_unavailable`.
- `LLM_ADAPTER_GEMINI_API_KEY`: Gemini provider credential.
- `LLM_ADAPTER_GEMINI_BASE_URL`: Gemini API base URL. Default `https://generativelanguage.googleapis.com`.
- `LLM_ADAPTER_GEMINI_API_VERSION`: Gemini REST API version segment. Default `v1beta`.
- `LLM_ADAPTER_GEMINI_INTERPRET_MODEL`: Gemini model used when the interpretation request model alias is provider-neutral. Default `gemini-2.0-flash`.
- `LLM_ADAPTER_GEMINI_DELIVERY_MODEL`: Gemini model used when the delivery request model alias is provider-neutral. Default `gemini-2.0-flash`.
- `LLM_ADAPTER_OPENAI_API_KEY`: OpenAI provider credential.
- `LLM_ADAPTER_OPENAI_BASE_URL`: OpenAI API base URL. Default `https://api.openai.com`.
- `LLM_ADAPTER_OPENAI_INTERPRET_MODEL`: OpenAI model used when the interpretation request model alias is provider-neutral. Default `gpt-5.4`.
- `LLM_ADAPTER_OPENAI_DELIVERY_MODEL`: OpenAI model used when the delivery request model alias is provider-neutral. Default `gpt-5.4`.
- `LLM_ADAPTER_OPENAI_ORGANIZATION`: optional OpenAI organization header value.
- `LLM_ADAPTER_OPENAI_PROJECT`: optional OpenAI project header value.
- `LLM_ADAPTER_SERVICE_NAME`: health metadata value. Default `klass-llm-adapter`.
- `LLM_ADAPTER_SERVICE_VERSION`: health metadata value. Default `0.1.0`.
- `LLM_ADAPTER_LOG_LEVEL`: application log level. Default `info`.

## Inter-Service Auth

The adapter uses timestamped HMAC signatures for backend-to-adapter requests.

Expected request headers:

- `X-Request-Id`
- `X-Klass-Generation-Id`
- `X-Klass-Request-Timestamp`
- `X-Klass-Signature-Algorithm=hmac-sha256`
- `X-Klass-Signature`

The signature format matches the existing Python renderer boundary:

`sha256_hmac(shared_secret, timestamp + "." + raw_request_body)`

Only the adapter shared secret should live in Laravel. Provider API keys such as Gemini or OpenAI must remain exclusive to `llm-adapter-service`.

## Credential Rotation

Use a two-step rollout for zero-downtime HMAC rotation:

1. Deploy `llm-adapter-service` with the new secret in `LLM_ADAPTER_SHARED_SECRET` and keep the old secret in `LLM_ADAPTER_SHARED_SECRET_PREVIOUS`.
2. Deploy Laravel with the same new value in `MEDIA_GENERATION_LLM_ADAPTER_SHARED_SECRET`.
3. Confirm `GET /health` or `GET /v1/health` reports `auth.rotation_enabled=true` and the expected `auth.accepted_secret_count` during the grace period.
4. Remove the previous secret from `LLM_ADAPTER_SHARED_SECRET_PREVIOUS` after in-flight jobs are drained.

## Health Contract

`GET /health` and `GET /v1/health` return schema version `llm_adapter_health.v1`.

The payload includes:

- `service_name`
- `service_version`
- `status` and `ready`
- `dependencies.postgres`
- `dependencies.providers.interpretation`
- `dependencies.providers.delivery`
- `auth`

The endpoint returns HTTP `200` when all readiness checks pass and HTTP `503` when any required dependency is not ready.

## Database State

Adapter database migrations live in `app/migrations/` and can be applied with:

```bash
python -m app.database migrate
```

The current migrations create:

- `schema_migrations`
- `interpretation_cache_entries`
- `delivery_cache_entries`
- `rate_limit_policies`
- `rate_limit_buckets`
- `llm_request_ledger`
- `price_catalog_entries`
- `llm_request_daily_aggregates`
- `llm_request_daily_route_aggregates`

The cache tables store `cache_key`, `request_payload`, `response_payload`, `created_at`, `expires_at`, `hit_count`, and `last_hit_at`, plus indexes for cache-key lookup and TTL cleanup.

The governance state also stores fixed-window rate-limit policies and buckets keyed by route/provider/model, a request ledger for upstream LLM calls with retry and fallback metadata, provider/model pricing rows, and daily aggregate views for route-level cost reporting, cache effectiveness, and retry volume.

## Next Phases

This phase intentionally still does not implement `/v1/interpret`, `/v1/respond`, semantic cache read-write flows, rate-limit enforcement, or automatic ledger write paths. Those runtime behaviors will be added in the next phases on top of the provider abstraction, route policy, and Postgres state foundations added here.
