# ADR-008: Cache DB Consolidation — `llm_cache_entries`

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2026-07-11 |
| **Deciders** | Engineering Team |
| **Supersedes** | — |

---

## Context

LLM Adapter saat ini memiliki 2 tabel cache terpisah dalam DB sendiri:

| Tabel | Route | TTL | Target Rust |
|-------|-------|-----|-------------|
| `interpretation_cache_entries` | `interpret` | 24h | Neon PostgreSQL |
| `delivery_cache_entries` | `respond` | 6h | Neon PostgreSQL |

Setelah ADR-007 (LLM Adapter consolidation), tabel-tabel ini harus dipindahkan ke Neon PostgreSQL. Pertanyaan: dipertahankan 2 tabel terpisah, atau digabung menjadi 1?

## Decision

**Konsolidasi 2 tabel menjadi 1 tabel `llm_cache_entries` dengan kolom `route` sebagai discriminator. Simpan di Neon PostgreSQL.**

```sql
CREATE TABLE llm_cache_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cache_key TEXT NOT NULL,
    route TEXT NOT NULL CHECK (route IN ('interpret', 'respond')),
    request_payload JSONB NOT NULL,
    response_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    hit_count BIGINT NOT NULL DEFAULT 0,
    last_hit_at TIMESTAMPTZ,

    CONSTRAINT uq_llm_cache_key UNIQUE (cache_key)
);

-- Partial indexes per route for efficient lookup + cleanup
CREATE INDEX idx_llm_cache_interpret_expires ON llm_cache_entries (expires_at)
    WHERE route = 'interpret';
CREATE INDEX idx_llm_cache_respond_expires ON llm_cache_entries (expires_at)
    WHERE route = 'respond';

-- Lookup index (hot path)
CREATE INDEX idx_llm_cache_lookup ON llm_cache_entries (cache_key, expires_at);
```

### Before vs After

```
Before (2 tables, 2 DBs):              After (1 table, 1 DB):

┌──────────────────────┐               ┌──────────────────────┐
│ LLM Adapter DB        │               │ Neon PostgreSQL       │
│                       │               │                       │
│ interpretation_cache_ │               │ llm_cache_entries     │
│   entries             │               │  ├─ route='interpret' │
│                       │               │  └─ route='respond'   │
│ delivery_cache_       │               │                       │
│   entries             │               │ ... tabel aplikasi    │
│                       │               │ ... tabel governance  │
│ rate_limit_policies   │               └──────────────────────┘
│ rate_limit_buckets    │
│ llm_request_ledger    │
└──────────────────────┘
```

## Alternatives Considered

### Pertahankan 2 tabel terpisah

| Pro | Kontra |
|-----|--------|
| Persis sama dengan schema existing | Duplikasi SQL: lookup, upsert, cleanup query ×2 |
| Tidak perlu migration script untuk gabung | Tidak bisa query lintas route dengan mudah (analytics) |
| | `UNION ALL` setiap kali butuh data cache gabungan |

### Gunakan Redis sebagai cache store (bukan PostgreSQL)

| Pro | Kontra |
|-----|--------|
| Native TTL → auto-expire, tidak perlu cleanup job | Redis bukan persistent store untuk cache semantics |
| Lebih cepat untuk lookup (<1ms) | **Cache migration kompleks**: Python→Redis bukan SQL→SQL |
| | Desain cache existing menggunakan PostgreSQL advisory lock — harus redesign total |
| | Upstash free tier 256MB — cache bisa tumbuh besar (payload LLM kompleks) |
| | Tidak bisa join dengan tabel aplikasi untuk audit trail |

### Satu tabel tanpa partial index (full index on route+expires)

| Pro | Kontra |
|-----|--------|
| Satu index lebih simple | Index menjadi gemuk — mencakup semua route |
| | Cleanup query harus filter route di WHERE (tidak efisien) |

### Kenapa single table + partial index menang

| Faktor | Solusi |
|--------|--------|
| Code simplicity | Satu set fungsi `lookup_entry()`, `store_entry()`, `cleanup_expired_entries()` — parametrized by `route` |
| Query performance | Partial index per route = index kecil + targeted — cleanup interpret TTL 24h hanya scan index interpret |
| Migration path | Idempotent upsert — bisa di-replay tanpa duplicate |
| Analytics | `GROUP BY route` langsung di 1 tabel — tidak butuh `UNION ALL` |
| Backward compat | `cache_key` tetap UNIQUE global — tidak bisa ada duplikat antar route |

## Migration Script (`migrate_cache.sql`)

```sql
-- Fase 6: Migrate from LLM Adapter DB to Neon
-- Run once pre-cutover, then verify count match

INSERT INTO llm_cache_entries (
    cache_key, route, request_payload, response_payload,
    created_at, expires_at, hit_count, last_hit_at
)
SELECT
    cache_key,
    'interpret' AS route,
    request_payload,
    response_payload,
    created_at,
    expires_at,
    hit_count,
    last_hit_at
FROM dblink('llm_adapter_db',
    'SELECT cache_key, request_payload, response_payload, created_at, expires_at, hit_count, last_hit_at
     FROM interpretation_cache_entries
     WHERE expires_at > NOW()'
) AS t(
    cache_key TEXT, request_payload JSONB, response_payload JSONB,
    created_at TIMESTAMPTZ, expires_at TIMESTAMPTZ, hit_count BIGINT, last_hit_at TIMESTAMPTZ
)
ON CONFLICT (cache_key) DO NOTHING;

-- Same for delivery_cache_entries with route='respond'

-- Verify
SELECT route, COUNT(*) FROM llm_cache_entries GROUP BY route;
```

## Consequences

### Positive

- **Single source of truth**: Semua data cache dalam 1 DB, 1 backup, 1 connection pool
- **Simpler code**: Fungsi cache parametrized by `route` bukan 2 class terpisah
- **Atomic operations**: Cache lookup + governance check bisa dalam 1 DB transaction
- **Partial indexes**: Cleanup efisien tanpa scan tabel besar — interpret (24h TTL) dan respond (6h TTL) dibersihkan independen
- **No additional infrastructure**: Tidak perlu Redis instance terpisah untuk cache

### Negative / Mitigation

| Risk | Mitigation |
|------|-----------|
| Cache table tumbuh besar → DB storage naik | Lazy cleanup setiap lookup; batch cleanup 100 entries per run; monitor table size |
| Cache lookup latency lebih tinggi dari Redis | PostgreSQL indexed lookup <5ms — cukup untuk volume saat ini; jika perlu, Redis layer bisa ditambahkan nanti |
| Single table → contention di index | Partial index per route memisahkan write path; `ON CONFLICT (cache_key) DO UPDATE` adalah atomic per row |
| Migration script risk (duplicate entries) | `ON CONFLICT DO NOTHING` — idempoten; verify count match source==target pre-cutover |

---

## References

- ADR-004: Database Strategy — konsolidasi DB
- ADR-007: LLM Adapter Consolidation — alasan in-process
- `IMPLEMENTATION_PLAN.md` — Task 2.4 (Database Schema Design), Task 4.5 (Cache Module)
- `INTEGRATION_MAPPING.md` — Cache Architecture (key generation, advisory lock, stampede protection)
- `llm-adapter-service/app/cache.py` — Existing cache implementation (829 lines)
