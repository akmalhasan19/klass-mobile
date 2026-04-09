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
- Enforces shared-secret signed request verification for interpretation and delivery routes.
- Adds structured JSON logging and per-request `X-Request-Id` headers.
- Reports readiness for Postgres connectivity, active provider configuration, and inter-service auth configuration.
- Exposes `POST /v1/interpret` and `POST /v1/respond` with request validation, governance preflight, semantic cache reuse, provider execution, response-contract validation, ledger writes, and fallback or structured-error behavior.
- Normalizes interpretation and delivery payloads into a vendor-neutral internal provider request shape.
- Implements the Gemini provider client for `generateContent` calls, response text extraction, stable error mapping, and usage metadata capture.
- Adds an OpenAI-ready provider client for `responses`-style JSON generation and a route-level provider router with per-route primary/fallback policy.
- Adds adapter-owned Postgres cache tables, deterministic semantic cache-key generation, route-specific TTL policies, advisory-lock stampede protection helpers, and lazy/manual cleanup utilities without Redis.
- Adds fixed-window rate-limit policy and bucket tables, request ledger tables, price catalog state, and daily cost aggregation views for future governance and observability.
- Adds a governance runtime that syncs baseline route policies into Postgres, enforces interpretation and delivery request quotas before provider calls, tracks deny counters without inflating request counts on blocked retries, and applies daily route budgets using estimated request cost.
- Exposes governance visibility in the health payload so operators can see active route limits, disable delivery temporarily, and detect when daily budget headroom is approaching exhaustion.
- Registers a shared adapter error handler so future routes can return stable structured JSON errors for quota or budget denials.
- Adds a cost tracking runtime that resolves active price-catalog entries, estimates request cost from normalized Gemini/OpenAI token usage, writes request-ledger rows for success, failure, cache-hit, and fallback paths, and preserves upstream request ids plus cost-source metadata.
- Exposes `GET /ops/summary` and `GET /v1/ops/summary` for route/provider operational metrics including latency, cache-hit ratio, deny rate, retry volume, fallback volume, and estimated cost totals.
- Adds configurable Postgres pooling and optional startup auto-migration for Docker or Hugging Face deployment.
- Leaves backend cutover, deployment hardening, and end-to-end smoke verification as the primary remaining phases.

This service is prepared to be deployed as a Docker-based Hugging Face Space.

## Local Run

```bash
pip install -r requirements.txt
python -m app.database migrate
uvicorn app.main:app --reload
```

Optional manual cache maintenance:

