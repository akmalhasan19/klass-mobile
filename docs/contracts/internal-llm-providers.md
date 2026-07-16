# Internal Contract: Rust Gateway → LLM Providers

| Field | Value |
|-------|-------|
| **Protocol** | HTTPS + API Key / Bearer Token |
| **Direction** | Gateway → Gemini API / OpenAI API |
| **Protocol version** | HTTP/2 (with HTTP/1.1 fallback via reqwest) |

---

## Provider Routing Architecture

```
Gateway orchestrator
  │
  ▼
ProviderRouter::execute_interpretation(payload) / execute_delivery(payload)
  │
  ├── Primary provider (configurable per route)
  │     │
  │     ├── Gemini: POST /v1beta/models/{model}:generateContent
  │     └── OpenAI: POST /v1/responses
  │
  └── Fallback provider (if primary fails with retryable error)
        │
        └── same interfaces as primary
```

### Route Configuration

| Setting | Interpret | Delivery | Default |
|---------|-----------|----------|---------|
| Provider | `LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER` | `LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER` | `gemini` |
| Fallback | `LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER` | `LLM_ADAPTER_DELIVERY_FALLBACK_PROVIDER` | — (optional) |
| Timeout | 30s | 30s | `LLM_ADAPTER_UPSTREAM_TIMEOUT_SECONDS` |

### Fallback Error Codes

Fallback hanya dipicu untuk error code berikut:
- `provider_timeout` — upstream tidak merespon dalam 30s
- `provider_connection_failed` — DNS/TCP failure
- `provider_rate_limited` — upstream HTTP 429
- `provider_unavailable` — upstream HTTP 5xx

---

## Provider 1: Google Gemini

### Endpoint

```
POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={API_KEY}
```

### Authentication

| Method | Location | Env Variable |
|--------|----------|-------------|
| API Key | Query parameter `?key=` | `LLM_ADAPTER_GEMINI_API_KEY` |

### Model Configuration

| Route | Default Model | Env Override |
|-------|-------------|-------------|
| Interpretation | `gemini-2.0-flash` | `LLM_ADAPTER_GEMINI_INTERPRET_MODEL` |
| Delivery | `gemini-2.0-flash` | `LLM_ADAPTER_GEMINI_DELIVERY_MODEL` |

### Model Resolution

```rust
fn resolve_model(route: ProviderRoute, requested: &str) -> String {
    if requested.to_lowercase().starts_with("gemini") {
        return requested.to_string(); // Passthrough
    }
    match route {
        ProviderRoute::Interpret => settings.gemini_interpretation_model.clone(),
        ProviderRoute::Respond   => settings.gemini_delivery_model.clone(),
    }
}
```

### Request Schema

```jsonc
{
  "systemInstruction": {
    "parts": [
      {
        "text": "<instruction_text>"  // Prompt instruction specific to route
      }
    ]
  },
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "<serialized_prompt_payload>"  // JSON-serialized user input
        }
      ]
    }
  ],
  "generationConfig": {
    "candidateCount": 1,
    "responseMimeType": "application/json"
  }
}
```

### Serialization of prompt payload

```jsonc
// Serialized as compact JSON string, included as parts[].text:
{
  "request_type": "media_prompt_interpretation",  // or "media_delivery_response", "media_content_draft"
  "generation_id": "550e8400-...",
  "route": "interpret",                           // or "respond"
  "input": {
    // InterpretationRequest.input or DeliveryRequest.input or ContentDraftRequest.input
    // Exact fields depend on route
  }
}

// Serialization: json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
```

### Success Response

```jsonc
{
  "candidates": [
    {
      "content": {
        "role": "model",
        "parts": [
          {
            "text": "{\"teacher_intent\": {...}, ...}"  // JSON output
          }
        ]
      },
      "finishReason": "STOP",
      "safetyRatings": [ /* ... */ ]
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 150,
    "candidatesTokenCount": 800,
    "totalTokenCount": 950
  },
  "modelVersion": "gemini-2.0-flash",
  "responseId": "abc123"
}
```

### Response Parsing (in order)

1. Parse response body as JSON
2. Extract `candidates[].content.parts[]` — concatenate all `text` fields
3. Extract usage: `usageMetadata.promptTokenCount`, `candidatesTokenCount`, `totalTokenCount`
4. If `totalTokenCount` missing: `promptTokenCount + candidatesTokenCount`
5. Request ID: `x-request-id` header or `x-goog-request-id` header or `responseId`

### Error Response Mapping

