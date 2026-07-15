# Technical Planning & Migration Strategy — Klass Media Generator

> **Lokasi**: `media-generator-service/` (Python 3.11 + FastAPI)
> **Status**: Ready for Execution
> **Last Updated**: 2026-07-15
> **Author**: Senior Technical Architect & Lead Product Manager

---

## Keputusan Terkunci (Confirmed Decisions)

| # | Decision | Catatan |
|---|----------|---------|
| 1 | **MIGRASI ke Template-Driven JSON** untuk PDF (Marp) + DOCX (python-docx direct) | PPTX sudah Template-Driven (`python-pptx` + master `.pptx` + manifest) — tidak diubah |
| 2 | PDF Engine: **Reuse Playwright Chromium** (sidecar sudah warm) | Hapus dependency `@marp-team/marp-core`, keep `playwright`, ganti input Marp HTML → Jinja2 HTML |
| 3 | Template: **Developer prototype dulu, designer polish nanti** | Fase 0A/0B dibuat developer (functional). Fase 6 = designer polish (iterative, post-launch) |
| 4 | `SlideBlueprint` (Pydantic SOT) **tidak berubah** | Migrasi = engine swap, bukan data model rewrite |
| 5 | Kontrak `media_generation_spec.v1` + HMAC **tidak berubah** | Field baru bersifat additive only |

---

## Bagian 1: Evaluasi & Keputusan Arsitektur (Ringkas)

### Kondisi Aktual

| Format | Engine Saat Ini | Status |
|--------|----------------|--------|
| **PPTX** | Template-Driven (`python-pptx` + master + manifest + TemplateInjector + Canvas fallback) | ✅ Sudah Template-Driven |
| **PDF + Preview** | Marp (`marp-core` + Playwright Chromium, Node sidecar) | ⚠️ Akan dimigrasi |
| **DOCX** | `python-docx` direct (hardcoded formatting, no template) | ⚠️ Akan dimigrasi |

### Perbandingan pada 2 Metrik Utama

| Metrik | Marp (saat ini) | Template-Driven JSON |
|--------|----------------|----------------------|
| **Visual Quality** | "Styled markdown slides" — kaku, ceiling rendah, parity PPTX↔PDF rendah | "Professionally designed" — full HTML/CSS freedom, parity tinggi |
| **Speed (warm PDF+preview)** | ~2-4s | ~1.5-3s (Jinja2 lebih cepat dari Marp parser; Chromium reuse) |
| **Architecture Consistency** | 2 paradigma (Marp + Template) | 1 paradigma (Template) untuk semua format |
| **Regression Risk** | Nol (sudah stabil) | Sedang — mitigasi: per-format migrasi, gate test per fase |

**REKOMENDASI FINAL: MIGRASI.** Marp memiliki visual ceiling fundamental yang tidak bisa mencapai output "menawan". Template-Driven JSON dengan master template (HTML untuk PDF, .docx untuk DOCX, .pptx untuk PPTX) memberikan kebebasan visual penuh + parity antar format. Speed tidak regresi (Chromium reuse, Jinja2 lebih cepat).

### Yang Tidak Berubah (Kontrak Stabil)

- `SlideBlueprint` Pydantic SOT
- `media_generation_spec.v1` + HMAC signature
- `artifact_download.py` signed URL mechanism
- `SidecarManager` lifecycle (spawn, health, self-healing, recycle)
- Gateway (Rust) — consume response yang sama
- Flutter `InAppWebView` — load self-contained HTML (karakteristik sama)
- PPTX pipeline — tidak disentuh

---

## Bagian 2: Implementation Plan (Roadmap dengan Checklist)

> **Tag Dependency**:
> - `[PARALEL]` — tugas bisa dikerjakan concurrent tanpa dependensi ketat
> - `[SEKUENSIAL]` — tugas hanya bisa dikerjakan setelah fase tertentu selesai

---

### FASE 0: Fondasi & Desain Template

> **Sifat**: [PARALEL] — semua sub-tugas independen, bisa concurrent
> **Estimasi**: 1-2 minggu
> **Gate**: Semua master template + Jinja2 infrastructure siap

