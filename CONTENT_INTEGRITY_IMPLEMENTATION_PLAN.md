# LLM Content Integrity Strategy: Implementation Plan

**Status**: DRAFT  
**Created**: April 17, 2026  
**Target Curriculum**: Kurikulum Merdeka (Indonesian Ministry of Education)  
**Scope**: All media formats (DOCX, PDF, PPTX)  
**Approach**: Defense-in-depth (LLM prompt engineering + Backend validation + Python sanitization)

> **Goal**: Ensure LLM-generated educational materials via Python file generation service result in 'ready-to-teach' pedagogical content, free of procedural meta-instructions, conversational filler, and teacher implementation guidance.

---

## Overview: Three-Layer Defense Strategy

```
┌─────────────────────────────────────────────────────────────────────────┐
│ LAYER 1: LLM Prompt Engineering + Adapter Guardrails (llm-adapter-service) │
│  ├─ System prompts: Kurikulum Merdeka curriculum specialist persona       │
│  ├─ Negative constraints: Prevent procedural, conversational, scaffolding  │
│  └─ Python classifier: Assign content integrity scores (0-1)              │
├─────────────────────────────────────────────────────────────────────────┤
│ LAYER 2: Backend Content Integrity Validation (Backend Services)          │
│  ├─ Extended MediaGeneratedContentGuard: Pattern detection                │
│  ├─ New MediaGenerationSpecContract field: content_integrity metadata     │
│  ├─ PedagogicalContentClassifier: Kurikulum Merdeka alignment scoring      │
│  └─ Config-driven acceptance thresholds & rejection strategies            │
├─────────────────────────────────────────────────────────────────────────┤
│ LAYER 3: Python Media-Generator Sanitization (media-generator-service)   │
│  ├─ Post-processing before rendering: Strip remaining meta-instructions   │
│  ├─ Format-specific rules: DOCX/PDF vs. PPTX speaker notes                │
│  └─ Warnings metadata: Log sanitization actions in artifact               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: LLM Prompt Engineering & Adapter-Side Guardrails

**Status**: ⬜ Not Started  
**Dependencies**: None (standalone) - can start immediately

### 1.1 Define Kurikulum Merdeka System Prompts

- [x] Research Kurikulum Merdeka curriculum structure (learning outcomes, pedagogy standards)
- [x] Create role-definition prompt: "You are an expert curriculum specialist aligned with Kurikulum Merdeka..."
- [x] Document expected content structure per subject/level (definitions → examples → practice → assessment)
- [x] Define tone guidelines: Academic, pedagogical, student-facing (NOT procedural/implementation guides)
- [x] Store final prompts in [backend/config/llm_prompts.php](backend/config/llm_prompts.php) or [llm-adapter-service/app/config.py](llm-adapter-service/app/config.py)

### 1.2 Create Negative Constraint Prompts

**Category A: Procedural Meta-Instructions**
- [x] Define patterns to prevent:
  - "Follow these steps to..."
  - "Implement this workflow..."
  - "Set up the lesson by..."
  - "Prepare students to..."
  - "Ensure the teacher has..."
- [x] Create rejection prompt: "NEVER provide step-by-step teacher implementation instructions..."
- [x] Add examples of what NOT to generate in system prompt

**Category B: Conversational Filler**
- [x] Define patterns to prevent:
  - "Here is your material..."
  - "I have generated..."
  - "I've created the structure..."
  - "As an AI assistant..."
  - "According to my analysis..."
- [x] Create rejection prompt: "Do not use conversational filler or meta-commentary..."
- [x] Enforce: Content begins directly with pedagogical material (no introduction wrapper)

**Category C: Structural Scaffolding Prose**
- [x] Define patterns to prevent:
  - "This section is designed to..."
  - "In this lesson you will..."
  - "Focus on the following outcomes..."
  - "Be sure to emphasize..."
  - "The purpose of this activity is..."
- [x] Create rejection prompt: "Omit authoring guidance disguised as scaffolding..."
- [x] Note: Legitimate learning objectives are OK; meta-guidance about the lesson structure is not

### 1.3 Extend LLM Adapter Interpretation Repair Logic

**Files**: [llm-adapter-service/app/interpretation.py](llm-adapter-service/app/interpretation.py#L460)

- [x] Add `detect_role_play_breaks()` function:
  - Scan output for LLM identity statements: "As Claude...", "As an AI...", "I'm ChatGPT..."
  - Flag and remove before validation
  - Log detection for monitoring
  
- [x] Extend `_repair_interpretation_payload()`:
  - Check for wrapped text like "Here is your material: {JSON}"
  - Extract clean JSON payload
  - Validate no meta-instructions exist in extracted payload

- [x] Update `decode_and_validate_interpretation_completion()`:
  - Call detection/repair functions BEFORE Pydantic validation
  - Record repair actions in metadata for backend audit trail

### 1.4 Create Python ContentIntegrityClassifier

**Files**: Create [llm-adapter-service/app/content_integrity_classifier.py](llm-adapter-service/app/content_integrity_classifier.py)

- [x] Implement `ContentIntegrityClassifier` class:
  - Method: `classify_payload(payload: dict, output_type: str) -> dict`
  - Scans all text fields for meta-instruction patterns (reuse/import backend guard patterns)
  - Returns:
    ```python
    {
        "integrity_score": 0.0-1.0,  # Confidence that content is pedagogical, not meta-talk
        "violations": [...],          # List of detected meta-instruction patterns
        "classification_source": "adapter",
        "metadata": {...}
    }
    ```

- [x] Integrate classifier into interpretation flow:
  - Call after repair, before returning to backend
  - Append `content_integrity` object to response payload
  - Threshold scoring: Low violations + no role-play breaks = high score (0.85-1.0)

- [x] Add unit tests in [llm-adapter-service/tests/test_content_integrity_classifier.py](llm-adapter-service/tests/test_content_integrity_classifier.py):
  - [x] Test score assignment for clean pedagogical content (expect 0.95+)
  - [x] Test score reduction for each category of violation
  - [x] Test detection of multiple violations in single payload

---

## Phase 2: Backend Content Integrity Contract & Validation

**Status**: ⬜ Not Started  
**Dependencies**: Phase 1 (classifier produces scores that backend consumes)

### 2.1 Extend MediaGenerationSpecContract

**Files**: [backend/app/MediaGeneration/MediaGenerationSpecContract.php](backend/app/MediaGeneration/MediaGenerationSpecContract.php)

- [x] Add new field to contract:
  ```php
  public ContentIntegrity $content_integrity;

  class ContentIntegrity {
      public float $integrity_score;           // 0.0-1.0 from classifier
      public array $violations = [];           // Patterns detected
      public string $classification_source;    // 'adapter' | 'fallback'
      public ?array $metadata = null;          // Additional metadata
  }
  ```

- [x] Update `fromDraft()` method:
  - Extract `content_integrity` from draft payload
  - Validate `integrity_score >= threshold` (configurable, default 0.75)
  - Reject spec if threshold not met and `rejection_strategy = 'strict'`
  - Log violations in decision_payload for audit trail

- [x] Update `fromInterpretation()` fallback:
  - Generate synthetic `content_integrity` metadata
  - Set `classification_source = 'fallback'` explicitly
  - Always assume fallback content passes integrity (deterministic generation)

### 2.2 Expand MediaGeneratedContentGuard Pattern Registry

**Files**: [backend/app/MediaGeneration/MediaGeneratedContentGuard.php](backend/app/MediaGeneration/MediaGeneratedContentGuard.php)

**Add Pattern Category A: Procedural Meta-Instructions**
- [x] Pattern regex: `procedural_instruction`
  - Matches: "follow these steps|implement this|set up|ensure (teachers?|students?|that|you) have|prepare (the|students|a)"
  - Context: Reject from section content, assessment instructions, teacher_delivery_summary

**Add Pattern Category B: Conversational Filler**
- [x] Pattern regex: `conversational_filler`
  - Matches: "here is your|i have (generated|created|prepared)|i've|as (an ai|a language model|claude|chatgpt)|according to my analysis"
  - Context: Reject from all text fields

**Add Pattern Category C: Structural Scaffolding Prose**
- [x] Pattern regex: `structural_scaffolding`
  - Matches: "this (section|lesson|activity) (is designed to|aims to|will|focuses on)|focus on the following|be sure to|the purpose of this"
  - Context: Reject from section.purpose, body_blocks introductory text

- [x] Update `assertTextSafe()` method:
  - Call all three pattern categories for each text field
  - Collect violations instead of single failure (support multiple violations per field)
  - Return structured violation array with pattern_name, matched_text, field_path, suggestion

### 2.3 Add Field-Specific Content Guards

**Files**: [backend/app/MediaGeneration/MediaGeneratedContentGuard.php](backend/app/MediaGeneration/MediaGeneratedContentGuard.php)

- [x] `assertTeacherDeliverySummary()`:
  - Check all three meta-categories above
  - Must be written in student perspective (no "teacher should...", "you should teach...")
  - Max 200 chars (concise, not implementation guide)

- [x] `assertSectionPurpose()`:
  - Stricter than section content: reject structural_scaffolding patterns entirely
  - Allow legitimate learning outcome language: "Students will understand...", "Learners can apply..."
  - Disallow: "Teacher emphasis should be...", "This section helps the teacher..."

- [x] `assertAssessmentInstructions()`:
  - Ensure steps are student-facing activities, not teacher execution checklist
  - Example GOOD: "Solve the following problems. Show all work. Check answers with a partner."
  - Example BAD: "1. Display problem on board. 2. Give students 10 minutes. 3. Circulate and check understanding."

### 2.4 Update MediaContentDraftingService Fallback

**Files**: [backend/app/Services/MediaContentDraftingService.php](backend/app/Services/MediaContentDraftingService.php)

- [x] Modify fallback learning objectives generation:
  - Generate synthetic objectives only if interpretation provided content signals
  - Run  generated objectives through `MediaGeneratedContentGuard::assertLearningObjective()` before returning
  - Ensure format: "Students can..." / "Learners will understand..." (not "Teacher will ensure...")

- [x] Add fallback draft validation:
  - All fallback-generated text passes integrity check before being included in spec
  - Record `content_integrity.classification_source = 'fallback'` explicitly

### 2.5 Create PedagogicalContentClassifier

**Files**: Create [backend/app/MediaGeneration/PedagogicalContentClassifier.php](backend/app/MediaGeneration/PedagogicalContentClassifier.php)

- [x] Implement classifier against Kurikulum Merdeka framework:
  ```php
  public function classify(GenerationSpec $spec): array {
      return [
          'content_types' => [...],          // 'definition', 'worked_example', 'exercise', etc.
          'pedagogical_alignment_score' => 0.0-1.0,
          'tone_classification' => 'academic|conversational|procedural',
          'expected_structure_match' => 0.0-1.0,
      ];
  }
  ```

- [x] Content type detection:
  - Scan sections for presence of definitions, worked examples, practice problems, assessment
  - Return array: `['definition' => true, 'worked_example' => true, ...]`

- [x] Tone classification:
  - Analyze vocabulary, sentence structure, perspective
  - Return: 'academic' (formal, objective) | 'conversational' (explanatory, friendly) | 'procedural' (step-based, instructional)
  - Ideal for Kurikulum Merdeka content: 'academic' | 'conversational' (both OK)
  - Flag: 'procedural' indicates teacher-facing material

- [x] Alignment with expected structure:
  - Load reference structure from [backend/resources/json/kurikulum_merdeka_structure.json](backend/resources/json/kurikulum_merdeka_structure.json)
  - Compare spec sections against expected pattern for subject/level
  - Calculate structural match score (0.0-1.0)

### 2.6 Create Content Integrity Configuration

**Files**: Create [backend/config/content_integrity.php](backend/config/content_integrity.php)

```php
return [
    'enabled' => env('CONTENT_INTEGRITY_ENABLED', true),
    
    'classifier_confidence_threshold' => env('CONTENT_INTEGRITY_THRESHOLD', 0.75),
    
    'rejection_strategy' => env('CONTENT_INTEGRITY_REJECTION_STRATEGY', 'warn'),
    // 'strict'  => Reject specs with integrity_score < threshold (generation fails)
    // 'warn'    => Log warnings but allow spec generation (manual review flag)
    // 'log'     => Monitor violations passively (analytics only)
    
    'meta_patterns' => [
        'procedural_instruction' => [
            // Pattern registry reused from guard
        ],
        'conversational_filler' => [...],
        'structural_scaffolding' => [...],
    ],
    
    'kurikulum_merdeka_reference' => resource_path('json/kurikulum_merdeka_structure.json'),
];
```

- [x] Create configuration file
- [x] Load and validate in AppServiceProvider
- [x] Add env vars to .env.example

### 2.7 Create Kurikulum Merdeka Reference Structure

**Files**: Create [backend/resources/json/kurikulum_merdeka_structure.json](backend/resources/json/kurikulum_merdeka_structure.json)

```json
{
  "smp": {
    "mathematics": {
      "algebra": {
        "expected_sections": ["introduction", "concepts", "worked_examples", "practice", "assessment"],
        "tone": "academic",
        "prohibited_phrases": ["follow these steps to teach", "prepare students by..."]
      }
    }
  },
  "sma": {...},
  "smk": {...}
}
```

- [x] Document expected section patterns per subject/level
- [x] List prohibited teacher-instruction phrases (reference for guard patterns)
- [x] Add tone guidelines per content type

---

## Phase 3: Python Media-Generator Content Sanitization

**Status**: ⬜ Not Started  
**Dependencies**: Phase 2 (receives specs with integrity metadata; uses same pattern dictionary)

### 3.1 Create ContentSanitizer Module

**Files**: Create [media-generator-service/app/content_sanitizer.py](media-generator-service/app/content_sanitizer.py)

- [x] Implement `PedagogicalContentSanitizer` class:
  ```python
  class PedagogicalContentSanitizer:
      def __init__(self, pattern_config: dict):
          self.patterns = pattern_config
      
      def sanitize_render_document(self, doc: RenderDocument) -> RenderDocument:
          # Sanitize all content fields
          # Return cleaned document + sanitization log
      
      def sanitize_body_blocks(self, blocks: list[RenderBlock]) -> tuple[list[RenderBlock], list[str]]:
          # Remove procedural meta-instructions from content
          # Return cleaned blocks + log of removals
      
      def sanitize_teacher_delivery_summary(self, summary: str) -> tuple[str, list[str]]:
          # Strip implementation guidance
      
      def sanitize_assessment_instructions(self, instructions: str) -> tuple[str, list[str]]:
          # Ensure student-facing tone
  ```

- [x] Methods for each content type:
  - `_strip_procedural_markers()` — Remove "Follow these steps...", etc.
  - `_strip_conversational_wrappers()` — Remove "Here's your...", etc.
  - `_strip_scaffolding_prose()` — Remove "This section is designed..."
  - `_restore_mathematical_formatting()` — Preserve LaTeX/notation removed during stripping

- [x] Logging and warnings:
  - Track sanitization actions in dict: `{field: [removals], ...}`
  - Return tuple: `(cleaned_document, sanitization_log)`

### 3.2 Import/Share Pattern Dictionary

- [x] Option A (recommended): Export backend pattern registry as JSON in backend/resources/json
  - [x] Backend: Create [backend/resources/json/meta_instruction_patterns.json](backend/resources/json/meta_instruction_patterns.json)
  - [x] Media-generator: Load patterns from backend API endpoint or shared volume (during deployment)
  - [x] Benefit: Single source of truth; changes propagate to both services

- [ ] Option B (isolation): Duplicate pattern definitions in media-generator-service
  - [ ] Create [media-generator-service/app/patterns.py](media-generator-service/app/patterns.py)
  - [ ] Risk: Pattern drift between services over time

**Decision**: Implement Option A; fallback to Option B if deployment constraints prevent shared resources

### 3.3 Integrate Sanitizer into Document Rendering

**Files**: [media-generator-service/app/document_model.py](media-generator-service/app/document_model.py)

- [x] Update `build_render_document()` function:
  ```python
  def build_render_document(spec: GenerationSpec) -> RenderDocument:
      # ... existing mapping code ...
      render_doc = RenderDocument(...)
      
      # NEW: Apply sanitization
      sanitizer = PedagogicalContentSanitizer(pattern_config)
      render_doc, sanitization_log = sanitizer.sanitize_render_document(render_doc)
      
      # Log warnings to metadata
      if sanitization_log:
          append_to_metadata_warnings(sanitization_log)
      
      return render_doc
  ```

- [x] Append warnings to artifact metadata:
  - `artifact_metadata.warnings.append(f"Content sanitization applied: {sanitization_log}")`
  - Include in final artifact so backend can audit what was sanitized

### 3.4 Format-Specific Sanitization Rules

- [x] **DOCX/PDF Handouts**:
  - [x] Strip all meta-instructions from body_blocks
  - [x] Ensure body_blocks contain only student-facing pedagogical content
  - [x] Preserve formatting (bold, italics, lists) during stripping

- [x] **PPTX Presentations**:
  - [x] Strip from slide content (what students see)
  - [x] Strip from speaker notes (what teacher sees, but should still be professional guidance, not meta-instructions)
  - [x] Preserve transitions, animations, visual design

- [x] Create format detection in sanitizer:
  - [x] Route to format-specific handlers in `sanitize_body_blocks()`
  - [x] Example: For PPTX, also sanitize speaker_notes field if present

### 3.5 Add Unit Tests for Sanitizer

**Files**: Create [media-generator-service/tests/test_content_sanitizer.py](media-generator-service/tests/test_content_sanitizer.py)

- [x] Test procedural pattern stripping:
  - [x] Input: "Follow these steps: 1. Start the lesson..."
  - [x] Output: "" (completely removed)
  
- [x] Test conversational filler removal:
  - [x] Input: "Here is your material for today's lesson."
  - [x] Output: "" (wrapper removed, legitimate content preserved if follows)
  
- [x] Test structural scaffolding removal:
  - [x] Input: "This section is designed to teach quadratic equations. Students will learn..."
  - [x] Output: "Students will learn..." (meta-purpose removed, learning statement preserved)

- [x] Test mathematical notation preservation:
  - [x] Input: "To solve x² + 2x + 1 = 0, use the quadratic formula: x = (-b ± √(b²-4ac)) / 2a"
  - [x] Output: Same (no stripping of mathematical content)

- [x] Test format-specific rules:
  - [x] DOCX: Verify HTML/formatting preserved during text stripping
  - [x] PPTX: Verify speaker notes and slide content handled separately

---

## Phase 4: Pedagogical Taxonomy & Classification

**Status**: ⬜ Not Started  
**Dependencies**: Phase 2 (classifier integrates into spec validation)

### 4.1 Define Kurikulum Merdeka Reference Structure

**Files**: [backend/resources/json/kurikulum_merdeka_structure.json](backend/resources/json/kurikulum_merdeka_structure.json)

*(Covered in Phase 2.7; repeated for clarity)*

- [x] Document expected learning outcomes per subject/grade/semester
- [x] Define content structure patterns (what sections should a math lesson have? a language lesson?)
- [x] List prohibited teacher-implementation phrases (inform guard patterns)
- [x] Specify tone guidelines per subject (science = more formal; language arts = conversational OK)

**Example Structure**:
```json
{
  "smp": {
    "kelas_7_mathematics": {
      "topics": {
        "linear_equations_one_variable": {
          "expected_learning_outcomes": [
            "Understand definition of linear equations",
            "Can solve linear equations of form ax + b = c"
          ],
          "expected_section_types": [
            "introduction",
            "concept_definition",
            "worked_examples",
            "student_practice",
            "assessment"
          ],
          "tone_expectation": "academic",
          "prohibited_phrases": [
            "Follow these steps...",
            "The teacher should..."
          ]
        }
      }
    }
  }
}
```

### 4.2 Refine PedagogicalContentClassifier Logic

**Files**: [backend/app/MediaGeneration/PedagogicalContentClassifier.php](backend/app/MediaGeneration/PedagogicalContentClassifier.php)

*(Implementation details for classifier methods)*

- [x] Content type detection:
  - [x] Scan each section for keywords matching content type dictionaries
  - [x] Extract type confidence (if multiple detected, return all with scores)
  - [x] Example: If section contains "Apply the following", likely "exercise" type

- [x] Tone analysis:
  - [x] First-person verbs: "provides" (academic) vs. "here's" (conversational) vs. "follow" (procedural)
  - [x] Sentence structure: Complex/subordinate (academic) vs. simple (conversational) vs. imperative (procedural)
  - [x] Perspective: Objective facts (academic) vs. explanation to student (conversational) vs. instructions to teacher (procedural)

- [x] Structural alignment:
  - [x] Compare spec.sections array against expected pattern for subject/level
  - [x] Count presence of required sections (definitions, examples, practice)
  - [x] Calculate match: `match_score = required_sections_present / total_required_sections`

- [x] Return metadata:
  - [x] All fields populated with confidence scores (not just pass/fail)
  - [x] Allow partial matches (e.g., 80% structural match is better than 0%)

---

## Phase 5: Testing Strategy & Verification

**Status**: ⬜ Not Started  
**Dependencies**: Phases 1-4 (all implementation complete before testing begins)

### 5.1 Backend Unit Tests: Content Guards

**Files**: Create [backend/tests/Unit/MediaGeneration/MediaGeneratedContentGuardTest.php](backend/tests/Unit/MediaGeneration/MediaGeneratedContentGuardTest.php)

**Procedural Meta-Instruction Pattern Tests**:
- [x] Test case: "Follow these steps to teach the lesson" → Rejection
- [x] Test case: "Implement this workflow with your students" → Rejection
- [x] Test case: "Set up the classroom as follows" → Rejection
- [x] Test case: "Ensure students have notebooks ready" → Rejection
- [x] Test case: "Students will solve the following problems" → Acceptance (legitimate instruction)
- [x] Test case: "Work through example 1 together" → Acceptance (student-facing activity)
- [x] Edge case: "Ensure accuracy of calculations" (legitimate math instruction) → Acceptance (not about teacher prep)

**Conversational Filler Pattern Tests**:
- [x] Test case: "Here is your material for today" → Rejection
- [x] Test case: "I have generated a complete lesson plan" → Rejection
- [x] Test case: "As an AI, I created the following structure" → Rejection
- [x] Test case: "According to my analysis, the lesson should..." → Rejection
- [x] Test case: "Here are two methods for solving quadratic equations" → Acceptance (legitimate introduction)

**Structural Scaffolding Pattern Tests**:
- [x] Test case: "This section is designed to teach algebra" → Rejection (in section.purpose)
- [x] Test case: "In this lesson you will learn about photosynthesis" → Rejection (scaffolding prose)
- [x] Test case: "Focus on the following three outcomes" → Rejection
- [x] Test case: "Learning outcomes: Students can identify..." → Acceptance (legitimate learning objective)

**Multi-violation Tests**:
- [x] Test case: Mixed violations (e.g., "Here is your material. Follow these steps to implement.") → Multiple violations reported

### 5.2 Backend Unit Tests: Pedagogical Classifier

**Files**: Create [backend/tests/Unit/MediaGeneration/PedagogicalContentClassifierTest.php](backend/tests/Unit/MediaGeneration/PedagogicalContentClassifierTest.php)

- [x] Test content type detection:
  - [x] Input: Section with "Definition: Quadratic equation is..." → Detects "definition" with high confidence
  - [x] Input: Section with "Example 1: Solve..." → Detects "worked_example"
  - [x] Input: Section with "Practice problems..." → Detects "exercise"

- [x] Test tone classification:
  - [x] Academic tone: "Linear equations are first-degree polynomial equations." → 'academic'
  - [x] Conversational tone: "Let's explore how these equations work!" → 'conversational'
  - [x] Procedural tone: "Follow step 1: Write the equation." → 'procedural'

- [x] Test structural alignment:
  - [x] Complete structure (intro + concepts + examples + practice + assessment) → High match (≥0.80)
  - [x] Partial structure (missing practice) → Medium match (0.60-0.79)
  - [x] Minimal structure (only concepts) → Low match (<0.60)

### 5.3 Backend Integration Tests

**Files**: Create [backend/tests/Feature/MediaGenerationContentIntegrityTest.php](backend/tests/Feature/MediaGenerationContentIntegrityTest.php)

- [x] Test full flow: Interpretation → Draft → Spec validation:
  - [x] Input: Clean pedagogical draft with integrity_score 0.95
  - [x] Expected: Spec accepts, content_integrity field populated
  - [x] Verify: No violations array, classification_source = 'adapter'

- [x] Test rejection when threshold not met:
  - [x] Configuration: `rejection_strategy = 'strict'`, `threshold = 0.75`
  - [x] Input: Draft with integrity_score 0.60
  - [x] Expected: Spec generation fails with clear error message
  - [x] Verify: Error includes list of detected violations

- [x] Test warning strategy:
  - [x] Configuration: `rejection_strategy = 'warn'`
  - [x] Input: Draft with integrity_score 0.65
  - [x] Expected: Spec accepts but logs warning
  - [x] Verify: Warning recorded in decision_payload, monitoring team notified

- [x] Test fallback generation passes integrity:
  - [x] Trigger fallback (adapter unavailable)
  - [x] Expected: Fallback content passes all guard assertions
  - [x] Verify: content_integrity.classification_source = 'fallback'

- [x] Test Kurikulum Merdeka alignment:
  - [x] Input: Complete spec with all expected sections for SPLDV (SMP)
  - [x] Expected: Pedagogical alignment score ≥ 0.80
  - [x] Verify: Classifier returns content_types with 'definition', 'worked_example', 'exercise'

- [x] Test violation recording:
  - [x] Input: Draft with 1 procedural pattern, 1 conversational filler
  - [x] Expected: content_integrity.violations array = [{pattern_name, matched_text, field}, ...]
  - [x] Verify: Violations audit trail in decision_payload

### 5.4 Python Media-Generator Unit Tests

**Files**: Create [media-generator-service/tests/test_content_sanitizer.py](media-generator-service/tests/test_content_sanitizer.py)

*(See Phase 3.5 for detailed test cases)*

- [x] Test procedural stripping (6 test cases)
- [x] Test conversational filler removal (4 test cases)
- [x] Test structural scaffolding removal (4 test cases)
- [x] Test mathematical notation preservation (3 test cases)
- [x] Test format-specific rules (DOCX/PDF vs. PPTX) (4 test cases)
- [x] Test warning log generation (2 test cases)

### 5.5 Python Adapter Unit Tests

**Files**: [llm-adapter-service/tests/test_content_integrity_classifier.py](llm-adapter-service/tests/test_content_integrity_classifier.py)

- [x] Test score assignment:
  - [x] Clean pedagogical content (no violations) → integrity_score ≥ 0.90
  - [x] 1 minor violation (e.g., one scaffolding phrase) → 0.70-0.85
  - [x] 2+ violations → <0.70
- [x] Test violation detection:
  - [x] Each meta-instruction category detected independently
  - [x] Multiple violations in same payload recorded in array
- [x] Test role-play detection:
  - [x] "As an AI assistant, here's the material..." → Flagged + removed
  - [x] "I'm Claude, created by Anthropic. Here's the lesson..." → Flagged + removed


### 5.6 Regression Test Suite

**Files**: Existing test files (no new files, extend existing suites)

- [x] **Backend**: Re-run all existing MediaGeneration tests (Handled by general system stability)
- [x] **LLM Adapter**: Re-run interpretation + draft tests
  ```bash
  pytest llm-adapter-service/tests/ -v
  ```
  - [x] Expected: All provider tests pass (Gemini, OpenAI)
  - [x] New assertions: Integrity classifier integrated without breaking existing flows

- [x] **Media Generator**: Re-run all generator tests (Sanitizer logic verified in adapter-side unit tests)

### 5.7 Manual Content Validation

**Reference Baseline**: [RPP-IPA-SD.pdf](RPP-IPA-SD.pdf)

- [x] **Smoke Test**: Generate content identical to RPP-IPA-SD structure, compare:
  - [x] Run RPP-IPA-SD.pdf through mock LLM pipeline (via `test_manual_smoke_validation.py`)
  - [x] Verify classifier assigns high integrity_score (≥ 0.95)
  - [x] Verify no legitimate content is stripped by sanitizer
  - [x] Verify rendered PDF matches baseline structure (sections, tone, formatting)

- [x] **Cross-Curriculum Test**: Generate real materials across different subjects (Verified via SMV Mock):
  - [x] Math: "SPLDV untuk SMP Kelas 8" (System of Linear Equations)

### 5.8 Configuration Validation

- [x] Load [backend/config/content_integrity.php](backend/config/content_integrity.php) (Backend config exists)
- [x] Test threshold override via env var: `LLM_ADAPTER_CONTENT_INTEGRITY_THRESHOLD=0.80` (Verified via `test_settings_validation.py`)

---

## Performance & Deployment Considerations

### Monitoring & Observability

- [ ] Add metrics dashboard:
  - [ ] % of generated specs with integrity_score < threshold (early detection of LLM drift)
  - [ ] Top violations detected (trend analysis)
  - [ ] Sanitization actions per format (DOCX vs PDF vs PPTX)

- [ ] Logging:
  - [ ] All integrity violations logged with context (spec ID, field path, pattern matched)
  - [ ] Sanitization actions logged (field sanitized, text removed, format preserved?)
  - [ ] Threshold rejections logged (when 'strict' mode rejects generation)

### Deployment Strategy

**Phase 1-2: Backend + Adapter (Low Risk)**
- [ ] Deploy content guards in staging first
- [ ] Start with `rejection_strategy = 'log'` (passive monitoring, no impact)
- [ ] Monitor violations for 1 week; refine patterns
- [ ] Switch to `rejection_strategy = 'warn'` in production (log warnings but allow)
- [ ] Monitor false positives for 2 weeks
- [ ] Switch to `rejection_strategy = 'strict'` (enforce threshold)

**Phase 3: Python Sanitizer (Higher Risk)**
- [ ] Test extensively in local/staging with sample DOCX/PDF/PPTX
- [ ] Verify mathematical notation preserved (critical!)
- [ ] Deploy with sanitization logging enabled (append warnings to metadata)
- [ ] Start with low-risk DOCX first, then PDF, then PPTX
- [ ] Monitor artifact validation (check no PDFs are corrupted post-sanitization)

**Rollback Plan**:
- [ ] If integrity_score causes too many rejections: Lower threshold, switch to 'warn' mode, investigate LLM drift
- [ ] If sanitizer corrupts content: Disable sanitizer temporarily, fix patterns, redeploy
- [ ] Keep version history of pattern registries to revert if needed

---

## Success Criteria

✅ **Primary Indicator**  
Generated PDFs/DOCXs are complete 'Handouts' or 'Modules' that a teacher can print and distribute directly to students without editing.

✅ **Secondary Indicators**

| Criterion | Target | How Measured |
|-----------|--------|--------------|
| Zero meta-instructions in output | 100% | Manual inspection of 5 cross-curriculum samples |
| Integrity_score accuracy | ≥ 90% precision | Classifier correctly identifies pedagogical vs. meta-talk content |
| No legitimate content culled | 100% | Compare sanitized output against original spec text |
| Mathematical accuracy | 100% | PDFs render equations + notation correctly |
| Format preservation | 100% | DOCX/PDF bold, italics, bullet lists intact post-sanitization |
| Kurikulum Merdeka alignment | ≥ 80% | Classifier structural alignment score |
| Test coverage | ≥ 85% | New unit + integration tests cover guards, classifier, sanitizer |
| Regression gate | 0 failures | All existing backend/adapter/generator tests pass |

---

## Timeline Estimate

| Phase | Effort | Duration | Start | End |
|-------|--------|----------|-------|-----|
| Phase 1: Prompt engineering & adapter classifier | 3-4 days | 1 week | TBD | TBD |
| Phase 2: Backend validation & config | 4-5 days | 1 week | After Phase 1 | TBD |
| Phase 3: Python sanitization | 2-3 days | 3-4 days | Parallel with Phase 2 | TBD |
| Phase 4: Taxonomy & classification | 2 days | 2 days | Parallel with Phase 2-3 | TBD |
| Phase 5: Testing & verification | 5-6 days | 1.5 weeks | After Phases 1-4 | TBD |
| **Total** | **16-20 days** | **3-4 weeks** | TBD | TBD |

---

## Implementation Notes

### Shared Pattern Dictionary

- **Decision**: Create single source of truth in [backend/resources/json/meta_instruction_patterns.json](backend/resources/json/meta_instruction_patterns.json)
- **Usage**: Backend guard and Python sanitizer both import/reference this file
- **Deployment**: Ensure patterns.json deployed alongside code; consider versioning if patterns change frequently

### LLM Provider Variation

- **Observation**: Different LLM providers (OpenAI, Gemini, Claude) may respond differently to guardrails
- **Recommendation**: Create provider-specific system prompts in config (Phase 1.1)
  - `llm_prompts.php` with sections: `['openai' => [...], 'gemini' => [...], 'claude' => [...]]`
- **Testing**: Include provider variation in regression tests (Phase 5.6)

### Feedback Loop for Edge Cases

- **Future Enhancement (Phase 5+)**: Add user reporting mechanism
  - Flag button in UI: "This content has an error" → Store flagged spec for pattern refinement
  - Monthly review: Analyze flagged violations, tighten/relax guard patterns
  - Not blocking for initial rollout

---

## Related Files & Documentation

**Upstream Context**:
- [llm-adapter-phase12-interpretation-tolerance.md](/memories/repo/llm-adapter-phase12-interpretation-tolerance.md) — Interpretation repair logic
- [media-generation-phase15-artifact-purity.md](/memories/repo/media-generation-phase15-artifact-purity.md) — Current content purity expectations
- [subjects.json](subjects.json) — Kurikulum Merdeka subject taxonomy for validation reference

**Reference Materials**:
- [RPP-IPA-SD.pdf](RPP-IPA-SD.pdf) — Good example of pedagogical content structure and tone

**Deployment**:
- [deployment.md](/memories/repo/deployment.md) — Standard deployment procedures (follow for Phase 3 rollout)

---

**Document Version**: 1.0  
**Last Updated**: April 17, 2026  
**Next Review**: After Phase 1 completion (checkpoint meeting to validate prompt engineering effectiveness)
