# Implementation Plan: Hybrid AI PPT Generation Engine

> **Lokasi**: `media-generator-service/` (Python 3.11 + FastAPI + `python-pptx`)
> **Klien**: Flutter mobile via Rust Gateway (gRPC stream + REST), bukan langsung ke service
> **Status**: Approved
> **Last Updated**: 2026-07-15
> **Based on**: Codebase audit `media-generator-service` + `IMPLEMENTATION_PLAN.md` (Laravel→Rust Gateway migration)

---

## Keputusan Arsitektur Terkunci

| # | Decision | Alasan |
|---|----------|--------|
| 1 | Master Template pakai paket `.pptx` + manifest JSON | Paling deterministik & testable; placeholder_id → shape_name mapping eksplisit |
| 2 | Marp HTML preview disajikan via **self-contained HTML + signed URL** | Konsisten dengan pola `artifact_download.py` yang sudah jalan; offline-friendly di Webview |
| 3 | Parity **struktural** antara preview & PPTX (bukan pixel-perfect) | Effort reasonable, cocok untuk iterasi AI |
| 4 | Marp sebagai tulang punggung visual untuk **PPTX preview + PDF** | Parity tinggi antara preview & PDF karena dari sumber HTML/CSS sama |
| 5 | PDF engine: **Chromium warm + Marp PDF** (Playwright) | Parity visual tertinggi; pre-warm di lifespan eliminasi cold start |
| 6 | Optimasi: **Node sidecar long-running** (bukan subprocess per request) | Eliminasi Node startup ~200ms per call; latensi paling rendah |
| 7 | PPTX native editable via Template Injection + Canvas Layout fallback | Desain desainer menang saat muat; kalkulator koordinat saat overflow |
| 8 | DOCX generator tidak disentuh | Nol regresi pada format yang sudah jalan |

---

## Temuan Kunci dari Audit Kode

| Aspek | Saat Ini | Implikasi |
|-------|----------|-----------|
| `pptx_generator.py:21` | `Presentation()` kosongan + `slide_layouts[6]`, hardcoded 2-kolom, truncate 6 baris `...` | Tidak ada desain profesional, tidak editable-rich, tidak ada preview |
| `pdf_generator.py` | reportlab naive (A4, Helvetica, plain) | Bisa diganti render Marp PDF (parity tinggi dengan preview) |
| `artifact_download.py` | Signed URL HMAC sudah jalan untuk `.pptx/.pdf/.docx` | Dapat dipakai langsung untuk serve Marp HTML preview — cukup perluas prefix check |
| `document_model.py` | `RenderDocument` (frozen dataclass) sebagai intermediate | Jadi pondasi `SlideBlueprint` universal |
| `contracts.py` | `media_generation_spec.v1`, HMAC `hmac-sha256` | Tetap dipertahankan; preview jadi additive field |
| `frontend/.../media_generation_service.dart` | Dio + polling 4s, baca `delivery_payload.artifact` | Preview URL ditambahkan ke `ArtifactInfo` proto / delivery payload |
| `pubspec.yaml` | `flutter_inappwebview` belum ada | Dependency baru di sisi Flutter (advisorial) |
| `IMPLEMENTATION_PLAN.md` | Media Gen tetap Python (Rust kurang parity library) | Engine baru tetap Python; Gateway hanya forward |
| `internal-media-gen.md:40` | Timeout Gateway → MediaGen = 60s per request | Budget render kita 60s, bukan 240s |

---

## 1. ARCHITECTURAL BLUEPRINT

### 1.1 Data Flow Diagram

```
┌────────────┐  REST POST /v1/media-generations {prompt}    ┌────────────────────┐
│  Flutter   │ ───────────────────────────────────────────> │  Rust Gateway      │
│ (Dio+gRPC) │ <── gRPC stream GenerationProgressEvent ──── │  (Axum+tonic)      │
└─────┬──────┘   (COMPLETED.delivery_payload.{preview,artifact}) └────────┬───────────┘
      │ flutter_inappwebview.loadUrl(preview_html_url)              │ HTTP/2 + HMAC
      │ Dio.download(artifact_pptx_url)                             │ POST /v1/generate
      │                                                              v
      │                                              ┌───────────────────────────────┐
      │                                              │  Media Generator (Python)     │
      │                                              │                                │
      │                                              │  1. build SlideBlueprint       │
      │                                              │     (from generation_spec)     │
      │                                              │                                │
      │                                              │  2. FORK into 2 pipelines:     │
      │                                              │  ┌───────────┐  ┌────────────┐ │
      │                                              │  │ PREVIEW + │  │ PPTX       │ │
      │                                              │  │ PDF pipe  │  │ pipe       │ │
      │                                              │  │           │  │            │ │
      │                                              │  │ Blueprint │  │ Blueprint  │ │
      │                                              │  │   ↓       │  │   ↓        │ │
      │                                              │  │ Marp MD   │  │ Template   │ │
      │                                              │  │   ↓       │  │ Injector   │ │
      │                                              │  │ sidecar   │  │   ↓ fits?  │ │
      │                                              │  │  ↓     ↓  │  │  yes→inject│ │
      │                                              │  │ HTML   PDF│  │  no→Canvas │ │
      │                                              │  │        ↓  │  │     Calc   │ │
      │                                              │  │        ↓  │  │     ↓      │ │
      │                                              │  │  self-   │  │  .pptx     │ │
      │                                              │  │ contained│ │  (editable)│ │
      │                                              │  │  .html   │  │            │ │
      │                                              │  └────┬─────┘  └─────┬──────┘ │
      │                                              │       │              │        │
      │                                              │  signed URL (artifact_download.py) │
      │                                              └───────┬──────────────┬────────┘
      └──────────────────────────────────────────────────────┘              │
                preview_url  +  artifact_url  (keduanya signed, HMAC) ───────┘
```

