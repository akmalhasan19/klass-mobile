# Implementation Plan — Komunikasi Flutter ⇄ Laravel (HF Space + Supabase)

> **Stack**: Flutter (Dio, Riverpod, flutter_secure_storage) ⇄ Laravel 11 (Sanctum, /v1/) ⇄ Hugging Face Docker Space + Supabase PostgreSQL + Supabase Storage
>
> **Urutan eksekusi mengikuti dependency graph**: File Structure → Env/CORS/Deploy → API Design → Auth Flow → Network Layer → State Management → Security → Supabase Storage
>
> **Estimasi total**: 10–15 hari kerja (1 developer)

---

## 📋 Task 1 — File Structure Refactor (Frontend & Backend)

**Tujuan**: Reorganisasi folder agar scalable sebelum migrasi besar Riverpod.
**Estimasi**: 1–2 hari

### Frontend

- [x] Buat struktur folder baru: `lib/app/`, `lib/core/`, `lib/features/`, `lib/shared/widgets/`
- [x] Pindahkan `main.dart` ke `lib/app/app.dart` (root MaterialApp) + tetap maintain `lib/main.dart` sebagai entry point
- [x] Buat `lib/app/env.dart` (placeholder, isi di Task 2)
- [x] Buat `lib/core/network/` (placeholder untuk dio_provider, interceptors)
- [x] Buat `lib/core/storage/` (placeholder untuk SecureTokenStore)
- [x] Buat `lib/core/utils/` dan pindahkan `utils/api_debug_info.dart`, `utils/role_guard.dart`, `utils/auth_guard.dart`
- [x] Buat `lib/features/auth/` dengan subfolder `data/`, `providers/`, `screens/`, `widgets/`
- [x] Buat `lib/features/home/`, `lib/features/gallery/`, `lib/features/media_generation/`, `lib/features/search/`, `lib/features/bookmark/`, `lib/features/profile/`, `lib/features/freelancer/`
- [x] Pindahkan `widgets/` cross-feature ke `lib/shared/widgets/` (bottom_nav, skeleton_loaders, dsb)
- [x] Pindahkan `screens/` ke folder features masing-masing
- [x] Pindahkan `services/` ke folder `features/<name>/data/` (bertahap, minimal auth dulu)
- [x] Update semua import di seluruh codebase agar resolve ke struktur baru
- [x] Jalankan `flutter analyze` dan pastikan zero error

### Backend

- [x] Buat namespace `App\Http\Controllers\Api\V1\`
- [x] Pindahkan semua controller di `app/Http/Controllers/Api/` ke `app/Http/Controllers/Api/V1/`
- [x] Update namespace semua controller yang dipindah
- [x] Update import di `routes/api.php` agar point ke namespace `V1`
- [x] Jalankan `php artisan route:list` dan pastikan semua route masih terdaftar
- [x] Jalankan `php artisan test` dan pastikan test pass

---

## 📋 Task 2 — Environment Management + CORS + HF Deployment Verification

**Tujuan**: Setup config per-env FE & BE, enable CORS, verify deploy HF Space bisa diakses dari Flutter.
**Estimasi**: 0.5–1 hari

### Flutter — `lib/app/env.dart`

- [x] Buat class `Env` dengan field `apiBaseUrl`, `hfSpaceUrl`, `isProd`, `enableVerboseLogging` pakai `String.fromEnvironment` / `bool.fromEnvironment`
- [x] Default `apiBaseUrl` ke `http://192.168.18.6:8000/api/v1`
- [x] Hapus class `ApiConfig._overrideBaseUrl` dan redirect semua pemanggilan ke `Env`
- [x] Update `api_config.dart` agar `baseUrl` baca dari `Env.apiBaseUrl`
- [x] Tambah dokumentasi inline cara run: `flutter run --dart-define=API_BASE_URL=... --dart-define=IS_PROD=true`

### Flutter — Build Flavors (opsional, recommended untuk release)

