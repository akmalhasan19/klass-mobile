---
title: Klass LLM Adapter
sdk: docker
app_port: 7860
pinned: false
---

# Klass LLM Adapter Service

FastAPI-based adapter service that will become the single LLM boundary for the Klass media generation flow.

Current capabilities in this baseline phase:

- Provides the new deployable `llm-adapter-service/` structure.
- Boots a FastAPI app from `app.main:app`.
- Exposes `GET /health` and `GET /v1/health`.
- Enforces shared-secret signed request verification helpers for future interpretation and delivery routes.
- Adds structured JSON logging and per-request `X-Request-Id` headers.
- Reports readiness for Postgres connectivity, active provider configuration, and inter-service auth configuration.
- Prepares `auth`, `database`, `routes`, and `providers` modules for the next implementation phases.

This service is prepared to be deployed as a Docker-based Hugging Face Space.

## Local Run

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Hugging Face Spaces

Deploy this folder as a Docker Space.

Suggested Space secrets and variables for the baseline:

- `LLM_ADAPTER_DATABASE_URL`
- `LLM_ADAPTER_DATABASE_CONNECT_TIMEOUT_SECONDS=3`
- `LLM_ADAPTER_SHARED_SECRET`
- `LLM_ADAPTER_SHARED_SECRET_PREVIOUS` optional comma-separated rotation secrets
- `LLM_ADAPTER_REQUEST_MAX_AGE_SECONDS=300`
- `LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER=gemini`
- `LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER=gemini`
- `LLM_ADAPTER_GEMINI_API_KEY`
- `LLM_ADAPTER_OPENAI_API_KEY` optional until OpenAI is enabled
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
- `LLM_ADAPTER_SHARED_SECRET`: shared secret placeholder for future signed request auth readiness.
- `LLM_ADAPTER_SHARED_SECRET_PREVIOUS`: optional comma-separated previous secrets accepted during rotation.
- `LLM_ADAPTER_REQUEST_MAX_AGE_SECONDS`: placeholder max age used by future signed auth. Default `300`.
- `LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER`: active provider alias for `/v1/interpret`. Default `gemini`.
- `LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER`: active provider alias for `/v1/respond`. Default `gemini`.
- `LLM_ADAPTER_GEMINI_API_KEY`: Gemini provider credential.
- `LLM_ADAPTER_OPENAI_API_KEY`: OpenAI provider credential placeholder.
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

## Next Phases

This baseline intentionally does not implement `/v1/interpret`, `/v1/respond`, provider calling, cache, or rate limiting yet. Those will be added in the next phases on top of the modules scaffolded here.