**Tiga pilar, dua pipeline, satu blueprint:**
- `SlideBlueprint` (JSON Pydantic) = single source of truth yang dipahami kedua pipeline.
- **Pipeline Preview+PDF**: Blueprint → Marp markdown (deterministic) → Node sidecar (marp-core + Playwright Chromium warm) → HTML self-contained (preview) + PDF (download). Parity tinggi karena dari sumber sama.
- **Pipeline PPTX**: Blueprint → Template Injector (master `.pptx` + manifest) → jika overflow → Canvas Calculator fallback → `.pptx` native editable.

### 1.2 Efisiensi Marp HTML untuk `flutter_inappwebview`

**Pilihan: Self-contained HTML via signed URL** (konsisten dengan pola `artifact_download.py` yang sudah jalan).

- `marp-core --html --allow-local-files` menghasilkan satu file HTML dengan seluruh CSS/theme/asset ter-inline (zero external request). Cocok untuk Webview mobile: tidak ada CORS, tidak ada dependensi jaringan, bisa offline setelah download.
- Disimpan di temp dir dengan prefix `klass_media_html_` → dilayani via endpoint `GET /v1/artifacts/download` yang sudah ada dengan signed URL HMAC (cukup perluas `normalize_downloadable_artifact_path` di `artifact_download.py:142` untuk mengizinkan prefix html + extension `.html`).
- Flutter: `InAppWebView(initialUrlRequest: URLRequest(url: WebUri(signedUrl)))`. Karena self-contained, `loadUrl` sekali selesai — tidak ada render round-trip tambahan.
- TTL sama dengan artifact lain (`MEDIA_GENERATION_PYTHON_ARTIFACT_URL_TTL_SECONDS=900`).

### 1.3 Integrasi Master Template Injection ↔ Dynamic Canvas Layout

Strategi **hybrid per-slide dengan capacity gate**:

```
for each slide in SlideBlueprint:
    layout = manifest.pick_layout(slide.slide_type)          # title|section|content|assessment
    if layout.capacity.fits(slide.cards, slide.chars):       # cek max_cards + max_chars dari manifest
        → TemplateInjector.fill(master_slide, placeholders)  # PRIORITAS: pakai desain profesional
    else:
        → CanvasLayoutEngine.render_slide(presentation, slide)  # FALLBACK: hitung X,Y,W,H
        warnings.append(f"slide {n}: fallback canvas (cards={n} > cap={m})")
```

- **Prioritas desain**: selama konten muat dalam kapasitas placeholder master, selalu pakai template (desain desainer menang).
- **Fallback otomatis**: saat kartu melebihi `max_cards` (mis: 3-4 kolom) atau total karakter melebihi `max_chars`, kalkulator canvas mengambil alih slide itu — hitung grid koordinat EMU dari dimensi slide + margin + gap, render rounded-rectangle via `python-pptx`.
- **Hybrid deck**: satu deck bisa berisi campuran slide template-injected dan slide canvas-calculated. Field `layout_source` per slide (`"template"` / `"canvas"`) dicatat di `RenderSummary.warnings` untuk transparansi debug.
- **Threshold dapat di-tune**: kapasitas didefinisikan di `manifest.json` per placeholder, jadi desainer bisa menaikkan batas tanpa ubah kode.

---

## 2. FOLDER STRUCTURE REFACTORING

### Struktur saat ini
```
media-generator-service/app/
  generators/{base,docx_generator,pdf_generator,pptx_generator,registry}.py
  document_model.py, models.py, contracts.py, auth.py, artifact_download.py, ...
```