- [x] Tambah `productFlavors { dev {...} prod {...} }` di `android/app/build.gradle`
- [x] Buat `android/app/src/dev/res/values/strings.xml` (app_name "Klass Dev")
- [x] Buat `android/app/src/prod/res/values/strings.xml` (app_name "Klass")
- [x] Buat scheme iOS `Dev` & `Prod` + xcconfig masing-masing
- [x] Update CI/build script untuk support flavor

### Backend — `.env` HF Space injection

- [x] Pastikan `backend/docker/entrypoint.sh` generate `.env` dari environ saat boot (cek baris seputar APP_KEY)
- [x] Tambahkan fallback di entrypoint: jika `APP_KEY` kosong, generate via `php artisan key:generate --force` (untuk first boot HF Space)
- [x] Tambah handling jika `RUN_MIGRATIONS=true` maka `php artisan migrate --force` (sudah ada, verify)

### Backend — CORS (gap yang harus ditutup)

- [x] Publish config: `php artisan config:publish cors` (atau buat manual `config/cors.php`)
- [x] Set `paths` => `['api/*', 'sanctum/csrf-cookie']`
- [x] Set `allowed_origins` => `explode(',', env('CORS_ALLOWED_ORIGINS', '*'))`
- [x] Set `allowed_methods` => `['*']`
- [x] Set `allowed_headers` => `['*']`
- [x] Set `supports_credentials` => `true`
- [x] Register CORS middleware di `bootstrap/app.php`: `$middleware->api(prepend: [\Illuminate\Http\Middleware\HandleCors::class])`
- [x] Tambah `CORS_ALLOWED_ORIGINS` ke `.env.example` + dokumentasi HF Secrets

### HF Space — Deployment Verification

- [x] Push ke HF Space dan tunggu build selesai
- [x] Set semua Secrets di HF Space Settings: `APP_KEY`, `APP_URL`, `DB_*`, `SANCTUM_STATEFUL_DOMAINS`, `CORS_ALLOWED_ORIGINS`
- [x] Set `RUN_MIGRATIONS=true` untuk first deploy
- [x] Cek `https://<space>.hf.space/up` return 200
- [x] Cek `https://<space>.hf.space/api/v1/` return JSON `{ success: true, version: "1.0.0" }`
- [x] Test dari Flutter dengan `--dart-define=API_BASE_URL=https://<space>.hf.space/api/v1`
- [x] Verifikasi CORS preflight `OPTIONS` dari browser console tidak ada error

---

## 📋 Task 3 — API Design: Versioning /v1/, Response Format, Validation

**Tujuan**: Wrap semua route di `/v1/`, standardisasi error payload, pindahkan inline validation ke FormRequest.
**Estimasi**: 1–2 hari

### Versioning /v1/

- [ ] Edit `routes/api.php`: wrap semua route dalam `Route::prefix('v1')->group(function () { ... })`
- [ ] Pastikan route publik `/` tetap di luar prefix v1 (health check)
- [ ] Update semua endpoint path di Flutter service dari `/auth/login` → `/v1/auth/login`, dst (macro search-replace perlu hati-hati)
- [ ] Update semua test backend yang hit endpoint lama
- [ ] Update semua test frontend yang mock endpoint

### Response Format Standardisasi

- [ ] Pertahankan `ApiResponseTrait` schema: `{ success, message, data, meta? }`
- [ ] Tambah field `error.code` (stable string) ke semua error response
  - [ ] Update `ValidationException` render di `bootstrap/app.php` → tambah `error: { code: 'VALIDATION_FAILED' }`
  - [ ] Update `ModelNotFoundException` → `error: { code: 'NOT_FOUND' }`
  - [ ] Update `AuthenticationException` → `error: { code: 'UNAUTHENTICATED' }`
  - [ ] Update catch-all `Throwable` → `error: { code: 'SERVER_ERROR' }`
- [ ] Standardkan urutan field di semua API Resources (timestamp + casts konsisten)
- [ ] Tambahkan `timestamp` ISO-8601 ke semua response (optional but recommended)