```bash
python -m app.cache cleanup --route all --limit 100
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
- `LLM_ADAPTER_CACHE_SCHEMA_VERSION=llm_adapter_cache.v1`
- `LLM_ADAPTER_INTERPRETATION_CACHE_TTL_SECONDS=86400`
- `LLM_ADAPTER_DELIVERY_CACHE_TTL_SECONDS=21600`
- `LLM_ADAPTER_CACHE_STAMPEDE_POLL_INTERVAL_MS=100`
- `LLM_ADAPTER_CACHE_STAMPEDE_WAIT_TIMEOUT_MS=1500`
- `LLM_ADAPTER_CACHE_CLEANUP_BATCH_SIZE=100`
- `LLM_ADAPTER_CACHE_LAZY_CLEANUP_INTERVAL_SECONDS=60`
- `LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER=gemini`
- `LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER=gemini`
- `LLM_ADAPTER_ALLOW_ROUTE_PROVIDER_DIVERGENCE=true`
- `LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER=` optional secondary provider for `/v1/interpret`
- `LLM_ADAPTER_DELIVERY_FALLBACK_PROVIDER=` optional secondary provider for `/v1/respond`
- `LLM_ADAPTER_PROVIDER_FALLBACK_ERROR_CODES=provider_timeout,provider_connection_failed,provider_rate_limited,provider_unavailable`
- `LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_MINUTE=30`
- `LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_HOUR=600`
- `LLM_ADAPTER_INTERPRETATION_DAILY_BUDGET_USD=25.00`
- `LLM_ADAPTER_INTERPRETATION_DEFAULT_ESTIMATED_COST_USD=0.025`
- `LLM_ADAPTER_INTERPRETATION_EXHAUSTED_ACTION=deny`
- `LLM_ADAPTER_DELIVERY_ROUTE_ENABLED=true`
- `LLM_ADAPTER_DELIVERY_REQUESTS_PER_MINUTE=60`
- `LLM_ADAPTER_DELIVERY_REQUESTS_PER_HOUR=1200`
- `LLM_ADAPTER_DELIVERY_DAILY_BUDGET_USD=10.00`
- `LLM_ADAPTER_DELIVERY_DEFAULT_ESTIMATED_COST_USD=0.010`
- `LLM_ADAPTER_DELIVERY_EXHAUSTED_ACTION=degrade`
- `LLM_ADAPTER_BUDGET_WARNING_RATIO=0.80`
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
- `GET /ops/summary`
- `GET /v1/ops/summary`

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
- `LLM_ADAPTER_CACHE_SCHEMA_VERSION`: schema namespace embedded into cache keys so version bumps invalidate old semantic cache entries. Default `llm_adapter_cache.v1`.
- `LLM_ADAPTER_INTERPRETATION_CACHE_TTL_SECONDS`: TTL for interpretation cache entries. Default `86400`.
- `LLM_ADAPTER_DELIVERY_CACHE_TTL_SECONDS`: TTL for delivery cache entries. Default `21600`.
- `LLM_ADAPTER_CACHE_STAMPEDE_POLL_INTERVAL_MS`: polling interval used when waiting on an in-flight cache fill protected by advisory locks. Default `100`.
- `LLM_ADAPTER_CACHE_STAMPEDE_WAIT_TIMEOUT_MS`: maximum wait time before failing fast when another replica owns the in-flight cache fill lock. Default `1500`.
- `LLM_ADAPTER_CACHE_CLEANUP_BATCH_SIZE`: maximum expired rows deleted per cache table in one cleanup run. Default `100`.
- `LLM_ADAPTER_CACHE_LAZY_CLEANUP_INTERVAL_SECONDS`: minimum interval between lazy cleanup runs triggered by cache operations. Default `60`; set `0` to allow cleanup on every cache access.
- `LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER`: active provider alias for `/v1/interpret`. Default `gemini`.
- `LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER`: active provider alias for `/v1/respond`. Default `gemini`.
- `LLM_ADAPTER_ALLOW_ROUTE_PROVIDER_DIVERGENCE`: when `true`, interpretation and delivery may use different active providers. Default `true`.
- `LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER`: optional fallback provider alias for interpretation when the primary provider is unavailable, times out, or gets rate-limited.
- `LLM_ADAPTER_DELIVERY_FALLBACK_PROVIDER`: optional fallback provider alias for delivery when the primary provider is unavailable, times out, or gets rate-limited.
- `LLM_ADAPTER_PROVIDER_FALLBACK_ERROR_CODES`: comma-separated adapter error codes that trigger provider fallback. Default `provider_timeout,provider_connection_failed,provider_rate_limited,provider_unavailable`.
- `LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_MINUTE`: baseline fixed-window request ceiling for `/v1/interpret`. Default `30`.
- `LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_HOUR`: sustained request ceiling for `/v1/interpret`. Default `600`.
- `LLM_ADAPTER_INTERPRETATION_DAILY_BUDGET_USD`: daily estimated-cost ceiling for `/v1/interpret`. Default `25.00`.
- `LLM_ADAPTER_INTERPRETATION_DEFAULT_ESTIMATED_COST_USD`: preflight estimated cost applied when checking the interpretation daily budget before an upstream call. Default `0.025`.
- `LLM_ADAPTER_INTERPRETATION_EXHAUSTED_ACTION`: governance action when interpretation quota or budget is exhausted. Supported values: `deny`, `degrade`. Default `deny`.
- `LLM_ADAPTER_DELIVERY_ROUTE_ENABLED`: temporary operator switch for delivery route availability. When `false`, governance immediately returns a fallback-friendly block instead of attempting a provider call. Default `true`.
- `LLM_ADAPTER_DELIVERY_REQUESTS_PER_MINUTE`: baseline fixed-window request ceiling for `/v1/respond`. Default `60`.
- `LLM_ADAPTER_DELIVERY_REQUESTS_PER_HOUR`: sustained request ceiling for `/v1/respond`. Default `1200`.
- `LLM_ADAPTER_DELIVERY_DAILY_BUDGET_USD`: daily estimated-cost ceiling for `/v1/respond`. Default `10.00`.
- `LLM_ADAPTER_DELIVERY_DEFAULT_ESTIMATED_COST_USD`: preflight estimated cost applied when checking the delivery daily budget before an upstream call. Default `0.010`.
- `LLM_ADAPTER_DELIVERY_EXHAUSTED_ACTION`: governance action when delivery quota or budget is exhausted. Supported values: `deny`, `degrade`. Default `degrade`.
- `LLM_ADAPTER_BUDGET_WARNING_RATIO`: threshold ratio used by health visibility to flag a route budget as nearing exhaustion. Default `0.80`.
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
- `governance.ready`
- `governance.budget_warning_ratio`
- `governance.routes[]` with route enablement, minute/hour ceilings, daily budget, remaining headroom, and warning/exhausted status

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

Interpretation and delivery use separate TTL settings because delivery cache entries usually depend on more volatile artifact and publication metadata than interpretation entries. Cache keys embed schema version, provider alias, and model so version changes or provider/model swaps automatically invalidate prior semantic cache entries.

The cache service also provides Postgres advisory-lock helpers for in-flight stampede protection, bounded wait-or-fail-fast polling, lazy cleanup during cache operations, and a manual cleanup command for operators.

The governance state also stores fixed-window rate-limit policies and buckets keyed by route/provider/model, a request ledger for upstream LLM calls with retry and fallback metadata, provider/model pricing rows, and daily aggregate views for route-level cost reporting, cache effectiveness, and retry volume.

The governance runtime currently manages baseline route policies for `interpret` and `respond`, records usage and deny counters into `rate_limit_buckets`, and uses daily estimated-cost buckets to surface budget headroom in health checks.

The cost tracking runtime writes `llm_request_ledger` rows for success, failure, cache-hit, and fallback paths, looks up active `price_catalog_entries` to estimate cost from normalized provider usage, and falls back to route-level internal cost estimates when no catalog row is active.

## Operator Summary Contract

`GET /ops/summary` and `GET /v1/ops/summary` return schema version `llm_adapter_ops.v1`.

The payload includes:

- `window` with `from_date`, `to_date`, and `days`
- `active_routes` with the active provider, default model, and fallback provider per route
- `routes` with per-route request volume, cache hit ratio, deny rate, average latency, retry volume, fallback volume, error volume, token totals, and estimated cost volume
- `provider_models` with per route/provider/model cost and latency rollups for dashboard cards or tables

## Next Phases

The adapter runtime is now wired for both `/v1/interpret` and `/v1/respond`. Remaining work is centered on backend cutover, deployment rollout, and end-to-end smoke verification across the Laravel backend, the adapter, and the Python renderer.
