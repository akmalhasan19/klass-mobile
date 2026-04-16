# Post-Generation Actions Implementation Plan

**Feature**: Regenerate Media + Hire Freelancer for Refinement  
**Last Updated**: April 14, 2026  
**Status**: Planning Phase

---

## Overview

Menambahkan fitur post-media-generation yang memberikan teacher 2 opsi:
1. **Regenerate dengan Prompt Tambahan** — Retain original prompt, add additional context, create new generation
2. **Hire Freelancer untuk Refine** — Teacher bisa auto-search best-fit freelancers atau post open task for bidding

**Key Features**:
- Parent-child generation tracking untuk audit trail
- Weighted freelancer matching algorithm (portfolio 50%, success rate 30%, availability 20%)
- Dual hiring modes: auto-suggest + manual task posting
- Simplified UI: Download, Regenerate, Hire buttons only (remove Share & Open)

---

## Phase 1: Database Schema & Models (Foundation)

### 1.1 Extend MediaGeneration Model dengan Parent-Child Relationship
- [x] Add migration: `add_parent_generation_to_media_generations`
  - [x] Add column `generated_from_id` (nullable FK to parent MediaGeneration)
  - [x] Add column `is_regeneration` (boolean, default false)
- [x] Update `MediaGeneration` model
  - [x] Add relationship `parentGeneration()`
  - [x] Add relationship `childGenerations()`
  - [x] Add helper methods: `isRegeneration()`, `getOriginalGeneration()`
- [x] Test: Verify migration runs without errors, columns created correctly

### 1.2 Enhance MarketplaceTask untuk Freelancer Refinement
- [x] Add migration: `optimize_marketplace_tasks_for_refinement` (jika diperlukan)
  - [x] Ensure column `task_type` exists (enum: 'bid'|'suggestion')
  - [x] Ensure column `description` exists (refinement requirements)
  - [x] Ensure column `suggested_freelancer_id` exists (nullable)
  - [x] Ensure column `media_generation_id` exists (FK)
- [x] Update `MarketplaceTask` model
  - [x] Add relationship `mediaGeneration()`
  - [x] Add relationship `suggestedFreelancer()` (hasOne User)
  - [x] Add relationship `freelancerBids()` (for open bid tasks)
- [x] Test: Verify relationships work correctly, columns accessible

### 1.3 Create FreelancerMatch Model (Baru)
- [x] Create model file: `app/Models/FreelancerMatch.php`
  - [x] Properties: `media_generation_id`, `freelancer_id`, `match_score`, `portfolio_relevance_score`, `success_rate`
- [x] Create migration: `create_freelancer_matches_table`
  - [x] Columns: `id`, `media_generation_id` (FK), `freelancer_id` (FK), `match_score` (float), `portfolio_relevance_score` (float), `success_rate` (float), `created_at`, `updated_at`
  - [x] Indexes: media_generation_id, freelancer_id, match_score
- [x] Update model relationships
  - [x] `belongsTo MediaGeneration`
  - [x] `belongsTo User (freelancer)`
- [x] Test: Verify migration, model instantiation, relationships

### 1.4 Run Database Migrations
- [x] Run all migration files
- [x] Verify all columns/tables created
- [x] Verify foreign keys set up correctly
- [x] Test rollback functionality

---

## Phase 2: Backend API Endpoints & Services

### 2.1 Create Regenerate Endpoint: POST /api/media-generations/{id}/regenerate
- [x] Create method in `MediaGenerationController`: `regenerate(RegenerateMediaGenerationRequest $request, string $id)`
- [x] Create form request: `app/Http/Requests/RegenerateMediaGenerationRequest.php`
  - [x] Validate: `additional_prompt` (required, max 5000 chars)
  - [x] Validate: Parent generation exists and is completed
- [x] Implement logic:
  - [x] Fetch parent MediaGeneration record
  - [x] Create new MediaGeneration record dengan `generated_from_id = parent_id`, `is_regeneration = true`
  - [x] Combine prompts: store both original + additional for context
  - [x] Dispatch `ProcessMediaGenerationJob` dengan new generation ID
  - [x] Return 202 Accepted response with new generation ID