### Validation — FormRequest untuk semua endpoint

- [ ] Buat `ResetPasswordRequest` (pindahkan inline validation dari `AuthController::verifyAndResetPassword`)
- [ ] Buat `GetSecurityQuestionRequest` (pindahkan inline validation dari `AuthController::getSecurityQuestion`)
- [ ] Audit semua controller method yang masih pakai `$request->validate()` inline, pindahkan ke FormRequest
- [ ] Pastikan semua FormRequest extend `ApiFormRequest` (sudah ada base class)

### Flutter — DTO + Exception Parser

- [ ] Buat `lib/core/network/api_error.dart` dengan sealed class `AppException` + subclass: `NetworkException`, `ServerException`, `ValidationException`, `UnauthorizedException`, `NotFoundException`
- [ ] Tambah field `code` di setiap subclass (matching backend `error.code`)
- [ ] Buat parser `AppException.fromDioError(DioException e)` yang map `DioExceptionType` + status code + backend `error.code` ke subclass yang sesuai

---

## 📋 Task 4 — Auth Flow: Sanctum Token Lifecycle + Secure Storage

**Tujuan**: Pindah token ke SecureStorage, tambah endpoint refresh, auto-refresh di interceptor, logout cleanup.
**Estimasi**: 1–2 hari

### Backend — Sanctum Hardening

- [ ] Update `config/sanctum.php`: ubah `'expiration' => null` menjadi `'expiration' => env('SANCTUM_EXPIRATION_MINUTES', 43200)` (30 hari)
- [ ] Tambah `SANCTUM_EXPIRATION_MINUTES=43200` ke `.env.example`
- [ ] Buat endpoint `POST /v1/auth/refresh` di `AuthController`:
  - [ ] Revoke current token
  - [ ] Issue token baru
  - [ ] Return `{ success: true, data: { token: <new> } }`
- [ ] Register route `POST /v1/auth/refresh` di `routes/api.php` dalam group `auth:sanctum`
- [ ] Tambah rate limit ke auth endpoints: `Route::post('/login', ...)->middleware('throttle:5,1')`
- [ ] Tambah rate limit ke register: `throttle:3,1`
- [ ] Tambah rate limit ke reset password: `throttle:3,1`
- [ ] Log failed login attempts (IP, email, timestamp) untuk audit

### Backend — Tests

- [ ] Test `POST /v1/auth/refresh` return new token
- [ ] Test old token revoked setelah refresh
- [ ] Test expired token ditolak
- [ ] Test rate limit trigger

### Flutter — flutter_secure_storage

- [ ] Tambah dependency `flutter_secure_storage: ^9.2.2` di `pubspec.yaml`
- [ ] Buat `lib/core/storage/secure_token_store.dart`:
  - [ ] Method `Future<void> write(String token)`
  - [ ] Method `Future<String?> read()`
  - [ ] Method `Future<void> delete()`
  - [ ] Key const: `auth_token`, `user_data`
- [ ] Tambah `user_data` ke SecureStorage (PII protection)
- [ ] Update `lib/android/app/build.gradle` pastikan `minSdkVersion >= 18` (syarat flutter_secure_storage)

### Flutter — AuthService Refactor

- [ ] Inject `SecureTokenStore` ke `AuthService` (constructor)
- [ ] Ganti semua `SharedPreferences.getString('auth_token')` → `SecureTokenStore.read()`
- [ ] Ganti semua `prefs.setString('auth_token', ...)` → `SecureTokenStore.write(...)`
- [ ] Ganti semua `prefs.remove('auth_token')` → `SecureTokenStore.delete()`
- [ ] Update `isLoggedIn()` baca dari SecureStorage
- [ ] Update `getUserRole()` baca user_data dari SecureStorage
- [ ] Update `getMe()` simpan user_data ke SecureStorage
- [ ] Update `logout()` hapus auth_token + user_data dari SecureStorage + invalidate cache

### Flutter — Auth Interceptor (401 refresh logic)