| HTTP Status | Gemini Error | Gateway Error Code | Retryable |
|-------------|-------------|-------------------|-----------|
| 400 | Invalid request | `provider_request_invalid` | No |
| 401, 403 | Auth failed | `provider_auth_failed` | No |
| 429 | Quota exceeded | `provider_rate_limited` | **Yes** (triggers fallback) |
| 5xx | Service error | `provider_unavailable` | **Yes** (triggers fallback) |
| Timeout | — | `provider_timeout` | **Yes** (triggers fallback) |
| Connection error | — | `provider_connection_failed` | **Yes** (triggers fallback) |
| Non-JSON response | — | `provider_response_invalid` | Yes |
| Status !2xx (other) | — | `provider_upstream_failed` | No |

### Instruction Guardrails (Interpretation Only)

Interpretation requests are augmented with JSON structure guardrails appended to the instruction:

```
Adapter contract guardrails:
- These rules define JSON structure only and must never be copied into teacher-facing content fields.
- Only subject_context, sub_subject_context, and target_audience may be null.
- teacher_intent, constraints, document_blueprint, confidence, and fallback must always be JSON objects.
- learning_objectives, output_type_candidates, assets, assessment_or_activity_blocks,
  constraints.must_include, constraints.avoid, requested_media_characteristics.format_preferences,
  and document_blueprint.sections must always be arrays, never null.
- subject_context keys must be subject_name and subject_slug.
- sub_subject_context keys must be sub_subject_name and sub_subject_slug.
- output_type_candidates entries must be objects with type, score, and reason.
- confidence must be an object with score, label, and rationale.
- If a required structure would otherwise be empty, emit the minimal valid JSON shape instead of null.
```

---

## Provider 2: OpenAI

### Endpoint

```
POST https://api.openai.com/v1/responses
```

### Authentication

| Method | Header | Env Variable |
|--------|--------|-------------|
| Bearer Token | `Authorization: Bearer {key}` | `LLM_ADAPTER_OPENAI_API_KEY` |
| Organization (optional) | `OpenAI-Organization: {org}` | `LLM_ADAPTER_OPENAI_ORGANIZATION` |
| Project (optional) | `OpenAI-Project: {project}` | `LLM_ADAPTER_OPENAI_PROJECT` |

### Model Configuration

| Route | Default Model | Env Override |
|-------|-------------|-------------|
| Interpretation | `gpt-5.4` | `LLM_ADAPTER_OPENAI_INTERPRET_MODEL` |
| Delivery | `gpt-5.4` | `LLM_ADAPTER_OPENAI_DELIVERY_MODEL` |

### Model Resolution

```rust
fn resolve_model(route: ProviderRoute, requested: &str) -> String {
    let lower = requested.to_lowercase();
    if lower.starts_with("gpt") || lower.starts_with("o") || lower.starts_with("chatgpt") {
        return requested.to_string(); // Passthrough
    }
    match route {
        ProviderRoute::Interpret => settings.openai_interpretation_model.clone(),
        ProviderRoute::Respond   => settings.openai_delivery_model.clone(),
    }
}
```

### Request Schema

```jsonc
{
  "model": "gpt-5.4",
  "input": [
    {
      "role": "system",
      "content": [
        {
          "type": "input_text",
          "text": "<instruction_text>"
        }
      ]
    },
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "<serialized_prompt_payload>"  // Same JSON serialization as Gemini
        }
      ]
    }
  ],
  "text": {
    "format": {
      "type": "json_object"     // Ensure JSON output
    }
  }
}
```

### Success Response

```jsonc
{
  "id": "resp_abc123",
  "object": "response",
  "model": "gpt-5.4-2025-06-01",
  "status": "completed",
  "output": [
    {
      "id": "msg_xyz789",
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "output_text",
          "text": "{\"teacher_intent\": {...}, ...}"  // JSON output
        }
      ],
      "status": "completed"
    }
  ],
  "output_text": "{\"teacher_intent\": {...}, ...}",
  "usage": {
    "input_tokens": 150,
    "output_tokens": 800,
    "total_tokens": 950
  }
}
```

### Response Parsing (priority order)

1. **Top-level `output_text`** — preferred path
2. **`output[].content[]`** — extract `text` where `type` is `output_text` or `text`
3. **`choices[].message.content`** — legacy chat completions fallback
4. **`choices[].text`** — legacy completions fallback

Usage: `input_tokens` (or `prompt_tokens`), `output_tokens` (or `completion_tokens`), `total_tokens`

Finish reason: `status` field, `incomplete_details.reason`, or legacy `choices[].finish_reason`

