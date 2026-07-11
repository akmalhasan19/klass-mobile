# ADR-004: Database Strategy — Neon PostgreSQL + sqlx

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2026-07-11 |
| **Deciders** | Engineering Team |
| **Supersedes** | — |

---

## Context

Database Neon PostgreSQL saat ini digunakan oleh Laravel dengan 30 migration files. Target arsitektur harus:
- Mempertahankan backward compatibility — tidak ada data migration untuk user data
- Sanctum token harus tetap valid (byte-compatible hash)
- Menambahkan tabel baru untuk cache + governance + rate-limit (sebelumnya di LLM Adapter DB terpisah)
- Connection pooling via PgBouncer (Neon free tier max 10 connections)

## Decision

**Pertahankan Neon PostgreSQL dengan schema identik. Port 30 Laravel migrations ke sqlx, tambahkan 5-6 migration untuk konsolidasi LLM Adapter schema.**

```
Migration sources:
  - 30 Laravel migrations  →  30 sqlx migration files (timestamp identik, schema identik)
  - LLM Adapter migrations  →  5-6 sqlx migration baru (konsolidasi cache + governance)
  ─────────────────────────────────────────────────────────────────────────────────
  Total: ~35-36 sqlx migration files
```

Tabel Laravel built-in yang **tidak diport** (digantikan Redis lifecycle):
- `cache`, `cache_locks` — digantikan oleh `llm_cache_entries` (dengan route discriminator)
- `jobs`, `job_batches`, `failed_jobs` — digantikan Redis Streams
- `password_reset_tokens`, `sessions` — stateless Sanctum, tidak diperlukan

15 Eloquent Model → 15 Rust struct dengan `#[derive(FromRow)]`.

## Alternatives Considered

### Schema redesign (normalisasi ulang)

| Pro | Kontra |
|-----|--------|
| Bisa optimalkan schema untuk access pattern Rust | **Data migration required** — high risk data loss |
| | Sanctum token hash bisa invalid jika user table berubah |
| | Timeline +4 minggu untuk migration script + verification |
| | Tidak ada benefit concrete — schema existing sudah cukup baik |

### ORM (Diesel / SeaORM)

| Pro | Kontra |
|-----|--------|
| Diesel: compile-time query verification tanpa perlu live DB | Diesel: migration DSL berbeda, learning curve |
| SeaORM: async-native, mirip ActiveRecord | SeaORM: abstraction overhead, sulit untuk query kompleks (governance) |
| | Keduanya: port migration dari Laravel `.sql` → ORM DSL = rawan error |
| | **sqlx** langsung pakai SQL mentah yang sudah tested di Laravel |

### Keep 2 Postgres DB (Neon + LLM Adapter DB)

| Pro | Kontra |
|-----|--------|
| Tidak perlu merge migration | 2 DB to manage, 2 connection pools |
| | LLM Adapter DB adalah dependensi yang akan dihapus (ADR-007) |
| | Cache lookup butuh cross-DB query untuk audit trail |

### Kenapa sqlx

| Kebutuhan | sqlx solution |
|-----------|-------------|
| Schema compatibility | `.sql` migration files — bisa copy-paste dari Laravel dengan adjustment minor |
| Type safety | `#[derive(FromRow)]` — compile-time struct↔row mapping |
| Async | `sqlx::query_as::<T>()` — fully async, kompatibel dengan `tokio` |
| Connection pooling | `PgPool` — built-in, dengan `max_connections` configurable |
| Offline build | `SQLX_OFFLINE=true` + `cargo sqlx prepare` → query metadata di-cache di `.sqlx/` |
| Migration runner | `sqlx migrate run` — embedded migration runner, no external tool needed di production |

## Migration Strategy

### Migration porting checklist (per tabel Laravel)

```
Untuk setiap migration Laravel di backend/database/migrations/:
  1. Copy SQL statement (up)
  2. Wrap dalam sqlx migration file: YYYYMMDDHHMMSS_description.sql
  3. Skip tabel: cache, cache_locks, jobs, job_batches, failed_jobs,
     password_reset_tokens, sessions
  4. Verify di Neon staging via sqlx migrate run
  5. Pastikan tidak ada schema drift (bandingkan dengan pg_dump existing)
```

### Tabel baru (konsolidasi LLM Adapter)

| # | Tabel | Sumber | Catatan |
|---|-------|--------|---------|
| 1 | `llm_cache_entries` | `interpretation_cache_entries` + `delivery_cache_entries` | Single table, discriminator kolom `route` |
| 2 | `llm_rate_limit_policies` | `rate_limit_policies` | UNIQUE (scope_type, route, provider, model, window_unit) |
| 3 | `llm_rate_limit_buckets` | `rate_limit_buckets` | FK ke policies, UNIQUE (policy_id, window_started_at) |
| 4 | `llm_request_ledger` | `llm_request_ledger` | Audit trail LLM API calls |
| 5 | `llm_price_catalog` | `price_catalog_entries` | Simplifikasi, deduplikasi by provider+model |

## Consequences

### Positive

- **Zero data migration**: User data, Sanctum tokens, media_generations tetap di tempat
- **Schema proven**: Laravel schema sudah production-tested, tidak ada risiko redesign
- **Single DB**: 1 connection pool, 1 backup, 1 monitoring target
- **sqlx offline**: CI/CD bisa build tanpa live DB (cocok untuk GitHub Actions)

### Negative / Mitigation

| Risk | Mitigation |
|------|-----------|
| sqlx compile-time check perlu query metadata | `cargo sqlx prepare` di-check in ke repo; CI verify dengan `--check` |
| JSON columns di Laravel pakai `json` bukan `jsonb` | `ALTER TYPE SET DATA TYPE jsonb` saat port migrasi — backward compatible untuk read, lebih efisien untuk query |
| 36 migration files = test lama | `sqlx migrate run` di ephemeral DB untuk setiap CI run; target <10s |
| Neon free tier connection limit (10) | PgBouncer pooling; `max_connections=5` untuk Gateway, sisakan 5 untuk dev tools |

---

## References

- `IMPLEMENTATION_PLAN.md` — Task 2.4 (Database Schema Design), Task 1.2 (Data Audit)
- `llm-adapter-service/app/migrations/` — LLM Adapter DB schema
- `backend/database/migrations/` — 30 Laravel migration files