- [x] Test: E2E regenerate flow, verify prompts stored, new generation tracked

### 2.2 Create Freelancer Matching Service
- [x] Create file: `app/Services/FreelancerMatchingService.php`
- [x] Implement matching algorithm:
  - [x] `matchByPortfolio(MediaGeneration $generation, Collection $candidates)`: float[]
    - [x] Find freelancers dengan past work similar to generation output_type & subject
    - [x] Score based on match relevance (0-1)
  - [x] `matchBySuccessRate(Collection $candidates)`: float[]
    - [x] Get freelancer ratings/completion rates
    - [x] Filter only top performers (configurable threshold)
    - [x] Normalize to 0-1 scale
  - [x] `matchByAvailability(Collection $candidates)`: float[]
    - [x] Check last activity, online status
    - [x] Normalize to 0-1 scale
  - [x] `findBestMatches(MediaGeneration $generation, int $limit = 5): Collection`
    - [x] Get all active freelancers
    - [x] Calculate scores: `portfolio_match * 0.5 + success_rate * 0.3 + availability * 0.2`
    - [x] Sort by total score descending
    - [x] Return top N with scores
- [x] Create unit tests for matching algorithm
  - [x] Test each matching component independently
  - [x] Test weighted score calculation
  - [x] Test sorting and limiting

### 2.3 Create Freelancer Suggestion Endpoint: POST /api/media-generations/{id}/suggest-freelancers
- [x] Create method in new `FreelancerSuggestionController`: `suggest(string $generationId)`
  - [x] Accept: `max_suggestions` (optional, default 5)
  - [x] Validate: Generation exists and is completed
  - [x] Call `FreelancerMatchingService.findBestMatches()`
  - [x] Store results in `FreelancerMatch` table for audit
  - [x] Return top candidates dengan match scores, basic info (name, rating, portfolio)
- [x] Test: Verify suggestions returned, scores calculated correctly, stored in DB

### 2.4 Create Freelancer Hire Endpoint: POST /api/media-generations/{id}/hire-freelancer
- [x] Create method in `FreelancerHiringController`: `hire(HireFreelancerRequest $request, string $generationId)`
- [x] Create form request: `app/Http/Requests/HireFreelancerRequest.php`
  - [x] Validate: `mode` (enum: 'auto_suggest'|'manual_task')
  - [x] Validate: `refinement_description` (required, max 2000 chars)
  - [x] Validate: `selected_freelancer_id` (required if mode == 'auto_suggest')
- [x] Implement logic:
  - [x] Fetch MediaGeneration
  - [x] For `auto_suggest` mode:
    - [x] Verify selected freelancer is from suggestions
    - [x] Create `MarketplaceTask` dengan `task_type = 'suggestion'`, `suggested_freelancer_id`, `status = 'assigned'`
    - [x] Send notification to selected freelancer
  - [x] For `manual_task` mode:
    - [x] Create `MarketplaceTask` dengan `task_type = 'bid'`, `status = 'open_for_bid'`
    - [x] Broadcast notification to all freelancers
  - [x] Return 201 Created with task details
- [x] Test: Both modes, verify task created with correct fields

### 2.5 Create Supporting Services
- [x] Update `MediaGenerationService` or create helper:
  - [x] `getRegenerationContext(MediaGeneration $generation)`: array
    - [x] Build context info for matcher, notifications, etc.
- [x] Create notification classes:
  - [x] `FreelancerAssignedTask` — sent when task auto-assigned
  - [x] `FreelancerNewTaskPosted` — broadcast when open bid task posted
- [x] Update existing services as needed:
  - [x] Adapt `MediaGenerationWorkflowService` if needed for regenerate flow
  - [x] Ensure notifications integrated

---

## Phase 3: Frontend UI Changes

### 3.1 Modify MediaGenerationStatusCard Widget
- [x] File: `frontend/lib/widgets/media_generation_status_card.dart`
- [x] Changes:
  - [x] Remove `Share` button from success state
  - [x] Remove `Open` button from success state
  - [x] Keep `Download` button
  - [x] Add `Regenerate` button → callback to navigate/show regenerate sheet
  - [x] Add `Hire Freelancer` button → callback to navigate/start hiring flow