### Struktur target (modularisasi 3 pilar)
```
media-generator-service/
├── app/
│   ├── engines/                          # BARU: 3 pilar Hybrid Engine
│   │   ├── __init__.py
│   │   ├── base.py                       # BaseEngine ABC (render → RenderSummary)
│   │   ├── blueprint.py                  # SlideBlueprint universal (Pydantic) — SOT
│   │   ├── blueprint_builder.py          # GenerationSpec/RenderDocument → SlideBlueprint
│   │   ├── marp/                         # Pilar 1: Marp (preview + PDF)
│   │   │   ├── __init__.py
│   │   │   ├── marp_renderer.py          # call Node sidecar (HTML + PDF) + timeout/error
│   │   │   ├── marp_markdown_builder.py  # SlideBlueprint → Marp markdown (directives)
│   │   │   ├── sidecar/                  # long-running Node process
│   │   │   │   ├── sidecar_manager.py    # Python: spawn, health, JSON-RPC, auto-restart
│   │   │   │   ├── marp_sidecar.js       # Node: marp-core + Playwright warm + stdio RPC
│   │   │   │   └── package.json          # @marp-team/marp-core, playwright
│   │   │   └── themes/
│   │   │       └── klass-default.css     # custom Marp theme (parity struktural dgn master)
│   │   ├── pptx_injector/               # Pilar 2: Master Template Injection
│   │   │   ├── __init__.py
│   │   │   ├── injector.py              # master.pptx + manifest → filled .pptx
│   │   │   ├── placeholder_resolver.py  # placeholder_id → shape by name/idx
│   │   │   └── manifest.py              # TemplateManifest schema + loader
│   │   └── canvas_calculator/           # Pilar 3: Dynamic Canvas Layout (fallback)
│   │       ├── __init__.py
│   │       ├── layout_engine.py         # grid/flow calc (X,Y,W,H EMU)
│   │       ├── font_metrics.py          # text → estimasi box size (fit check)
│   │       └── shape_renderer.py        # render box via python-pptx shapes
│   ├── templates/                       # BARU: master template + manifest registry
│   │   ├── __init__.py
│   │   ├── registry.py                  # catalog (template_id → master+manifest), startup load
│   │   ├── masters/
│   │   │   └── klass-educational-v1.pptx
│   │   └── manifests/
│   │       └── klass-educational-v1.json
│   ├── generators/                      # LAMA: tetap, jadi orchestrator tipis
│   │   ├── base.py                      # tetap
│   │   ├── docx_generator.py            # tetap (python-docx, jangan sentuh)
│   │   ├── pdf_generator.py             # refactor → delegate ke engines.marp (Marp PDF)
│   │   ├── pptx_generator.py            # refactor → delegate ke engines.pptx_injector (+fallback)
│   │   └── registry.py                  # wiring diperbarui
│   ├── preview/                         # BARU: preview serving
│   │   ├── __init__.py
│   │   └── preview_handler.py           # build signed URL untuk HTML (reuse artifact_download)
│   ├── models.py                        # extend: SlideBlueprint, PreviewArtifact models
│   ├── contracts.py                     # extend: PREVIEW schema ver, MIME text/html, .html
│   ├── artifact_download.py             # extend: prefix html + .html extension
│   ├── main.py                          # extend: response + preview_delivery field
│   └── ... (auth, settings, errors, document_model — tetap)
├── tests/
│   ├── test_blueprint.py                # baru
│   ├── test_marp_renderer.py            # baru
│   ├── test_marp_markdown_builder.py    # baru
│   ├── test_sidecar_manager.py          # baru
│   ├── test_pptx_injector.py            # baru
│   ├── test_canvas_calculator.py        # baru
│   ├── test_preview_api.py              # baru
│   └── test_generators.py               # update assertion
├── requirements.txt                     # tetap (sidecar pakai npm, bukan pip)
└── Dockerfile                           # + Node.js + Playwright Chromium
```

**Aturan modularisasi**: `generators/` jadi orchestrator tipis (route + metadata + signed URL), logika visual pindah ke `engines/`. DOCX tidak disentuh (regresi nol). Registry tetap single entry-point untuk Gateway.

---

## 3. PERFORMANCE ARCHITECTURE: Node Sidecar + Chromium Warm

### Arsitektur Sidecar

```
FastAPI process (Python)                Node Sidecar (long-running)
┌──────────────────────────┐            ┌────────────────────────────┐
│ lifespan startup:        │            │ marp_sidecar.js            │
│  SidecarManager.spawn()  │──stdio───> │  - @marp-team/marp-core    │
│  wait for ready signal   │<─stdout── │  - Playwright Chromium     │
│                          │            │    (launch ONCE, reuse)    │
│ Request /v1/generate:    │            │                            │
│  blueprint = build(...)  │            │ JSON-RPC over stdio:       │
│  asyncio.gather(         │            │  render_html(md) → str     │
│    thread(inject_pptx),  │            │  render_pdf(html) → bytes  │
│    sidecar.render_html,  │──stdio───> │                            │
│    sidecar.render_pdf    │<─stdout── │  BrowserContext warm        │
│  )                       │            │  Page per request (cleanup)│
└──────────────────────────┘            └────────────────────────────┘
```

**Komunikasi**: stdio JSON-RPC (cross-platform, no port allocation, no Windows Unix-socket issue). Python kirim `{"id":1,"method":"render_html","markdown":"..."}` → Node balas `{"id":1,"html":"..."}`.

### Budget Performa Aktual

| Skenario | Estimasi | Budget 60s |
|---|---|---|
| Cold start (container restart, first request) | ~5-8s (sidecar launch + Chromium warm) | margin 7-12x |
| Warm: PPTX + HTML preview (paralel) | ~1.5-3s | margin 20-40x |
| Warm: PDF + HTML preview (paralel) | ~2-4s | margin 15-30x |
| Worst case (20 slide + 4 canvas fallback) | ~6-10s | margin 6-10x |

Full flow 4 menit terpenuhi dengan margin sangat besar — media gen hanya ~5-10s dari 240s, sisanya untuk LLM interpret + draft + R2 upload.

---

## 4. STEP-BY-STEP IMPLEMENTATION PLAN

### FASE 1: Parsing & Schema Definition (Blueprint Universal)