- [x] **FASE 0: Fondasi & Desain Template**
  - [x] **0A [PARALEL]** — Desain HTML master template (developer prototype) untuk PDF & preview. 3 slide layouts (title, content, assessment) dengan placeholder Jinja2 (`{{ slide.title }}`, `{% for card in slide.cards %}`). Inline CSS self-contained. Design tokens parity PPTX (`#0B1F33`, `#0F4C5C`).
    - Output: `app/templates/masters/klass-educational-v1.html`
  - [x] **0B [PARALEL]** — Desain .docx master template (developer prototype). Word/LibreOffice: cover page, header/footer, heading styles, section template dengan `{{ title }}`/`{% for section in sections %}`, activity block styling.
    - Output: `app/templates/masters/klass-educational-v1.docx`
  - [x] **0C [PARALEL]** — Setup Jinja2 template infrastructure. `Environment` + `FileSystemLoader` ke `app/templates/masters/`, template registry (map `template_id` → HTML + DOCX paths), fail-fast validation startup.
    - Output: `app/templates/jinja_env.py`, update `app/templates/registry.py`
  - [x] **0D [PARALEL]** — Audit `SlideBlueprint` (`app/engines/blueprint.py`). Identifikasi field tambahan untuk template rendering. Extend jika perlu (additive, tidak break kontrak).
    - Output: Audit report + optional `blueprint.py` extension

---

### FASE 1: Migrasi Engine DOCX (python-docx → docxtpl)

> **Sifat**: [PARALEL] dengan Fase 2 — DOCX dan PDF migration independen
> **Estimasi**: 1 minggu
> **Dependensi**: 1A menunggu 0B + 0C; 1B menunggu 1A; 1C menunggu 1B
> **Gate**: DOCX generate via docxtpl lulus integration test

- [x] **FASE 1: Migrasi Engine DOCX**
  - [x] **1A [SEKUENSIAL] Menunggu Fase 0B + 0C selesai** — Implementasi `DocxTemplateEngine`. Wrapper `docxtpl.DocxTemplate(master_path)`, build Jinja2 context dari `SlideBlueprint` (slides → sections, cards → body blocks, activities → assessment), render + save. Ganti `DocxGenerator.render()` delegate ke engine.
    - Output: `app/engines/docx_template/engine.py`, update `app/generators/docx_generator.py`
  - [x] **1B [SEKUENSIAL] Menunggu Fase 1A selesai** — Unit tests DOCX engine: template rendering, placeholder filling, loop sections, activity blocks, edge cases (empty sections, long content, special chars). Assert file re-openable oleh `python-docx`.
    - Output: `tests/test_docx_template_engine.py`
  - [x] **1C [SEKUENSIAL] Menunggu Fase 1B selesai** — Integration test DOCX: full `POST /v1/generate` `export_format=docx`, verify response, download artifact, validate `.docx` magic bytes + openable.
    - Output: Update `tests/test_api.py`, `tests/test_generators.py`

---

### FASE 2: Migrasi Engine PDF + Preview (Marp → HTML Template + Chromium)

> **Sifat**: [PARALEL] dengan Fase 1 — PDF dan DOCX migration independen
> **Estimasi**: 2-3 minggu
> **Dependensi**: 2A menunggu 0A + 0C; 2B menunggu 2A; 2C menunggu 2B; 2D menunggu 2C; 2E menunggu 2D
> **Gate**: PDF + preview generate via HTML template lulus integration test; visual parity dengan PPTX terverifikasi
> **Keputusan**: Reuse Playwright Chromium (hapus `@marp-team/marp-core`, keep `playwright`)

- [x] **FASE 2: Migrasi Engine PDF + Preview**
  - [x] **2A [SEKUENSIAL] Menunggu Fase 0A + 0C selesai** — Implementasi `HtmlTemplateEngine`. `jinja2.render(template, context)` dari `SlideBlueprint` → HTML self-contained. Context builder map blueprint slides → Jinja2 variables.
    - Output: `app/engines/html_template/engine.py`, `app/engines/html_template/context_builder.py`
  - [x] **2B [SEKUENSIAL] Menunggu Fase 2A selesai** — Modifikasi Node sidecar (`marp_sidecar.js`): hapus `@marp-team/marp-core`, hapus `render_html(markdown)`. Tambah `html_to_pdf(html)` — `page.setContent(html)` + `page.pdf({ preferCSSPageSize, printBackground })`. Keep Playwright Chromium warm + lifecycle. Update `sidecar_manager.py` RPC method.
    - Output: Update `app/engines/marp/sidecar/marp_sidecar.js`, `sidecar_manager.py`
  - [x] **2C [SEKUENSIAL] Menunggu Fase 2B selesai** — Implementasi `PdfRenderer` (HTML string → sidecar `html_to_pdf` → PDF bytes → file) + `PreviewHandler` (HTML string → self-contained `.html` → signed URL via `artifact_download.py`). Refactor `PdfGenerator.render()` delegate ke engine baru.
    - Output: `app/engines/html_template/pdf_renderer.py`, update `app/generators/pdf_generator.py`, update `app/preview/preview_handler.py`
  - [x] **2D [SEKUENSIAL] Menunggu Fase 2C selesai** — Unit tests PDF/preview engine: HTML rendering (assert Jinja2 output), PDF generation (`%PDF-` header, page_count), preview self-contained (no external URLs), sidecar `html_to_pdf`, error mapping.
    - Output: `tests/test_html_template_engine.py`, `tests/test_pdf_renderer.py`
  - [x] **2E [SEKUENSIAL] Menunggu Fase 2D selesai** — Integration test PDF + preview: full `POST /v1/generate` `export_format=pdf`, verify `preview_delivery` signed URL, download PDF + preview HTML, validate magic bytes + WebView compatibility. Visual parity check PDF↔PPTX.
    - Output: Update `tests/test_api.py`, `tests/test_preview_api.py`, `tests/test_contract_e2e.py`

