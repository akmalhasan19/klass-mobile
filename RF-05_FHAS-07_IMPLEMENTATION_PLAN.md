# Implementation Plan: History Generasi (RF-05) & Error Handling (FHAS-07)

**Last Updated**: April 16, 2026  
**Status**: Phase 4 Complete — Phase 5 (Testing) In Progress  
**Related Document**: [POST_GENERATION_ACTIONS_IMPLEMENTATION.md](POST_GENERATION_ACTIONS_IMPLEMENTATION.md)

---

## Overview

Memerbaiki dua gap dari post-generation actions:

1. **RF-05** — Buat layar history/riwayat generasi agar generasi asli tetap bisa diakses setelah regenerasi
   - Architecture: Separate `GenerationHistoryService` untuk manage parent-chain history
   - Access: Link "View History" di `MediaGenerationStatusCard`
   - Scope: Parent-chain only (parent + semua child dari parent tersebut)

2. **FHAS-07** — Perbaiki `suggestFreelancers()` agar propagasi error (return null/throw) sehingga UI bisa membedakan error vs empty
   - Current: Silent catch → return [] (tidak bisa bedakan error vs no freelancers)
   - Updated: Rethrow exception → error state UI dengan retry button
   - Pattern: Match existing GalleryScreen error UI

---

## Key Decisions (Finalized)

| Aspek | Keputusan |
|---|---|
| **History Scope** | Parent-chain only (generasi asli + regenerasi-regenerasi dari parent) |
| **History Access** | Link "View History" di MediaGenerationStatusCard |
| **Service Architecture** | New `GenerationHistoryService` (ChangeNotifier, separate dari MediaGenerationService) |
| **Error Strategy** | Rethrow exception + error screen with retry (like GalleryScreen) |
| **History Sorting** | Newest first (latest regen at top) untuk UX discovery |
| **State Management** | Gunakan ChangeNotifier pattern (consistent dengan existing codebase) |

---

## Phase 1: Backend Verification

> **Dependency**: Minimal — parent-child tracking sudah ada di Phase 1 POST_GENERATION_ACTIONS_IMPLEMENTATION.md
> **Status**: ✅ COMPLETE (2026-04-16)

### 1.1 Verify Parent-Child Query Endpoint
- [x] Check existing endpoint untuk query children dari parent generasi
  - Lokasi potensial: `backend/app/Http/Controllers/MediaGenerationController.php`
  - **Temuan**: Endpoint `GET /api/media-generations?parent_id={}` BELUM ADA → dibuat baru
  - **Implementasi**: Tambah method `index()` di `MediaGenerationController` + route `GET /api/media-generations`
  - Response: `{ success: true, data: [...] }` sorted by `created_at` ascending (oldest-first)

- [x] Verify response fields include:
  - [x] `id`, `teacher_id`, `prompt`, `preferred_output_type`
  - [x] `status`, `created_at`, `updated_at`
  - [x] `generated_from_id` (parent ID reference) — **ditambahkan ke MediaGenerationResource**
  - [x] `is_regeneration` (boolean flag) — **ditambahkan ke MediaGenerationResource**

- [x] Test dengan automated test suite:
  - [x] Response includes parent + 2+ children (test: `history_endpoint_returns_parent_and_children_sorted_oldest_first`)
  - [x] Sorted chronologically oldest-first (verified in test assertions)

### 1.2 Document Query Endpoint
- [x] Endpoint documented via PHPDoc inline di `MediaGenerationController::index()` (lines 22-48)
  - Method, query param, example request, example response format semua terdokumentasi
- [x] Test suite sebagai living documentation: `MediaGenerationHistoryTest.php` (7 test cases, 47 assertions)

### 1.3 Test Results
> **7 tests, 47 assertions — ALL PASS** (Duration: 6.87s)