- [x] **Task 1.1: Definisikan `SlideBlueprint` Pydantic model**
  - [x] Buat `app/engines/__init__.py` dan `app/engines/base.py` (BaseEngine ABC)
  - [x] Buat `app/engines/blueprint.py` dengan `SlideBlueprint`, `Slide`, `Card` strict models
  - [x] `SlideBlueprint { deck_meta, theme_id, slides: list[Slide] }`
  - [x] `Slide { slide_type: Literal["title","section","content","assessment"], title, subtitle?, cards: list[Card], columns_hint?, speaker_notes?, layout_source? }`
  - [x] `Card { heading?, body_blocks: list[RenderBlock] }` (reuse `RenderBlock` dari `document_model.py`)
  - [x] Gunakan `ConfigDict(extra="forbid", str_strip_whitespace=True)` sesuai style `models.py:17`

- [x] **Task 1.2: Implementasikan `blueprint_builder.py`**
  - [x] Buat `app/engines/blueprint_builder.py`
  - [x] Fungsi `build_slide_blueprint(render_document) -> SlideBlueprint`
  - [x] Mapping heuristik: section → content slide, activity_blocks → assessment slide, title slide dari deck meta
  - [x] Backward-compat dengan `media_generation_spec.v1` (tidak pecah kontrak Gateway)
  - [x] Handle `learning_objectives` → title slide cards

- [x] **Task 1.3: Definisikan `TemplateManifest` schema**
  - [x] Buat `app/engines/pptx_injector/__init__.py`
  - [x] Buat `app/engines/pptx_injector/manifest.py`
  - [x] Schema: `{ template_id, version, slide_layouts: [{ layout_id, slide_type, slide_index, placeholders: [{ placeholder_id, shape_name, kind, capacity }] }] }`
  - [x] Method `pick_layout(slide_type)` dan `placeholder(id)` lookup
  - [x] `Capacity { max_cards?, max_chars? }` untuk fit-check

- [x] **Task 1.4: Unit test Fase 1**
  - [x] Buat `tests/test_blueprint.py`
  - [x] Test builder round-trip dari `sample_request("pptx")`
  - [x] Test manifest validation (extra="forbid")
  - [x] Test semua slide_type ter-cover
  - [x] Gate: blueprint + manifest tervalidasi, backward-compat dengan v1

---

### FASE 2: Marp Preview API (HTML Generator) + PDF via Sidecar

- [x] **Task 2.1: Setup Node sidecar infrastructure**
  - [x] Buat `app/engines/marp/sidecar/package.json` dengan deps `@marp-team/marp-core`, `playwright`
  - [x] Buat `app/engines/marp/sidecar/marp_sidecar.js`
  - [x] Spawn Chromium sekali saat startup, kirim `{"ready":true}` ke stdout
  - [x] Implementasi JSON-RPC over stdio: `render_html(md)`, `render_pdf(html)`
  - [x] Per request: Playwright page baru (reuse browser), cleanup setelah render
  - [x] Handle error: invalid markdown, Chromium crash, timeout

- [x] **Task 2.2: Implementasikan `SidecarManager` (Python)**
  - [x] Buat `app/engines/marp/sidecar/sidecar_manager.py`
  - [x] `asyncio` wrapper untuk stdio JSON-RPC (request/response correlation by id)
  - [x] `SidecarManager.start()` → spawn node process, wait for ready signal
  - [x] `SidecarManager.stop()` → graceful shutdown (SIGTERM → kill)
  - [x] Health check heartbeat tiap 30s
  - [x] Auto-restart on crash/unresponsive (timeout 30s)
  - [x] `asyncio.Semaphore` max 4 paralel render
  - [x] Restart sidecar setiap N=100 render atau 1 jam (configurable) untuk memory cleanup

- [x] **Task 2.3: Buat Marp markdown builder**
  - [x] Buat `app/engines/marp/marp_markdown_builder.py`
  - [x] Fungsi `build_marp_markdown(blueprint) -> str`
  - [x] Header directives: `--- marp: true\ntheme: klass-default\npaginate: true\nsize: 16:9 ---`
  - [x] Per-slide: `<!-- _class: {slide_type} -->` + heading + card bullets
  - [x] Handle semua slide_type (title, section, content, assessment)

- [x] **Task 2.4: Buat custom Marp theme CSS**
  - [x] Buat `app/engines/marp/themes/klass-default.css`
  - [x] Theme struktural (warna/font mendekati master template — parity struktural)
  - [x] CSS classes: `title`, `section`, `content`, `assessment` (match slide_type)
  - [x] Card layout: grid/flex untuk multi-column

- [x] **Task 2.5: Implementasikan `marp_renderer.py`**
  - [x] Buat `app/engines/marp/marp_renderer.py`
  - [x] `render_html(markdown, out_html)` → call `sidecar.render_html(md)`, write to file
  - [x] `render_pdf(markdown, out_pdf)` → call `sidecar.render_pdf(html)`, write to file
  - [x] Raise `GenerationError` on failure
  - [x] Theme CSS di-inline ke markdown (via `--theme` flag atau inline directive)

- [x] **Task 2.6: Integrasikan sidecar ke FastAPI lifespan**
  - [x] Update `app/main.py` lifespan: `await sidecar.start()` sebelum accept request
  - [x] Shutdown: `await sidecar.stop()` graceful
  - [x] Health endpoint report sidecar status (`/v1/health` tambah `sidecar: {status, uptime}`)

