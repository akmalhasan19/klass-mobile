# Webhook Contract: Media Generator → Rust Gateway

| Field | Value |
|-------|-------|
| **Version** | `media_generation_webhook.v1` |
| **Protocol** | HTTP/1.1 or HTTP/2 + HMAC-SHA256 |
| **Direction** | Media Generator → Gateway |
| **Endpoint** | `POST /internal/media-generations/webhook` |

---

## Authentication

HMAC-SHA256 signature-based. The Rust Gateway verifies this signature to ensure the webhook came from the trusted Media Generator service.

### Headers

| Header | Required | Value |
|--------|----------|-------|
| `Content-Type` | Yes | `application/json` |
| `X-Webhook-Signature` | Yes | `HMAC-SHA256(payload_body, MEDIA_GEN_WEBHOOK_SECRET)` hex digest |

### Shared Secret

| Variable | Consumer | Env |
|----------|----------|-----|
| Primary | Media Gen (sender) + Gateway (verifier) | `MEDIA_GEN_WEBHOOK_SECRET` |

---

## Webhook Payload Schema

### Success Payload

Sent when the artifact has been successfully generated and uploaded to object storage (S3/R2).

```jsonc
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "generation_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "completed",
  "s3_object_key": "materials/123e4567-e89b-12d3-a456-426614174000/content.pdf",
  "presigned_url": "https://bucket.s3.region.amazonaws.com/materials/...&X-Amz-Signature=...",
  "expires_at": "2026-07-16T15:30:00Z"
}
```

### Failure Payload

Sent when the generation process fails (e.g., parsing error, invalid format, render crash) and all generation retries are exhausted.

```jsonc
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "generation_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "failed",
  "error_code": "generation_failed",
  "error_message": "Failed to render PDF: Chromium timeout"
}
```

---

## Delivery & Retry Policy

The Python Media Generator uses Arq + reliable webhook delivery with exponential backoff.

1. **Trigger Conditions:** Webhook is fired exactly once per job when it reaches a terminal state (`completed` or `failed`).
2. **Timeout:** The HTTP request timeout for the webhook delivery is 10 seconds.
3. **Retryable Errors:** 
   - Network errors (Connection Refused, Timeout)
   - `5xx` Server Errors from Rust Gateway
   - `429` Too Many Requests
4. **Non-Retryable Errors (Abort immediately):**
   - `4xx` Client Errors (e.g., `400 Bad Request`, `401 Unauthorized` signature mismatch). This indicates a bug or misconfiguration.
5. **Exponential Backoff Schedule (Max 5 attempts):**
   - Attempt 1: Immediate
   - Attempt 2: wait 2s
   - Attempt 3: wait 4s
   - Attempt 4: wait 8s
   - Attempt 5: wait 16s
   - Attempt 6: wait 32s
   - *Total maximum wait time: ~62 seconds.*
6. **Dead Letter Queue (DLQ):** If all webhook retries are exhausted, the Python worker marks the job internally as `failed` with `error_code: WEBHOOK_DELIVERY_FAILED` and pushes the job data to `gen:jobs:dlq` in Redis for manual investigation.