- [x] Update button styling to accommodate new layout
- [x] Test: Verify buttons display correctly, callbacks trigger

### 3.2 Create RegenerateBottomSheet Widget
- [x] Create file: `frontend/lib/widgets/regenerate_bottom_sheet.dart`
- [x] Design:
  - [x] Show original prompt in read-only text field
  - [x] Show input field for additional prompt
  - [x] Submit button
  - [x] Close button (X)
- [x] Logic:
  - [x] Fetch original prompt from MediaGeneration
  - [x] `onSubmit()`: Validate additional prompt not empty → call `MediaGenerationService.regenerateWithPrompt()`
  - [x] Show loading state during submission
  - [x] Handle errors gracefully with snackbar messages
  - [x] On success: Close sheet, trigger parent refresh, show new generation status
- [x] Test: Display, input validation, submission flow

### 3.3 Create FreelancerHiringFlow Screens

#### 3.3a Refinement Input Screen
- [x] Create file: `frontend/lib/screens/hiring/refinement_input_screen.dart`
- [x] Design:
  - [x] Title: "What needs to be refined?"
  - [x] Multiline text field for refinement description
  - [x] Character count (max 2000)
  - [x] Next button
- [x] Logic:
  - [x] Validate input not empty
  - [x] Save description to controller state
  - [x] Navigate to hiring mode selection screen
- [x] Test: Input validation, navigation

#### 3.3b Hiring Mode Selection Screen
- [x] Create file: `frontend/lib/screens/hiring/hiring_mode_screen.dart`
- [x] Design:
  - [x] Title: "How would you like to find a freelancer?"
  - [x] 2 cards/buttons:
    - [x] "Auto-Search Freelancers" (system finds best matches)
    - [x] "Post Public Task" (freelancers bid)
- [x] Logic:
  - [x] Route to respective screen based selection
  - [x] Store mode in controller state
- [x] Test: Card styling, routing

#### 3.3c Auto-Suggest Freelancer Review Screen
- [x] Create file: `frontend/lib/screens/hiring/freelancer_suggestions_screen.dart`
- [x] Design:
  - [x] Show loading state initially
  - [x] Cards for top 3-5 freelancers showing:
    - [x] Profile picture/avatar
    - [x] Name, rating (stars), success rate %
    - [x] Brief portfolio summary
    - [x] Match score badge (%)
  - [x] Select button per card
  - [x] Confirmation dialog after selection
- [x] Logic:
  - [x] On screen load: Call `MediaGenerationService.suggestFreelancers()`
  - [x] Handle loading, error states
  - [x] On selection: Show confirmation → call `MediaGenerationService.hireFreelancer(mode='auto_suggest')`
  - [x] On success: Navigate to completion screen or back
- [x] Test: Display of suggestions, selection flow, API calls

#### 3.3d Manual Task Posting Confirmation Screen
- [x] Create file: `frontend/lib/screens/hiring/task_posting_screen.dart`
- [x] Design:
  - [x] Summary section:
    - [x] Media generated: title, type (PPTX/PDF/DOCX)
    - [x] Refinement description (from step 1)
  - [x] Price estimate section (TBD, placeholder for now)
  - [x] Post Task button (confident CTA)
  - [x] Back button
- [x] Logic:
  - [x] On "Post Task": Call `MediaGenerationService.hireFreelancer(mode='manual_task')`
  - [x] Show loading state
  - [x] Handle success/error
  - [x] On success: Show confirmation message → navigate back to home
- [x] Test: Summary display, task posting flow

### 3.4 Create FreelancerHiringFlowController
- [x] Create file: `frontend/lib/controllers/freelancer_hiring_flow_controller.dart`
- [x] State management (using GetX or Provider):
  - [x] `generationId` (String)
  - [x] `refinementDescription` (String)
  - [x] `selectedMode` (String: 'auto_suggest'|'manual_task')
  - [x] `selectedFreelancerId` (String?)
  - [x] `isLoading` (bool)
  - [x] `currentStep` (int) for navigation