- [x] **Task 2.7: Buat preview handler + extend artifact_download**
  - [x] Buat `app/preview/__init__.py` dan `app/preview/preview_handler.py`
  - [x] Simpan HTML ke temp dir dengan prefix `klass_media_html_`
  - [x] Bangun signed URL via `build_signed_artifact_locator`
  - [x] Update `app/artifact_download.py:142` `normalize_downloadable_artifact_path` — perluas prefix check agar menerima `klass_media_html_` + extension `.html`

- [x] **Task 2.8: Extend contracts & models**
  - [x] Update `app/contracts.py`: tambah `PREVIEW_SCHEMA_VERSION = "media_generator_preview.v1"`, `MIME_TYPES["html"] = "text/html"`
  - [x] Update `app/models.py`: tambah `PreviewDelivery` model, extend `GenerateSuccessResponse` dengan `preview_delivery` field opsional

- [x] **Task 2.9: Refactor `pdf_generator.py` → delegate ke Marp**
  - [x] Update `app/generators/pdf_generator.py` `render()` → delegate ke `marp_renderer.render_pdf`
  - [x] Ganti reportlab dengan Marp PDF (parity tinggi dengan preview)
  - [x] `RenderSummary` tetap `page_count`
  - [x] Hapus dependency reportlab dari `requirements.txt` (opsional, keep untuk safety)

- [x] **Task 2.10: Update `main.py` response + Dockerfile**
  - [x] Update `app/main.py` `generate_artifact`: saat `export_format in ("pptx","pdf")`, render preview HTML paralel, tambah `data.preview_delivery` ke response
  - [x] Update `Dockerfile`: base `python:3.11-slim` + multi-stage install Node 20 + Playwright Chromium + system deps
  - [x] System deps: `libnss3`, `libnspr4`, `libatk1.0-0`, `libatk-bridge2.0-0`, `libcups2`, `libdrm2`, `libdbus-1-3`, `libxkbcommon0`, `libatspi2.0-0`, `libxcomposite1`, `libxdamage1`, `libxfixes3`, `libxrandr2`, `libgbm1`, `libpango-1.0-0`, `libcairo2`, `libasound2`
  - [x] `npm install --omit=dev` + `npx playwright install chromium` di sidecar dir

- [x] **Task 2.11: Unit + integration test Fase 2**
  - [x] Buat `tests/test_sidecar_manager.py` — test start/stop/health/restart
  - [x] Buat `tests/test_marp_markdown_builder.py` — test blueprint → markdown
  - [x] Buat `tests/test_marp_renderer.py` — test HTML valid (contains `<div class="marp"`), PDF `%PDF-`
  - [x] Buat `tests/test_preview_api.py` — test signed URL preview 200, mime `text/html`
  - [x] Gate: preview HTML & PDF ter-render, signed URL jalan, PDF menggantikan reportlab

---

### FASE 3: Core PPTX Engine (Template Injection + Canvas Fallback)

- [ ] **Task 3.1: Sediakan master template + manifest**
  - [ ] Buat `app/templates/__init__.py` dan `app/templates/registry.py`
  - [ ] Sediakan `app/templates/masters/klass-educational-v1.pptx` (master desainer)
  - [ ] Buat `app/templates/manifests/klass-educational-v1.json` (placeholder mapping)
  - [ ] Validasi shape names ada di master saat startup — fail fast dengan `ServiceMisconfiguredError` jika mismatch

- [ ] **Task 3.2: Implementasikan `TemplateRegistry`**
  - [ ] `app/templates/registry.py`: load semua template saat lifespan startup
  - [ ] Cache manifest (JSON, immutable) — boleh share across requests
  - [ ] Re-open master `.pptx` path per request (bukan deepcopy — `python-pptx` tidak thread-safe)
  - [ ] API: `registry.get(template_id) -> (master_path, manifest)`

- [ ] **Task 3.3: Implementasikan `placeholder_resolver.py`**
  - [ ] Buat `app/engines/pptx_injector/placeholder_resolver.py`
  - [ ] `resolve_shape(slide, shape_name) -> Shape` (cari di `slide.shapes` by `shape.name`)
  - [ ] Handle missing shape → return None + warning
  - [ ] Support kind: "text" (set text_frame), "image" (placeholder for future)

- [ ] **Task 3.4: Implementasikan `injector.py` (Template Injection)**
  - [ ] Buat `app/engines/pptx_injector/injector.py` (lihat prototype §5a)
  - [ ] `TemplateInjector.__init__(master_path, manifest)`
  - [ ] `inject(blueprint, output_path) -> InjectionResult`
  - [ ] Per-slide: capacity gate → fill atau delegate canvas
  - [ ] Preserve master formatting: set text pada run pertama (jangan replace text_frame.text)
  - [ ] `InjectionResult { slide_count, fallback_slides, warnings }`

- [ ] **Task 3.5: Implementasikan `font_metrics.py` (fit check)**
  - [ ] Buat `app/engines/canvas_calculator/font_metrics.py`
  - [ ] `estimate_box(text, font_pt, box_w_emu) -> height_emu`
  - [ ] chars-per-line ≈ `width / (0.5 * font_pt)`
  - [ ] lines = ceil(total_chars / chars_per_line)
  - [ ] height = lines × font_pt × 1.2 (line spacing)

