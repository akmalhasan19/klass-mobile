# Internal Contract: Rust Gateway → Media Generator

| Field | Value |
|-------|-------|
| **Version** | `media_generation_spec.v1` |
| **Protocol** | HTTP/2 + HMAC-SHA256 |
| **Direction** | Gateway → Media Generator |
| **Base URL** | `MEDIA_GENERATION_PYTHON_BASE_URL` env var |

---

## Authentication

HMAC-SHA256 signature-based. See `INTEGRATION_MAPPING.md` for full HMAC contract.

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

## Endpoint: `POST /v1/generate`

### Timeout & Retry

| Setting | Default | Configurable via |
|---------|---------|-----------------|
| Request timeout | 60s | `MEDIA_GENERATION_PYTHON_TIMEOUT_SECONDS` |
| Connect timeout | 10s | `MEDIA_GENERATION_PYTHON_CONNECT_TIMEOUT_SECONDS` |
| Retry attempts | 2 | `MEDIA_GENERATION_PYTHON_RETRY_ATTEMPTS` |
| Retry backoff | 500ms | `MEDIA_GENERATION_PYTHON_RETRY_SLEEP_MILLISECONDS` |

### Request Body

```jsonc
{
  // Schema version (constant)
  "generation_spec_version": "media_generation_spec.v1",

  // Desired output format: "auto" | "docx" | "pdf" | "pptx"
  "preferred_output_type": "pdf",

  // Full interpretation response from LLM (MediaPromptInterpretation schema)
  "prompt_interpretation": {
    "teacher_intent": { /* ... */ },
    "subject_context": { "subject_name": "Matematika", "subject_slug": "matematika" },
    "sub_subject_context": { /* ... */ },
    "target_audience": { "grade_level": "SMA", /* ... */ },
    "learning_objectives": [{ "objective": "...", "taxonomy_level": "understand" }],
    "output_type_candidates": [{ "type": "pdf", "score": 0.95, "reason": "..." }],
    "assets": [],
    "assessment_or_activity_blocks": [],
    "constraints": { "must_include": [], "avoid": [] },
    "requested_media_characteristics": { "format_preferences": [], /* ... */ },
    "confidence": { "score": 0.92, "label": "high", "rationale": "..." },
    "fallback": { /* ... */ }
  },

  // Content document structure (document_blueprint)
  "document_blueprint": {
    "sections": [
      { "heading": "Pendahuluan", "content_type": "text", "estimated_length": "short" },
      { "heading": "Materi Inti", "content_type": "text", "estimated_length": "long" },
      { "heading": "Latihan Soal", "content_type": "exercises", "estimated_length": "medium" }
    ]
  },

  // Media rendering characteristics
  "media_characteristics": {
    "page_layout": "a4",
    "font_family": "default",
    "include_header_footer": true,
    "include_table_of_contents": true,
    "color_scheme": "educational"
  }
}
```

### Success Response (200)

```jsonc
{
  // Artifact metadata
  "artifact_metadata": {
    "metadata_version": "media_generator_output_metadata.v1",
    "export_format": "pdf",                           // "docx" | "pdf" | "pptx"
    "mime_type": "application/pdf",
    "size_bytes": 245760,                             // File size in bytes
    "checksum_sha256": "a1b2c3d4e5f6..."             // SHA-256 hash
  },

  // Signed URL for artifact download
  "artifact_locator": "https://{hf-space-url}/artifacts/{file_id}?token=..."
}
```

### Error Response (4xx, 5xx)

```jsonc
{
  "detail": {
    "code": "unsupported_export_format",               // Machine-readable error code
    "message": "Export format 'xlsx' is not implemented.", // Human-readable
    "details": {
      "export_format": "xlsx",
      "supported_formats": ["docx", "pdf", "pptx"]
    },
    "retryable": true
  }
}
```

### All Media Gen Error Codes

| Code | HTTP | Retryable | Laravel Error Hint | Description |
|------|------|-----------|-------------------|-------------|
| `signature_invalid` | 401 | Yes | `python_service_unavailable` | HMAC signature mismatch |
| `timestamp_invalid` | 401 | Yes | `python_service_unavailable` | Can't parse timestamp |
| `timestamp_out_of_range` | 401 | Yes | `python_service_unavailable` | Beyond `request_max_age_seconds` |
| `generation_id_header_missing` | 401 | Yes | `python_service_unavailable` | Missing required header |
| `signature_algorithm_invalid` | 401 | Yes | `python_service_unavailable` | Not `hmac-sha256` |
| `unsupported_export_format` | 422 | Yes | `artifact_invalid` | Format not implemented |
| `service_misconfigured` | 503 | Yes | `python_service_unavailable` | Missing config/secret |
| `artifact_invalid` | 500+ | Yes | `artifact_invalid` | Corrupt/missing artifact |
| `generation_failed` | 500 | Yes | `artifact_invalid` | Render pipeline failure |

---

## Gateway Implementation Notes (Rust)

```rust
// Pseudocode for Rust media gen client

use reqwest::Client;
use hmac::{Hmac, Mac};
use sha2::Sha256;

struct MediaGenClient {
    base_url: String,
    shared_secret: String,
    client: Client,           // HTTP/2 connection pooling
    timeout: Duration,        // 60s
    retry_attempts: u32,      // 2
    retry_backoff: Duration,  // 500ms
}

impl MediaGenClient {
    async fn generate(
        &self,
        generation_id: Uuid,
        spec: &MediaGenerationSpec,
    ) -> Result<GenerateResponse, MediaGenError> {
        let body = serde_json::to_string(&spec)?;
        let timestamp = Utc::now().timestamp().to_string();
        let signature = self.sign(&timestamp, &body);

        let response = self.client
            .post(format!("{}/v1/generate", self.base_url))
            .header("Content-Type", "application/json")
            .header("X-Klass-Generation-Id", generation_id.to_string())
            .header("X-Klass-Request-Timestamp", &timestamp)
            .header("X-Klass-Signature-Algorithm", "hmac-sha256")
            .header("X-Klass-Signature", &signature)
            .body(body)
            .timeout(self.timeout)
            .send()
            .await?;

        // ... handle response, download artifact, upload to R2
    }

    fn sign(&self, timestamp: &str, body: &str) -> String {
        let mut mac = Hmac::<Sha256>::new_from_slice(
            self.shared_secret.as_bytes()
        ).unwrap();
        mac.update(timestamp.as_bytes());
        mac.update(b".");
        mac.update(body.as_bytes());
        hex::encode(mac.finalize().into_bytes())
    }
}
```
