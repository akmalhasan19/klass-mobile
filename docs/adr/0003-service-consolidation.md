# ADR-003: Konsolidasi Laravel → Rust Gateway; Media Gen Tetap Terpisah

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2026-07-11 |
| **Deciders** | Engineering Team |
| **Supersedes** | — |

---

## Context

Saat ini ada 3 Hugging Face Space:

| Space | Service | Bahasa | DB Terpisah |
|-------|---------|--------|-------------|
| #1 | Laravel Backend | PHP 8.3 | ❌ (shared Neon) |
| #2 | LLM Adapter | Python/FastAPI | ✅ (PostgreSQL sendiri) |
| #3 | Media Generator | Python/FastAPI | ❌ (stateless) |

Target konsolidasi: Space #1 + #2 → 1 Rust Gateway. Pertanyaan: apakah Space #3 (Media Gen) juga dikonsolidasi?

## Decision

**Konsolidasi Laravel (#1) + LLM Adapter (#2) ke Rust Gateway, tetapi pertahankan Media Generator (#3) sebagai service terpisah.**

```
Before:  3 HF Spaces, 2 Postgres DBs      After:  2 Services, 1 Postgres DB
┌──────────┐  ┌──────────┐  ┌──────────┐   ┌──────────────┐  ┌──────────────┐
│ Laravel   │  │ LLM       │  │ Media     │   │ Rust Gateway  │  │ Media Gen     │
│ (HF #1)  │  │ Adapter   │  │ Gen (#3)  │   │ (Render)      │  │ (HF Space)    │
│ PHP 8.3   │  │ Python    │  │ Python    │   │ axum+tonic    │  │ FastAPI       │
└─────┬─────┘  └─────┬─────┘  └─────┬─────┘   └───────┬──────┘  └──────┬───────┘
      │              │              │                 │                │
      └──────┬───────┘              │                 │    HTTP/2+HMAC │
             │                      │                 └────────────────┘
      ┌──────▼──────┐        ┌──────▼──────┐       ┌────────▼───────┐
      │ Neon PG      │        │ LLM Adptr DB│       │ Neon PostgreSQL │
      └─────────────┘        └─────────────┘       └────────────────┘
```

## Alternatives Considered

### Konsolidasi semua 3 service ke Rust

| Pro | Kontra |
|-----|--------|
| 1 binary, 0 HF Space | **Tidak ada library Rust yang setara** dengan `python-docx`, `reportlab`, `python-pptx` |
| Deploy paling sederhana | `.docx` OOXML rendering kompleks — perlu rebuild dari scratch |
| | `pdf` generation di Rust (`printpdf`, `genpdf`) terbatas, tidak bisa layout kompleks |
| | **Timeline +8-12 minggu** untuk rewrite renderer |

### Konsolidasi Laravel + Media Gen ke Rust, keep LLM Adapter terpisah

| Pro | Kontra |
|-----|--------|
| — | LLM Adapter adalah pure orchestration + cache + governance — paling mudah diport ke Rust |
| | Tidak ada alasan untuk mempertahankan service Python terpisah untuk logika ini |

### Keep semua 3 HF Space, hanya ganti Laravel ke Rust

| Pro | Kontra |
|-----|--------|
| Risiko rendah | Tetap 3 service = 3x operational overhead |
| | LLM Adapter → Gateway network hop = tambahan latency ~5-10ms |
| | Tetap bayar 2 Postgres DB (Neon + LLM Adapter DB) |

### Kenapa Media Gen tetap terpisah

Media Generator menggunakan library Python yang tidak punya padanan di Rust:

| Library | Kegunaan | Rust alternative | Status |
|---------|----------|-----------------|--------|
| `python-docx` | Generate `.docx` (OOXML) | `docx-rs` | Abandoned, last commit 2022 |
| `reportlab` | Generate `.pdf` (complex layout) | `printpdf` / `genpdf` | Basic only, no table/page layout |
| `python-pptx` | Generate `.pptx` (OOXML) | — | Tidak ada |

Selain itu, Media Gen sudah well-tested dan tidak memerlukan perubahan. Menyimpannya terpisah juga memungkinkan scaling independen.

## Consequences

### Positive

- **Technical feasibility**: Tidak perlu rewrite renderer dari scratch → timeline tetap 18 minggu
- **Isolation**: Bug di Media Gen tidak impact Gateway; deploy independen
- **Cost**: HF Space #3 tetap $0-20 (gratis jika idle), tidak ada biaya tambahan
- **Focus**: Tim fokus port business logic + orchestrator yang sudah well-understood

### Negative / Mitigation

| Risk | Mitigation |
|------|-----------|
| 2 service = 2 deployment pipeline | Gateway deploy via Render CI/CD; Media Gen auto-deploy dari HF — keduanya simple |
| HMAC secret perlu disinkronkan antara 2 service | Satu source of truth (Render env vars + HF secrets); rotation dengan `accepted_shared_secrets` |
| Cold start HF Space #3 (inactive → spin up) | Gateway ping keep-alive ke `/v1/health` setiap 4 menit (sudah di risk matrix) |

---

## References

- `IMPLEMENTATION_PLAN.md` — Risk Assessment Matrix (row: "Cold start HF Space #3")
- `IMPLEMENTATION_PLAN.md` — Architecture Target diagram
- `media-generator-service/app/main.py` — Current Media Gen entry point
