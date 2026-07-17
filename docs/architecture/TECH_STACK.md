# Tech Stack — Klass Rust Gateway

> **Phase**: Fase 2 Design (Task 2.5)
> **Date**: 2026-07-11
> **Status**: Locked

---

## Table of Contents

1. [Runtime Stack](#runtime-stack)
2. [Production Dependencies](#production-dependencies)
3. [Dev Dependencies](#dev-dependencies)
4. [Dev Tooling](#dev-tooling)
5. [Cargo Features Configuration](#cargo-features-configuration)
6. [CI/CD Pipeline](#cicd-pipeline)
7. [Deployment](#deployment)
8. [Editions & Policies](#editions--policies)

---

## Runtime Stack

| Component | Version | Notes |
|-----------|---------|-------|
| Rust | **1.85+** (stable) | Edition 2024, MSRV policy |
| Tokio | **1.43** | Multi-thread runtime with `rt-multi-thread` |
| PostgreSQL | **17** (Neon) | Via PgBouncer connection pooling |
| Redis | **7** (Upstash) | Streams with consumer groups |
| Protobuf | **proto3** | `prost` + `tonic-build` codegen |
| OpenAPI | **3.1** | `utoipa` codegen from axum handlers |
| Docker | **multi-stage** | Builder: `rust:1.85-slim-bookworm`, Runtime: `debian:bookworm-slim` |

---

## Production Dependencies

### Core Framework

| Crate | Version | Purpose | Why this crate |
|-------|---------|---------|---------------|
| `tokio` | `1.43` | Async runtime | Industry standard. `features = ["full"]` — macros, rt-multi-thread, sync, time, net, fs, signal. |
| `axum` | `0.8` | REST HTTP server | Built on tower + tokio. Type-safe extractors. Zero-cost route layer composition. |
| `tonic` | `0.12` | gRPC server | Native Rust gRPC. Server-streaming support. Interceptor-based auth. |
| `tower` | `0.5` | Middleware framework | Limit, retry, timeout, buffer, concurrency. Foundation for circuit breaker. |
| `tower-http` | `0.6` | HTTP middleware | CORS, tracing, compression, timeout, request-id, set-header. Battle-tested. |

### Database & Serialization

| Crate | Version | Purpose | Why this crate |
|-------|---------|---------|---------------|
| `sqlx` | `0.8` | PostgreSQL driver | Async, compile-time query verification. `features = ["postgres", "runtime-tokio-rustls", "chrono", "uuid", "rust_decimal", "migrate", "offline"]`. |
| `serde` | `1.0` | Serialization framework | `derive` feature. Foundation for all JSON handling. |
| `serde_json` | `1.0` | JSON serialize/deserialize | `preserve_order` feature for canonical JSON (cache key hash). |
| `chrono` | `0.4` | Date/time types | `serde` feature. Used with sqlx for TIMESTAMPTZ columns. |
| `uuid` | `1.11` | UUID generation | `v4`, `serde`, `sqlx` features. Primary keys for app tables. |
| `rust_decimal` | `1.36` | Precise decimal type | `serde`, `sqlx` features. Budget tracking (USD). Byte-compatible with Python `Decimal`. |

### Auth & Security

| Crate | Version | Purpose | Why this crate |
|-------|---------|---------|---------------|
| `argon2` | `0.5` | Password hash verify | Byte-compatible with Laravel's Argon2id. `password_hash` feature for PHC string format. |
| `sha2` | `0.10` | SHA-256 hashing | Sanctum token hash (`hash('sha256', plain_token)`). Cache key generation. File checksums. |
| `hmac` | `0.12` | HMAC signing | Inter-service request signing & Webhook verification. `HMAC-SHA256(timestamp + "." + body, secret)`. |
| `hex` | `0.4` | Hex encoding | Encode SHA-256 hash outputs. Encode HMAC signatures. |
| `subtle` | `2.6` | Constant-time comparison | `ConstantTimeEq` for HMAC signature verification. Prevents timing attacks. |

### HTTP Clients

| Crate | Version | Purpose | Why this crate |
|-------|---------|---------|---------------|
| `reqwest` | `0.12` | HTTP/2 client | `rustls-tls`, `http2`, `gzip`, `json` features. Connection pooling, timeout, redirect. Used for LLM provider calls + Media Gen calls. |
| `aws-sdk-s3` | `1.x` | S3/R2 client | Multipart upload, signed URL generation for Flutter download. |
| `aws-config` | `1.x` | AWS credential chain | Load credentials from env vars for R2 compatibility. |

### Cache, Governance & Queue

| Crate | Version | Purpose | Why this crate |
|-------|---------|---------|---------------|
| `redis` | `0.27` | Redis client | `tokio-comp`, `streams` features. XADD, XREADGROUP, XACK, XCLAIM commands. |
| `deadpool-redis` | `0.18` | Redis connection pool | Managed pool with health checks. Compatible with Upstash free tier limits. |
| `blake2` | `0.10` | BLAKE2b hashing | Advisory lock ID generation. `person=b"klasscch"` — must be byte-identical with Python. |

### Observability

| Crate | Version | Purpose | Why this crate |
|-------|---------|---------|---------------|
| `tracing` | `0.1` | Structured logging | Span-based. `log` feature for compatibility. Integration with `tracing-subscriber`. |
| `tracing-subscriber` | `0.3` | Log subscriber | `json`, `env-filter` features. JSON stdout output → Render log viewer. |
| `tower-http` | (above) | Request tracing | `TraceLayer` — auto-generate span per request with latency + status code. |

### Error Handling & Config

| Crate | Version | Purpose | Why this crate |
|-------|---------|---------|---------------|
| `thiserror` | `2.0` | Derive `Error` trait | `AppError` enum with per-category variants. Compile-time `Display` + `Error` impl. |
| `anyhow` | `1.0` | Flexible error context | For glue code and startup where typed errors aren't needed. `.context()` chaining. |
| `config` | `0.14` | Configuration management | Hierarchical config: env vars → `.env` → defaults. `toml` and `json` features. |
| `dotenvy` | `0.15` | `.env` file loading | Dev-only. Load `.env.local` before config crate in `main.rs`. |

### Validation & API Docs

| Crate | Version | Purpose | Why this crate |
|-------|---------|---------|---------------|
| `garde` | `0.20` | Request validation | Derive macros for struct validation. Equivalent to Laravel `FormRequest::rules()`. `email`, `length`, `pattern`, custom validators. |
| `utoipa` | `5.0` | OpenAPI codegen | Auto-generate `openapi.json` from axum handler annotations. `axum` feature for extractor support. |
| `utoipa-swagger-ui` | `8.0` | Swagger UI | Serve Swagger UI at `GET /docs`. Embedded HTML. |

### LLM Provider Integration

| Crate | Version | Purpose | Why this crate |
|-------|---------|---------|---------------|
| `reqwest` | (above) | HTTP/2 + connection pooling | HTTP client for Gemini API (query-param key auth) + OpenAI API (bearer token auth). |
| `serde_json` | (above) | JSON request/response | Parse Gemini `generateContent` response, OpenAI `v1/responses` response. |
| `async-trait` | `0.1` | Async trait support | `Provider` trait with `async fn complete()`. Required until native async traits stabilize. |

---

## Dev Dependencies

| Crate | Version | Purpose |
|-------|---------|---------|
| `sqlx-cli` | `0.8` | `sqlx migrate add/run/revert` + `sqlx prepare` for offline query checking |
| `cargo-nextest` | `0.9` | Faster test runner (parallel by default, better output) |
| `cargo-watch` | `8.x` | `cargo watch -x run` — hot reload during dev |
| `rustfmt` | (rustup) | Code formatting. `max_width = 100`, `tab_spaces = 4`. |
| `clippy` | (rustup) | Linter. `-D warnings` in CI. Custom lints in `clippy.toml`. |
| `tokio-test` | `0.4` | `tokio::test` macro for async test functions |
| `mockito` | `1.x` | HTTP mock server for provider integration tests |
| `testcontainers` | `0.23` | Ephemeral PostgreSQL + Redis for integration tests |
| `prost-build` | `0.13` | Proto → Rust codegen (build.rs) |
| `tonic-build` | `0.12` | Proto → tonic service codegen (build.rs) |

---

## Cargo Features Configuration

### tokio features

```toml
tokio = { version = "1.43", features = [
    "rt-multi-thread",  # Multi-thread runtime (default on server)
    "macros",           # #[tokio::main], tokio::select!, tokio::join!
    "sync",             # Mutex, RwLock, Semaphore, Notify, mpsc
    "time",             # sleep, timeout, interval
    "net",              # TCP listener (axum requires)
    "fs",               # Read proto files, write SQLX_OFFLINE data
    "signal",           # Graceful shutdown on SIGTERM
    "io-util",          # AsyncRead/AsyncWrite utilities
] }
```

### sqlx features

```toml
sqlx = { version = "0.8", features = [
    "postgres",              # PostgreSQL driver
    "runtime-tokio-rustls",  # Tokio runtime + TLS
    "chrono",                # DateTime<Utc> column support
    "uuid",                  # Uuid column support
    "rust_decimal",          # Decimal column support
    "migrate",               # Embedded migration runner
    "offline",               # SQLX_OFFLINE=true support in CI
] }
```

### serde features

```toml
serde = { version = "1.0", features = ["derive"] }
serde_json = { version = "1.0", features = ["preserve_order"] }
```

---

## Dev Tooling

### Toolchain (rust-toolchain.toml)

```toml
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy", "rust-analyzer"]
targets = ["x86_64-unknown-linux-musl"]
```

### rustfmt.toml

```toml
max_width = 100
tab_spaces = 4
edition = "2024"
use_small_heuristics = "Max"
group_imports = "StdExternalCrate"
imports_granularity = "Crate"
reorder_impl_items = true
```

### clippy.toml

```toml
too-many-arguments-threshold = 8
type-complexity-threshold = 350
```

### VS Code (settings.json)

```jsonc
{
    "rust-analyzer.cargo.features": "all",
    "rust-analyzer.check.command": "clippy",
    "rust-analyzer.cargo.buildScripts.enable": true,
    "[rust]": {
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "rust-lang.rust-analyzer"
    }
}
```

### .env.local template

```bash
# Neon PostgreSQL (via PgBouncer)
DATABASE_URL=postgres://user:pass@ep-xxx.ap-southeast-1.aws.neon.tech/klass?sslmode=require
DATABASE_MAX_CONNECTIONS=5

# Upstash Redis
REDIS_URL=redis://default:pass@xxx.upstash.io:6379

# Media Generator (HF Space #3)
MEDIA_GENERATION_PYTHON_BASE_URL=https://xxx.hf.space
MEDIA_GENERATION_PYTHON_SHARED_SECRET=***
MEDIA_GEN_WEBHOOK_SECRET=***

# LLM Providers
LLM_ADAPTER_GEMINI_API_KEY=***
LLM_ADAPTER_GEMINI_BASE_URL=https://generativelanguage.googleapis.com
LLM_ADAPTER_GEMINI_INTERPRET_MODEL=gemini-2.0-flash
LLM_ADAPTER_GEMINI_DELIVERY_MODEL=gemini-2.0-flash

LLM_ADAPTER_OPENAI_API_KEY=***
LLM_ADAPTER_OPENAI_BASE_URL=https://api.openai.com
LLM_ADAPTER_OPENAI_INTERPRET_MODEL=gpt-5.4
LLM_ADAPTER_OPENAI_DELIVERY_MODEL=gpt-5.4

# Provider routing
LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER=gemini
LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER=gemini
LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER=openai
LLM_ADAPTER_UPSTREAM_TIMEOUT_SECONDS=30

# Cache & Governance
LLM_ADAPTER_INTERPRETATION_CACHE_TTL_SECONDS=86400
LLM_ADAPTER_DELIVERY_CACHE_TTL_SECONDS=21600
LLM_ADAPTER_INTERPRETATION_DAILY_BUDGET_USD=25.00
LLM_ADAPTER_DELIVERY_DAILY_BUDGET_USD=10.00

# Cloudflare R2
AWS_ACCESS_KEY_ID=***
AWS_SECRET_ACCESS_KEY=***
AWS_ENDPOINT_URL=https://xxx.r2.cloudflarestorage.com
AWS_REGION=auto
R2_BUCKET_NAME=klass-artifacts

# Gateway
RUST_LOG=info,klass_gateway=debug
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
GRPC_PORT=50051
```

---

## CI/CD Pipeline

### GitHub Actions Workflow

**File**: `.github/workflows/gateway-ci.yml`

```yaml
name: Gateway CI

on:
  push:
    branches: [main]
    paths:
      - 'gateway/**'
      - 'proto/**'
      - '.github/workflows/gateway-ci.yml'
  pull_request:
    branches: [main]
    paths:
      - 'gateway/**'
      - 'proto/**'

env:
  CARGO_TERM_COLOR: always
  SQLX_OFFLINE: true
  RUSTFLAGS: "-D warnings"

jobs:
  # ── Lint ──────────────────────────────────────────────
  lint:
    name: Lint (clippy + fmt)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: gateway
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy
      - uses: Swatinem/rust-cache@v2
        with:
          workspaces: gateway
      - name: Check formatting
        run: cargo fmt --all -- --check
      - name: Run clippy
        run: cargo clippy --all-targets --all-features -- -D warnings

  # ── Test ─────────────────────────────────────────────
  test:
    name: Test (cargo nextest)
    runs-on: ubuntu-latest
    needs: lint
    services:
      postgres:
        image: postgres:17-alpine
        env:
          POSTGRES_DB: klass_test
          POSTGRES_USER: klass
          POSTGRES_PASSWORD: klass_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
    defaults:
      run:
        working-directory: gateway
    env:
      DATABASE_URL: postgres://klass:klass_test@localhost:5432/klass_test
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
        with:
          workspaces: gateway
      - uses: taiki-e/install-action@cargo-nextest
      - name: Run migrations
        run: cargo sqlx migrate run
      - name: Prepare sqlx offline data
        run: cargo sqlx prepare --check
      - name: Run tests
        run: cargo nextest run --all-features
      - name: Upload test report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: nextest-report
          path: gateway/target/nextest/default/junit.xml

  # ── Build ────────────────────────────────────────────
  build:
    name: Build (Docker image)
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Build Docker image
        uses: docker/build-push-action@v6
        with:
          context: gateway
          push: false
          load: true
          tags: klass-gateway:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
      - name: Verify image size
        run: |
          SIZE=$(docker image inspect klass-gateway:latest --format '{{.Size}}')
          echo "Image size: $SIZE bytes"
          # Target <30MB, warn if >50MB
          if [ "$SIZE" -gt 50000000 ]; then
            echo "::warning::Docker image size >50MB, target <30MB"
          fi

  # ── Deploy ───────────────────────────────────────────
  deploy:
    name: Deploy to Render
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Trigger Render deploy
        run: |
          curl -X POST \
            "${{ secrets.RENDER_DEPLOY_HOOK_URL }}" \
            -H "Content-Type: application/json"
```

### Pipeline Stage Summary

| Stage | Command | Time Budget | Blocking |
|-------|---------|-------------|----------|
| `lint` | `cargo fmt --check` + `cargo clippy` | <2 min | Yes |
| `test` | `cargo nextest run` + `sqlx prepare --check` | <5 min | Yes (after lint) |
| `build` | `docker build` (multi-stage) | <5 min | Yes (after test, main only) |
| `deploy` | Render deploy hook | <1 min | Manual approval for prod |

**Total CI time**: ~12 min (parallel lint+test → build → deploy)

---

## Deployment

### Dockerfile (Multi-Stage)

```dockerfile
# ── Builder Stage ───────────────────────────
FROM rust:1.85-slim-bookworm AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Cache dependencies (layer caching)
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Copy source and build
COPY src/ src/
COPY migrations/ migrations/
COPY proto/ proto/
COPY build.rs build.rs
COPY .sqlx/ .sqlx/

RUN SQLX_OFFLINE=true cargo build --release

# ── Runtime Stage ────────────────────────────
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/klass-gateway /usr/local/bin/klass-gateway

EXPOSE 8080 50051

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/usr/local/bin/klass-gateway"]
```

### Render Service Config

```yaml
# render.yaml (or manual config via Render dashboard)
services:
  - type: web
    name: klass-gateway
    env: docker
    region: singapore
    plan: starter
    healthCheckPath: /health
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: klass-db
          property: connectionString
      - key: REDIS_URL
        sync: false
      - key: RUST_LOG
        value: info,klass_gateway=debug
    autoDeploy: true
    dockerfilePath: ./Dockerfile
    dockerContext: ./gateway
```

---

## Editions & Policies

### Rust Edition

```toml
# Cargo.toml
[package]
edition = "2024"
rust-version = "1.85"
```

**Edition 2024 rationale**: Stable since Rust 1.85. Key features used:
- `impl Trait` in return position everywhere (not just functions)
- `unsafe_op_in_unsafe_fn` lint by default
- Lifetime capture rules for RPIT (simpler `async fn` lifetimes)

### MSRV Policy

- Minimum Supported Rust Version: **1.85** (stable)
- `cargo-msrv` checked in CI
- Dependencies must compile on 1.85+
- Upgrade MSRV when edition 2027 stabilizes

### Security Updates

- `cargo audit` in CI (weekly scheduled run)
- `dependabot` enabled for Cargo.toml updates
- Critical security patches: merge same-day, deploy same-day

---

## Crate Dependency Graph

```
klass-gateway
├── axum 0.8 ──────────────► tower 0.5, tower-http 0.6, tokio 1.43
├── tonic 0.12 ────────────► prost 0.13, tokio 1.43, tower 0.5
├── sqlx 0.8 ──────────────► tokio 1.43, chrono 0.4, uuid 1.11, rust_decimal 1.36
├── reqwest 0.12 ──────────► tokio 1.43, hyper 1.x, rustls 0.23
│   └── h2 0.4 ────────────► HTTP/2 framing
├── redis 0.27 ────────────► tokio 1.43
├── deadpool-redis 0.18 ───► redis 0.27
├── aws-sdk-s3 1.x ────────► aws-config 1.x, aws-credential-types 1.x
├── serde 1.0 ◄──────────── (shared by all serialization)
├── argon2 0.5 ────────────► blake2 0.10 (Argon2id uses Blake2b internally)
├── sha2 0.10 ─────────────► digest 0.10
├── hmac 0.12 ─────────────► digest 0.10, sha2 0.10
├── blake2 0.10 ───────────► digest 0.10
├── tracing 0.1 ───────────► tracing-subscriber 0.3
├── thiserror 2.0
├── anyhow 1.0
├── config 0.14
├── garde 0.20
├── utoipa 5.0 ────────────► serde 1.0
└── uuid 1.11
```

---

## References

- `IMPLEMENTATION_PLAN.md` — Task 2.5, Architecture Target
- `docs/adr/0001-rust-gateway-language.md` — Rust language choice
- `docs/adr/0005-deployment-target-render.md` — Render deployment
- `docs/adr/0006-queue-strategy-redis-streams.md` — Redis Streams choice
- `docs/architecture/TARGET_ARCHITECTURE.md` — Component diagram & module dependencies
- `docs/contracts/webhook_media_gen.md` — Webhook Contract
- `docs/mobile/async_media_gen.md` — Mobile Integration Guide
