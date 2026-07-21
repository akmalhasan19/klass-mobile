# Architecture Decision Records (ADRs)

> **Project**: klass-mobile — Laravel → Rust Gateway Migration
> **Last Updated**: 2026-07-11
> **Status**: All Accepted

---

## Overview

This directory contains Architecture Decision Records (ADRs) for the klass-mobile project. ADRs document the key architectural decisions made during the migration from Laravel to Rust Gateway.

Each ADR follows a standard format:
- **Context**: The problem or situation that prompted the decision
- **Decision**: The architectural choice made
- **Alternatives Considered**: Other options evaluated
- **Consequences**: The resulting impact (positive and negative)

---

## ADR Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| [0001](0001-rust-gateway-language.md) | Bahasa Gateway — Rust | Accepted | 2026-07-11 | Memilih Rust sebagai bahasa tunggal untuk gateway karena safety, performance, dan expressiveness yang dibutuhkan untuk state machine, parallel orchestrator, dan cache byte-compatibility. |
| [0002](0002-hybrid-grpc-rest-protocol.md) | Protokol Flutter ↔ Gateway — Hybrid gRPC + REST | Accepted | 2026-07-11 | Menggunakan hybrid protocol: gRPC server-streaming untuk media generation progress, REST/JSON untuk25 endpoint lainnya. |
| [0003](0003-service-consolidation.md) | Konsolidasi Laravel → Rust Gateway; Media Gen Tetap Terpisah | Accepted | 2026-07-11 | Mengonsolidasi Laravel dan LLM Adapter ke Rust Gateway, tetapi mempertahankan Media Generator sebagai service terpisah karena keterbatasan library Rust. |
| [0004](0004-database-strategy-neon-sqlx.md) | Database Strategy — Neon PostgreSQL + sqlx | Accepted | 2026-07-11 | Mempertahankan Neon PostgreSQL dengan schema identik, port30 Laravel migrations ke sqlx, tambahkan5-6 migration untuk konsolidasi LLM Adapter schema. |
| [0005](0005-deployment-target-render.md) | Deployment Target — Render Web Service | Accepted | 2026-07-11 | Memilih Render Web Service Starter tier ($7/bln) di Singapore region untuk latency rendah ke Neon PostgreSQL. |
| [0006](0006-queue-strategy-redis-streams.md) | Queue Strategy — Redis Streams via Upstash | Accepted | 2026-07-11 | Menggunakan Redis Streams via Upstash free tier untuk job queue dengan consumer groups, idempotent retry, dan dead-letter queue. |
| [0007](0007-llm-adapter-consolidation.md) | LLM Adapter Consolidation ke Rust Gateway | Accepted | 2026-07-11 | Memindahkan semua logika LLM Adapter (~3,000 lines Python) ke dalam Rust Gateway sebagai module in-process, menghapus HF Space #2 dan LLM Adapter DB. |
| [0008](0008-cache-db-consolidation.md) | Cache DB Consolidation — `llm_cache_entries` | Accepted | 2026-07-11 | Mengonsolidasi2 tabel cache terpisah menjadi1 tabel `llm_cache_entries` dengan kolom `route` sebagai discriminator. |

---

## Key Decisions Summary

### 1. Language Choice (ADR-001)
**Rust** dipilih karena:
- State machine9-state dengan `enum` dan exhaustive pattern matching
- Parallel orchestrator dengan `tokio::join!` zero-cost
- Cache hash byte-compatible dengan Python (critical untuk migration)
- Sanctum token verify dengan `argon2` dan `sha2` — byte-identical dengan PHP
- Binary deployment <30MB, cold start <1s

### 2. Protocol Strategy (ADR-002)
**Hybrid gRPC + REST**:
- **gRPC server-streaming**: Untuk `SubmitMediaGeneration` + `Regenerate` dengan latency <100ms
- **REST/JSON**: Untuk25 endpoint lainnya (auth, CRUD, gallery, profile)
- **Flutter impact**: Hanya1 file rewrite (`media_generation_service.dart`)

### 3. Service Consolidation (ADR-003)
**2 services,1 Postgres DB**:
- **Rust Gateway**: Mengonsolidasi Laravel + LLM Adapter
- **Media Generator**: Tetap terpisah (Python) karena keterbatasan library Rust untuk DOCX/PDF/PPTX
- **Cost saving**: -2 HF Space, -1 Postgres DB

### 4. Database Strategy (ADR-004)
**Schema identik, port ke sqlx**:
- Zero data migration untuk user data dan Sanctum tokens
-30 Laravel migrations →30 sqlx migration files
-5-6 migration baru untuk konsolidasi cache + governance
- Tabel Laravel built-in tidak diport (digantikan Redis lifecycle)

### 5. Deployment Target (ADR-005)
**Render Web Service**:
- $7/bulan (Starter tier)
- Singapore region (same as Neon, <5ms latency)
- Docker deployment dengan GitHub auto-deploy
- Health check `GET /health` → auto-recovery

### 6. Queue Strategy (ADR-006)
**Redis Streams via Upstash**:
- Free tier:10,000 commands/day,256MB storage
- Consumer groups dengan `XREADGROUP` + `XACK` + `XCLAIM`
- Dead-letter queue untuk failed jobs
- Idempotent retry via `statusBefore` invariant

### 7. LLM Adapter Consolidation (ADR-007)
**In-process module**:
- Provider module (xiaomi + OpenAI clients)
- Cache module (829 lines → ~700 lines Rust)
- Governance module (1014 lines → ~800 lines Rust)
- Rate limit module (291 lines → ~250 lines Rust)
- Total: ~3,000 lines Python → ~2,750 lines Rust

### 8. Cache DB Consolidation (ADR-008)
**Single table `llm_cache_entries`**:
- Gabungan `interpretation_cache_entries` + `delivery_cache_entries`
- Kolom `route` sebagai discriminator ('interpret'/'respond')
- Partial indexes per route untuk cleanup efisien
- Migration script untuk data migration di Fase6

---

## References

- [IMPLEMENTATION_PLAN.md](../../IMPLEMENTATION_PLAN.md) — Main implementation plan
- [INTEGRATION_MAPPING.md](../../INTEGRATION_MAPPING.md) — Service boundaries & contracts
- [TASK_1_2_AUDIT.md](../../TASK_1_2_AUDIT.md) — Data audit & schema analysis

---

## How to Use

1. **For new team members**: Read ADRs in order (0001-0008) to understand architectural decisions
2. **For implementation**: Reference specific ADR when making related decisions
3. **For reviews**: Verify implementation aligns with ADR decisions
4. **For updates**: Create new ADR (0009+) for new decisions, don't modify existing ones

---

## ADR Template

When creating new ADRs, use this template:

```markdown
# ADR-XXX: Title

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | YYYY-MM-DD |
| **Deciders** | Engineering Team |
| **Supersedes** | — |

---

## Context

[Describe the problem or situation]

## Decision

[Describe the architectural choice]

## Alternatives Considered

[Describe other options evaluated]

## Consequences

[Describe the resulting impact]

---

## References

[Link to related documents]
```

---

## Maintenance

- **New decisions**: Create new ADR (0009+) with "Accepted" status
- **Superseded decisions**: Update old ADR status to "Superseded by ADR-XXX"
- **Rejected decisions**: Document with "Rejected" status and reason
- **Periodic review**: Review ADRs every6 months for relevance