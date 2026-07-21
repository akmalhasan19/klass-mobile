# ADR-007: LLM Adapter Consolidation ke Rust Gateway

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2026-07-11 |
| **Deciders** | Engineering Team |
| **Supersedes** | — |

---

## Context

LLM Adapter saat ini adalah service Python terpisah (HF Space #2) dengan:
- **Provider module** (829 lines): xiaomi + OpenAI client, routing, fallback logic
- **Cache module** (829 lines): Semantic cache dengan PostgreSQL advisory lock stampede protection
- **Governance module** (1014 lines): Rate limiting fixed-window, budget tracking, preflight check
- **Rate limit module** (291 lines): Policy definitions, bucket mutations, window calculation
- **Own PostgreSQL DB**: Tabel `interpretation_cache_entries`, `delivery_cache_entries`, `rate_limit_policies`, `rate_limit_buckets`, `llm_request_ledger`, `price_catalog_entries`

Total: **~3,000 lines Python** yang esensinya adalah:
```
Request → Preflight check → Cache lookup → Provider call → Cache store → Record usage → Response
```

Semua logika ini adalah **pure orchestration + data access** — tidak ada rendering, tidak ada heavy computation, tidak ada library Python spesifik yang tidak bisa diganti di Rust.

## Decision

**Port semua logika LLM Adapter ke dalam Rust Gateway sebagai module in-process. Hapus HF Space #2 dan LLM Adapter DB terpisah.**

```
Before:                              After:
┌──────────┐  HMAC  ┌──────────┐    ┌─────────────────────────┐
│ Laravel   │ ─────>│ LLM       │    │ Rust Gateway             │
│  (PHP)    │       │ Adapter   │    │                          │
└──────────┘       │ (Python)  │    │  src/providers/          │
                   └─────┬─────┘    │    xiaomi.rs             │
                         │          │    openai.rs             │
                   ┌─────▼─────┐    │    routing.rs            │
                   │ DB sendiri │    │                          │
                   │ (Postgres) │    │  src/cache.rs            │
                   └───────────┘    │  src/governance.rs       │
                                    │  src/rate_limits.rs       │
                                    │                          │
                                    │  (all in-process,         │
                                    │   single Neon DB)         │
                                    └─────────────────────────┘
```

### Module Mapping

| Python (LLM Adapter) | Rust (Gateway) | Lines (est.) |
|----------------------|----------------|-------------|
| `app/providers/xiaomi.py` (339) | `src/providers/xiaomi.rs` | ~300 |
| `app/providers/openai.py` (401) | `src/providers/openai.rs` | ~350 |
| `app/providers/base.py` (203) | `src/providers/mod.rs` | ~150 |
| `app/providers/routing.py` (238) | `src/providers/routing.rs` | ~200 |
| `app/cache.py` (829) | `src/cache.rs` | ~700 |
| `app/governance.py` (1014) | `src/governance.rs` | ~800 |
| `app/rate_limits.py` (291) | `src/rate_limits.rs` | ~250 |
| `app/auth.py` (138) | Auth middleware (existing) | — |
| `app/errors.py` (41) | `src/error.rs` (unified) | — |
| **Total ~3,000** | | **~2,750** |

## Alternatives Considered

### Keep LLM Adapter terpisah, Gateway sebagai API proxy

| Pro | Kontra |
|-----|--------|
| Tidak perlu rewrite Python → Rust | Extra network hop (~5-10ms) per LLM call |
| LLM Adapter sudah tested | Harus maintain HMAC signing di Gateway + verification di Adapter |
| | 2 service = 2 deployment, 2 monitoring, 2 error budgets |
| | LLM Adapter DB tetap terpisah — tidak bisa join dengan tabel aplikasi untuk audit |
| | Same operational overhead as today |

### Port LLM Adapter ke Rust tapi tetap sebagai service terpisah

| Pro | Kontra |
|-----|--------|
| Isolation: bug di LLM module tidak crash Gateway | Network hop tetap ada |
| | Harus define API contract + serialize/deserialize di boundary |
| | Tidak ada benefit dibanding in-process — bottleneck selalu I/O (LLM API call), bukan CPU |

### Kenapa in-process consolidation menang

| Faktor | In-process |
|--------|-----------|
| Latency | 0 network hop — cache lookup, governance check, provider call semua dalam proses yang sama |
| Atomicity | Preflight check + cache lookup + provider call bisa dalam 1 DB transaction |
| Simplicity | Tidak ada HMAC signing internal, tidak ada API contract internal |
| Cost | Hapus 1 HF Space ($0-20) + 1 Postgres DB |
| Observability | Single `tracing` span untuk seluruh flow — interpretasi + draft + delivery dalam 1 trace |

## Key Technical Decisions

### Provider trait

```rust
// src/providers/mod.rs
#[async_trait]
pub trait Provider: Send + Sync {
    fn name(&self) -> &'static str;
    fn resolve_model(&self, route: ProviderRoute, requested: &str) -> String;
    async fn complete(&self, request: NormalizedProviderRequest) -> Result<ProviderCompletion>;
}
```

### Cache key byte-compatibility (CRITICAL)

Cache hash **harus byte-identical** dengan Python untuk memungkinkan cache migration (Fase 6):
```rust
// Python: json.dumps(doc, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
// Rust: serde_json::to_string(&doc)?  // ...must use sort_keys + compact separators
// Hash: sha2::Sha256::digest(serialized.as_bytes())
```

### Advisory lock ID generation (CRITICAL)

```rust
// Python: blake2b(route:cache_key, digest_size=8, person=b"klasscch")
// Rust: Blake2bMac::<U64>::new_with_salt_and_personal(key, salt, b"klasscch")
// ...convert to i64 with 2^63 underflow handling
```

## Consequences

### Positive

- **Latency reduction**: 0ms network overhead vs ~5-10ms (HTTP call ke service terpisah)
- **Infra simplification**: -1 HF Space, -1 Postgres DB, -1 deployment pipeline
- **Code colocation**: Orchestrator + LLM logic dalam 1 codebase — atomic refactoring
- **Cache migration path**: Tabel cache dipindah ke Neon (ADR-008), migration script Fase 6
- **Unified tracing**: `tracing` spans mencakup seluruh flow dari REST handler → provider → response

### Negative / Mitigation

| Risk | Mitigation |
|------|-----------|
| Rewrite 3,000 lines Python → Rust | Provider module paling straightforward (HTTP call + JSON parse); cache + governance sudah well-documented di `INTEGRATION_MAPPING.md` |
| Cache hash incompatibility | Unit test Fase 5: hash 100 sample payload di Python + Rust, assert byte-identik |
| Advisory lock ID mismatch | Blake2b params verified via unit test (person b"klasscch", digest_size=8) |
| Provider response parsing beda (Pydantic vs serde) | Contract test: 5 real xiaomi + OpenAI responses, deserialize di Rust |

---

## References

- `IMPLEMENTATION_PLAN.md` — Final Decision Matrix (row #3)
- `IMPLEMENTATION_PLAN.md` — Task 4.4 (LLM Provider Module) + Task 4.5 (Cache + Governance)
- `INTEGRATION_MAPPING.md` — Provider behavior, cache architecture, error code index
- `llm-adapter-service/app/` — Source code yang akan diport