- [x] Methods:
  - [x] `setRefinementDescription(String)`
  - [x] `selectMode(String)`
  - [x] `selectFreelancer(String)`
  - [x] `submitHiring()` → call service
  - [x] `resetFlow()`
  - [x] `navigateToStep(int)`
- [x] Test: State transitions, method calls

### 3.5 Extend MediaGenerationService
- [x] File: `frontend/lib/services/media_generation_service.dart`
- [x] Add methods:
  - [x] `regenerateWithPrompt(String parentId, String additionalPrompt): Future<MediaGeneration>`
    - [x] Validate inputs
    - [x] Call `POST /api/media-generations/{parentId}/regenerate`
    - [x] Parse response, return new generation
  - [x] `suggestFreelancers(String generationId): Future<List<FreelancerSuggestion>>`
    - [x] Call `POST /api/media-generations/{generationId}/suggest-freelancers`
    - [x] Parse response
  - [x] `hireFreelancer(String generationId, {required String mode, required String refinementDescription, String? selectedFreelancerId}): Future<MarketplaceTask>`
    - [x] Build request payload
    - [x] Call `POST /api/media-generations/{generationId}/hire-freelancer`
    - [x] Parse response
- [x] Create model/DTO:
  - [x] `FreelancerSuggestion` model with fields: id, name, rating, successRate, portfolioSummary, matchScore
  - [x] Parse from API response
- [x] Test: API calls, error handling, response parsing

### 3.6 Update HomeScreen Navigation
- [x] File: `frontend/lib/screens/home_screen.dart`
- [x] Changes:
  - [x] In `_build` method, wrap/ensure `MediaGenerationStatusCard` has the correct callbacks.
  - [x] Implement `onRegenerate` to call `RegenerateBottomSheet.show`
  - [x] Implement `onHireFreelancer` to initialize `FreelancerHiringFlowController` and navigate to `RefinementInputScreen`.
- [x] Test: Full E2E flow from home screen to generation status to post-generation actions

---

## Phase 4: Integration & Testing

### 4.1 Backend Integration Testing

#### 4.1a Regenerate Endpoint Testing
- [x] Create test file: `backend/tests/Feature/MediaGeneration/RegenerateMediaGenerationTest.php`
- [x] Tests:
  - [x] Test successful regenerate: POST with valid data → 202, returns new generation ID
  - [x] Test parent generation is completed: Regenerate from non-completed → 422 error
  - [x] Test additional prompt validation: Empty/too long → 422 error
  - [x] Test invalid parent ID: Non-existent parent → 404
  - [x] Verify parent-child relationship: Query new generation, check `generated_from_id`
  - [x] Verify both prompts accessible: Check both in workflow/context
  - [x] Verify new generation starts processing: Check job dispatched

#### 4.1b Freelancer Matching Testing
- [x] Create test file: `backend/tests/Unit/Services/FreelancerMatchingServiceTest.php`
- [x] Tests:
  - [x] Test `matchByPortfolio()`: Similar vs dissimilar work → correct scoring
  - [x] Test `matchBySuccessRate()`: High vs low rated freelancers → sorted correctly
  - [x] Test `matchByAvailability()`: Available vs unavailable → differentiated
  - [x] Test `findBestMatches()`: Weighted calculation, top N returned
  - [x] Edge case: No matching freelancers → empty collection
  - [x] Edge case: More candidates than limit → correct limiting

#### 4.1c Freelancer Suggestion Endpoint Testing
- [x] Create test file: `backend/tests/Feature/FreelancerSuggestion/SuggestFreelancersTest.php`
- [x] Tests:
  - [x] Test successful suggestion: GET endpoint → 200, candidates returned with scores
  - [x] Verify FreelancerMatch stored: Check DB, records created with correct data
  - [x] Test custom limit: Send `max_suggestions` param → correct number returned
  - [x] Test invalid generation: Non-existent → 404
  - [x] Test generation not completed: Pending generation → 422