| Test Case | Status |
|---|---|
| `history_endpoint_returns_parent_and_children_sorted_oldest_first` | ✅ PASS |
| `history_response_includes_parent_chain_fields` | ✅ PASS |
| `history_walks_to_root_when_querying_by_child_id` | ✅ PASS |
| `history_with_other_teacher_parent_id_returns_404` | ✅ PASS |
| `history_endpoint_rejects_non_teacher_role` | ✅ PASS |
| `history_endpoint_returns_recent_generations_when_no_parent_id` | ✅ PASS |
| `history_does_not_leak_generations_from_other_teachers` | ✅ PASS |

### 1.4 Files Modified/Created
| File | Change |
|---|---|
| `backend/app/Http/Controllers/Api/MediaGenerationController.php` | Added `index()` method with `GET /api/media-generations?parent_id` |
| `backend/app/Http/Resources/MediaGenerationResource.php` | Added `generated_from_id` + `is_regeneration` fields |
| `backend/routes/api.php` | Registered `Route::get('/media-generations', ...)` |
| `backend/tests/Feature/MediaGeneration/MediaGenerationHistoryTest.php` | **NEW** — 7 test cases |

---

## Phase 2: Frontend Service Layer

### 2.1 Create GenerationHistoryService

**File**: `frontend/lib/services/generation_history_service.dart`

- [x] Create new service class extending `ChangeNotifier`

- [x] Define state properties:
  - [x] `List<Map<String, dynamic>> _generationHistory = []`
  - [x] `String? _parentGenerationId` (track history untuk parent mana)
  - [x] `String? _errorMessage`
  - [x] `HistoryViewState _viewState = HistoryViewState.idle`

- [x] Add getters:
  - [x] `HistoryViewState get viewState => _viewState`
  - [x] `List<Map<String, dynamic>> get generationHistory => _generationHistory`
  - [x] `bool get isLoading => _viewState == HistoryViewState.loading`
  - [x] `String? get errorMessage => _errorMessage`

- [x] Implement method: `fetchParentChainHistory(String parentGenerationId)`
  - [x] Validate `parentGenerationId` tidak null/empty
  - [x] Set `_viewState = HistoryViewState.loading` → `notifyListeners()`
  - [x] Call API: `GET /api/media-generations?parent_id={parentId}`
  - [x] Parse response sebagai `List<Map<String, dynamic>>`
  - [x] Sort by `created_at` ascending (parent first)
  - [x] Update `_generationHistory = sorted_list`
  - [x] Set `_parentGenerationId = parentId`
  - [x] Set `_viewState = HistoryViewState.success` → `notifyListeners()`
  - [x] Handle error case:
    - [x] Catch DioException
    - [x] Resolve error message via `_resolveErrorMessage(e)`
    - [x] Set `_errorMessage = resolved_message`
    - [x] Set `_viewState = HistoryViewState.error` → `notifyListeners()`
    - [x] Rethrow exception

- [x] Implement method: `refreshHistory()`
  - [x] Refetch current parent chain if `_parentGenerationId` exists
  - [x] Call `fetchParentChainHistory(_parentGenerationId)`

- [x] Implement method: `getHistoryForGeneration(String generationId)`
  - [x] Query `ApiService` untuk metadata generasi → get parent_id
  - [x] If parent exists: call `fetchParentChainHistory(parentId)`
  - [x] Else: call `fetchParentChainHistory(generationId)` (treat sebagai parent)

- [x] Implement error resolution helper: `String _resolveErrorMessage(dynamic e)`
  - [x] Implement chain: try `response['error']['message']` → `response['message']` → generic message

- [x] Add unit tests:
  - [x] Test `fetchParentChainHistory()` dengan mock API response
  - [x] Test sorting happens correctly
  - [x] Test error handling — state updates to error, message set
  - [x] Test `refreshHistory()` — calls fetch again

---

### 2.2 Update MediaGenerationService — suggestFreelancers Error Propagation

**File**: `frontend/lib/services/media_generation_service.dart` (lines ~240-255)