Request ID: `x-request-id` response header or response `id` field

### Error Response Mapping

| HTTP Status | OpenAI Error | Gateway Error Code | Retryable |
|-------------|-------------|-------------------|-----------|
| 400 | Invalid request | `provider_request_invalid` | No |
| 401, 403 | Auth failed | `provider_auth_failed` | No |
| 429 | Rate limit | `provider_rate_limited` | **Yes** (triggers fallback) |
| 5xx | Server error | `provider_unavailable` | **Yes** (triggers fallback) |
| Timeout | — | `provider_timeout` | **Yes** (triggers fallback) |
| Connection error | — | `provider_connection_failed` | **Yes** (triggers fallback) |
| Non-JSON response | — | `provider_response_invalid` | Yes |
| Status !2xx (other) | — | `provider_upstream_failed` | No |

---

## Rust Implementation Notes

### Provider Trait

```rust
#[async_trait]
pub trait Provider: Send + Sync {
    /// Provider identifier ("gemini", "openai")
    fn name(&self) -> &'static str;

    /// Resolve the model name for a route
    fn resolve_model(&self, route: ProviderRoute, requested: &str) -> String;

    /// Execute a completion call
    async fn complete(
        &self,
        request: NormalizedProviderRequest,
    ) -> Result<ProviderCompletion, ProviderRequestError>;
}
```

### HTTP Client Configuration

```rust
use reqwest::Client;

fn build_provider_client() -> Client {
    Client::builder()
        .http2_prior_knowledge()           // HTTP/2 by default
        .pool_max_idle_per_host(20)        // Connection pooling
        .pool_idle_timeout(Duration::from_secs(90))
        .timeout(Duration::from_secs(30))  // Upstream timeout
        .build()
        .expect("Failed to build provider HTTP client")
}
```

### Circuit Breaker (tower)

```rust
// Implemented in Rust Gateway
// 5 consecutive failures → circuit open for 30s → fast-fail

use tower::limit::ConcurrencyLimit;
use tower::retry::Policy;
use tower::timeout::TimeoutLayer;

// Stack:
// ConcurrencyLimit::new(10)          ← max concurrent calls per provider
//   → TimeoutLayer::new(30s)         ← per-call timeout
//     → RetryLayer::new(policy)      ← 2 attempts with backoff
//       → CircuitBreaker::new(5, Duration::from_secs(30))
//         → actual HTTP call
```

### Model Routing Config

```rust
struct LLMConfig {
    gemini_api_key: String,
    gemini_base_url: String,              // https://generativelanguage.googleapis.com
    gemini_api_version: String,           // v1beta
    gemini_interpretation_model: String,  // gemini-2.0-flash
    gemini_delivery_model: String,        // gemini-2.0-flash

    openai_api_key: String,
    openai_base_url: String,              // https://api.openai.com
    openai_interpretation_model: String,  // gpt-5.4
    openai_delivery_model: String,        // gpt-5.4
    openai_organization: String,          // optional
    openai_project: String,               // optional

    active_interpretation_provider: String,  // "gemini" | "openai"
    active_delivery_provider: String,        // "gemini" | "openai"
    interpretation_fallback_provider: Option<String>,
    delivery_fallback_provider: Option<String>,
    allow_route_provider_divergence: bool,
    provider_fallback_error_codes: Vec<String>,
    upstream_timeout_seconds: u64,           // 30
}
```

---

## Request Routing (Pseudocode)

```rust
async fn execute_provider_call(
    router: &ProviderRouter,
    route: ProviderRoute,
    payload: &InterpretationRequest, // or DeliveryRequest
) -> Result<ProviderExecutionResult, ProviderRequestError> {
    let policy = router.policy_for_route(route);

    // Attempt primary provider
    let primary = router.build_client(route, false)?;
    match primary.complete(normalize(primary, route, payload)).await {
        Ok(completion) => return Ok(ProviderExecutionResult {
            completion,
            primary_provider: policy.primary_provider.clone(),
            fallback_used: false,
            ..Default::default()
        }),
        Err(err) if policy.should_attempt_fallback(&err) => {
            // Attempt fallback
            let fallback = router.build_client(route, true)?;
            match fallback.complete(normalize(fallback, route, payload)).await {
                Ok(completion) => Ok(ProviderExecutionResult {
                    completion,
                    fallback_used: true,
                    fallback_reason: Some(err.code),
                    ..
                }),
                Err(fallback_err) => Err(fallback_err),
            }
        }
        Err(err) => Err(err),
    }
}
```
