# ADR-006: Queue Strategy — Redis Streams via Upstash

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2026-07-11 |
| **Deciders** | Engineering Team |
| **Supersedes** | — |

---

## Context

Laravel saat ini menggunakan **database queue** (`jobs` table di PostgreSQL) untuk `ProcessMediaGenerationJob`. Database queue punya kelemahan:

- **Polling overhead**: Queue worker query `SELECT ... FOR UPDATE SKIP LOCKED` setiap 3 detik — CPU waste
- **Table bloat**: Completed jobs tetap di database, perlu manual cleanup
- **No priority**: FIFO only, tidak bisa prioritas atau delay
- **Single consumer**: Database lock contention jika >1 worker

Gateway Rust membutuhkan queue untuk:
- Enqueue `ProcessMediaGenerationJob` dari REST/gRPC handler
- Process job via orchestrator state machine (9-state)
- Idempotent retry (max 3 attempts)
- Dead-letter queue untuk failed jobs
- Acknowledgment-based redelivery (bukan polling)

## Decision

**Redis Streams via Upstash free tier. Consumer groups dengan `XREADGROUP` + `XACK` + `XCLAIM` untuk redeliver.**

```redis
# Stream key
KLASS:media-generation        # Main stream
KLASS:media-generation-dlq    # Dead-letter queue

# Consumer group
KLASS:workers                 # XREADGROUP consumer group

# Flow
XADD KLASS:media-generation * generation_id <uuid> attempt 1 context <json>
  → XREADGROUP GROUP KLASS:workers worker-<id> COUNT 1 BLOCK 5000 STREAMS KLASS:media-generation >
  → Process job (orchestrator)
  → XACK KLASS:media-generation KLASS:workers <message-id>
  → If terminal: done
  → If retryable: XADD with attempt+1
  → If exhausted: XADD to DLQ
```

### Upstash Redis Spec

| Parameter | Limit (Free Tier) | Current Usage Estimate |
|-----------|-------------------|----------------------|
| Commands/day | 10,000 | ~500 (low volume media gen) |
| Storage | 256 MB | <1 MB (streams are ephemeral) |
| Max connections | 100 | ~5 (consumer pool) |
| Data persistence | Daily backup | Cukup untuk replay |
| Region | `ap-southeast-1` (Singapore) | Same as Neon + Render |

## Alternatives Considered

### PostgreSQL `SKIP LOCKED` queue (port existing)

| Pro | Kontra |
|-----|--------|
| Zero new infrastructure | **Polling overhead**: tetap harus query setiap 3 detik |
| Transaksional — job + state update dalam satu DB TX | Table bloat (completed/failed jobs) |
| Simple, well-understood | Message ordering tidak terjamin |
| | Tidak ada native DLQ — harus implementasi manual |

### RabbitMQ (AMQP)

| Pro | Kontra |
|-----|--------|
| Battle-tested message broker | Perlu managed hosting (CloudAMQP free tier: 1 instance, limited) |
| Native DLQ, routing keys, TTL | Tambahan operational complexity |
| Push-based delivery | Overkill untuk 1 stream dengan low volume |
| | Biaya: free tier terbatas, production tier mulai $5/bulan |

### AWS SQS + SNS

| Pro | Kontra |
|-----|--------|
| Fully managed, auto-scaling | Tidak ada Singapore region untuk latency rendah |
| Native DLQ (auto-redrive) | Biaya per-request (meskipun kecil) |
| | SDK dependency (`aws-sdk-sqs`) — tambahan binary size |
| | Overkill untuk single job type |

### Kenapa Redis Streams menang

| Kebutuhan | Redis Streams solution |
|-----------|----------------------|
| Push + pull delivery | `XREADGROUP` block dengan timeout — quasi-push (low latency) tanpa koneksi persistent |
| Idempotent retry | `XACK` remove message → hanya sukses jika message belum di-ACK |
| Dead-letter queue | `XADD` ke DLQ stream terpisah setelah retry exhausted |
| Redeliver unacked (consumer crash) | `XCLAIM` klaim message dari consumer yang idle > timeout |
| Consumer groups | Multiple workers consume paralel, masing-masing dapat message unik |
| Low volume | Upstash free tier 10k commands/day — cukup untuk <500 jobs/day |
| Rust library | `redis` crate 0.27 dengan `deadpool-redis` connection pool |

## Job Lifecycle

```
Submit
  │
  ▼
XADD KLASS:media-generation * generation_id <id> attempt 1 context <json>
  │
  ▼
XREADGROUP ... > (claim pending)
  │
  ▼
Worker: orchestrator.process(generation_id, attempt, context)
  │
  ├─ Success (terminal state)
  │    └─ XACK → message removed from stream
  │
  ├─ Retryable failure (attempt < 3)
  │    ├─ XACK old message
  │    └─ XADD with attempt+1
  │
  └─ Fatal / exhausted retries
       ├─ XACK old message
       ├─ XADD KLASS:media-generation-dlq
       └─ Alert via log + metric
```

## Worker Idempotency

Setiap job diproses dengan check `statusBefore` invariant:
```rust
// Jika state sudah di depan atau sama dengan target, skip (idempoten)
if generation.status >= target_status {
    xack(job_id).await?;
    return Ok(()); // Already processed
}
```

Ini memastikan bahwa meskipun message ter-deliver ulang (via `XCLAIM`), state machine tidak mundur atau double-transition.

## Consequences

### Positive

- **No polling overhead**: `XREADGROUP BLOCK 5000` — worker idle tanpa CPU spin
- **Reliable delivery**: `XACK` + `XCLAIM` — message tidak hilang jika consumer crash
- **Free infrastructure**: Upstash free tier mencakup kebutuhan dengan margin lebar
- **Simple Rust API**: `redis` crate support Streams via `XADD`, `XREADGROUP`, `XACK`, `XCLAIM` commands
- **DLQ built-in**: Stream terpisah untuk failed jobs — bisa di-monitor tanpa query database

### Negative / Mitigation

| Risk | Mitigation |
|------|-----------|
| Upstash free tier 10k commands/day | <500 jobs/day = <2000 commands — jauh di bawah limit |
| Redis Stream memory bertumbuh jika tidak di-ACK | `XACK` di setiap success/failure path; monitor `XLEN` sebagai alert |
| Network partition → message bisa di-deliver dua kali | Idempotent via `statusBefore` invariant di orchestrator |
| Upstash downtime (SLA free tier none) | Graceful degradation: Gateway tetap jalan, job di-enqueue saat Redis kembali via connection retry |
| Anti-pattern: Stream sebagai persistent store | `MAXLEN` trim agar stream tidak bertumbuh; completed jobs tidak disimpan di stream |

---

## References

- `IMPLEMENTATION_PLAN.md` — Task 3.5 (Redis Setup)
- `IMPLEMENTATION_PLAN.md` — Task 4.6 (Media Gen Integration + Redis Worker)
- `IMPLEMENTATION_PLAN.md` — Risk Assessment Matrix (row: Redis Stream message lost)
- `upstash.com` — Redis free tier limits