**Current Code**:
```dart
Future<List<FreelancerSuggestion>> suggestFreelancers(String generationId) async {
  try {
    final res = await apiService.suggestFreelancers(
      generationId: generationId,
    );
    return FreelancerSuggestion.fromJsonList(res);
  } catch (e) {
    debugPrint('Error suggesting freelancers: $e');
    return []; // ❌ Silent fail
  }
}
```

- [x] Replace with:
  ```dart
  Future<List<FreelancerSuggestion>> suggestFreelancers(String generationId) async {
    try {
      final response = await _apiService.dio.post(
        '/media-generations/$generationId/suggest-freelancers',
      );
      // ... parsing logic ...
    } on DioException catch (error) {
      final message = _resolveDioErrorMessage(error, endpoint: '/media-generations/$generationId/suggest-freelancers');
      throw Exception(message);
    } catch (error) {
      debugPrint('Error suggesting freelancers: $error');
      throw Exception('Failed to suggest freelancers: $error');
    }
  }
  ```

- [x] Verify `_resolveDioErrorMessage()` method exists
  - [x] Already exists in `MediaGenerationService`

- [x] Update unit tests untuk `suggestFreelancers()`
  - [x] Test success case: returns list
  - [x] Test error case: throws exception
  - [x] Verify exception message contains helpful context

---

## Phase 3: Frontend UI Layer

### 3.1 Create GenerationHistoryScreen

**File**: `frontend/lib/screens/generation_history_screen.dart` (NEW)

#### 3.1.1 Screen Structure
- [x] Create `GenerationHistoryScreen` class extending `StatefulWidget`
- [x] Constructor accepts `generationId`
  ```dart
  const GenerationHistoryScreen({required String this.generationId});
  final String generationId;
  ```

- [x] Create `_GenerationHistoryScreenState` extending `State`
- [x] Inject `GenerationHistoryService` via `ChangeNotifierProvider` atau constructor

#### 3.1.2 Lifecycle & Service Binding
- [x] In `initState()`:
  - [x] Call `service.getHistoryForGeneration(widget.generationId)`
  - [x] Add listener: `service.addListener(_onServiceChanged)`
  - [x] Set up error retry callback state

- [x] In `dispose()`:
  - [x] Remove listener: `service.removeListener(_onServiceChanged)`
  - [x] Cleanup

- [x] Implement `_onServiceChanged()` callback:
  - [x] Call `setState()` untuk rebuild sesuai state baru

#### 3.1.3 Build UI — AppBar
- [x] AppBar dengan title "Generation History" atau "Riwayat Generasi"
- [x] Back button (default atau explicit)

