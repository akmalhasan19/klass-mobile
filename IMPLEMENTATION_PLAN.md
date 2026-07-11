# Implementation Plan: Laravel → Rust Gateway Migration

> **Status**: Approved
> **Timeline**: 18 minggu (4.5 bulan)
> **Last Updated**: 2026-07-11
> **Based on**: Codebase audit `klass-mobile` (commit `0b794bc`)

---

## Final Decision Matrix

| # | Decision | Impact |
|---|----------|--------|
| 1 | Hybrid gRPC server-streaming (media-gen flow) + REST/Dio (11 service lain) | Flutter: 1 service file rewrite + 2 new packages; proto file |
| 2 | Render Web Service (Starter $7/bln) + Upstash Redis free tier | ADR-005; region sama dengan Neon |
| 3 | Konsolidasi LLM Adapter ke Rust Gateway. Keep Media Gen di HF Space #3 | HF Space: 3 → 1; hapus 1 Postgres DB; timeline +2 minggu |
| 4 | Redis Streams (Upstash) untuk job queue | ADR-006; `XREADGROUP` consumer groups |
| 5 | Audit table identik; migrate existing cache entries saat cutover | Fase 6 tambah data migration script |

---

## Architecture Target

```
┌─────────────┐  REST/JSON    ┌──────────────────────┐  HTTP/2 + HMAC  ┌────────────────────┐
│  Flutter    │ ─────────────>│  Rust Gateway        │ ──────────────>│  HF Space #3:      │
│  (Dio REST  │ <─polling──── │  (Axum + tonic,      │ <──artifact────│  Media Generator   │
│   + gRPC    │               │   tokio, sqlx,       │   signed URL    │  (FastAPI/Python)  │
│   stream)   │               │   Redis Streams)     │                 │  python-docx/      │
└─────────────┘               │                      │                 │  reportlab/        │
                              │  - Sanctum auth      │                 │  python-pptx       │
                              │  - LLM providers     │                 └────────────────────┘
                              │    (Gemini/OpenAI)   │
                              │  - Cache + rate-    │
                              │    limit governance  │
                              │  - State machine     │
                              │  - tokio::join!      │
                              └────────┬─────────────┘
                                       │ sqlx (PgBouncer)
                                       v
                              ┌──────────────────────┐
                              │  Neon PostgreSQL     │  (schema aplikasi + cache/governance
                              │  + Cloudflare R2/S2  │   consolidasi)
                              └──────────────────────┘
                                       │
                                       v
                              ┌──────────────────────┐
                              │  Upstash Redis       │  (Stream queue)
                              └──────────────────────┘
```

