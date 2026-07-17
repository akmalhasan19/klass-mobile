# Mobile Integration Guide: Async Media Generation

This guide details how the Flutter mobile app should interact with the new Asynchronous Media Generation flow via the Rust Gateway.

## Overview

The Media Generation process has moved from a synchronous API call to an asynchronous job queue. 
**The mobile app no longer waits for the generation to complete in a single HTTP request.** Instead, it follows a 3-step process:
1. Submit the prompt (Returns 202 Accepted immediately).
2. Poll for job status with exponential backoff.
3. Download the artifact directly from S3/R2 using a presigned URL.

---

## Step 1: Submit Generation Request

**Endpoint:** `POST /api/v1/media-generations`

This endpoint behavior has changed. It now responds almost instantly.

**Response (202 Accepted):**
```json
{
  "generation_id": "123e4567-e89b-12d3-a456-426614174000",
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "pending",
  "poll_url": "/api/v1/media-generations/123e4567-e89b-12d3-a456-426614174000/job-status"
}
```

---

## Step 2: Polling for Status

**Endpoint:** `GET /api/v1/media-generations/{generation_id}/job-status`

You must poll this endpoint until the status becomes `completed` or `failed`.

### Polling Strategy (Exponential Backoff)

Do not poll aggressively. Use an exponential backoff strategy:
- 1st poll: after 2 seconds
- 2nd poll: after 4 seconds
- 3rd poll: after 8 seconds
- Subsequent polls: every 15-30 seconds

*Note: Most generations take between 5 to 20 seconds depending on the format (PDF takes longer than DOCX).*

### Status Transitions

- `pending`: Job is queued, waiting for a worker.
- `processing`: Worker is actively generating the document. Show a progress indicator to the user.
- `completed`: Job is done, URL is ready. (Terminal state)
- `failed`: Job encountered an error. (Terminal state)

**Response - Completed:**
```json
{
  "status": "completed",
  "download_url": "https://bucket.s3.region.amazonaws.com/...&X-Amz-Signature=..."
}
```

**Response - Failed:**
```json
{
  "status": "failed",
  "error_code": "generation_failed",
  "error_message": "Failed to render PDF document."
}
```

---

## Step 3: Downloading the Artifact

When the status is `completed`, the `download_url` will contain a **presigned S3/R2 URL** valid for 1 hour.

**Crucial Implementation Details:**
1. **Direct Download:** Download the file directly from this URL. Do **not** send this request through the Rust Gateway.
2. **No Auth Headers:** Do **not** attach your mobile Bearer token or any Klass auth headers to this S3 download request. S3 will reject requests with unexpected Authorization headers. The presigned URL already contains all necessary authentication in its query parameters.
3. **Resuming:** The S3 bucket supports HTTP `Range` requests, meaning you can resume interrupted downloads.

---

## UI/UX Recommendations

- **Don't block the UI:** Allow the user to navigate away while the document is generating.
- **Background notifications:** Consider using local notifications when a long-running generation completes if the user is in a different tab.
- **Status Badges:** Show a small "Generating..." badge in the user's gallery/history view.