- [ ] **Task 3.6: Implementasikan `layout_engine.py` (Canvas Calculator)**
  - [ ] Buat `app/engines/canvas_calculator/layout_engine.py` (lihat prototype §5b)
  - [ ] `CanvasLayoutEngine.__init__(slide_width, slide_height, margin, gap, title_band)`
  - [ ] `render_slide(presentation, slide)` — hitung grid, delegate ke shape_renderer
  - [ ] `_pick_columns(card_count)`: 1→1, 2→2, 3-4→2, 5-9→3, ≥10→4
  - [ ] `_grid(columns, rows)` → list[Box] dengan X/Y/W/H EMU

- [ ] **Task 3.7: Implementasikan `shape_renderer.py`**
  - [ ] Buat `app/engines/canvas_calculator/shape_renderer.py`
  - [ ] Render card box: `ROUNDED_RECTANGLE` + text frame + bullet runs
  - [ ] Styling: fill putih, border biru-muda, font size per column count
  - [ ] Handle heading (bold) + body_blocks (bullet/checklist/paragraph)

- [ ] **Task 3.8: Refactor `pptx_generator.py` → delegate ke engine**
  - [ ] Update `app/generators/pptx_generator.py` `render()`:
    - [ ] Build blueprint dari render_document
    - [ ] Call `TemplateInjector.inject(blueprint, out)`
    - [ ] Untuk slide fallback, call `CanvasLayoutEngine.render_slide`
    - [ ] Kumpulkan `RenderSummary.warnings` (+ `fallback_slides`)
  - [ ] Hapus kode hardcoded layout lama (`_add_title_slide`, `_add_section_slide`, dll)

- [ ] **Task 3.9: Update registry wiring**
  - [ ] Update `app/generators/registry.py`: pastikan PptxGenerator dan PdfGenerator instantiate dengan dependency injection (template registry, sidecar manager)
  - [ ] Update lifespan: start template registry + sidecar

- [ ] **Task 3.10: Unit + integration test Fase 3**
  - [ ] Buat `tests/test_pptx_injector.py` — test inject mengisi placeholder (assert shape.text)
  - [ ] Buat `tests/test_canvas_calculator.py` — test overflow 3/4-col trigger canvas (assert shape count = cards)
  - [ ] Test `slide_count` benar, warnings tercatat
  - [ ] Test file editable (buka di PowerPoint tidak error — validasi via python-pptx re-open)
  - [ ] Update `tests/test_generators.py` assertion jika perlu (test `test_pptx_generator_renders_title_section_and_activity_slides`)
  - [ ] Gate: PPTX editable dengan campuran slide template + canvas, backward-compat

---

### FASE 4: Flutter-Backend Contract Finalize

- [ ] **Task 4.1: Finalisasi request/response contract**
  - [ ] Request: tetap `media_generation_spec.v1` (backward-compat)
  - [ ] Field opsional baru (additive): `template_id?: str`, `preview_format?: "marp_html"`
  - [ ] Response `POST /v1/generate` tambah field `data.preview_delivery` (signed URL HTML) saat `export_format in ("pptx","pdf")`
  - [ ] `artifact_metadata` tambah `preview_url`, `layout_sources[]`

- [ ] **Task 4.2: Extend artifact download endpoint**
  - [ ] `GET /v1/artifacts/download` handle `.html`, `.pdf`, `.pptx` (sudah ada, cuma perluas prefix/extension)
  - [ ] Test: download `.html` → 200, `Content-Type: text/html`

- [ ] **Task 4.3: Update proto file (advisorial)**
  - [ ] Update `proto/klass/media/v1/media_generation.proto`: tambah `optional string preview_url = 6;` di `ArtifactInfo`
  - [ ] Proto field opsional, tidak break Gateway existing
  - [ ] Gateway forward `preview_delivery.value` ke sini

- [ ] **Task 4.4: Flutter changes (advisorial, di luar service ini)**
  - [ ] Tambah `flutter_inappwebview: ^6.x` ke `frontend/pubspec.yaml`
  - [ ] Widget preview: `InAppWebView` load `preview_url`
  - [ ] Tombol download pakai `artifact.url` (sudah ada)
  - [ ] UI lain tetap (status card, polling, dll)

- [ ] **Task 4.5: Contract test + E2E**
  - [ ] Test: response lulus `GenerateSuccessResponse.model_validate`
  - [ ] Test: signed URL preview 200, mime `text/html`
  - [ ] Test: `artifact_metadata.slide_count` konsisten
  - [ ] Test: HMAC tidak berubah (preview signed URL pakai secret yang sama)
  - [ ] Test: timeout/retry — Marp render 30s; total request timeout Gateway→MediaGen tetap 60s
  - [ ] Gate: end-to-end Flutter submit → preview tampil di Webview → download PPTX editable

---

## 5. CODE PROTOTYPE / BLUEPRINT CODE

### 5a. Template Injection — inject konten ke master `.pptx` via placeholder ID

