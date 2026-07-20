# Prompt Clarification Mode — Implementation Plan

> **Status:** Draft — Menunggu pengisian `Required Fields` oleh Product Owner
> **Created:** 2026-07-20
> **Target User:** Guru Indonesia (70%+ berusia 45 tahun ke atas)

---

## Problem Statement

Guru Indonesia kesulitan menulis prompt detail untuk LLM. Saat ini, prompt mereka masuk langsung ke pipeline generasi dengan minimal interpretasi — menghasilkan konten yang tidak optimal karena informasi yang kurang.

## Solution

Sistem akan **menganalisis prompt** setelah disubmit, **mendeteksi elemen yang kurang** berdasarkan standar konten, lalu **menampilkan pertanyaan klarifikasi** (max 5 pertanyaan) dalam bentuk conversational UI sebelum masuk ke pipeline generasi.

---

## Flow Overview

```
Teacher types prompt
    │
    ▼
POST /media-generations/preflight
    │
    ├── is_ready = true ──→ Skip clarification, generate langsung
    │
    └── is_ready = false ──→ Show ClarificationScreen
                                │
                                ├── Teacher answers max 5 questions
                                │
                                ├── "Generate dengan Prompt Ini" (enriched prompt)
                                │   atau
                                └── "Lewati" (tetap pakai enriched prompt, bukan original)
                                        │
                                        ▼
                                POST /media-generations/confirm
                                        │
                                        ▼
                                Generate & poll (existing flow)
```

---

## 1. REQUIRED FIELDS (Wajib Ditanya)

> **TODO:** Isi bagian ini. Tentukan field mana yang WAJIB ditanya ke guru.
> Minimal 2-3 field. Max 5 field (karena max pertanyaan = 5).

### 1.1 Daftar Semua Field yang Tersedia

| # | Field ID | Label (ID) | Label (EN) | Tipe Input | Bisa Di-infer? |
|---|---|---|---|---|---|
| 1 | `target_audience` | Jenjang/Kelas | Grade Level | Select | Ya (regex "kelas X") |
| 2 | `output_type` | Format File | File Format | Select | Ya (keyword detection) |
| 3 | `subject` | Mata Pelajaran | Subject | Select | Ya (taxonomy inference) |
| 4 | `page_count` | Jumlah Halaman | Page Count | Select | Tidak |
| 5 | `slide_count` | Jumlah Slide | Slide Count | Select | Tidak |
| 6 | `learning_objectives` | Tujuan Pembelajaran | Learning Objectives | Text | Tidak |
| 7 | `include_activities` | Sertakan Latihan? | Include Exercises? | Select | Tidak |
| 8 | `meeting_duration` | Durasi Pertemuan | Meeting Duration | Select | Tidak |
| 9 | `teaching_method` | Metode Pembelajaran | Teaching Method | MultiSelect | Tidak |
| 10 | `assessment_method` | Cara Penilaian | Assessment Method | MultiSelect | Tidak |
| 11 | `difficulty_level` | Tingkat Kesulitan | Difficulty Level | Select | Tidak |
| 12 | `question_count` | Jumlah Soal | Question Count | Number | Tidak |
| 13 | `visual_density` | Tampilan Slide | Slide Style | Select | Tidak |
| 14 | `speaker_notes` | Catatan Presenter | Speaker Notes | Select | Tidak |

### 1.2 Required Fields Definition

<!-- ╔══════════════════════════════════════════════════════════════╗
     ║  TODO: Isi tabel di bawah ini                               ║
     ║  Pilih 2-3 field yang WAJIB ditanya                         ║
     ║  Sisanya akan jadi "recommended" atau "auto-detect"         ║
     ╚══════════════════════════════════════════════════════════════╝ -->

| # | Field ID | Priority | Alasan Wajib |
|---|---|---|---|
| 1 | `target_audience` | 1 | Wajib, untuk menentukan jenjang dan kelas |
| 2 | `output_type` | 2 | Wajib, untuk menentukan format output |
| 3 | `subject` | 3 | Wajib, untuk menentukan mata pelajaran |
| 4 | `difficulty_level` | 4 | Wajib, untuk menentukan tingkat kesulitan |
| 5 | `page_count` | 5 | Wajib, untuk menentukan jumlah halaman |

### 1.3 Recommended Fields Definition