- [ ] Buat `lib/core/network/auth_interceptor.dart` extends `Interceptor`
- [ ] `onRequest`: baca token via `SecureTokenStore`, inject `Authorization: Bearer <token>`
- [ ] `onError` (401):
  - [ ] Cek jika endpoint refresh sendiri → jangan retry, langsung logout
  - [ ] Cek jika sudah pernah retry request ini → logout, jangan infinite loop
  - [ ] Panggil `POST /v1/auth/refresh` → simpan token baru ke SecureStorage
  - [ ] Retry original request dengan token baru (1x only)
  - [ ] Jika refresh gagal → hapus token + trigger `AuthState.logout` + redirect `/login`
- [ ] Tambah flag `extra['isRefresh']` di request refresh untuk avoid loop

### Flutter — Logout Flow

- [ ] Panggil `POST /v1/auth/logout` ke backend (revoke server-side)
- [ ] Hapus token + user_data dari SecureStorage
- [ ] Invalidate auth-scoped cache (key prefix `api_cache_`)
- [ ] Reset `AuthState` ke unauthenticated
- [ ] Navigate ke login screen

---

## 📋 Task 5 — Network Layer: Dio Refactor

**Tujuan**: Pecah ApiService monolitik jadi dio_provider + interceptors terpisah per concern.
**Estimasi**: 1 hari

### Dio Provider (Riverpod)

- [ ] Buat `lib/core/network/dio_provider.dart`:
  - [ ] `Provider<Dio>` return configured Dio instance
  - [ ] `BaseOptions` dengan `Env.apiBaseUrl`, timeout dari `ApiConfig`
  - [ ] Headers default `Accept: application/json`
- [ ] Register interceptors: AuthInterceptor, RetryInterceptor, CacheInterceptor
- [ ] Daftarkan LoggingInterceptor hanya jika `!Env.isProd`

### Interceptor Files (extract dari ApiService monolitik)

- [ ] Buat `lib/core/network/auth_interceptor.dart` (dari Task 4)
- [ ] Buat `lib/core/network/retry_interceptor.dart`:
  - [ ] Pindahkan logic retry GET dari `ApiService.onError` (baris 96–117)
  - [ ] Hanya retry GET requests
  - [ ] Linear backoff: `delay = retryDelayMs * (retries + 1)`
  - [ ] Max retries dari `ApiConfig.maxRetries`
  - [ ] Retry pada: `connectionTimeout`, `receiveTimeout`, `sendTimeout`, `connectionError`, `unknown && response == null`
- [ ] Buat `lib/core/network/logging_interceptor.dart`:
  - [ ] Pindahkan structured logging dari `ApiService` (baris 42–49, 62–70, 83–93)
  - [ ] Gate via `FeatureFlags.enableVerboseApiLogging`
  - [ ] Log REQUEST, RESPONSE, ERROR dengan timestamp ISO-8601
- [ ] Pindahkan `cache_interceptor.dart` ke `lib/core/network/cache_interceptor.dart` (existing logic tetap)

### Caching Strategy

- [ ] Mapping per-endpoint cache policy:
  - [ ] `/v1/topics`, `/v1/contents` → cache 5 menit
  - [ ] `/v1/auth/me` → no cache
  - [ ] `/v1/media-generations` → no cache (user-specific, mutable)
  - [ ] POST/PUT/DELETE → invalidate related GET key
- [ ] Upgrade `CacheInterceptor` pakai `dio_cache_interceptor` + `dio_cache_interceptor_hive_store` (sudah dep) untuk LRU + TTL per-route
- [ ] Tambah invalidation: saat POST/PUT/DELETE sukses, hapus cache key dengan prefix yang relevan

### CancelToken & Lifecycle

- [ ] Tambah `CancelToken` per screen, di-dispose saat `State.dispose` (anti memory leak)
- [ ] Saat pop screen, cancel semua in-flight request

### Removed / Cleanup

