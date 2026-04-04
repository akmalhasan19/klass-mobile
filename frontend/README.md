# klass_app

## Running With Backend API

API base URL can be overridden at runtime using `--dart-define`.

Example:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
```

Default behavior without override:

- Android emulator: `http://10.0.2.2:8000/api`
- iOS simulator: `http://127.0.0.1:8000/api`
- Other platforms: `http://127.0.0.1:8000/api`

Notes:

- Physical device cannot use `127.0.0.1` or `10.0.2.2` to reach your laptop backend.
- Use your laptop LAN IP and ensure backend is started with host `0.0.0.0`.

## Homepage Recommendation Feed

- HomeScreen loads section visibility from `GET /homepage-sections`.
- Project Recommendation cards load from `GET /homepage-recommendations` instead of the legacy topics feed.
- UI keeps a safe fallback path for three states: backend-configured labels, empty recommendation feed, and request failure with retry/debug info.

## Test Commands

```bash
flutter test -r expanded
flutter test test/screens/home_screen_section_config_test.dart -r expanded
```