<!-- ╔══════════════════════════════════════════════════════════════╗
     ║  TODO: Isi tabel di bawah ini                               ║
     ║  Pilih 2-3 field yang DISARANKAN (ditanya jika ada slot)    ║
     ║  Max total pertanyaan = 5                                   ║
     ╚══════════════════════════════════════════════════════════════╝ -->

| # | Field ID | Priority | Alasan Disarankan |
|---|---|---|---|
| 1 | `learning_objectives` | 1 | Disarankan, untuk menentukan tujuan pembelajaran |
| 2 | `teaching_method` | 2 | Disarankan, untuk menentukan metode pembelajaran |
| 3 | `include_activities` | 3 | Disarankan, untuk menentukan apakah perlu ada latihan |
| 4 | `slide_count` | 4 | Disarankan, untuk menentukan jumlah slide yang akan dibuat |
| 5 | `question_count` | 5 | Disarankan, untuk menentukan jumlah soal |

### 1.4 Auto-Detect Fields (Tidak Ditanya)

Field-field ini akan di-infer otomatis oleh sistem:

| # | Field ID | Detection Method | Confidence Threshold |
|---|---|---|---|
| 1 | `subject` | Taxonomy keyword matching (`subjects.json`) | > 0.6 |
| 2 | `target_audience` | Regex pattern "kelas X" + jenjang detection | > 0.8 |
| 3 | `output_type` | Keyword signals (slide/ppt → pptx, handout/pdf → pdf) | > 0.7 |
| 4 | `topic` | Keyword extraction dari prompt | > 0.5 |

---

## 2. CONTENT STANDARDS PER TYPE

### 2.1 Materi Pembelajaran (Learning Material)

**Default output:** PDF atau DOCX

| Field | Priority | Notes |
|---|---|---|
| `target_audience` | Required | |
| `output_type` | Required | |
| `learning_objectives` | Recommended | |
| `page_count` | Recommended | |
| `include_activities` | Recommended | |

**Suggestion Chips untuk `page_count`:**
- Singkat (2-3 halaman)
- Sedang (5-7 halaman)
- Lengkap (10+ halaman)

### 2.2 Slide Presentasi (Presentation)

**Default output:** PPTX

| Field | Priority | Notes |
|---|---|---|
| `target_audience` | Required | |
| `slide_count` | Recommended | |
| `visual_density` | Recommended | |
| `speaker_notes` | Optional | |

**Suggestion Chips untuk `slide_count`:**
- Singkat (8-10 slide)
- Sedang (15-20 slide)
- Lengkap (25+ slide)

### 2.3 RPP (Lesson Plan)

**Default output:** PDF atau DOCX

| Field | Priority | Notes |
|---|---|---|
| `target_audience` | Required | |
| `meeting_duration` | Recommended | |
| `learning_objectives` | Required | |
| `teaching_method` | Recommended | |
| `assessment_method` | Recommended | |

**Suggestion Chips untuk `meeting_duration`:**
- 35 Menit
- 40 Menit
- 45 Menit
- 2 x 45 Menit (1 JP)

### 2.4 Lembar Kerja (Worksheet)

**Default output:** PDF atau DOCX

| Field | Priority | Notes |
|---|---|---|
| `target_audience` | Required | |
| `page_count` | Recommended | |
| `difficulty_level` | Required | |
| `question_count` | Recommended | |

### 2.5 Silabus (Syllabus)

**Default output:** PDF atau DOCX

| Field | Priority | Notes |
|---|---|---|
| `target_audience` | Required | |
| `semester` | Optional | |
| `learning_objectives` | Recommended | |

### 2.6 Penilaian/Soal (Assessment)

**Default output:** PDF atau DOCX

| Field | Priority | Notes |
|---|---|---|
| `target_audience` | Required | |
| `question_count` | Required | |
| `difficulty_level` | Required | |
| `question_type` | Recommended | |

---

## 3. API CONTRACTS

### 3.1 POST /api/v1/media-generations/preflight

**Purpose:** Analyze prompt, return clarification questions

**Request Body:**
```json
{
    "raw_prompt": "string (required)",
    "preferred_output_type": "string (optional, default: auto)",
    "subject_id": "int64 (optional)",
    "sub_subject_id": "int64 (optional)"
}
```