- [ ] Hapus `ApiService` singleton (digantikan dioProvider)
- [ ] Update semua service yang masih pakai `ApiService().dio` → pakai `ref.watch(dioProvider)`
- [ ] Hapus `monitoring_service.dart` jika sudah terpisah di LoggingInterceptor
- [ ] Jalankan `flutter test` dan update test yang masih mock `ApiService`

---

## 📋 Task 6 — State Management: Riverpod Migration

**Tujuan**: Migrasi StatefulWidget+service ke Riverpod. Bertahap per feature.
**Estimasi**: 3–5 hari

### Foundation

- [ ] Tambah deps di `pubspec.yaml`:
  - [ ] `flutter_riverpod: ^2.5.1`
  - [ ] (opsional) `riverpod_annotation: ^2.3.5` + `riverpod_generator` + `build_runner` (jika pakai codegen)
- [ ] Wrap `main.dart` dengan `ProviderScope(child: KlassApp(...))`
- [ ] Buat `lib/core/providers/core_providers.dart`: `dioProvider`, `secureTokenStoreProvider`
- [ ] Setup `ConsumerWidget` base mixin kalau perlu

### Week 1 — Auth Feature Migration

- [ ] Buat `features/auth/data/auth_api.dart` (auth API client: login, register, me, refresh, logout)
- [ ] Buat `features/auth/providers/auth_repository_provider.dart`
- [ ] Buat `features/auth/providers/auth_provider.dart` dengan `StateNotifier<AsyncValue<AuthState>>`
- [ ] Implement `AuthNotifier`: `init()`, `login()`, `register()`, `logout()`, `refresh()`
- [ ] Migrasi `login_screen` ke `ConsumerWidget`
- [ ] Migrasi `register_screen` ke `ConsumerWidget`
- [ ] Update `MainShell` baca `AuthState` dari provider (bukan `AuthService` langsung)
- [ ] Update `profile_screen` baca user data dari provider
- [ ] Hapus `AuthService` singleton, pindah logic ke `AuthRepository` + `AuthNotifier`
- [ ] Update `test/services/` dan `test/screens/` untuk auth flow

### Week 2 — Home, Gallery, Bookmark, Search

- [ ] Migrasi `HomeService` → `features/home/data/home_api.dart` + `home_provider.dart`
- [ ] Migrasi `GalleryService` → `features/gallery/data/gallery_api.dart` + `gallery_provider.dart`
- [ ] Migrasi `SearchService` → `features/search/data/search_api.dart` + `search_provider.dart`
- [ ] Migrasi `BookmarkScreen` state ke provider (jika perlu)
- [ ] Update screen bersangkutan ke `ConsumerWidget`
- [ ] Update test bersangkutan

### Week 3 — Media Generation, Profile, Freelancer

- [ ] Migrasi `MediaGenerationService` → `features/media_generation/data/` + `providers/`
- [ ] Migrasi `MediaGenerationActionService` ke provider
- [ ] Migrasi `GenerationHistoryService` ke provider
- [ ] Migrasi `ProjectService` → `features/media_generation/data/project_api.dart`
- [ ] Migrasi `freelancer_hiring_flow_controller.dart` → `features/freelancer/providers/`
- [ ] Migrasi `LocalePreferencesService` → `core/providers/locale_provider.dart`
- [ ] Update semua screen bersangkutan ke `ConsumerWidget`
- [ ] Update test bersangkutan

### Cleanup

- [ ] Hapus folder `lib/services/` (emptied)
- [ ] Hapus folder `lib/controllers/` (emptied)
- [ ] Hapus folder `lib/screens/` (emptied)
- [ ] Hapus folder `lib/widgets/` (emptied, pindah ke shared/services)
- [ ] Jalankan `flutter analyze` pastikan zero error
- [ ] Jalankan `flutter test` pastikan semua pass
- [ ] Update `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` jika ada, dokumentasi struktur baru

---

## 📋 Task 7 — Deployment Hardening (HF Space + Dockerfile)

**Tujuan**: Optimize Dockerfile, setup healthcheck, non-root user, HTTPS, Supabase Storage integration.
**Estimasi**: 1–2 hari