---

### FASE 3: Wiring & Registry Update

> **Sifat**: [SEKUENSIAL] — menunggu Fase 1 + Fase 2 selesai (kedua engine baru harus siap)
> **Estimasi**: 1 minggu
> **Gate**: Semua 3 format (DOCX, PDF, PPTX) generate via Template-Driven, backward-compat terverifikasi

- [x] **FASE 3: Wiring & Registry Update**
  - [x] **3A [SEKUENSIAL] Menunggu Fase 1C + Fase 2E selesai** — Update `app/generators/registry.py`: `DocxGenerator` → `DocxTemplateEngine`, `PdfGenerator` → `HtmlTemplateEngine` + sidecar `html_to_pdf`. Update lifespan: start Jinja2 template registry + sidecar (config berubah, tidak lagi Marp).
    - Output: Update `app/generators/registry.py`, `app/main.py` lifespan
  - [x] **3B [SEKUENSIAL] Menunggu Fase 3A selesai** — Update `app/main.py` `generate_artifact` response: verify `preview_delivery` (HTML dari Jinja2), `artifact_metadata.preview_url`, `layout_sources`. Backward-compat `media_generation_spec.v1` (additive fields).
    - Output: Update `app/main.py`, `app/models.py`, `app/contracts.py`
  - [x] **3C [SEKUENSIAL] Menunggu Fase 3B selesai** — Contract backward-compat test: `GenerateSuccessResponse.model_validate`, HMAC unchanged, signed URL preview 200 + mime `text/html`, `slide_count` konsisten, timeout/retry (render 30s, Gateway→MediaGen 60s). Run full pytest.
    - Output: Update `tests/test_contract_e2e.py`, full test run

---

### FASE 4: Retire Marp & Cleanup

> **Sifat**: [SEKUENSIAL] — menunggu Fase 3 selesai (semua format sudah pakai engine baru)
> **Estimasi**: 0.5 minggu
> **Gate**: Marp sepenuhnya dihapus, test suite hijau, Docker image build sukses

- [x] **FASE 4: Retire Marp & Cleanup**
  - [x] **4A [SEKUENSIAL] Menunggu Fase 3C selesai** — Hapus file Marp: `marp_markdown_builder.py`, `marp_renderer.py`, `themes/klass-default.css`. Rename `app/engines/marp/` → `app/engines/chromium_sidecar/`.
    - Output: File deletion + directory restructure
  - [x] **4B [SEKUENSIAL] Menunggu Fase 4A selesai** — Update `sidecar/package.json`: hapus `@marp-team/marp-core`, keep `playwright`. Rename `marp_sidecar.js` → `chromium_sidecar.js`.
    - Output: Update `package.json`, rename sidecar script
  - [x] **4C [SEKUENSIAL] Menunggu Fase 4B selesai** — Cleanup Marp tests: hapus/rewrite `test_marp_renderer.py`, `test_marp_markdown_builder.py`. Update `test_sidecar_manager.py` RPC method baru. Update `Dockerfile` (hapus Marp-specific deps). Full test suite green.
    - Output: Update tests, `Dockerfile`

---

### FASE 5: Flutter & E2E Finalize

> **Sifat**: Campuran [PARALEL] + [SEKUENSIAL]
> **Estimasi**: 1 minggu
> **Gate**: E2E Flutter → Gateway → Media Generator → preview + download sukses untuk semua 3 format