**Response (200 OK):**
```json
{
    "data": {
        "generation_id": "uuid",
        "detected": {
            "output_type": "string | null",
            "subject": "string | null",
            "subject_id": "int64 | null",
            "audience": "string | null",
            "topic": "string | null",
            "content_type": "string",
            "confidence": "float 0.0-1.0"
        },
        "gaps": [
            {
                "field_id": "string",
                "question": "string",
                "priority": "required | recommended",
                "input_type": "select | multi_select | text_input | number_input",
                "suggestions": [
                    { "value": "string", "label": "string" }
                ],
                "detected_value": "string | null"
            }
        ],
        "suggested_prompt": "string",
        "is_ready": "boolean",
        "total_required_gaps": "int",
        "total_recommended_gaps": "int"
    }
}
```

**Response (200 OK) — Prompt sudah lengkap:**
```json
{
    "data": {
        "generation_id": "uuid",
        "detected": {
            "output_type": "pdf",
            "subject": "Matematika",
            "subject_id": 5,
            "audience": "SD Kelas 5",
            "topic": "Pecahan",
            "content_type": "materi_pembelajaran",
            "confidence": 0.92
        },
        "gaps": [],
        "suggested_prompt": "Buatkan materi pecahan untuk SD Kelas 5, format PDF",
        "is_ready": true,
        "total_required_gaps": 0,
        "total_recommended_gaps": 0
    }
}
```

### 3.2 POST /api/v1/media-generations/confirm

**Purpose:** Submit enriched prompt untuk generation

**Request Body:**
```json
{
    "generation_id": "uuid (required)",
    "enriched_prompt": "string (required)",
    "answers": {
        "field_id": "value"
    },
    "subject_id": "int64 (optional)",
    "sub_subject_id": "int64 (optional)"
}
```

**Response (202 Accepted):**
```json
{
    "message": "Generasi media berhasil dibuat dan sedang diproses.",
    "data": {
        "generation_id": "uuid",
        "job_id": "uuid",
        "status": "pending",
        "poll_url": "/api/v1/media-generations/{id}/job-status"
    }
}
```

### 3.3 POST /api/v1/media-generations/{id}/skip-clarification

**Purpose:** Skip semua pertanyaan, generate dengan enriched prompt

**Request Body:** (empty)

**Response (202 Accepted):** Same as confirm

---

## 4. DATABASE CHANGES

### Migration: `20260720000001_add_clarification_fields.sql`

```sql
ALTER TABLE media_generations
ADD COLUMN IF NOT EXISTS clarification_state JSONB,
ADD COLUMN IF NOT EXISTS clarified_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS clarification_skipped BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_media_generations_clarification
ON media_generations (clarified_at)
WHERE clarified_at IS NOT NULL;
```

---

## 5. FRONTEND ARCHITECTURE

### 5.1 New Files

```
frontend/lib/features/media_generation/
├── screens/
│   └── clarification_screen.dart          # Main clarification screen
├── widgets/
│   ├── clarification_question_card.dart   # Individual question card
│   ├── clarification_suggestion_chip.dart # Chip for suggestions
│   ├── clarification_chat_bubble.dart     # Chat bubble component
│   ├── clarification_summary_card.dart    # Auto-enriched prompt card
│   └── clarification_progress_indicator.dart
├── models/
│   ├── clarification_response.dart        # API response model
│   ├── clarification_gap.dart             # Gap model
│   └── chat_message.dart                  # Chat message model
├── data/
│   └── clarification_service.dart         # API calls
└── providers/
    └── clarification_provider.dart        # State management
```

### 5.2 Modified Files

| File | Change |
|---|---|
| `home_screen.dart` | `_submitPrompt()` → call preflight → navigate to ClarificationScreen |
| `media_generation_service.dart` | Add `preflight()`, `confirmGeneration()`, `skipClarification()` methods |
| `app_id.arb` | Add clarification-related strings |
| `app_en.arb` | Add clarification-related strings |

### 5.3 UI Constants (Existing Patterns)

| Pattern | Value | Source |
|---|---|---|
| Card borderRadius | 24 | `theme.dart` |
| Input borderRadius | 20 | `theme.dart` |
| Button borderRadius | 16-18 | `theme.dart` |
| Bottom sheet top radius | 24 | `regenerate_bottom_sheet.dart` |
| Primary green | `#529F60` | `app_colors.dart` |
| Card shadow | blur 24, offset (0, 12) | `media_generation_status_card.dart` |
| Animation duration | 200-220ms | Various |
| Title font | Mona Sans, w800 | `media_generation_status_card.dart` |
| Body font | Inter, w600 | `theme.dart` |
| Submit button | primary bg, white text, borderRadius 16, elevation 4 | `regenerate_bottom_sheet.dart` |