### Dockerfile Improvements

- [ ] Tambah `HEALTHCHECK` di `Dockerfile`:
  ```dockerfile
  HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost:${PORT:-7860}/up || exit 1
  ```
- [ ] Tambah `USER www-data` di akhir Dockerfile (pastikan files sudah chown)
- [ ] Verify `entrypoint.sh` running as www-data sukses (supervisord perlu root prefix, su-exec ke www-data untuk artisan)
- [ ] Tambah label OCI metadata di Dockerfile (version, maintainer)
- [ ] Verify multi-stage build masih efisien (layer cache)

### HF Space Metadata

- [ ] Buat/Update `README.md` di root dengan HF Space frontmatter:
  ```yaml
  ---
  title: Klass Backend
  emoji: 📚
  colorFrom: blue
  colorTo: indigo
  sdk: docker
  pinned: false
  ---
  ```
- [ ] Add description di body README

### Nginx Hardening

- [ ] Verify `server_tokens off` (sudah ada baris 20 `nginx.conf`)
- [ ] Tambah `add_header X-Content-Type-Options nosniff`
- [ ] Tambah `add_header X-Frame-Options DENY`
- [ ] Tambah `add_header Referrer-Policy no-referrer`
- [ ] Limit `client_max_body_size` ke 25m (sudah ada, verify)
- [ ] Tambah gzip compression config

### Supabase Storage Integration (ephemeral HF)

- [ ] Tambah dep `league/flysystem-aws-s3-v3` di `backend/composer.json`
- [ ] Konfigurasi disk `supabase` di `config/filesystems.php`:
  - [ ] `driver` => `s3`
  - [ ] `key` => `env('SUPABASE_STORAGE_KEY')`
  - [ ] `secret` => `env('SUPABASE_STORAGE_SECRET')`
  - [ ] `region` => `env('SUPABASE_STORAGE_REGION')`
  - [ ] `bucket` => `env('SUPABASE_STORAGE_BUCKET')`
  - [ ] `endpoint` => `env('SUPABASE_STORAGE_ENDPOINT')`
- [ ] Set `FILESYSTEM_DISK=supabase` di `.env.example` + HF Secrets
- [ ] Update `FileUploadController` agar pakai disk `supabase` (stream file ke Supabase, bukan storage/app local)
- [ ] Update `AvatarController` agar pakai disk `supabase`
- [ ] Test upload file dari Flutter ke HF backend → verify file di Supabase Storage bucket
- [ ] Document di `.env.example` cara dapatkan kredensial Supabase S3

---

## 📋 Task 8 — Security Hardening

**Tujuan**: Hardening pass di atas layer yang sudah jalan.
**Estimasi**: 1–2 hari

### Token Storage (sudah didahului Task 4)

- [ ] Verify flutter_secure_storage aktif di iOS (Keychain) + Android (EncryptedSharedPreferences)
- [ ] Tambah `minSdkVersion 18` di `android/app/build.gradle` (syarat flutter_secure_storage)
- [ ] Test token survive app restart
- [ ] Test token tidak survive uninstall (secure storage auto-clean)

### Backend Token Hardening

- [ ] Set `SANCTUM_EXPIRATION_MINUTES=43200` di HF Secrets prod
- [ ] Verify expired token ditolak
- [ ] Tambah rate limit per-user ke media generation: `throttle:10,1`
- [ ] Log failed login attempts dengan IP + email

### Certificate Pinning (Dio)

- [ ] Dapatkan SHA-256 fingerprint cert HF Space (`openssl s_client -connect <space>.hf.space:443 | openssl x509 -fingerprint -sha256`)
- [ ] Tambah config `pinnedFingerprints` di `Env` (dart-define)
- [ ] Implement IOHttpClientAdapter dengan `badCertificateCallback` yang verify fingerprint
- [ ] Disable pinning di dev mode (boleh self-signed cert localhost)
- [ ] Test prod build dengan pinning aktif ke HF Space