**Removed components**: Laravel backend (HF Space #1), LLM Adapter (HF Space #2), LLM Adapter DB.

---

## Risk Assessment Matrix

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Sanctum token byte-incompatible di Rust | Med | High | Replikasi exact hash algo `hash('sha256', plain_token)`; validasi via shadow-read Fase 5 |
| HF Space Media Gen tidak bisa dijangkau HTTP/2 | Med | Med | Audit Fase 1; fallback HTTP/1.1 + keep-alive (reqwest otomatis) |
| State machine 8-state salah replikasi | High | High | Property-based test untuk semua transisi; port unit test Laravel 1:1 |
| Redis Stream message lost saat consumer crash | Low | High | `XREADGROUP` + `XCLAIM` untuk redeliver; worker idempotent via `statusBefore` check |
| Cache hash byte inkompatibel Python↔Rust | Med | High | Unit test Fase 5: hash 100 sample payload di Python & Rust, assert byte-identik |
| Provider response parsing beda (Pydantic vs serde) | Med | Med | Contract test: capture 5 sample real Gemini+OpenAI response, deserialize di Rust |
| Cold start HF Space #3 (Media Gen) | High | Med | Ping keep-alive dari Rust gateway setiap 4 menit |
| 1-2 dev belajar Rust → velocity rendah 4 minggu pertama | High | Med | Pair programming; mulai dari modul kecil (auth) sebelum orchestrator |
| Cache migration miss → LLM bill spike minggu 1 | Med | Med | Migrate existing cache entries pre-cutover; verify count match source==target |
| Budget infra naik >50% | Low | Med | Render $7 + Upstash free + 1 HF Space dihapus → netral/turun |

---

## Timeline Gantt

```
W1-2:   [====] Fase 1 Audit (expanded: + LLM Adapter DB schema)
W3-4:   [====] Fase 2 Design (revised ADRs, proto, cache/governance port spec)
W5-6:   [====] Fase 3 Setup (Render + Upstash Redis + Docker compose)
W7:        [=] Fase 4.1 Core Framework
W7-8:      [==] Fase 4.2 DB Layer + LLM Adapter Schema Port
W8:        [=] Fase 4.3 Auth & Security
W9-10:     [====] Fase 4.4 LLM Provider Module
W9-11:     [======] Fase 4.5 Cache + Governance Module
W11-12:    [====] Fase 4.6 Media Gen Integration + Redis Worker
W12-13:    [====] Fase 4.7 Orchestrator + State Machine
W13-14:    [====] Fase 4.8 API Surface (gRPC tonic + REST Axum)
W15-16:    [====] Fase 5 Testing (k6, chaos, contract, cache)
W17-18:    [====] Fase 6 Migration (blue-green + cache migration + cutover)
```

---

## Success Metrics

| Dimensi | Metric | Target |
|---------|--------|--------|
| Performance | p99 `POST /media-generations` end-to-end | ≤ Laravel baseline (target -30%) |
| Performance | p95 `GET /media-generations/{id}` | < 80ms |
| Performance | Throughput sustained | ≥ 500 rps read, ≥ 50 rps submit |
| Performance | gRPC stream token-to-Flutter delay | < 100ms |
| Reliability | Uptime gateway | > 99.9% |
| Reliability | Error rate 5xx | < 0.1% |
| Reliability | Queue job failure rate | < 2% |
| Cost | Infra bill monthly | ≤ baseline + 50% (target: turun) |
| DX | `cargo build` clean incremental | < 60s |
| DX | `cargo nextest run` | < 90s |
| DX | Test coverage | > 75% (target 80%) |
| Migration | Flutter app breakage | 0 (1 service file rewrite, UI tetap) |
| Migration | User re-auth required | 0 (token Sanctum compatible) |
| Migration | Data loss | 0 |

---

## FASE 1: AUDIT & ASSESSMENT (W1-2)

### Task 1.1: Code Audit Laravel

- [x] Dump semua 26 endpoint (unique URL patterns, 40 controller actions) ke tabel inventory: `route | controller | method | middleware chain | FormRequest | Resource | rate-limit`
  - [x] Public auth routes (4): register, login, get-security-question, verify-and-reset-password
  - [x] Protected auth routes (3): logout, me, refresh
  - [x] Public read routes (9): topics (index+show), contents (index+show), marketplace-tasks (index+show), student-progress (index+show), homepage-recommendations
  - [x] App config routes (1): homepage-sections
  - [x] Gallery routes (1): gallery (index only — no `show` route exists)
  - [x] Protected routes (6 unique URL patterns — user/avatar, media-generations [index+store], media-generations/{id} [show], /regenerate, /suggest-freelancers, /hire-freelancer)
  - [x] Teacher routes (1): topics/store
  - [x] Freelancer routes (0): middleware group exists but no routes defined (placeholder)
  - [x] Admin routes (10 unique URL patterns): debug-taxonomy, topics/{id} (update+destroy), contents (store+update+destroy across 2 URLs), marketplace-tasks (store+update+destroy across 2 URLs), student-progress (store+update+destroy across 2 URLs), upload/{category} (upload+destroy)
- [x] List semua `FormRequest` di `app/Http/Requests/` — kumpulkan validation rules untuk porting ke crate `garde` (NB: ditemukan inkonsistensi password min: `RegisterRequest` pakai `min:8`, `ResetPasswordRequest` pakai `min:6` — standarisasi di Rust)
- [x] List semua `JsonResource` di `app/Http/Resources/` — spec output shape per endpoint sebagai basis serde struct
- [x] Dependency graph 22 service class di `app/Services/` — identifikasi pure-orchestration (port ke Rust) vs business-decision (perlu spec)
- [x] Document `ProcessMediaGenerationJob` + `MediaGenerationWorkflowService` state machine map EXACT
- [x] Verify event listener & subscriber — Laravel 11+ uses auto-discovery, no `EventServiceProvider`. Check `app/Notifications/` (2 kelas: `FreelancerAssignedTask`, `FreelancerNewTaskPosted` — currently TODO only) dan inline `ActivityLog` calls
- [x] Composer dependency analysis (4 prod deps: framework, sanctum, tinker, flysystem-aws-s3-v3)
- [x] List scheduled tasks — Laravel 11+ removed `app/Console/Kernel.php`. Check `routes/console.php` (only `inspire` command) + Artisan commands di `app/Console/Commands/` (6 commands: BackfillMediaFiles, BackfillProjectThumbnails, BackfillTopicOwnership, SeedBucketAssets, SmokeTestLlmAdapter, SmokeTestMediaGenerator)

### Task 1.2: Data Audit

- [x] Export schema via `pg_dump --schema-only` dari Neon (DB aplikasi)
- [x] 30 migrations: `php artisan migrate:status` — identifikasi yang sudah jalan vs schema drift (catatan: 2 migration membuat multiple tabel — `create_users_table` membuat `users`, `password_reset_tokens`, `sessions`; `create_jobs_table` membuat `jobs`, `job_batches`, `failed_jobs`; beberapa tabel Laravel built-in (`cache`, `cache_locks`, `jobs`, `job_batches`, `failed_jobs`, `password_reset_tokens`, `sessions`) tidak perlu diport ke Rust)
- [x] Per-table: row count, growth rate (query `pg_class.reltuples` + sampling 7 hari terakhir via `created_at`)
- [x] Identifikasi kolom JSON structured (NB: Laravel pakai `json` bukan `jsonb` — perlu dipertimbangkan saat port ke Rust apakah perlu `ALTER TYPE SET DATA TYPE jsonb`):
  - [x] `media_generations` (7 kolom): `interpretation_payload`, `interpretation_audit_payload`, `generation_spec_payload`, `decision_payload`, `orchestration_audit_payload`, `delivery_payload`, `generator_service_response` — kandidat dipecah ke tabel atau tetap JSON
  - [x] `activity_logs.metadata` (polymorphic subject data)
  - [x] `contents.data` (module/quiz/brief content blob)
  - [x] `recommended_projects.tags`, `recommended_projects.modules`, `recommended_projects.source_payload`
  - [x] LLM Adapter JSONB columns: `request_payload`, `response_payload` (both cache tables), `attempted_providers`, `metadata` (llm_request_ledger)
- [x] Identifikasi FK constraint + ON DELETE behavior (penting untuk sqlx migration)
- [x] Cek trigger via `pg_trigger` — Laravel biasanya tidak pakai tapi verify
- [x] Dump schema LLM Adapter DB terpisah (6 tabel + 2 view di 2 file migration):
  - [x] `0001_adapter_state.sql`: `interpretation_cache_entries`, `delivery_cache_entries`
  - [x] `0002_governance_state.sql`: `rate_limit_policies`, `rate_limit_buckets`, `llm_request_ledger`, `price_catalog_entries`, `llm_request_daily_aggregates` (VIEW), `llm_request_daily_route_aggregates` (VIEW)
- [x] Cek `llm-adapter-service/app/migrations/` folder untuk semua migration files
- [x] Row count LLM Adapter DB + cache hit ratio baseline (kedua tabel):
  - [x] `SELECT COUNT(*), SUM(hit_count) / NULLIF(COUNT(*), 0) FROM interpretation_cache_entries WHERE expires_at > NOW()`
  - [x] `SELECT COUNT(*), SUM(hit_count) / NULLIF(COUNT(*), 0) FROM delivery_cache_entries WHERE expires_at > NOW()`
  - [x] Query yang sama via VIEW: `SELECT route, SUM(cache_hit_count) / NULLIF(SUM(request_count), 0) FROM llm_request_daily_route_aggregates WHERE usage_date = CURRENT_DATE GROUP BY route`
- [x] List semua env vars di `llm-adapter-service/app/settings.py` untuk port ke Rust config

### Task 1.3: Performance Baseline

- [x] Pasang APM sementara (Sentry performance OR Laravel Telescope) selama 7 hari
- [x] Capture per-endpoint: p50/p95/p99, throughput rps, error rate
- [x] Khusus: latensi `POST /v1/media-generations` end-to-end (submit → completed) — metric paling kritis
- [x] Memory/CPU: `docker stats` selama peak load
- [x] Failure mode catalog: 5xx terakhir 30 hari dari log
- [x] Baseline cache hit ratio LLM Adapter (interpret vs respond route)

### Task 1.4: Integration Mapping

- [x] Sequence diagram Mermaid: Flutter → Laravel → LLM Adapter → Media Gen → S3 → Flutter download
- [x] Document HMAC contract lengkap dari `InterServiceRequestSigner::build` + `llm-adapter-service/app/auth.py` + `media-generator-service/app/auth.py`
- [x] Timeouts/retry per integration (dari `config/services.php`):
  - [x] Interpreter: 30s/2 retry/250ms backoff
  - [x] Drafting: 30s/2 retry/250ms backoff
  - [x] Delivery: 30s/2 retry/250ms backoff
  - [x] Python Media Gen: 60s/2 retry/500ms backoff
- [x] Eksplisit: tidak ada circuit breaker formal saat ini — Rust akan add via `tower::limit`
- [x] Document LLM Adapter provider behavior di `llm-adapter-service/app/providers/` (gemini, openai)
- [x] Identifikasi rate-limit fallback logic, error code mapping di provider

### Gate Fase 1 → Fase 2 (Go/No-Go)

- [x] Daftar 26 endpoint lengkap dengan kontrak req/resp
- [x] State machine diagram `MediaGenerationLifecycle` terverifikasi 1:1 dengan kode
- [x] Baseline p50/p95/p99 di tangan
- [x] HMAC contract diverifikasi dari sisi Python (`verify_request_signature`)
- [x] LLM Adapter DB schema dump lengkap
- [x] Cache hit ratio baseline tercatat

---

## FASE 2: ARSITEKTUR & DESIGN (W3-4)

### Task 2.1: Architecture Decision Records (ADRs)

- [ ] ADR-001: Bahasa Gateway — Rust (diterima) vs Go vs Node.js
- [ ] ADR-002: Protokol Flutter ↔ Gateway — Hybrid gRPC server-streaming (media-gen) + REST (lainnya)
- [ ] ADR-003: Konsolidasi Laravel → Rust; tetap pertahankan Media Gen terpisah
- [ ] ADR-004: Database strategy — Neon PostgreSQL tetap; schema identik; port migration ke sqlx
- [ ] ADR-005: Deployment target — Render Web Service (Starter $7/bln); region sama Neon
- [ ] ADR-006: Queue strategy — Redis Streams via Upstash free tier
- [ ] ADR-007: Consolidate LLM Adapter ke Rust Gateway — hapus HF Space #2 + 1 Postgres DB
- [ ] ADR-008: Cache DB pindah ke Neon aplikasi — tabel `llm_cache_entries` (gabungan interpret+delivery, route discriminator)

### Task 2.2: Target Architecture Diagram

- [ ] Component diagram lengkap (Flutter → Rust Gateway → Media Gen → Neon → R2 → Redis)
- [ ] Data flow Generate PDF: LLM interpret → draft → decision → Media Gen → PDF → R2 → Flutter
- [ ] Data flow Generate DOCX (same flow)
- [ ] Data flow Generate PPTX (same flow)
- [ ] Communication protocol per edge: gRPC stream, REST/JSON, HTTP/2 + HMAC, Redis Streams

### Task 2.3: API Contract Design

- [ ] Proto file `proto/klass/media/v1/media_generation.proto`:
  - [ ] `service MediaGenerationService` dengan `SubmitMediaGeneration` + `Regenerate` (server-streaming)
  - [ ] `message SubmitRequest` (prompt, preferred_output_type, subject_id, sub_subject_id)
  - [ ] `message RegenerateRequest` (parent_id, additional_prompt)
  - [ ] `message GenerationProgressEvent` (generation_id, status, is_terminal, metadata, delivery_payload, error)
  - [ ] `message DeliveryPayload` (title, preview_summary, teacher_message, artifact, recommended_next_steps, fallback)
  - [ ] `message ErrorPayload` (code, message, retryable)
- [ ] REST fallback spec (OpenAPI 3.1): basis dump semua `JsonResource` Laravel ke JSON schema
- [ ] Internal API contract Gateway → Media Gen: HTTP/2 + HMAC (sama dengan Laravel sekarang)
- [ ] Internal contract Gateway → LLM providers (Gemini/OpenAI): HTTP/2 + API key

### Task 2.4: Database Schema Design

- [ ] 30 Laravel migrations → 30 sqlx migration files (timestamp identik; table yang tidak perlu diport: `cache`, `cache_locks`, `jobs`, `job_batches`, `failed_jobs`, `password_reset_tokens`, `sessions` — ini digantikan Redis lifecycle)
- [ ] 5-6 sqlx migration baru untuk konsolidasi LLM Adapter schema:
  - [ ] `llm_cache_entries` — konsolidasi `interpretation_cache_entries` + `delivery_cache_entries` ke satu tabel dengan kolom `route` ('interpret'/'respond') sebagai discriminator; (cache_key, route, request_payload JSONB, response_payload JSONB, created_at, expires_at, hit_count, last_hit_at) + partial index per route
  - [ ] `llm_rate_limit_policies` (scope_type, strategy, route, provider, model, window_unit, max_requests, max_input_tokens, max_output_tokens, max_total_tokens, max_estimated_cost_usd, enabled) + UNIQUE constraint pada (scope_type, route, provider, model, window_unit)
  - [ ] `llm_rate_limit_buckets` (policy_id FK, window_started_at, window_ends_at, request_count, input_tokens, output_tokens, total_tokens, estimated_cost_usd, deny_count, last_request_id, last_generation_id) + UNIQUE pada (policy_id, window_started_at)
  - [ ] `llm_request_ledger` — audit trail untuk tiap LLM API call (request_id, generation_id, route, provider, model, latency_ms, retry_count, cache_status, final_status, error_class, error_code, fallback_used, input_tokens, output_tokens, total_tokens, estimated_cost_usd, cache_key, metadata JSONB) — non-kritis, bisa di-stream ke tabel terpisah
  - [ ] `llm_price_catalog` — simplifikasi dari `price_catalog_entries` (provider, model, input_cost_per_unit_usd, output_cost_per_unit_usd, effective_from, is_active) + deduplikasi by provider+model
  - [ ] (Opsional) View `llm_request_daily_aggregates` & `llm_request_daily_route_aggregates` bisa diganti query langsung via `sqlx`; tidak perlu migration terpisah
- [ ] Mapping 15 Eloquent Model → 15 Rust struct + `#[derive(FromRow)]`
- [ ] Mapping LLM Adapter cache struct (Python dataclass) → Rust struct
- [ ] Data migration strategy: zero-downtime, dual-read di Fase 6

### Task 2.5: Tech Stack Final

- [ ] Rust crates list dengan versi spesifik:
  - [ ] `axum` 0.7, `tokio` 1.x (full features), `sqlx` 0.8 (postgres, runtime-tokio-rustls)
  - [ ] `tonic` 0.12 (gRPC server), `prost` 0.13 (protobuf)
  - [ ] `reqwest` 0.12 (HTTP/2, rustls), `serde` 1, `serde_json` 1
  - [ ] `argon2` 0.5 (Sanctum password verify), `tower` 0.5, `tower-http` 0.6
  - [ ] `tracing` 0.1, `tracing-subscriber` 0.3
  - [ ] `thiserror` 1, `anyhow` 1
  - [ ] `config` 0.14, `aws-sdk-s3` 1.x
  - [ ] `uuid` 1.x, `garde` 0.20 (validation), `utoipa` 5 (OpenAPI)
  - [ ] `rust_decimal` 1.36 (governance budget), `blake2` 0.10 (advisory lock id)
  - [ ] `redis` 0.27 (Redis Streams), `deadpool-redis` 0.18
- [ ] Dev tools: `cargo-watch`, `sqlx-cli` 0.8, `cargo-nextest`, `rustfmt`, `clippy`
- [ ] CI/CD: GitHub Actions (lint → test → build → deploy Render)
- [ ] Deployment target: Render Web Service Docker, region sama Neon

### Gate Fase 2 → Fase 3 (Go/No-Go)

- [ ] Semua 8 ADR signed off
- [ ] Proto file draft reviewed
- [ ] Schema design untuk ~35 migrations selesai (30 Laravel parity + 5-6 konsolidasi baru)
- [ ] Tech stack dengan versi terkunci
- [ ] Env var mapping (Laravel + LLM Adapter → Rust) lengkap

---

## FASE 3: SETUP & INFRASTRUCTURE (W5-6)

### Task 3.1: Development Environment

- [ ] Create Rust project structure:
  ```
  gateway/
    Cargo.toml
    src/
      main.rs
      config.rs
      error.rs
      state.rs
      auth/
      db/
      cache/
      governance/
      providers/
      media_gen/
      orchestrator/
      api/
        grpc/
        rest/
    migrations/
    proto/
      klass/media/v1/media_generation.proto
    docker-compose.yml
    Dockerfile
  ```
- [ ] `docker-compose.yml` untuk local dev:
  - [ ] `postgres:17` (DB aplikasi mock)
  - [ ] `redis:7-alpine` (Stream queue mock)
  - [ ] `minio/minio` (R2/S3-compatible mock)
  - [ ] `rust-gateway` service dengan `cargo-watch -x run`
- [ ] Hot reload: `cargo watch -x "run"` + `SQLX_OFFLINE=true` untuk compile tanpa live DB
- [ ] `.env.local` template dengan semua env vars (paritas Laravel + LLM Adapter)

### Task 3.2: CI/CD Pipeline

- [ ] GitHub Actions workflow `.github/workflows/gateway-ci.yml`:
  - [ ] Stage `lint`: `cargo clippy -D warnings`
  - [ ] Stage `fmt-check`: `cargo fmt -- --check`
  - [ ] Stage `test`: `cargo nextest run` + `SQLX_OFFLINE=true`
  - [ ] Stage `build`: multi-stage Docker build
  - [ ] Stage `deploy`: manual approval → deploy ke Render
- [ ] Multi-stage Dockerfile Rust (target image <30MB):
  - [ ] Builder stage: `rustlang/rust:nightly`, `cargo fetch`, `SQLX_OFFLINE=true cargo build --release`
  - [ ] Runtime stage: `debian:bookworm-slim`, copy binary only
- [ ] Cache `~/.cargo` + `target/` di GitHub Actions
- [ ] `cargo sqlx prepare --check` di CI setiap query baru

### Task 3.3: Infrastructure Setup

- [ ] Render Web Service: create project, tier Starter ($7), pilih region sama Neon
- [ ] Set env vars di Render (paritas .env Laravel + LLM Adapter + Redis URL)
- [ ] Upstash Redis: create account, free tier, dapatkan `REDIS_URL`
- [ ] Render health check endpoint: `GET /health` → `{"status":"ok"}`
- [ ] Render auto-deploy dari `main` branch (setelah manual approval untuk production)
- [ ] Monitoring: `axum-prometheus` middleware → push ke Grafana Cloud free tier ATAU Render dashboard
- [ ] Log: `tracing` JSON stdout → Render logs (atau Papertrail temporary)

### Task 3.4: Database Setup

- [ ] Neon connection string dengan PgBouncer pooled (max 10 conns free tier)
- [ ] `sqlx migrate run` terhubung ke Neon staging branch (Neon fitur branch DB)
- [ ] Verify 30 migration ports successful
- [ ] Verify 5 new migration (cache + governance) successful
- [ ] Backup strategy: Neon automated PITR sudah cukup; verify restore procedure

### Task 3.5: Redis Setup

- [ ] Upstash Redis: enable Streams, dapatkan endpoint + password
- [ ] Verify `XADD` + `XREADGROUP` works dari Rust via `redis-rs`
- [ ] Define stream key: `klass:media-generation` + DLQ `klass:media-generation-dlq`
- [ ] Consumer group: `klass-workers`
- [ ] Backup: Upstash free tier daily backup sudah cukup

### Gate Fase 3 → Fase 4 (Go/No-Go)

- [ ] `cargo build` succeed tanpa warning
- [ ] `cargo nextest run` di Docker compose green (empty测试 skeleton)
- [ ] `sqlx migrate run` ke Neon staging berhasil (~35 migrations)
- [ ] Docker image <30MB
- [ ] Render deploy manual test berhasil (`/health` 200 OK)
- [ ] Redis Streams `XADD`/`XREADGROUP` verified dari Rust

---

## FASE 4: IMPLEMENTASI RUST GATEWAY (W7-14)

### Task 4.1: Core Framework (W7)

- [ ] Axum router dengan `AppState { db_pool, redis_pool, llm_clients, media_gen_client, config }`
- [ ] Middleware stack (order penting):
  - [ ] `TraceLayer` (tracing structured logging)
  - [ ] `CORS` (config dari `config/cors.php`)
  - [ ] `CompressionLayer`
  - [ ] `TimeoutLayer` (30s default)
  - [ ] `RequestId` middleware
  - [ ] `StructuredApiLogger` (port dari `backend/app/Http/Middleware/StructuredApiLogger.php`)
- [ ] Error handling: `AppError` enum (`thiserror`) dengan varian per kategori
- [ ] `IntoResponse` impl → JSON `{success: false, error: {code, message}}` (match format Laravel)
- [ ] Config management: `config` crate, env vars identik dengan Laravel (`config/services.php`, `config/sanctum.php`)
- [ ] Health endpoint `GET /health` → `{"status":"ok","version":"..."}` 

### Task 4.2: Database Layer (W7-8)

- [ ] `sqlx::PgPool::connect()` dengan `PgPoolOptions::max_connections(20)`
- [ ] 15 struct `#[derive(FromRow)]` mirroring 15 model:
  - [ ] User, Subject, SubSubject, Topic, Content, MediaGeneration, MediaFile, RecommendedProject
  - [ ] StudentProgress, MarketplaceTask, HomepageSection, SystemSetting, SystemRecommendationAssignment
  - [ ] FreelancerMatch, ActivityLog
- [ ] Repository pattern: trait per entity (e.g., `MediaGenerationRepo`) + impl `PgMediaGenerationRepo`
- [ ] Offline mode: `cargo sqlx prepare --check` di CI
- [ ] Port 30 migrations Laravel → sqlx migration files (timestamp identik; skip tabel Laravel built-in: `cache`, `cache_locks`, `jobs`, `job_batches`, `failed_jobs`, `password_reset_tokens`, `sessions`):
  - [ ] Verify setiap migration berjalan di Neon staging
  - [ ] Tidak ada schema drift
- [ ] Port 5-6 migration baru untuk konsolidasi cache + governance:
  - [ ] `llm_cache_entries` table (gabungan interpret+delivery dengan discriminator `route`)
  - [ ] `llm_rate_limit_policies` table
  - [ ] `llm_rate_limit_buckets` table
  - [ ] `llm_request_ledger` table (audit trail LLM API calls)
  - [ ] `llm_price_catalog` table (simplifikasi `price_catalog_entries`)
  - [ ] Index + constraints
- [ ] Connection pooling: deadpool-postgres + Neon PgBouncer

### Task 4.3: Auth & Security (W8)

- [ ] Sanctum-compatible token validation:
  - [ ] Password hash verifikasi via `argon2` crate (params `Argon2::verify`), compatible dengan hash Laravel
  - [ ] Sanctum plain token → `hash('sha256', plain)` → query `SELECT * FROM personal_access_tokens WHERE token = $1`
  - [ ] Verify byte-compatible di unit test (hash sample token di PHP, compare di Rust)
- [ ] Rate limit per-route (paritas `throttle:3,1` / `throttle:5,1` dari Laravel):
  - [ ] Implement via Redis counter (SETNX + EXPIRE) atau `tower-governator`
  - [ ] Route group: auth register 3/min, login 5/min, verify-and-reset 3/min
- [ ] HMAC signer untuk service-to-service (port `InterServiceRequestSigner::build`):
  - [ ] Header: `X-Request-Id`, `X-Klass-Generation-Id`, `X-Klass-Request-Timestamp`, `X-Klass-Signature-Algorithm`, `X-Klass-Signature`
  - [ ] Signature: `hash_hmac('sha256', timestamp + '.' + encoded_payload, shared_secret)`
  - [ ] Replay protection: `request_max_age_seconds` window check
- [ ] CORS: copy `config/cors.php` allowed paths & origins
- [ ] Security headers via `tower-http::set_header`: HSTS, X-Content-Type-Options, X-Frame-Options
- [ ] Role-based middleware: `auth:sanctum`, `teacher`, `freelancer`, `admin` (port `EnsureUserIs*.php`)

### Task 4.4: LLM Provider Module (W9-10)

- [ ] Define `Provider` trait:
  ```rust
  trait Provider {
      async fn interpret(&self, req: InterpretationRequest) -> Result<InterpretationResponse>;
      async fn draft(&self, req: ContentDraftRequest) -> Result<DraftResponse>;
      async fn respond(&self, req: DeliveryRequest) -> Result<DeliveryResponse>;
  }
  ```
- [ ] Port `providers/gemini.py` → `src/providers/gemini.rs`:
  - [ ] HTTP call ke `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
  - [ ] API key auth
  - [ ] Parse response: `usage.input_tokens`, `output_tokens`, `total_tokens`
  - [ ] Default model: `gemini-2.0-flash`
- [ ] Port `providers/openai.py` → `src/providers/openai.rs`:
  - [ ] HTTP call ke `https://api.openai.com/v1/responses`
  - [ ] Bearer token auth
  - [ ] Parse response: usage metadata
  - [ ] Default model: `gpt-5.4`
- [ ] HTTP/2 client dengan connection pooling: `reqwest::Client::builder().http2_prior_knowledge().pool_max_idle_per_host(20)`
- [ ] Provider fallback logic (dari `DEFAULT_PROVIDER_FALLBACK_ERROR_CODES`):
  - [ ] Error codes: `provider_timeout`, `provider_connection_failed`, `provider_rate_limited`, `provider_unavailable`
  - [ ] Switch primary → fallback provider
- [ ] Circuit breaker: `tower::limit::ConcurrencyLimit` + failover `tower::retry::Policy` + `tower::timeout`
  - [ ] 5 failures beruntun → fast-fail 30s
- [ ] Retry logic: 2 attempts, 250ms backoff (paritas `config/services.php` interpreter)
- [ ] Prompt template engine hook (no-op sekarang — payload terformat oleh Flutter)
- [ ] Contract test: capture 5 sample real Gemini+OpenAI response, deserialize di Rust, assert field identik

### Task 4.5: Cache + Governance Module (W9-11)

- [ ] `src/cache.rs` — port `cache.py` (829 baris):
  - [ ] `AdapterCacheService` struct dengan `PgPool`
  - [ ] `lookup_interpretation(payload, provider, model) -> Option<CacheEntry>`
  - [ ] `lookup_delivery(payload, provider, model) -> Option<CacheEntry>`
  - [ ] `store_interpretation_response(payload, provider, model, response) -> CacheEntry`
  - [ ] `store_delivery_response(payload, provider, model, response) -> CacheEntry`
  - [ ] `try_acquire_inflight_lock(route, cache_key) -> CacheInFlightLock` via `SELECT pg_try_advisory_lock($1)`
  - [ ] `release_inflight_lock(lock) -> bool` via `SELECT pg_advisory_unlock($1)`
  - [ ] `wait_for_inflight_entry(route, cache_key, timeout_ms, poll_interval_ms)` dengan `tokio::time::sleep`
  - [ ] `cleanup_expired_entries(route, limit)` lazy cleanup
  - [ ] `run_lazy_cleanup_if_due(route, now)` dengan interval check
- [ ] Cache key hash function (CRITICAL — byte-compatible dengan Python):
  - [ ] Canonical JSON: `serde_json` dengan `sort_keys` equivalent + separators `(",",":")` + `ensure_ascii=false`
  - [ ] SHA-256 hash hex
  - [ ] Unit test: hash 100 sample payload di Python, hash di Rust, assert byte-identik
- [ ] Advisory lock ID generation:
  - [ ] Blake2b dengan `digest_size=8`, `person=b"klasscch"`
  - [ ] Convert to i64 signed (handle `>= 2^63` underflow)
  - [ ] Verifikasi via unit test
- [ ] `src/governance.rs` — port `governance.py` (1014 baris):
  - [ ] `AdapterGovernanceService` struct
  - [ ] `preflight_check(route, provider, model, request_id, generation_id, estimated_cost)` → `GovernanceDecision`
  - [ ] `record_usage(route, provider, model, request_id, generation_id, usage, estimated_cost)` → buckets
  - [ ] `record_denial(...)` → bucket
  - [ ] `budget_statuses(now)` → `Vec<GovernanceRouteStatus>`
  - [ ] `sync_default_policies()` startup idempotent
- [ ] `src/rate_limits.rs` — port `rate_limits.py`:
  - [ ] `RateLimitPolicyRecord` struct
  - [ ] `RateLimitBucketSnapshot` struct
  - [ ] `RateLimitBucketMutation` struct
  - [ ] Fixed window start/end calculation per `window_unit` (minute/hour/day)
  - [ ] Bucket upsert via `INSERT ... ON CONFLICT (policy_id, window_started_at) DO UPDATE`
- [ ] Decimal handling via `rust_decimal`:
  - [ ] Budget tracking `Decimal` type
  - [ ] Verifikasi precision match dengan Python `Decimal`
- [ ] Schema versions: `INTERPRETATION_CACHE_TABLE_NAME` → `llm_cache_entries` dengan `route='interpret'`; `DELIVERY_CACHE_TABLE_NAME` → `llm_cache_entries` dengan `route='respond'`

### Task 4.6: Media Gen Integration + Redis Worker (W11-12)

- [ ] Redis Streams producer:
  - [ ] `XADD klass:media-generation * generation_id <id> attempt <n> context <json>`
  - [ ] Setelah submit endpoint, enqueue job
- [ ] Redis Streams consumer worker:
  - [ ] `XREADGROUP GROUP klass-workers worker-$id COUNT 1 BLOCK 5000 STREAMS klass:media-generation >`
  - [ ] Process job via orchestrator
  - [ ] `XACK` setelah state machine mencapai terminal
  - [ ] `XCLAIM` untuk redeliver unacked pada consumer restart
- [ ] Dead-letter queue `klass:media-generation-dlq`:
  - [ ] Move jobs yang fail semua retry (3x)
  - [ ] Alerting via log + metric
- [ ] Media Gen client (port `PythonMediaGeneratorClient.php`):
  - [ ] `POST /v1/generate` dengan HMAC signature, timeout 60s, retry 2, backoff 500ms
  - [ ] Parse response: `artifact_metadata`, `artifact_locator` (signed URL)
  - [ ] Download artifact dari signed URL
- [ ] S3 upload (port `MediaPublicationService` + `ThumbnailGeneratorService`):
  - [ ] `aws-sdk-s3` multipart upload ke Cloudflare R2
  - [ ] Generate thumbnail (PDF first-page render via `image` crate ATAU shell `pdftoppm`)
- [ ] Webhook receiver (opsional kalau Media Gen async):
  - [ ] Endpoint `POST /v1/internal/media-gen-webhook` (HMAC-verified)
  - [ ] Update state machine berdasarkan webhook event

### Task 4.7: Orchestrator + State Machine (W12-13)

- [ ] `src/orchestrator/lifecycle.rs` — port `MediaGenerationLifecycle`:
  - [ ] 9 status constants: QUEUED, INTERPRETING, CLASSIFIED, GENERATING, UPLOADING, PUBLISHING, COMPLETED, FAILED, CANCELLED
  - [ ] `STATUS_ORDER` map (identik dengan `MediaGenerationWorkflowService::STATUS_ORDER`)
- [ ] State machine `transition(generation, new_status, metadata, attempt, job_context)`:
  - [ ] Validate `statusBefore` invariant (state tidak boleh mundur)
  - [ ] Insert row di audit trail table
  - [ ] Update `media_generations.status`
- [ ] `WorkflowService::process(generation_id, attempt, job_context)`:
  - [ ] `ensureClassified`: interpret + decision
  - [ ] `ensureGenerated`: Media Gen call
  - [ ] `ensurePublished`: publication entities + S3
  - [ ] `ensureCompleted`: delivery payload composition
- [ ] **Parallel optimization** (win utama vs Laravel):
  - [ ] `tokio::join!(interpret, draft)` — interpret + draft paralel (Laravel sequential)
  - [ ] Verify state transitions correct: INTERPRETING → (parallel) → CLASSIFIED
- [ ] Cache integration:
  - [ ] Preflight check sebelum panggil provider
  - [ ] Cache lookup sebelum provider call
  - [ ] Cache store setelah provider response
  - [ ] Record usage setelah provider call
- [ ] Error recovery:
  - [ ] Retryable error → retry dengan backoff
  - [ ] Fatal error → state `FAILED`, audit trail, `failed()` hook
  - [ ] Partial failure: jika interpret sukses tapi generate gagal → state `FAILED`, tidak partial publish
- [ ] Property-based test: semua 8×8 state transitions, assert invariant

### Task 4.8: API Surface (W13-14)

- [ ] gRPC server via `tonic` (port 50051):
  - [ ] Implement `MediaGenerationService` trait
  - [ ] `submit_media_generation` → enqueue + stream progress events
  - [ ] `regenerate` → enqueue dengan parent_id + stream
  - [ ] Stream `GenerationProgressEvent` per state transition
  - [ ] Share `AppState` dengan Axum (same process, different port)
- [ ] REST server via `axum` (port 8080) — 26 endpoint (unique URL patterns):
  - [ ] Auth routes (7): 4 public (register, login, get-security-question, verify-and-reset-password) + 3 protected (logout, me, refresh)
  - [ ] Public read routes (9): topics (index+show), contents (index+show), marketplace-tasks (index+show), student-progress (index+show), homepage-recommendations
  - [ ] App config + Gallery (2): homepage-sections, gallery
  - [ ] Protected routes — auth:sanctum (6): user/avatar, media-generations (index+store), media-generations/{id} (show), regenerate, suggest-freelancers, hire-freelancer
  - [ ] Teacher routes — auth:sanctum+teacher (1): topics/store
  - [ ] Admin routes — auth:sanctum+admin (shares URL patterns with public read + dedicated): topics/{id} (update+destroy), contents (store+update+destroy), marketplace-tasks (store+update+destroy), student-progress (store+update+destroy), upload/{category} (upload+destroy), admin/debug-taxonomy
  - [ ] Freelancer routes (0): placeholder group exists, no active endpoints
- [ ] Request validation via `garde` crate (port `FormRequest::rules()` 1:1):
  - [ ] Register: name, email, password, role
  - [ ] Login: email, password, device_name
  - [ ] Media generation: prompt (required, non-empty), preferred_output_type (auto|pdf|docx|pptx), subject_id (optional), sub_subject_id (optional)
  - [ ] Verify-and-reset: security_answer, new_password
- [ ] Response shape: derive `serde::Serialize` dari Resource class — pastikan key naming `snake_case` sama
- [ ] OpenAPI documentation via `utoipa`:
  - [ ] Generate `openapi.json` dari handler annotations
  - [ ] Swagger UI via `utoipa-swagger-ui` di `GET /docs`
- [ ] Backward compatibility: error response format `{success: false, error: {code, message}}` identik dengan Laravel

### Gate Fase 4 → Fase 5 (Go/No-Go)

- [ ] Semua 26 endpoint REST ada impl + unit test
- [ ] gRPC `submit_media_generation` stream works di Docker compose
- [ ] 1 flow E2E `POST /media-generations` → `COMPLETED` hijau
- [ ] Auth: login user existing Laravel → success dengan token yang sama
- [ ] `cargo clippy -D warnings` bersih
- [ ] Cache hash byte-compatible test 100 sample lulus
- [ ] State machine property-based test lulus

---

## FASE 5: TESTING & VALIDATION (W15-16)

### Task 5.1: Functional Testing

- [ ] Unit test coverage target >75% (target 80%) via `cargo tarpaulin`:
  - [ ] Auth module coverage
  - [ ] Cache module coverage
  - [ ] Governance module coverage
  - [ ] Provider module coverage
  - [ ] Orchestrator/state machine coverage
- [ ] Integration test: `sqlx::test` ephemeral DB + `mockito` untuk HTTP mock:
  - [ ] DB round-trip per repository
  - [ ] Provider HTTP mock (Gemini + OpenAI)
  - [ ] Media Gen HTTP mock
  - [ ] Redis Streams enqueue + dequeue
- [ ] Contract test: Proto compatibility Flutter ↔ Gateway
  - [ ] Generate JSON schema dari Rust response
  - [ ] Diff dengan dump Laravel `JsonResource` via artisan command
  - [ ] Assert identical untuk 100 sample input
- [ ] Cache correctness test:
  - [ ] Hash 100 sample payload Python vs Rust → byte-identik
  - [ ] Advisory lock ID generation match
  - [ ] Cache lookup/store roundtrip
  - [ ] Stampede protection verify
- [ ] End-to-end test: full flow dari prompt sampai file download di Docker compose

### Task 5.2: Performance Testing

- [ ] k6 load test scripts (`tests/load/`):
  - [ ] `POST /v1/auth/login` 100 rps for 5 min → compare p99 vs Laravel baseline
  - [ ] `POST /v1/media-generations` 10 rps submit → measure end-to-end complete
  - [ ] Concurrent: 100, 1000, 10000 idle connections
- [ ] Benchmark: p50/p95/p99 latency vs Laravel baseline per endpoint
- [ ] Memory profiling: `cargo run --features=heap` dengan `dhat` crate
  - [ ] Target <50MB RSS saat 1000 idle connections
- [ ] Streaming latency test: gRPC token-to-Flutter delay <100ms
- [ ] Throughput sustained: ≥500 rps read, ≥50 rps submit

### Task 5.3: Compatibility Testing

- [ ] Flutter app existing (Play Store/internal) → pointed ke Rust gateway via `API_BASE_URL` override
- [ ] Smoketest 5 user flow:
  - [ ] Register
  - [ ] Login
  - [ ] Browse topics
  - [ ] Submit media generation (PDF)
  - [ ] Download artifact
- [ ] Backward compatibility: old Flutter version masih works (REST endpoints identik)
- [ ] Error response format match: `{success: false, error: {code, message}}` identik
- [ ] Sanctum token dari user existing → login di Rust berhasil, `/me` returns data sama
- [ ] gRPC stream test: Flutter dengan new `media_generation_service.dart` → state transitions real-time

### Task 5.4: Chaos Testing

- [ ] Simulate LLM provider (Gemini) down → circuit breaker trigger <2s, fallback error code `provider_unavailable`
- [ ] Simulate Media Gen timeout (proxy delay 65s) → timeout 60s trigger, retry 2x, state `FAILED`
- [ ] Simulate Neon connection drop (PgBouncer kill) → sqlx auto-reconnect, request retry
- [ ] Simulate Redis Stream consumer crash → `XCLAIM` redeliver unacked, idempotent via `statusBefore`
- [ ] Auto-scaling: k6 ramp 0→500 rps dalam 60s → no 5xx
- [ ] Cache stampede: 100 concurrent requests dengan cache_key sama → hanya 1 provider call, 99 wait

### Gate Fase 5 → Fase 6 (Go/No-Go)

- [ ] p99 latency `POST /media-generations` ≤ Laravel baseline
- [ ] p95 `GET /media-generations/{id}` < 80ms
- [ ] 0 failure di 1-hour soak test 100 rps
- [ ] Contract test 100% pass
- [ ] Cache correctness test 100% pass
- [ ] Chaos test semua scenario green
- [ ] Memory <50MB at 1000 conns

---

## FASE 6: MIGRATION & ROLLOUT (W17-18)

### Task 6.1: Migration Strategy

- [ ] Blue-Green deployment plan document:
  - [ ] Blue (Laravel): handle 100% traffic live
  - [ ] Green (Rust): deploy ke URL parallel (gateway-staging.onrender.com)
- [ ] Traffic splitting sequence:
  - [ ] T-7 days: 1% → Green (5 users canary) — monitor 24h
  - [ ] T-5 days: 10% → Green — monitor 48h
  - [ ] T-3 days: 50% → Green — monitor 24h
  - [ ] T-1 day: 100% → Green — Laravel set READ_ONLY
- [ ] Rollback plan:
  - [ ] DNS kembali ke Laravel
  - [ ] Laravel `READ_ONLY=false` (Laravel tetap hidup 1 minggu)
  - [ ] Trigger: error rate >1% sustained 5 min, p99 >2x baseline, data inconsistency

### Task 6.2: Cache + Rate-Limit Data Migration

- [ ] Stop LLM Adapter HF Space #2 — set read-only (URL redirect ke Rust gateway)
- [ ] One-shot migration script `migrate_cache.py` (or Rust binary):
  - [ ] Baca dari LLM Adapter DB: `SELECT cache_key, request_payload, response_payload, created_at, expires_at, hit_count, last_hit_at FROM interpretation_cache_entries WHERE expires_at > NOW()`
  - [ ] Insert ke Rust schema: `INSERT INTO llm_cache_entries (route, cache_key, ...) VALUES ('interpret', ...) ON CONFLICT DO NOTHING`
  - [ ] Same for `delivery_cache_entries` → `llm_cache_entries` dengan `route='respond'`
- [ ] Migrate `rate_limit_policies`: upsert langsung (idempotent — `sync_default_policies` di startup akan handle)
- [ ] Migrate `rate_limit_buckets`: `SELECT * FROM rate_limit_buckets WHERE window_ends_at > NOW()` → upsert
- [ ] Verify count match: source == target
- [ ] Verify cache hit ratio green: sample 100 lookup, all hit
- [ ] Decommission HF Space #2
- [ ] Drop LLM Adapter DB terpisah

### Task 6.3: Data Migration (User Data)

- [ ] User data: TIDAK perlu migrate — DB sama (Neon)
- [ ] Active sessions: Sanctum token byte-compatible → tidak invalidate, user tetap login
- [ ] File references di R2: URL tidak berubah → tidak perlu migrate

### Task 6.4: Cutover Checklist

- [ ] **Pre-cutover (T-24h)**:
  - [ ] Final Neon backup (PITR) + manual `pg_dump` full
  - [ ] Alerting: PagerDuty on error rate >1%, p99 >2x baseline, 5xx >0.5%
  - [ ] Team standby: 2 dev + 1 SRE di Slack channel migration
  - [ ] Rollback runbook tested end-to-end
  - [ ] Cache migration script tested di staging
- [ ] **Cutover (DNS switch)**:
  - [ ] Cloudflare DNS: A record `api.klass.app` → Render IP (TTL 60s)
  - [ ] Laravel `.env` flag `READ_ONLY=true` (refuse `POST /media-generations`)
  - [ ] Monitor error rate, p99, queue depth, HF Space #3 health setiap 15 min
- [ ] **Post-cutover**:
  - [ ] Hour 1: error rate <0.5%
  - [ ] Hour 6: p99 stable
  - [ ] Day 1: zero user complaints
  - [ ] Day 7: Laravel shutdown, HF Space #1 dipensiunkan

### Task 6.5: Post-Migration

- [ ] Laravel keep-alive 7 hari sebagai backup (read-only enforcement), lalu delete HF Space #1
- [ ] Performance report 30 hari:
  - [ ] Cost before vs after
  - [ ] Latency before vs after
  - [ ] Throughput before vs after
  - [ ] Cache hit ratio stabilization
- [ ] Documentation update:
  - [ ] `README.md` root repo
  - [ ] `GEMINI.md` architecture overview
  - [ ] API docs Swagger via `utoipa`
  - [ ] Runbook: Rust local setup + sqlx + Render deploy + Redis
  - [ ] Onboarding: untuk dev baru
- [ ] Laravel deprecation notice ke tim
- [ ] Final HF Space inventory: hanya #3 (Media Gen)

### Gate Fase 6 → Complete (Go/No-Go)

- [ ] 100% traffic di Rust gateway ≥7 hari stabil
- [ ] Error rate <0.1% sustained
- [ ] p99 ≤ baseline
- [ ] Cache hit ratio ≥ baseline
- [ ] Zero data loss
- [ ] Zero user re-auth required
- [ ] Laravel decommissioned

---

## Resource Requirements

### Team Composition

| Role | Count | Catatan |
|------|-------|--------|
| Rust Backend Engineer (senior) | 1 | Lead architect + kompleks modul (orchestrator, cache, governance) |
| Backend Engineer (belajar Rust) | 1 | Port CRUD endpoints, validation, tests — ramp up W1-4 |
| DevOps/SRE | 0.5 part-time | Render setup, CI/CD, monitoring |
| Flutter Engineer | 0 advisorial | Review 1 service file rewrite (`media_generation_service.dart`) |
| QA | 0.5 part-time | k6 scripts + canary user koordinasi |

**Total: 2 FTE + 1 part-time**

### Infrastructure Cost (per bulan, estimasi)

| Komponen | Before | After | Δ |
|------|--------|-------|---|
| HF Space #1 (Laravel) | $0-20 | $0 | -$0-20 |
| HF Space #2 (LLM Adapter) | $0-20 | $0 | -$0-20 |
| HF Space #3 (Media Gen) | $0-20 | $0-20 | 0 |
| Neon PostgreSQL | $0 (free) / $19 | sama | 0 |
| Cloudflare R2/S2 | $0-5 | sama | 0 |
| Render Web Service | 0 | $7 | +$7 |
| Upstash Redis | 0 | $0 (free tier) | 0 |
| **Total** | **~$0-65** | **~$7-32** | **hemat** |

---

## Flutter Changes (Explicit List)

| File | Change | Estimasi Lines |
|------|--------|----------------|
| `pubspec.yaml` | Tambah `grpc: ^4.0.1`, `protobuf: ^3.1.0`; dev: `protoc_plugin` | ~5 |
| `lib/features/media_generation/data/media_generation_service.dart` | Rewrite: Dio.post + `Timer.periodic(4s)` → gRPC stream `submitMediaGeneration(...).listen(...)` | ~200 |
| `proto/klass/media/v1/media_generation.proto` | File baru (codegen ke Dart + Rust) | ~80 |
| `lib/features/media_generation/data/generation_history_service.dart` | Tetap Dio (REST) | 0 |
| `lib/core/providers/dio_provider.dart` | Tetap (REST untuk 11 service lain) | 0 |
| `lib/features/media_generation/widgets/media_generation_status_card.dart` | Tetap (renderer baca `currentStatus`, sekarang dari stream event) | 0 |

**Net Flutter code change: 1 file rewrite + 2 packages + 1 proto.** UI tetap utuh.

---

## Notes

- **Constraint Flutter**: longgar untuk 1 service file (`media_generation_service.dart`) + 2 packages. UI renderer tetap utuh.
- **Constraint DB/storage**: Neon + R2 tetap dipakai, tidak migrate.
- **Constraint budget**: ≤+50% — netral/turun (hemat 2 HF Space, tambah $7 Render).
- **Constraint Hugging Face**: HF Space #3 (Media Gen) dipertahankan karena library Rust tidak punya feature parity dengan `python-docx`/`reportlab`/`python-pptx`.