### 5.4 ClarificationScreen Layout

```
┌─────────────────────────────────────────────┐
│  ← Kembali        Clarifikasi Prompt        │  AppBar
│                                [Lewati →]   │  (skip button)
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ 💬 Buatkan materi pecahan           │   │  User bubble (right)
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ 🤖 Saya mengerti Anda ingin...     │   │  System bubble (left)
│  │ Saya perlu beberapa info lagi.      │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ── Pertanyaan 1 dari 3 ──────────────── │  Progress dots
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ 📚 Untuk jenjang/kelas berapa?      │   │  QuestionCard
│  │                                     │   │
│  │  [SD Kelas 3]  [SD Kelas 4]        │   │  SuggestionChips
│  │  [SD Kelas 5]  [SMP Kelas 7]       │   │  (auto-advance on select)
│  │  [SMP Kelas 8] [SMA Kelas 10]      │   │
│  │                                     │   │
│  │  ┌─────────────────────────────┐   │   │
│  │  │ Atau ketik sendiri...       │   │   │  Custom input
│  │  └─────────────────────────────┘   │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  (pertanyaan berikutnya slide in dari kanan)│
│                                             │
│  ═══════════════════════════════════════  │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ 💡 Prompt yang disempurnakan:       │   │  SummaryCard
│  │ "Buatkan materi pecahan untuk       │   │  (always visible)
│  │  SD Kelas 5, format PDF, 5-7 hal"   │   │
│  │                                     │   │
│  │ [✨ Generate dengan Prompt Ini]     │   │  Primary CTA
│  │ [✏️ Edit Prompt Ini]               │   │  Secondary
│  └─────────────────────────────────────┘   │
│                                             │
├─────────────────────────────────────────────┤
│  [Ketik jawaban...]              [→ Kirim] │  Chat input (fallback)
└─────────────────────────────────────────────┘
```

---

## 6. NAVIGATION FLOW

```
HomeScreen._submitPrompt(text)
    │
    ▼
ClarificationService.preflight(text)
    │
    ├── is_ready = true
    │     └── MediaGenerationService.submitPrompt(enriched)
    │           └── Status card shows (existing flow)
    │
    └── is_ready = false
          └── Navigator.push(ClarificationScreen)
                │
                ├── Teacher answers questions (max 5)
                │     └── ClarificationNotifier.answerQuestion()
                │           └── Auto-advance to next question
                │
                ├── "Generate dengan Prompt Ini"
                │     └── ClarificationService.confirmGeneration(enriched)
                │           └── Pop to home, status card shows
                │
                └── "Lewati"
                      └── ClarificationService.confirmGeneration(enriched)
                            └── Pop to home, status card shows
```

---

## 7. STATE MANAGEMENT

### ClarificationState

```dart
class ClarificationState {
  final String? generationId;
  final ClarificationResponse? response;
  final Map<String, String> answers;       // field_id -> value
  final List<ChatMessage> messages;        // Chat history
  final int currentQuestionIndex;
  final bool isSubmitting;
  final bool isGenerating;
  final String? error;

  // Computed
  bool get isReady;
  int get totalRequiredGaps;
  int get answeredRequiredCount;
  String get suggestedPrompt;
  bool get allRequiredAnswered;
}
```

### ClarificationNotifier Methods

| Method | Description |
|---|---|
| `initialize(response)` | Set initial state dengan preflight response |
| `answerQuestion(fieldId, value)` | Record jawaban, advance to next question |
| `skipQuestion()` | Skip current question, advance |
| `useSuggestedPrompt()` | Generate dengan auto-enriched prompt |
| `confirmGeneration()` | Generate dengan enriched prompt dari answers |
| `skipAll()` | Skip semua, generate dengan enriched prompt |
| `editSuggestedPrompt()` | Allow manual edit of suggested prompt |

---

## 8. LOCALIZATION

### Indonesian (app_id.arb) — Keys to Add

