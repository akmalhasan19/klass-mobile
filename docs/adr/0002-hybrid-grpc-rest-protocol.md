# ADR-002: Protokol Flutter ↔ Gateway — Hybrid gRPC + REST

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2026-07-11 |
| **Deciders** | Engineering Team |
| **Supersedes** | — |

---

## Context

Gateway Rust harus melayani 26 endpoint REST (unik URL pattern) dari Laravel existing + 1 flow media generation yang saat ini menggunakan polling `Timer.periodic(4s)` di Flutter.

Polling 4 detik punya kelemahan:
- **Latency**: Progress event bisa tertunda sampai 4 detik setelah state transition di backend
- **Waste**: 90%+ polling request return status unchanged (no-op)
- **Scale**: Semakin banyak concurrent generation → polling request tumbuh linear

Di sisi lain, 25 endpoint lain (auth, CRUD topics, gallery, profile, dll) adalah request-response sederhana yang tidak butuh real-time updates.

## Decision

**Hybrid protocol**: gRPC server-streaming untuk `SubmitMediaGeneration` + `Regenerate`, REST/JSON (Dio) untuk 25 endpoint lainnya.

| Edge | Protocol | Port | Library (Rust) | Library (Flutter) |
|------|----------|------|----------------|-------------------|
| Media Gen progress | gRPC server-streaming | 50051 | `tonic` 0.12 + `prost` 0.13 | `grpc` ^4.0.1 + `protobuf` ^3.1.0 |
| Semua endpoint lain | REST/JSON | 8080 | `axum` 0.7 | `dio` 5.9.2 (existing, no change) |

## Alternatives Considered

### Pure REST + polling (status quo)

| Pro | Kontra |
|-----|--------|
| Tidak ada perubahan Flutter | 4s latency, waste bandwidth, tidak scalable |
| Simple, well-understood | Tidak leverage Rust async streaming capability |

### WebSockets (`tokio-tungstenite`)

| Pro | Kontra |
|-----|--------|
| Single connection untuk semua progress events | Tidak ada type safety pada messages — manual JSON serialize/deserialize |
| Flutter punya `web_socket_channel` built-in | Connection management kompleks (reconnect, backoff, auth per message) |
| | Tidak ada codegen → contract mudah drift antara Flutter & Rust |

### Server-Sent Events (SSE)

| Pro | Kontra |
|-----|--------|
| Simple, unidirectional (server→client cocok untuk progress) | Hanya text-based, tidak ada binary framing |
| Flutter bisa consume via `http` package | Multiplexing sulit (satu koneksi per stream) |
| | Tidak ada formal schema — risk contract drift |

### Kenapa gRPC server-streaming menang

| Kebutuhan | gRPC solution |
|-----------|-------------|
| Type safety | Proto file → codegen Dart + Rust, compile-time contract guarantee |
| Real-time progress | `ServerStreaming<GenerationProgressEvent>` — push event per state transition |
| Connection multiplexing | HTTP/2 native — multiple streams over single TCP connection |
| Backward compatibility | Proto field numbering + `optional` — add fields without breaking |
| Flutter adoption | `grpc` package mature, Flutter team internal Google project |

## Flutter Impact

Perubahan terbatas pada **1 file**:

| File | Perubahan | Estimasi LoC |
|------|-----------|-------------|
| `lib/features/media_generation/data/media_generation_service.dart` | Rewrite: `Dio.post` + `Timer.periodic(4s)` → `grpc.ClientChannel` + `submitMediaGeneration(...).listen(...)` | ~200 |
| `pubspec.yaml` | Tambah `grpc: ^4.0.1`, `protobuf: ^3.1.0`; dev: `protoc_plugin` | ~5 |
| `proto/klass/media/v1/media_generation.proto` | File baru (shared source of truth) | ~80 |

**11 service class lain, semua widget UI, dan interceptor Dio tetap utuh — tidak ada perubahan.**

## gRPC Stream Fallback

Jika gRPC connection gagal (misal HTTP/2 tidak didukung proxy), Flutter fallback ke REST polling existing sebagai degradasi graceful:

```dart
try {
  await for (final event in stub.submitMediaGeneration(request)) {
    // gRPC stream events
  }
} on GrpcError catch (e) {
  // Fallback to REST polling
  _startPollingFallback(generationId);
}
```

## Consequences

### Positive

- **Latency progress event**: <100ms dari state transition di Rust → Flutter render (vs 4s polling)
- **Bandwidth saving**: Tidak ada polling no-op, hanya push saat state berubah
- **Type safety**: Proto contract shared source of truth antara Flutter & Rust
- **Scalable**: HTTP/2 multiplexing, tidak ada koneksi baru per polling cycle

### Negative / Mitigation

| Risk | Mitigation |
|------|-----------|
| gRPC di mobile network kadang terblokir proxy/firewall | Fallback ke REST polling; `grpc` package support HTTP/1.1 transport |
| Flutter gRPC package butuh native channel setup | `grpc` ^4.0.1 sudah support Dart native; Android/iOS tested |
| Proto codegen menambah build step | Otomatis via `build_runner` di Flutter, `tonic-build` di Rust — CI reproducible |
| Dev perlu belajar proto syntax | Syntax minimal (80 baris), hanya 2 RPC + 6 message |

---

## References

- `IMPLEMENTATION_PLAN.md` — Task 2.3 (API Contract Design) untuk proto spec
- `INTEGRATION_MAPPING.md` — Existing REST endpoint inventory (26 URL patterns)
- `frontend/lib/features/media_generation/data/media_generation_service.dart` — Current polling implementation