```python
# app/engines/pptx_injector/injector.py
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from pptx import Presentation

from app.engines.blueprint import SlideBlueprint, Slide
from app.engines.pptx_injector.manifest import TemplateManifest, LayoutManifest
from app.engines.pptx_injector.placeholder_resolver import resolve_shape


@dataclass(frozen=True)
class InjectionResult:
    slide_count: int
    fallback_slides: list[int]      # 1-indexed slide yang dipassing ke canvas
    warnings: list[str]


class TemplateInjector:
    def __init__(self, master_path: Path, manifest: TemplateManifest) -> None:
        self._master_path = master_path
        self._manifest = manifest

    def inject(self, blueprint: SlideBlueprint, output_path: Path) -> InjectionResult:
        presentation = Presentation(str(self._master_path))
        fallback: list[int] = []
        warnings: list[str] = []

        for index, slide in enumerate(blueprint.slides, start=1):
            layout = self._manifest.pick_layout(slide.slide_type)
            if layout is None:
                warnings.append(f"slide {index}: no layout for '{slide.slide_type}'")
                continue
            if self._fits(layout, slide):
                self._fill(presentation, layout, slide)
            else:
                fallback.append(index)
                warnings.append(
                    f"slide {index}: exceeds '{layout.layout_id}' capacity -> canvas fallback"
                )

        presentation.save(str(output_path))
        return InjectionResult(len(blueprint.slides), fallback, warnings)

    def _fits(self, layout: LayoutManifest, slide: Slide) -> bool:
        body = layout.placeholder("body")
        if body is None or body.capacity is None:
            return True
        if body.capacity.max_cards and len(slide.cards) > body.capacity.max_cards:
            return False
        if body.capacity.max_chars:
            total = sum(
                len(c.heading or "") + sum(len(b.content) for b in c.body_blocks)
                for c in slide.cards
            )
            if total > body.capacity.max_chars:
                return False
        return True

    def _fill(self, presentation: Presentation, layout: LayoutManifest, slide: Slide) -> None:
        prs_slide = presentation.slides.add_slide(layout.slide_layout)
        for placeholder_id, value in self._bindings(slide).items():
            spec = layout.placeholder(placeholder_id)
            if spec is None:
                continue
            shape = resolve_shape(prs_slide, spec.shape_name)
            if shape is None:
                continue
            self._write_text(shape, value, preserve_master=True)

    def _bindings(self, slide: Slide) -> dict[str, str]:
        out: dict[str, str] = {"title": slide.title}
        if slide.subtitle:
            out["subtitle"] = slide.subtitle
        lines: list[str] = []
        for card in slide.cards:
            if card.heading:
                lines.append(card.heading)
            lines.extend(self._format_block(b) for b in card.body_blocks)
        out["body"] = "\n".join(lines)
        if slide.speaker_notes:
            out["notes"] = slide.speaker_notes
        return out

    @staticmethod
    def _write_text(shape, value: str, *, preserve_master: bool) -> None:
        frame = shape.text_frame
        # Preserve formatting master: tulis di run pertama agar font/warna desainer tetap
        if preserve_master and frame.paragraphs and frame.paragraphs[0].runs:
            frame.paragraphs[0].runs[0].text = value
            return
        frame.text = value

    @staticmethod
    def _format_block(block) -> str:
        if block.kind == "bullet":
            return f"• {block.content}"
        if block.kind == "checklist":
            return f"☐ {block.content}"
        return block.content
```

### 5b. Dynamic Canvas Layout — kalkulasi otomatis 3/4 kolom

```python
# app/engines/canvas_calculator/layout_engine.py
from __future__ import annotations

import math
from dataclasses import dataclass

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_AUTO_SHAPE_TYPE
from pptx.util import Emu, Inches, Pt

from app.engines.blueprint import Slide, Card


@dataclass(frozen=True)
class Box:
    x: Emu; y: Emu; w: Emu; h: Emu


class CanvasLayoutEngine:
    """Fallback: hitung X/Y/W/H programatis saat kartu melebihi kapasitas template."""

    def __init__(
        self,
        slide_width: Emu = Inches(13.333),
        slide_height: Emu = Inches(7.5),
        margin: Emu = Inches(0.5),
        gap: Emu = Inches(0.25),
        title_band: Emu = Inches(1.1),
    ) -> None:
        self._w, self._h = slide_width, slide_height
        self._margin, self._gap, self._title_band = margin, gap, title_band

    def render_slide(self, presentation: Presentation, slide: Slide) -> None:
        prs_slide = presentation.slides.add_slide(presentation.slide_layouts[6])
        self._paint_title(prs_slide, slide.title)

        columns = self._pick_columns(len(slide.cards))
        rows = math.ceil(len(slide.cards) / columns)
        for card, box in zip(slide.cards, self._grid(columns, rows)):
            self._render_card(prs_slide, card, box)

    @staticmethod
    def _pick_columns(card_count: int) -> int:
        # 1→1, 2→2, 3-4→2, 5-9→3, ≥10→4
        if card_count <= 1: return 1
        if card_count <= 4: return 2
        if card_count <= 9: return 3
        return 4

    def _grid(self, columns: int, rows: int) -> list[Box]:
        usable_w = self._w - 2 * self._margin - (columns - 1) * self._gap
        usable_h = self._h - self._margin - self._title_band - self._margin - (rows - 1) * self._gap
        cell_w, cell_h = usable_w // columns, usable_h // rows
        boxes: list[Box] = []
        for r in range(rows):
            for c in range(columns):
                x = self._margin + c * (cell_w + self._gap)
                y = self._margin + self._title_band + r * (cell_h + self._gap)
                boxes.append(Box(x, y, cell_w, cell_h))
        return boxes

    def _render_card(self, prs_slide, card: Card, box: Box) -> None:
        shape = prs_slide.shapes.add_shape(
            MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE, box.x, box.y, box.w, box.h
        )
        shape.fill.solid(); shape.fill.fore_color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        shape.line.color.rgb = RGBColor(0xBC, 0xCC, 0xDC)
        frame = shape.text_frame
        frame.word_wrap = True
        frame.margin_left = frame.margin_right = Inches(0.12)
        frame.margin_top = Inches(0.10)

        first = True
        if card.heading:
            p = frame.paragraphs[0] if first else frame.add_paragraph()
            first = False
            run = p.add_run()
            run.text, run.font.bold, run.font.size = card.heading, True, Pt(14)
            run.font.color.rgb = RGBColor(0x0B, 0x1F, 0x33)
        for block in card.body_blocks:
            p = frame.paragraphs[0] if first else frame.add_paragraph()
            first = False
            run = p.add_run()
            run.text = self._format_block(block)
            run.font.size, run.font.color.rgb = Pt(11), RGBColor(0x1F, 0x29, 0x33)
            p.space_after = Pt(4)

    def _paint_title(self, prs_slide, title: str) -> None:
        box = prs_slide.shapes.add_textbox(
            self._margin, self._margin, self._w - 2 * self._margin, self._title_band
        )
        run = box.text_frame.paragraphs[0].add_run()
        run.text, run.font.bold, run.font.size = title, True, Pt(24)
        run.font.color.rgb = RGBColor(0x0B, 0x1F, 0x33)

    @staticmethod
    def _format_block(block) -> str:
        if block.kind == "bullet":   return f"• {block.content}"
        if block.kind == "checklist": return f"☐ {block.content}"
        return block.content
```