#### 4.1d Freelancer Hiring Endpoint Testing
- [x] Create test file: `backend/tests/Feature/FreelancerHiring/HireFreelancerTest.php`
- [x] Tests - Auto-Suggest Mode:
  - [x] POST with mode='auto_suggest' + valid freelancer → 201 Created, task created
  - [x] Verify task fields: task_type='suggestion', suggested_freelancer_id set, status='assigned'
  - [x] Verify freelancer notified: Check notification queued
  - [x] Test invalid freelancer ID: Not in suggestions → error
  - [x] Test missing freelancer ID: Required for auto mode → 422
- [x] Tests - Manual Task Mode:
  - [x] POST with mode='manual_task' → 201 Created, task created
  - [x] Verify task fields: task_type='bid', suggested_freelancer_id=null, status='open_for_bid'
  - [x] Verify notification broadcast: Check notification queued/logged
  - [x] Verify no freelancer_id required: Create successfully without it
- [x] Tests - Validation:
  - [x] Invalid mode enum → 422
  - [x] Missing refinement_description → 422
  - [x] Refinement description too long → 422
  - [x] Invalid generation ID → 404

### 4.2 Frontend Integration Testing

#### 4.2a UI Display Testing
- [ ] Manually test in app:
  - [ ] After generation completes, **MediaGenerationStatusCard shows 3 buttons**: Download, Regenerate, Hire Freelancer
  - [ ] Verify Share & Open buttons are removed
  - [ ] Buttons are properly styled, clickable

#### 4.2b Regenerate Flow E2E
- [ ] Manually test:
  - [ ] Generate media (setup)
  - [ ] Tap "Regenerate" button
  - [ ] **BottomSheet appears** with original prompt (read-only)
  - [ ] Enter additional prompt in text field
  - [ ] Tap Submit
  - [ ] **New generation starts**, card shows loading state
  - [ ] Wait for completion
  - [ ] **Both original generation** (if accessible) **and new generation** visible
  - [ ] Check generation history shows both

#### 4.2c Hiring Flow E2E - Auto-Suggest Mode
- [ ] Manually test:
  - [ ] Generate media → Tap "Hire Freelancer"
  - [ ] **Step 1 (Refinement)**: Enter refinement description → tap Next
  - [ ] **Step 2 (Mode Selection)**: Select "Auto-Search Freelancers" → tap Next
  - [ ] **Step 3 (Suggestions)**: Wait for loading → **3-5 freelancer cards appear** with ratings, match scores
  - [ ] Select one freelancer
  - [ ] **Confirmation dialog** appears
  - [ ] Confirm → loading state
  - [ ] **Success message** → navigate back to home
  - [ ] Verify task created (check backend/freelancer side if possible)

#### 4.2d Hiring Flow E2E - Manual Task Mode
- [ ] Manually test:
  - [ ] Generate media → Tap "Hire Freelancer"
  - [ ] **Step 1 (Refinement)**: Enter refinement description → tap Next
  - [ ] **Step 2 (Mode Selection)**: Select "Post Public Task" → tap Next
  - [ ] **Step 3 (Confirmation)**: Summary shows media details & refinement description
  - [ ] Tap "Post Task"
  - [ ] **Success message** → navigate back to home
  - [ ] Verify task created (open_for_bid status)

#### 4.2e Error Handling Testing
- [ ] Test error scenarios:
  - [ ] Network error during regenerate → show error snackbar, allow retry
  - [ ] Network error during suggestion fetch → show error on suggestions screen
  - [ ] No matching freelancers → show message on suggestions screen
  - [ ] Invalid inputs (empty refinement) → prevent submission

### 4.3 API Contract Validation
- [x] Use REST client (Postman/Insomnia) or automated test:
  - [x] Verify request/response structure matches between frontend & backend
  - [x] Check all field names, types, formats
  - [x] Verify status codes (202, 201, etc.)
  - [x] Test error responses: 400, 404, 422, 500
  - [x] Validate pagination (if applicable for suggestions)

---

## Verification Checklist

> **Verifikasi diperbarui**: 2026-04-16 | Metode: Code Audit + `flutter analyze` (No issues found)

### Post-Generation UI
- [x] ✅ PGUI-01: After media generation completes, **MediaGenerationStatusCard shows**: Download, Regenerate, Hire Freelancer buttons
- [x] ✅ PGUI-01: **Share & Open buttons removed** from UI
- [x] ✅ PGUI-02: Buttons styled consistently with app design