- [ ] **FASE 5: Flutter & E2E Finalize**
  - [x] **5A [PARALEL]** — Verify Flutter `InAppWebView` compatibility dengan HTML preview baru (self-contained dari Jinja2). Test: load `previewUrl` di WebView, verify render.
    - Output: Flutter test, manual verification
  - [x] **5B [SEKUENSIAL] Menunggu Fase 3C selesai** — Update `proto/klass/media/v1/media_generation.proto` jika ada field change (kemungkinan: tidak ada, `preview_url` field 6 sudah ada). Verify Gateway forward `preview_delivery`.
    - Output: Update proto (jika perlu), verify Gateway
  - [x] **5C [SEKUENSIAL] Menunggu Fase 4C + Fase 5A selesai** — E2E test lengkap: Flutter submit prompt → Gateway queue → LLM → Media Generator render (DOCX/PDF/PPTX) → preview di WebView → download sukses. Test semua 3 format. Verify visual parity PDF↔PPTX.
    - Output: E2E test pass, sign-off

---

### FASE 6: Designer Polish (Post-Migration Iteration)

> **Sifat**: [PARALEL] — iterative, tidak block launch. Mulai setelah Fase 5 selesai.
> **Estimasi**: 2-4 minggu (tergantung designer throughput)
> **Catatan**: Template swap tidak perlu kode change — cukup ganti file master di `app/templates/masters/`

- [ ] **FASE 6: Designer Polish**
  - [ ] **6A [PARALEL]** — Mulai setelah Fase 5C selesai. Designer polish HTML master template: decorative elements, SVG icons, gradient, background per-slide, typography refinement, subject-specific variants.
    - Output: `app/templates/masters/klass-educational-v1.html` (polished) + variant templates
  - [ ] **6B [PARALEL]** — Mulai setelah Fase 5C selesai. Designer polish .docx master template: header/footer logo, cover page, styled tables, TOC, section breaks.
    - Output: `app/templates/masters/klass-educational-v1.docx` (polished)
  - [ ] **6C [SEKUENSIAL] Menunggu Fase 6A selesai** — Visual parity audit: compare PDF output (HTML template) dengan PPTX output (master template) untuk deck sama. Adjust HTML template hingga parity tercapai.
    - Output: Visual parity report + template adjustment
  - [ ] **6D [PARALEL]** — Mulai setelah Fase 5C selesai. Buat template variant per subjek (IPA ikon sains, Matematika grid layout, Bahasa typography-focused). Update manifest registry.
    - Output: `app/templates/masters/klass-{subject}-v1.html`, update `registry.py`

---

## Critical Path

```
0A(dev) → 2A → 2B → 2C → 2D → 2E → 3A → 3B → 3C → 4A → 4B → 4C → 5C
                                                                    ↓
                                                              6A → 6C (designer polish, iterative)
```

**Launcher path** (Fase 0-5): ~5-7 minggu → semua 3 format via Template-Driven, developer-quality templates.
**Polish path** (Fase 6): iterative post-launch, designer tingkatkan visual tanpa kode change (swap file master).

---

## Ringkasan Blocker & Dependency

| Blocker | Menghambat | Karena |
|---------|-----------|--------|
| Fase 0A (HTML template) | Fase 2A, 2B, 2C | Template harus ada sebelum engine bisa render |
| Fase 0B (DOCX template) | Fase 1A | Master .docx harus ada sebelum docxtpl render |
| Fase 0C (Jinja2 infra) | Fase 1A, 2A | Template loader harus ada sebelum engine |
| Fase 1 + 2 selesai | Fase 3 | Kedua engine baru harus siap sebelum wiring |
| Fase 3 selesai | Fase 4 | Semua format harus stabil sebelum Marp dihapus |
| Fase 4 + 5A selesai | Fase 5C | Cleanup + WebView verify sebelum E2E final |
| Fase 5C selesai | Fase 6 | Launch sebelum designer polish iteration |

---

## Yang Tidak Berubah (Kontrak Stabil)

- `SlideBlueprint` Pydantic SOT — engine swap, bukan model change
- `media_generation_spec.v1` kontrak + HMAC signature — additive only
- `artifact_download.py` signed URL mechanism — reuse untuk HTML preview + PDF
- `SidecarManager` lifecycle — hanya RPC method name berubah
- Gateway (Rust) — tidak ada change
- Flutter `InAppWebView` — load self-contained HTML (karakteristik sama)
- PPTX pipeline — sudah Template-Driven, tidak disentuh
