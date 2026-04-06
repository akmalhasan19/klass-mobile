# Language Settings Implementation Plan

Dokumen ini menjadi implementation plan dan progress tracker untuk fitur pemilihan bahasa pada aplikasi Flutter `frontend/`.

## Objective

Menyediakan Settings page yang dapat diakses dari ikon gear pada Home screen, memiliki kontrol pemilihan bahasa, menerapkan bahasa terpilih ke seluruh UI aplikasi Flutter, dan menyimpan preferensi bahasa secara lokal agar tetap aktif setelah app ditutup lalu dibuka kembali.

## Scope

- Target repo: `frontend/`
- Platform: Flutter mobile app
- Bahasa awal: English dan Bahasa Indonesia
- Pengguna yang tercakup: Guest, Teacher/Guru, Freelancer
- Di luar scope: Laravel backend/admin UI dan konten dinamis yang berasal dari backend atau user-generated content

## Success Criteria

- [ ] Ikon gear pada Home screen membuka Settings screen
- [ ] Settings screen memiliki language selector yang aktif
- [ ] Perubahan bahasa meng-update seluruh UI Flutter yang dikelola client
- [ ] Bahasa terpilih tersimpan di local storage dan dipulihkan saat cold start
- [ ] Guest, Teacher/Guru, dan Freelancer mendapatkan perilaku yang sama
- [ ] Logout tidak menghapus preferensi bahasa

## Implementation Checklist

### Phase 1 - Preserve Existing Navigation Flow

- [x] Verifikasi entry point Settings dari `HomeScreen` tetap aktif
- [x] Verifikasi entry point Settings dari `FreelancerHomeScreen` tetap aktif
- [x] Pastikan `MainShell` tetap menjadi jalur navigasi ke `SettingsScreen`
- [x] Pastikan tidak ada duplicate settings entry yang membingungkan user

### Phase 2 - Add Localization Infrastructure

- [x] Update `frontend/pubspec.yaml` untuk mengaktifkan localization generation
- [x] Tambahkan dependency Flutter localization yang dibutuhkan
- [x] Buat konfigurasi localization (`l10n.yaml` jika dipakai)
- [x] Buat resource file untuk English
- [x] Buat resource file untuk Bahasa Indonesia
- [x] Wire `MaterialApp` dengan `localizationsDelegates`
- [x] Wire `MaterialApp` dengan `supportedLocales`
- [x] Tambahkan locale aktif ke root app

### Phase 3 - Add Persisted App Locale State

- [x] Tambahkan helper/service khusus untuk menyimpan dan membaca preferensi bahasa
- [x] Tentukan storage key yang stabil untuk locale preference
- [x] Load locale preference saat startup sebelum `runApp`
- [x] Integrasikan initial locale ke bootstrap app di `frontend/lib/main.dart`
- [x] Sediakan update path tunggal untuk mengganti locale secara runtime
- [x] Pastikan pergantian locale meng-update `MaterialApp.locale` secara langsung
- [x] Pastikan logout tidak menghapus locale preference

### Phase 4 - Build Language Control in Settings

- [ ] Ganti row `System Language` yang statis di `SettingsScreen` menjadi kontrol yang aktif
- [ ] Tampilkan pilihan bahasa English
- [ ] Tampilkan pilihan bahasa Bahasa Indonesia
- [ ] Sinkronkan nilai selector dengan locale aktif saat screen dibuka
- [ ] Simpan pilihan bahasa segera setelah user memilih
- [ ] Trigger update UI aplikasi tanpa perlu restart manual
- [ ] Pastikan Settings screen tetap shared untuk Guest, Teacher/Guru, dan Freelancer

### Phase 5 - Localize Shared App Chrome

- [ ] Localize app title dan root-level labels
- [ ] Localize bottom navigation labels di `frontend/lib/widgets/bottom_nav.dart`
- [ ] Localize Settings screen labels, section titles, buttons, dan helper text
- [ ] Localize reusable modal/sheet text pada widget bersama
- [ ] Localize generic empty states, prompts, dan CTA yang dipakai lintas screen

### Phase 6 - Localize Priority Screens