### Input Sanitization

- [ ] Audit semua controller method, pastikan pakai FormRequest (seharusnya selesai di Task 3)
- [ ] File upload: validate mime + size + extension whitelist
- [ ] API Resource `when()` filter output untuk hindari mass-assignment leak field sensitif
- [ ] Tambah middleware `TrimStrings` + `ConvertEmptyStringsToNull` di bootstrap (di-load oleh default Laravel, verify)

### Other Hardening

- [ ] Verify `APP_DEBUG=false` di prod (Dockerfile baris 92 sudah set, verify HF Secrets tidak override)
- [ ] Verify `SESSION_DRIVER=database` (sudah ada di .env.example)
- [ ] Hapus `TELESCOPE_ENABLED` jika tidak diaktifkan (pastikan tidak ada debug toolbar di prod)
- [ ] Audit `storage/logs` tidak exposed via nginx (location block sudah ada di nginx.conf:55, verify)
- [ ] Tambah `throttle:60,1` default ke API group (global rate limit)
- [ ] Setup log rotation di supervisord untuk queue worker output

---

## 📋 Task 9 — Test Suite Update & Documentation

**Tujuan**: Pastikan test suite pass setelah semua migration, dokumentasi baru up-to-date.
**Estimasi**: 1 hari

### Test Update Backend

- [ ] Update semua test yang hit endpoint lama `/api/...` → `/api/v1/...`
- [ ] Tambah test untuk `POST /v1/auth/refresh`
- [ ] Tambah test untuk rate limiting login/register
- [ ] Tambah test CORS preflight `OPTIONS`
- [ ] Jalankan `php artisan test` pastikan semua pass

### Test Update Frontend

- [ ] Update test yang mock `ApiService` singleton → mock `dioProvider` riverpod
- [ ] Update test yang pakai `SharedPreferences` mock → `FlutterSecureStorage` mock
- [ ] Tambah test untuk auth interceptor 401 refresh flow
- [ ] Tambah test untuk retry interceptor
- [ ] Tambah test untuk cache invalidation saat POST/PUT/DELETE
- [ ] Jalankan `flutter test` pastikan semua pass

### Documentation

- [ ] Update `GEMINI.md` dengan struktur folder baru
- [ ] Update `frontend/README.md` dengan cara run + dart-define
- [ ] Update `backend/README.md` dengan env HF Space + Supabase setup
- [ ] Buat `AGENTS.md` di root dengan commands:
  - [ ] `flutter test` (frontend)
  - [ ] `php artisan test` (backend)
  - [ ] `flutter analyze` (frontend)
  - [ ] `composer lint` (backend, jika ada)
- [ ] Update `.env.example` semua var baru konsisten

---

## 📋 Task 10 — Final Verification & Release

**Tujuan**: End-to-end verification sebelum deploy produksi.
**Estimasi**: 0.5 hari

- [ ] Run `flutter analyze` — must zero errors
- [ ] Run `flutter test` — must all pass
- [ ] Run `php artisan test` — must all pass
- [ ] Run `php artisan route:list` — verify semua route prefix `/v1/`
- [ ] Manual smoke test end-to-end:
  - [ ] Register → login → get me → logout
  - [ ] Login dengan wrong password → error message
  - [ ] Access protected route tanpa token → 401
  - [ ] Token expired → auto-refresh sukses
  - [ ] Refresh failed → auto-logout + redirect login
  - [ ] Upload avatar → stored di Supabase Storage
  - [ ] Media generation flow (teacher only)
  - [ ] Search + bookmark flow
- [ ] Verify HF Space cold start acceptable (first request < 10s)
- [ ] Verify HTTPS cert valid + pinning works di prod build
- [ ] Verify no `APP_DEBUG=true` leak di prod response
- [ ] Build prod APK + iOS: `flutter build apk --flavor prod --dart-define=API_BASE_URL=... --dart-define=IS_PROD=true`
- [ ] Tag release commit `v2.0.0` (breaking change: /v1/ + secure storage + riverpod)