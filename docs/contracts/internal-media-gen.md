# Internal Contract: Rust Gateway → Media Generator (Async)

| Field | Value |
|-------|-------|
| **Version** | `media_generation_spec.v2.async` |
| **Protocol** | HTTP/2 + HMAC-SHA256 |
| **Direction** | Gateway → Media Generator |
| **Base URL** | `MEDIA_GENERATION_PYTHON_BASE_URL` env var |

---

## Authentication

HMAC-SHA256 signature-based.

### Headers

| Header | Required | Value |
|--------|----------|-------|
| `Content-Type` | Yes | `application/json` |
| `X-Klass-Generation-Id` | Yes | UUID v4 of the media generation |
| `X-Klass-Request-Timestamp` | Yes | Unix epoch seconds |
| `X-Klass-Signature-Algorithm` | Yes | `hmac-sha256` |
| `X-Klass-Signature` | Yes | `HMAC-SHA256(timestamp + "." + body, shared_secret)` hex digest |

### Shared Secret

| Variable | Consumer | Env |
|----------|----------|-----|
| Primary | Gateway (sender) + Media Gen (verifier) | `MEDIA_GENERATION_PYTHON_SHARED_SECRET` |

---

## Endpoint: `POST /v1/jobs`

Initiates an asynchronous media generation job.

### Timeout & Retry

| Setting | Default | Configurable via |
|---------|---------|-----------------|
| Request timeout | 10s | `MEDIA_GENERATION_PYTHON_TIMEOUT_SECONDS` |
| Connect timeout | 5s | `MEDIA_GENERATION_PYTHON_CONNECT_TIMEOUT_SECONDS` |
| Retry attempts | 3 | `MEDIA_GENERATION_PYTHON_RETRY_ATTEMPTS` |
| Retry backoff | 500ms | `MEDIA_GENERATION_PYTHON_RETRY_SLEEP_MILLISECONDS` |

### Request Body

```jsonc
{
  // Job Tracking
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "generation_id": "123e4567-e89b-12d3-a456-426614174000",
  
  // Callback URL for completion/failure (Rust Gateway endpoint)
  "webhook_url": "http://rust-gateway:8080/internal/media-generations/webhook",
  
  // Generation Specification
  "generation_spec": {
    "generation_spec_version": "media_generation_spec.v1",
    "preferred_output_type": "pdf",
    "prompt_interpretation": { /* ... */ },
    "document_blueprint": { /* ... */ },
    "media_characteristics": { /* ... */ }
  }
}
```

### Success Response (202 Accepted)

```jsonc
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "generation_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "pending"
}
```

### Error Response (4xx, 5xx)

```jsonc
{
  "detail": {
    "code": "invalid_request",
    "message": "Missing required field: webhook_url",
    "retryable": false
  }
}
```

---

## Gateway Implementation Notes (Rust)

```rust
// Pseudocode for Rust async media gen client

impl MediaGenClient {
    async fn enqueue_job(
        &self,
        job_id: Uuid,
        generation_id: Uuid,
        spec: &MediaGenerationSpec,
    ) -> Result<JobAcceptedResponse, MediaGenError> {
        let payload = GenerateJobRequest {
            job_id,
            generation_id,
            webhook_url: format!("{}/internal/media-generations/webhook", self.gateway_internal_url),
            generation_spec: spec.clone(),
        };
        
        let body = serde_json::to_string(&payload)?;
        let timestamp = Utc::now().timestamp().to_string();
        let signature = self.sign(&timestamp, &body);

        let response = self.client
            .post(format!("{}/v1/jobs", self.base_url))
            .header("Content-Type", "application/json")
            .header("X-Klass-Generation-Id", generation_id.to_string())
            .header("X-Klass-Request-Timestamp", &timestamp)
            .header("X-Klass-Signature-Algorithm", "hmac-sha256")
            .header("X-Klass-Signature", &signature)
            .body(body)
            .timeout(self.timeout)
            .send()
            .await?;

        // Returns immediately on 202 Accepted.
        // Results will be delivered via Webhook to the `webhook_url`.
    }
}
```