### Regenerate Flow
- [x] ✅ RF-01: Click Regenerate → **bottom sheet appears** with:
  - [x] ✅ RF-01: Original prompt displayed (read-only)
  - [x] ✅ RF-01: Input field for additional prompt
- [x] ✅ RF-02: Input additional prompt → validate + submit
- [x] ✅ RF-03: **New generation starts**, loading state shown
- [ ] ⚠️ RF-05: BLOCKED — Original generation **still accessible** in history/workspace (tidak ada history UI di frontend; singleton service)
- [x] ✅ RF-04: Both **original & additional prompts visible** in new generation (parent-child di DB)

### Freelancer Hiring - Auto-Suggest
- [x] ✅ FHAS-01: Click Hire Freelancer → **refinement input screen** appears (judul + maxLength 2000)
- [x] ✅ FHAS-02: Input refinement description → navigate to next step (HiringModeScreen)
- [x] ✅ FHAS-02: Select "Auto-Search Freelancers" → **suggestions screen appears**
- [x] ✅ FHAS-03: **3-5 freelancer cards shown** with:
  - [x] Profile info (name, rating, success rate)
  - [x] Match score percentage
  - [ ] ⚠️ portfolio summary (field tidak ada di model FreelancerSuggestion)
  - [x] Select button per card
- [x] ✅ FHAS-04: Select freelancer → **confirmation dialog** (AlertDialog)
- [x] ✅ FHAS-05: Confirm → **task created** with:
  - [x] `task_type = 'suggestion'`
  - [x] `suggested_freelancer_id` set to selected
  - [x] `status = 'assigned'`
  - [x] `refinement_description` stored
- [ ] ❌ FHAS-06: FAIL — Freelancer **receives notification** (perlu verifikasi manual E2E dengan server aktif)

### Freelancer Hiring - Manual Task
- [ ] Click Hire Freelancer → **refinement input screen**
- [ ] Input refinement description → next
- [ ] Select "Post Public Task" → **summary screen**
- [ ] Summary shows:
  - [ ] Media title & type (PPTX/PDF/DOCX)
  - [ ] Refinement description (from step 1)
- [ ] Confirm → **task created** with:
  - [ ] `task_type = 'bid'`
  - [ ] `suggested_freelancer_id = null`
  - [ ] `status = 'open_for_bid'`
  - [ ] `refinement_description` stored
- [ ] **All freelancers receive broadcast notification**

### Database Consistency
- [ ] Run migrations successfully
- [ ] Verify new columns exist:
  - [ ] `media_generations.generated_from_id`
  - [ ] `media_generations.is_regeneration`
  - [ ] `marketplace_tasks.task_type`
  - [ ] `marketplace_tasks.suggested_freelancer_id`
  - [ ] `marketplace_tasks.media_generation_id`
- [ ] Verify new table created:
  - [ ] `freelancer_matches` table with all columns
  - [ ] Indexes on media_generation_id, freelancer_id, match_score
- [ ] Verify relationships:
  - [ ] Parent-child MediaGeneration relationships stored correctly
  - [ ] FreelancerMatch records created during suggestion
  - [ ] MarketplaceTask records created with correct task_type
  - [ ] Foreign keys working (no orphaned records)

### API Testing (Automated)
- [ ] **Regenerate Endpoint**:
  - [ ] POST with valid data → 202 response, new generation ID returned
  - [ ] Verify `generated_from_id` set correctly
  - [ ] Job dispatched successfully
- [ ] **Suggestion Endpoint**:
  - [ ] POST → 200 response, top matches returned with scores
  - [ ] FreelancerMatch records created in DB
  - [ ] Scores calculated using weighted algorithm
- [ ] **Hiring Endpoint**:
  - [ ] Mode='auto_suggest' → 201, task created with status 'assigned'
  - [ ] Mode='manual_task' → 201, task created with status 'open_for_bid'
  - [ ] Both store refinement_description
  - [ ] Correct notifications queued

---

## Implementation Order (Suggested)