#### 3.1.4 Build UI — Body
- [x] Render based on `service.viewState`:

  **Loading State**:
  - [x] Render centered `CircularProgressIndicator`
  - [x] Optional: show "Loading generation history..."

  **Success State**:
  - [x] Render timeline list:
    ```dart
    ListView.builder(
      itemCount: service.generationHistory.length,
      itemBuilder: (context, index) => _buildHistoryItem(history[index])
    )
    ```
  - [x] Each item is a card:
    - [x] Generated time (formatted relative: "Just now", "2 hours ago", "3 days ago")
    - [x] Status badge (Icons + color):
      - [x] ✅ success (green, icon: Icons.check_circle)
      - [x] ⏳ processing (orange, icon: Icons.schedule)
      - [x] ❌ error (red, icon: Icons.cancel)
    - [x] Output type badge (PPTX/PDF/DOCX)
    - [x] Prompt (truncated max 100 chars, with "..." if longer)
    - [x] "View Details" button
    - [x] If is_regeneration: small info "Regenerated from..." dengan parent timestamp

  **Empty State** (shouldn't happen for parent-chain, but handle):
  - [x] Show message "No generations found"

  **Error State**:
  - [x] Centered error UI:
    - [x] Error icon: `Icons.error_outline` (red)
    - [x] Error message: `service.errorMessage`
    - [x] "Retry" button: calls `service.refreshHistory()`
  - [x] Reference: GalleryScreen error pattern (lib/screens/gallery_screen.dart lines ~95-111)

#### 3.1.5 Helper Methods
- [x] `_buildHistoryItem(Map<String, dynamic> generation) → Widget`
  - [x] Build card dengan layout di atas
  - [x] On tap "View Details": navigate/show dialog dengan full generation info

- [x] `_formatTimestamp(String createdAt) → String`
  - [x] Return relative time ("just now", "2h ago", "3 days ago")
  - [x] Use `timeago` package atau `DateTime.parse().difference()`

- [x] `_getStatusIcon(String status) → Widget`
  - [x] Return icon + color based on status enum

- [x] `_onDetailsTap(String generationId)`
  - [x] Navigate to generation details screen (bisa reuse existing, atau show modal)
  - [x] OR show full info dialog

#### 3.1.6 Testing
- [x] Widget test: `generation_history_screen_test.dart`
  - [x] Test loading state renders CircularProgressIndicator
  - [x] Test success state renders list with N items
  - [x] Test error state renders error UI + retry button
  - [x] Test retry button calls `service.refreshHistory()`
  - [x] Test navigation on "View Details" tap

---

### 3.2 Update MediaGenerationStatusCard

**File**: `frontend/lib/widgets/media_generation_status_card.dart` (existing, modify)

#### 3.2.1 Add View History Button
- [x] In `MediaGenerationStatusCard` constructor, add `onViewHistory` callback
- [x] In `build()` method, add new button:
  ```dart
  if (onViewHistory != null) {
    TextButton.icon(
      onPressed: onViewHistory,
      icon: Icons.history_rounded,
      label: const Text('Lihat Riwayat Generasi'),
    )
  }
  ```

- [x] Style:
  - [x] Match existing button styling
  - [x] Icon: `Icons.history_rounded`
  - [x] Use `TextButton` with underline for subtle look below main actions
  - [x] Padding + height consistent

#### 3.2.2 Button Positioning
- [x] Add View History button below the action cluster
- [x] Posisi: subtle link below "Regenerate" and "Hire Freelancer"

#### 3.2.3 Testing
- [x] Widget test:
  - [x] Test View History button appears when callback provided
  - [x] Test button doesn't appear when callback null
  - [x] Test onPressed calls callback

---

### 3.3 Update FreelancerSuggestionsScreen — Error State (FHAS-07)

**File**: `frontend/lib/screens/hiring/freelancer_suggestions_screen.dart` (existing, modify)

#### 3.3.1 Add Error State
- [x] Add state field: `String? _errorMessage`
- [x] Update `_fetchSuggestions()`:
  - [x] Add `try-catch` block
  - [x] On error: `setState(() { _errorMessage = e.message; })`
- [x] Update `build()`:
  - [x] Check `if (_errorMessage != null)` → show `_buildErrorState()`
- [x] Implement `_buildErrorState()`:
  - [x] Display error icon (red)
  - [x] Display message from API
  - [x] Add "Coba Lagi" button → calls `_fetchSuggestions()` again
- [x] Ensure "Post Public Task" fallback is still accessible or mentioned in empty/error state if appropriate

#### 3.3.5 Testing
- [x] Unit test:
  - [x] Mock `apiService.suggestFreelancers()` to throw Exception
  - [x] Verify `_errorMessage` is set
  - [x] Verify UI shows error state

- [x] Widget test:
  - [x] Test error state renders error icon + message + retry button
  - [x] Test retry button calls `_fetchSuggestions()` again
  - [x] Differentiate from empty state (verify both UIs are different)

---

## Phase 4: Integration & Navigation

### 4.1 Route Registration

**File**: `frontend/lib/main.dart` or routing config file

- [x] Register route untuk `GenerationHistoryScreen`:
  - [x] Using direct Navigator: no registration needed (use `Navigator.push()`)

- [x] Update navigation:
  - [x] In `HomeScreen.dart`, pass `onViewHistory` callback to `MediaGenerationStatusCard`:
    ```dart
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => GenerationHistoryScreen(generationId: _generationId),
    ));
    ```

### 4.2 Provider Setup (If Using Provider)

- [x] Ensure `GenerationHistoryService` is provided in widget tree:
  - [x] Using Singleton pattern (consistent with other services in the app)

### 4.3 API Service Integration

- [x] Verify `ApiService.suggestFreelancers()` exists and is called correctly
- [x] Ensure endpoint matches backend: `POST /api/media-generations/{id}/suggest-freelancers`
- [x] Verify response parsing untuk `FreelancerSuggestion` model

---

## Phase 5: Testing & Validation

### 5.1 Backend API Testing

- [ ] Postman/curl test parent-child query endpoint:
  - [ ] Request: `GET /api/media-generations?parent_id={validParentId}`
  - [ ] Response: 200 OK, array of 2+ generations sorted by created_at
  - [ ] Request: `GET /api/media-generations?parent_id={invalidId}`
  - [ ] Response: 200 OK, empty array (or error, depends on backend)

### 5.2 Unit Testing

#### Service Tests
- [x] `test/services/generation_history_service_test.dart`:
  - [x] [x] Test `fetchParentChainHistory()` success path
  - [x] [x] Test error path — DioException thrown, state updates to error
  - [x] [x] Test `refreshHistory()` — calls fetch again
  - [x] [x] Test sorting — oldest first order

- [x] `test/services/media_generation_service_test.dart`:
  - [x] [x] Update `suggestFreelancers()` test
  - [x] [x] Test exception thrown on error
  - [x] [x] Test success path still works

#### Widget Tests
- [x] `test/screens/generation_history_screen_test.dart`:
  - [x] [x] Test loading state
  - [x] [x] Test success state — renders items
  - [x] [x] Test error state — renders error UI + retry
  - [x] [x] Test retry button functionality

- [x] `test/widgets/media_generation_status_card_history_test.dart`:
  - [x] [x] Test View History button visibility logic
  - [x] [x] Test navigation callback execution

- [x] `test/screens/freelancer_suggestions_screen_error_test.dart`:
  - [x] [x] Test error state UI renders
  - [x] [x] Test differentiation from empty state
  - [x] [x] Test retry button works

### 5.3 Integration Testing (E2E)

#### History Flow
- [ ] [ ] Create test media generation (manually atau via API)
- [ ] [ ] Regenerate media (via app UI)
- [ ] [ ] When generation completes, verify "View History" button appears
- [ ] [ ] Tap button → `GenerationHistoryScreen` loads
  - [ ] [ ] Loading indicator briefly shown
  - [ ] [ ] Parent + child generation displayed
  - [ ] [ ] Correct timestamps shown
  - [ ] [ ] Status badges correct
- [ ] [ ] Tap "View Details" on item → shows full generation info atau details screen
- [ ] [ ] Test error scenario:
  - [ ] [ ] Simulate network error (disconnect, mock API failure)
  - [ ] [ ] Error UI displays
  - [ ] [ ] Tap "Retry" → recovers, shows history

#### Freelancer Suggestions Error Flow
- [ ] [ ] In hiring flow, get to suggestions screen
- [ ] [ ] Simulate network error (mock API failure atau disconnect)
  - [ ] [ ] Error state shows (not empty state)
  - [ ] [ ] Error message displayed (e.g., "Network timeout")
  - [ ] [ ] Retry button visible
- [ ] [ ] Tap "Retry":
  - [ ] [ ] Fetch happens again
  - [ ] [ ] Success or retry error message
- [ ] [ ] Generate scenario with no matching freelancers:
  - [ ] [ ] Empty state shows (different UI from error state)
  - [ ] [ ] Message: "No matching freelancers found"

### 5.4 Regression Testing

- [ ] [ ] Verify existing flows not broken:
  - [ ] [ ] Regenerate still works (new generation creates child correctly)
  - [ ] [ ] Hire freelancer auto-suggest flow (suggestFreelancers() success path)
  - [ ] [ ] Home screen → generation status card → all buttons functional

---

## Implementation Roadmap

**Recommended Order** (can parallelize):

1. **Phase 1** (1-2 hours) — Backend verification (minimal work)
2. **Phase 2** (2-3 hours) — Create service layer (isolated, no UI dependency)
   - 2.1 GenerationHistoryService (parallel with 2.2)
   - 2.2 Update media_generation_service error handling
3. **Phase 3** (3-4 hours) — Create UI layer
   - 3.1 GenerationHistoryScreen (can start after 2.1)
   - 3.2 Update MediaGenerationStatusCard (parallel)
   - 3.3 Update FreelancerSuggestionsScreen (parallel, independent from history)
4. **Phase 4** (1 hour) — Integration & navigation
5. **Phase 5** (2-3 hours) — Testing & validation

**Total Estimate**: 9-13 hours

---

## Key Files Reference

| File | Type | Change |
|---|---|---|
| `backend/app/Http/Controllers/MediaGenerationController.php` | Existing | Verify query endpoint exists |
| `frontend/lib/services/generation_history_service.dart` | New | Create new service |
| `frontend/lib/services/media_generation_service.dart` | Modify | Update `suggestFreelancers()` |
| `frontend/lib/screens/generation_history_screen.dart` | New | Create history screen |
| `frontend/lib/widgets/media_generation_status_card.dart` | Modify | Add View History button |
| `frontend/lib/screens/hiring/freelancer_suggestions_screen.dart` | Modify | Add error state |
| `frontend/lib/main.dart` | Modify | Register route if needed |
| Tests (multiple files) | New/Modify | Unit + widget tests |

---

## Troubleshooting & Edge Cases

| Scenario | Handling |
|---|---|
| **Parent generation not found** | Query endpoint returns empty array; empty state shown |
| **Network error on history fetch** | Show error UI with retry; rethrow exception from service |
| **No freelancers match criteria** | Empty state (different from error); message "No matching freelancers" |
| **Partial history load** (some items error) | Show what loaded; allow refresh |
| **User navigates away from history screen** | Cleanup listener; no memory leak |
| **User rapid-clicks Retry button** | Debounce or disable button during fetch `_isLoading` state |

---

## Further Considerations (Defer to Next Phase)

1. **Generation Details Dialog/Screen**
   - [ ] Do we need dedicated "Generation Details" view, or info in history card?
   - Recommendation: Modal dialog showing full prompt + output preview

2. **History Filtering/Sorting Options**
   - [ ] Filter by status? Sort options?
   - Recommendation: Start simple (chronological only), add filters later

3. **Deletion/Cleanup**
   - [ ] Should users delete historical generations?
   - Recommendation: Defer to Phase 2 (focus on viewing for now)

4. **Bulk Regenerate**
   - [ ] Option to regenerate multiple items at once?
   - Recommendation: Future feature, start with single regenerate

5. **Export History**
   - [ ] Export generation history as PDF/CSV?
   - Recommendation: Defer to future analytics feature

---

## Checklist Summary

**Phase 1 (Backend)**: [x] ✅ COMPLETE — 4 files modified/created, 7 tests PASS, 47 assertions  
**Phase 2 (Services)**: [x] 100% — 2.1 (Implemented) + 2.2 (Implemented)  
**Phase 3 (UI)**: [x] 100% — 3.1, 3.2, 3.3 Implemented (UI only, integration next)  
**Phase 4 (Integration)**: [x] 100% — Navigation wired in HomeScreen  
**Phase 5 (Testing)**: [x] 80% — Unit & Widget tests COMPLETE, Integration pending manual verification  

**Total**: ~110 checkboxes for comprehensive tracking

---

**Document History**:
- 2026-04-16 — Detailed implementation plan created with checkboxes for RF-05 & FHAS-07