```json
{
    "clarificationTitle": "Clarifikasi Prompt",
    "clarificationSkip": "Lewati",
    "clarificationQuestionProgress": "Pertanyaan {current} dari {total}",
    "clarificationSystemIntro": "Saya mengerti Anda ingin membuat konten tentang {topic}. Saya perlu beberapa info lagi agar hasilnya lebih baik.",
    "clarificationSystemIntroGeneric": "Saya perlu beberapa informasi tambahan agar konten yang dihasilkan lebih sesuai.",
    "clarificationChipOrType": "Atau ketik sendiri...",
    "clarificationSummaryTitle": "Prompt yang disempurnakan:",
    "clarificationSummaryProgress": "{count} dari {total} pertanyaan terjawab",
    "clarificationUsePrompt": "Generate dengan Prompt Ini",
    "clarificationEditPrompt": "Edit Prompt Ini",
    "clarificationInputHint": "Ketik jawaban...",
    "clarificationSend": "Kirim",
    "clarificationRequiredBadge": "Wajib",
    "clarificationRecommendedBadge": "Disarankan",
    "clarificationAllAnswered": "Semua pertanyaan sudah terjawab!",
    "clarificationAutoAdvance": "Pertanyaan berikutnya...",
    "clarificationEmptyGaps": "Prompt Anda sudah lengkap! Siap untuk digenerate."
}
```

### English (app_en.arb) — Keys to Add

```json
{
    "clarificationTitle": "Clarify Prompt",
    "clarificationSkip": "Skip",
    "clarificationQuestionProgress": "Question {current} of {total}",
    "clarificationSystemIntro": "I understand you want to create content about {topic}. I need a few more details to give you better results.",
    "clarificationSystemIntroGeneric": "I need some additional information to make the content more relevant.",
    "clarificationChipOrType": "Or type your own...",
    "clarificationSummaryTitle": "Enhanced prompt:",
    "clarificationSummaryProgress": "{count} of {total} questions answered",
    "clarificationUsePrompt": "Generate with This Prompt",
    "clarificationEditPrompt": "Edit This Prompt",
    "clarificationInputHint": "Type your answer...",
    "clarificationSend": "Send",
    "clarificationRequiredBadge": "Required",
    "clarificationRecommendedBadge": "Recommended",
    "clarificationAllAnswered": "All questions answered!",
    "clarificationAutoAdvance": "Next question...",
    "clarificationEmptyGaps": "Your prompt is complete! Ready to generate."
}
```

---

## 9. IMPLEMENTATION PHASES

### Phase 1: Backend Foundation (3-4 hari)

- [x] Buat `gateway/src/standards/mod.rs` + `content_standards.rs`
- [x] Buat `gateway/src/llm/clarification.rs` — ClarificationService
- [x] Buat API handler `POST /preflight`
- [x] Buat API handler `POST /confirm`
- [x] Buat API handler `POST /{id}/skip-clarification`
- [x] Unit tests

### Phase 2: Database & API Integration (1-2 hari)

- [x] Migration: add clarification fields
- [x] Repository updates
- [x] Wire preflight into create handler (optional path)
- [x] Integration tests

### Phase 3: Frontend Models & Service (2-3 hari)

- [x] Models: ClarificationResponse, ClarificationGap, ChatMessage
- [x] Service: `clarification_service.dart`
- [x] Provider: `clarification_provider.dart`
- [x] Update MediaGenerationService with new methods

### Phase 4: Frontend UI (3-4 hari)

- [x] ClarificationSuggestionChip
- [x] ClarificationChatBubble
- [x] ClarificationQuestionCard
- [x] ClarificationSummaryCard
- [x] ClarificationProgressIndicator
- [x] ClarificationScreen (main)
- [x] Modify HomeScreen._submitPrompt()
- [x] Navigation integration

### Phase 5: Polish & QA (1-2 hari)

- [x] Animations (staggered, slide-in)
- [x] Error handling & edge cases
- [x] Localization (ARB files)
- [x] Loading states & skeletons
- [x] Offline support
- [x] Manual QA & bug fixes

---

## 10. DESIGN DECISIONS

| Decision | Choice | Reasoning |
|---|---|---|
| Detection location | Backend (Rust) | Consistent, reuse governance/cache, thin Flutter |
| Detection approach | Rules first, LLM fallback | Fast (0ms), cheap (0 cost), LLM only for edge cases |
| UI pattern | Chat-like cards | Familiar for non-tech users, natural flow |
| Auto-advance | Yes, after selection | Faster, less friction |
| Skip behavior | Enriched prompt (not original) | Better quality output even when skipping |
| Summary card | Always visible | User can see progress and generate anytime |
| Max questions | 5 | Not overwhelming, covers required fields |
| State persistence | In-memory (Riverpod) | Short session, no persistence needed |
| Backward compatibility | Separate endpoints | Existing flow unchanged |