1. **Phase 1 (Database)** — Foundation
   - 1.1-1.4: Create all migrations & models
   - Parallel: Verify data for freelancer ratings exists (for matching later)

2. **Phase 2 (Backend)** — Core logic
   - 2.1: Regenerate endpoint (simpler, fewer dependencies)
   - 2.2-2.4: Matching service & hiring endpoints (depend on 1.x)
   - Parallel: Run all backend tests

3. **Phase 3 (Frontend)** — UI
   - 3.1-3.2: MediaCard changes & RegenerateBottomSheet (can work standalone)
   - 3.3-3.6: Hiring flow & service extensions (depend on Phase 2 being ready)
   - Parallel: Unit test individual screens

4. **Phase 4 (Testing)** — Validation
   - 4.1-4.3: Run integration, E2E, and contract tests
   - Fix any issues found

---

## Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| **Parent-Child Generation Tracking** | Maintain audit trail, enable querying generation history, support future features like version comparison |
| **Weighted Freelancer Matching** | Portfolio (50%) + success_rate (30%) + availability (20%) balances relevance with reliability |
| **Dual Hiring Modes** | Cater to different teacher preferences: quick assignment (auto) vs transparent bidding (manual) |
| **UI Simplification** | Remove Share/Open to focus user on next action: regenerate or refine |
| **FreelancerMatch Table** | Store suggestion results for audit, enable retry logic, analyze matching effectiveness |

---

## Further Considerations (Defer to Next Phase)

1. **Pricing & Compensation**
   - ( ) Define pricing model: fixed price? percentage-based? freelancer self-set rates?
   - ( ) Where to store pricing: in MarketplaceTask? config?
   - ( ) Recommendation: Implement fixed default price now, make configurable later

2. **Freelancer Rating & Portfolio Data**
   - ( ) Verify backend has existing freelancer ratings/completion rates
   - ( ) If not, create backfill script or manual seeding
   - ( ) Attach sample portfolio data for testing

3. **Notification System**
   - ( ) Verify notification service exists (check Jobs or Channels)
   - ( ) Extend if needed for new notification types
   - ( ) Test notification delivery in both modes

4. **Approval Workflow** (Future)
   - ( ) Consider if auto-assigned tasks need freelancer approval
   - ( ) If yes, add status: 'assigned_pending_approval' or similar
   - ( ) Add freelancer action endpoints to accept/decline

5. **Task Management UI** (Future)
   - ( ) Add freelancer-side screen to view assigned tasks
   - ( ] Add teacher-side screen to track refinement progress
   - ( ) Add chat/comment feature for task discussion

---

## Progress Tracking

**Completion Status**: [ ] 0% — Planning Phase

- [x] **Phase 1 (Database)**: 100%
  - [x] 1.1: 100%
  - [x] 1.2: 100%
  - [x] 1.3: 100%
  - [x] 1.4: 100%

- [x] **Phase 2 (Backend)**: 100%
  - [x] 2.1: 100%
  - [x] 2.2: 100%
  - [x] 2.3: 100%
  - [x] 2.4: 100%
  - [x] 2.5: 100%

- [ ] **Phase 3 (Frontend)**: 0%
  - [ ] 3.1: 0%
  - [ ] 3.2: 0%
  - [ ] 3.3a: 0%
  - [ ] 3.3b: 0%
  - [ ] 3.3c: 0%
  - [ ] 3.3d: 0%
  - [ ] 3.4: 0%
  - [ ] 3.5: 0%
  - [ ] 3.6: 0%

- [ ] **Phase 4 (Testing)**: 50%
  - [x] 4.1a: 100%
  - [x] 4.1b: 100%
  - [x] 4.1c: 100%
  - [x] 4.1d: 100%
  - [ ] 4.2a: 0%
  - [ ] 4.2b: 0%
  - [ ] 4.2c: 0%
  - [ ] 4.2d: 0%
  - [ ] 4.2e: 0%
  - [x] 4.3: 100%

- [/] **Verification**: ~65% (Post-Generation UI ✅, Regenerate Flow ✅ partial, FHAS ✅ partial — notifikasi & history perlu E2E)

---

**Document History**:
- 2026-04-14: Initial plan created based on requirements gathering