- [ ] Localize `frontend/lib/screens/login_screen.dart`
- [ ] Localize `frontend/lib/screens/forgot_password_screen.dart`
- [ ] Localize `frontend/lib/screens/home_screen.dart`
- [ ] Localize `frontend/lib/screens/freelancer_home_screen.dart`
- [ ] Localize `frontend/lib/screens/profile_screen.dart`
- [ ] Localize `frontend/lib/screens/search_screen.dart`
- [ ] Localize `frontend/lib/screens/bookmark_screen.dart`
- [ ] Localize `frontend/lib/screens/freelancer_jobs_screen.dart`
- [ ] Localize `frontend/lib/screens/freelancer_portfolio_screen.dart`
- [ ] Localize `frontend/lib/screens/account_settings_screen.dart`
- [ ] Localize `frontend/lib/screens/gallery_screen.dart`
- [ ] Localize `frontend/lib/screens/help_screen.dart`
- [ ] Localize `frontend/lib/screens/project_success_screen.dart`

### Phase 7 - Handle Client-Owned vs Backend-Owned Text

- [ ] Identifikasi string client-owned yang wajib dipindahkan ke resource localization
- [ ] Biarkan konten dari backend tetap apa adanya kecuali sudah ada translated variant
- [ ] Biarkan user-generated content tetap apa adanya
- [ ] Review service messages yang muncul ke UI agar ikut localized bila memang client-owned

### Phase 8 - Add Automated Tests

- [ ] Extend startup/state tests untuk memuat locale dari SharedPreferences
- [ ] Tambahkan widget test untuk Settings language selector
- [ ] Tambahkan widget test untuk runtime locale switching
- [ ] Tambahkan widget test untuk cold-start locale restore
- [ ] Verifikasi role-based shell tetap benar setelah locale ditambahkan
- [ ] Jalankan `flutter test -r expanded` di folder `frontend/`
- [ ] Pertimbangkan integration test tambahan bila coverage widget belum cukup

### Phase 9 - Manual Regression Validation

- [ ] Uji flow Guest: Home -> Settings -> ganti bahasa -> restart app
- [ ] Uji flow Teacher/Guru: Home -> Settings -> ganti bahasa -> restart app
- [ ] Uji flow Freelancer: Home -> Settings -> ganti bahasa -> restart app
- [ ] Verifikasi label UI berubah tanpa full reinstall app
- [ ] Verifikasi bahasa terakhir tetap aktif setelah cold start
- [ ] Verifikasi logout tidak me-reset bahasa

## Target Files

### Core App State

- [ ] `frontend/lib/main.dart`
- [ ] Helper/service preferensi bahasa baru atau file util terkait
- [ ] `frontend/pubspec.yaml`
- [ ] File localization config dan ARB resources baru

### Screens

- [ ] `frontend/lib/screens/settings_screen.dart`
- [ ] `frontend/lib/screens/home_screen.dart`
- [ ] `frontend/lib/screens/freelancer_home_screen.dart`
- [ ] `frontend/lib/screens/login_screen.dart`
- [ ] `frontend/lib/screens/forgot_password_screen.dart`
- [ ] `frontend/lib/screens/profile_screen.dart`
- [ ] `frontend/lib/screens/search_screen.dart`
- [ ] `frontend/lib/screens/bookmark_screen.dart`
- [ ] `frontend/lib/screens/freelancer_jobs_screen.dart`
- [ ] `frontend/lib/screens/freelancer_portfolio_screen.dart`
- [ ] `frontend/lib/screens/account_settings_screen.dart`
- [ ] `frontend/lib/screens/gallery_screen.dart`
- [ ] `frontend/lib/screens/help_screen.dart`
- [ ] `frontend/lib/screens/project_success_screen.dart`

### Shared Widgets and Services

- [ ] `frontend/lib/widgets/bottom_nav.dart`
- [ ] `frontend/lib/widgets/feature_coming_soon.dart`
- [ ] Widget/sheet reusable lain yang memiliki text hard-coded
- [ ] Service file yang mengeluarkan message ke UI

### Tests

- [ ] `frontend/test/screens/main_shell_role_test.dart`
- [ ] Test widget baru untuk settings/localization bila diperlukan
- [ ] `frontend/integration_test/login_role_flow_test.dart` bila diputuskan untuk diperluas

## Notes and Constraints

- Locale state sebaiknya dimiliki app root, bukan screen lokal.
- Penyimpanan preferensi bahasa sebaiknya dipisahkan dari `AuthService` agar concern auth dan app preferences tidak tercampur.
- Implementasi harus mengikuti flow yang sudah ada: gear icon pada Home menuju `SettingsScreen` yang shared.
- Konten backend dan user-generated content tidak wajib diterjemahkan oleh client selama tidak ada data translated variant dari API.

## Progress Log

- [x] Planning selesai
- [x] Implementasi dimulai
- [x] Localization infrastructure selesai
- [ ] Settings language selector selesai
- [ ] App-wide string migration selesai
- [ ] Automated test coverage selesai
- [ ] Manual QA selesai
- [ ] Feature siap direview / merge