---

## 11. RISK MITIGATION

| Risk | Mitigation |
|---|---|
| LLM cost increase | Rules-first, cache results, LLM only if confidence < 0.5 |
| Latency increase | Rules-based = instant, show loading indicator |
| Teacher skips all | Enriched prompt still used (not original) |
| Over-questioning | Max 5 questions, required only, clear skip |
| Backward compatibility | Separate endpoints, existing flow unchanged |
| Small screen real estate | Scrollable, collapsible, adaptive layout |

---

## Appendix A: Suggestion Chips Reference

### Grade Levels
| Value | Label (ID) | Label (EN) |
|---|---|---|
| `SD_Kelas_1` | SD Kelas 1 | Grade 1 Elementary |
| `SD_Kelas_2` | SD Kelas 2 | Grade 2 Elementary |
| `SD_Kelas_3` | SD Kelas 3 | Grade 3 Elementary |
| `SD_Kelas_4` | SD Kelas 4 | Grade 4 Elementary |
| `SD_Kelas_5` | SD Kelas 5 | Grade 5 Elementary |
| `SD_Kelas_6` | SD Kelas 6 | Grade 6 Elementary |
| `SMP_Kelas_7` | SMP Kelas 7 | Grade 7 Junior High |
| `SMP_Kelas_8` | SMP Kelas 8 | Grade 8 Junior High |
| `SMP_Kelas_9` | SMP Kelas 9 | Grade 9 Junior High |
| `SMA_Kelas_10` | SMA Kelas 10 | Grade 10 Senior High |
| `SMA_Kelas_11` | SMA Kelas 11 | Grade 11 Senior High |
| `SMA_Kelas_12` | SMA Kelas 12 | Grade 12 Senior High |

### Output Types
| Value | Label (ID) | Label (EN) |
|---|---|---|
| `pdf` | PDF (Untuk Dicetak) | PDF (For Printing) |
| `docx` | Word (Bisa Diedit) | Word (Editable) |
| `pptx` | PowerPoint (Presentasi) | PowerPoint (Presentation) |

### Page Counts
| Value | Label (ID) | Label (EN) |
|---|---|---|
| `short` | Singkat (2-3 halaman) | Short (2-3 pages) |
| `medium` | Sedang (5-7 halaman) | Medium (5-7 pages) |
| `long` | Lengkap (10+ halaman) | Comprehensive (10+ pages) |

### Slide Counts
| Value | Label (ID) | Label (EN) |
|---|---|---|
| `short` | Singkat (8-10 slide) | Short (8-10 slides) |
| `medium` | Sedang (15-20 slide) | Medium (15-20 slides) |
| `long` | Lengkap (25+ slide) | Comprehensive (25+ slides) |

### Meeting Durations
| Value | Label (ID) | Label (EN) |
|---|---|---|
| `35` | 35 Menit | 35 Minutes |
| `40` | 40 Menit | 40 Minutes |
| `45` | 45 Menit | 45 Minutes |
| `2x45` | 2 x 45 Menit (1 JP) | 2 x 45 Minutes (1 Session) |

### Visual Density
| Value | Label (ID) | Label (EN) |
|---|---|---|
| `visual` | Banyak Gambar/Visual | Image-heavy/Visual |
| `balanced` | Seimbang Teks & Visual | Balanced Text & Visual |
| `text_focused` | Fokus Teks | Text-focused |

### Teaching Methods
| Value | Label (ID) | Label (EN) |
|---|---|---|
| `ceramah` | Ceramah | Lecture |
| `diskusi` | Diskusi | Discussion |
| `praktik` | Praktik | Practice |
| `inquiry` | Inkuiri | Inquiry |
| `problem_based` | Problem Based Learning | Problem Based Learning |
| `project_based` | Project Based Learning | Project Based Learning |

### Assessment Methods
| Value | Label (ID) | Label (EN) |
|---|---|---|
| `written_test` | Tes Tertulis | Written Test |
| `oral` | Tes Lisan | Oral Test |
| `practical` | Penilaian Praktik | Practical Assessment |
| `portfolio` | Portofolio | Portfolio |
| `observation` | Observasi | Observation |