### 5c. Dockerfile Prototype (Node + Chromium + Sidecar)

```dockerfile
FROM python:3.11-slim AS base

# System deps untuk Playwright Chromium
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg ca-certificates \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libdbus-1-3 libxkbcommon0 libatspi2.0-0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 \
    libcairo2 libasound2 && rm -rf /var/lib/apt/lists/*

# Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install sidecar deps + Chromium
COPY app/engines/marp/sidecar/package.json ./sidecar/
RUN cd sidecar && npm install --omit=dev && npx playwright install chromium

# Install Python deps
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY README.md ./README.md

EXPOSE 7860

CMD ["sh", "-lc", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-7860}"]
```

---

## 6. RISIKO & MITIGASI

| Risiko | Probability | Impact | Mitigasi |
|--------|------------|--------|----------|
| Sidecar crash → semua render gagal | Med | High | `SidecarManager` auto-restart + health check 30s + request retry 1x setelah restart |
| Chromium memory leak (long-running) | Med | Med | Restart sidecar setiap N=100 render atau 1 jam (configurable); graceful drain |
| Concurrency: 2 request bersamaan | Med | Med | `asyncio.Semaphore` di Python (max 4 paralel) + Playwright multi-page paralel di satu browser |
| Cold start HF Space | High | Med | Gateway ping keep-alive 4 menit (sudah ada di `IMPLEMENTATION_PLAN.md:66`) — sidecar tetap warm |
| Image besar ~700MB-1GB | Low | Low | Multi-stage build; terima trade-off karena parity + performance prioritas |
| `python-pptx` tidak thread-safe untuk `Presentation` cache | Med | High | Re-open master path per request (murah), bukan deepcopy |
| Shape name master tidak cocok manifest | Med | High | Validasi saat startup lifespan — fail fast dengan `ServiceMisconfiguredError` |
| Gateway hanya kenal `media_generation_spec.v1` | Low | Med | Field baru bersifat additive & opsional — tidak break kontrak HMAC yang ada |
| Test `test_pptx_generator_renders...` assert `slide_count==4` | High | Low | Update assertion sekali engine baru stabil; tetap uji title/section/activity ada |
| Windows dev tidak ada Unix socket | Med | Low | Pakai stdio (cross-platform) — bukan socket |
| Marp theme CSS drift dari master template | Med | Low | Parity struktural (bukan pixel-perfect) sesuai keputusan; theme CSS di-maintain terpisah |

---

## 7. URUTAN EKSEKUSI REKOMENDASI

1. **Fase 1** — Blueprint + manifest (foundation, no external deps)
2. **Fase 2** — Sidecar + Marp renderer + preview API + PDF refactor
3. **Fase 3** — Template injection + canvas fallback
4. **Fase 4** — Contract finalize + tests

Setiap fase punya gate test sebelum lanjut ke fase berikutnya.

---

## 8. YANG TIDAK BERUBAH

- Kontrak HMAC `media_generation_spec.v1` (additive field saja)
- `docx_generator.py` (nol regresi)
- `auth.py`, `settings.py`, `errors.py`, `content_sanitizer.py`
- Struktur folder `tests/` (hanya tambah file baru)
- Dependency `python-docx`, `python-pptx` di `requirements.txt`
- Endpoint `GET /health`, `GET /v1/health`, `POST /v1/generate`, `GET /v1/artifacts/download`
- Algoritma HMAC signature (shared secret, timestamp, sha256)
- Pola signed URL artifact download
