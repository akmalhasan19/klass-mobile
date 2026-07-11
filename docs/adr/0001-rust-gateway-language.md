# ADR-001: Bahasa Gateway — Rust

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2026-07-11 |
| **Deciders** | Engineering Team |
| **Supersedes** | — |

---

## Context

Laravel backend (`backend/`, HF Space #1) akan digantikan oleh gateway baru yang mengonsolidasi Laravel + LLM Adapter. Gateway ini harus:
- Menangani 26 REST endpoint + streaming media-gen progress
- Mengorkestrasi state machine 9-state dengan `tokio::join!` parallelism
- Memvalidasi Sanctum token secara byte-compatible
- Port cache + governance module dari Python LLM Adapter
- Budget: ≤ 2 FTE, 18 minggu total

Perlu dipilih bahasa dengan **safety, performance, dan expressiveness** yang cukup untuk tugas-tugas di atas.

## Decision

**Menggunakan Rust** (`edition 2024`, stable toolchain) sebagai bahasa tunggal untuk gateway.

Krate kunci: `axum` 0.7 (HTTP), `tonic` 0.12 (gRPC), `sqlx` 0.8 (database), `tokio` 1.x (runtime).

## Alternatives Considered

### Go (`chi` / `connect-go`)

| Pro | Kontra |
|-----|--------|
| Learning curve rendah (1 minggu) | Tidak ada enum/sum types → state machine harus pakai `const` + `switch`, rawan bug |
| Goroutine ringan, GC mature | GC pauses tidak deterministik (meskipun <1ms, tetap ada tail latency) |
| `connect-go` untuk gRPC streaming | Error handling pattern `if err != nil` verbose, risk forget-to-check |
| Stdlib HTTP router cukup untuk 26 endpoint | Tidak ada `#[derive(FromRow)]` — ORM heavy atau manual scan |

### Node.js (`Express` / `fastify` + TypeScript)

| Pro | Kontra |
|-----|--------|
| Bahasa yang sama dengan Flutter (Dart mirip JS/TS) | Single-thread event loop — blocking di cache/governance akan bottleneck |
| Ekosistem npm besar | Sanctum `hash('sha256')` byte-compatible harus manual bindings |
| Dev cepat, hot reload built-in | Memory footprint besar vs binary Rust |
| TypeScript memberi type safety | GC pauses + V8 warm-up = latency tidak predictable |

### Kenapa Rust menang

| Kebutuhan | Rust solution |
|-----------|-------------|
| State machine 9-state | `enum` dengan `#[derive(PartialEq, PartialOrd)]` — compile-time exhaustive match |
| Parallel orchestrator | `tokio::join!(interpret, draft)` — zero-cost, compile-time checked |
| Cache hash byte-compatible Python | `sha2` crate, kontrol penuh atas canonical JSON serialization |
| Sanctum token verify | `argon2` 0.5 untuk password, `sha2` untuk token hash — byte-identical dengan PHP |
| Circuit breaker | `tower::limit`, `tower::retry`, `tower::timeout` — battle-tested middleware |
| Budget governance decimal | `rust_decimal` 1.36 — precision identik dengan Python `Decimal` |
| Binary deployment | Single <30MB binary, tidak ada runtime dependency |

## Consequences

### Positive

- **Safety**: Borrow checker + `Send`/`Sync` trait mencegah data race di orchestrator concurrent
- **Performance**: p99 latency konsisten tanpa GC; `cargo build --release` menghasilkan binary optimized
- **Maintainability**: `clippy` linting, exhaustive pattern matching mencegah bug state machine
- **Operational**: Single binary deploy, Docker image <30MB, cold start <1s

### Negative / Mitigation

| Risk | Mitigation |
|------|-----------|
| 1-2 dev belum familiar Rust | Pair programming Fase 4; mulai dari modul sederhana (auth, CRUD endpoint) sebelum orchestrator |
| Velocity 4 minggu pertama lebih rendah | Task breakdown granular; `cargo watch` hot reload untuk DX |
| `sqlx` compile-time query check perlu live DB | `SQLX_OFFLINE=true` + `cargo sqlx prepare` di CI; ephemeral DB di integration test |

---

## References

- `IMPLEMENTATION_PLAN.md` — Task 2.5 (Tech Stack Final) untuk daftar crate dengan versi
- `INTEGRATION_MAPPING.md` — Provider behavior, HMAC contract, state machine states
