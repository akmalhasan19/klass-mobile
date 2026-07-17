"""Reliable webhook sender for notifying the Rust Gateway of job completion.

Task 2.3.7 / 2.3.3 of the async media generation migration plan.

Implements:
- HMAC-SHA256 signature (matching ``X-Webhook-Signature`` expected by Rust)
- Exponential backoff with configurable base/max and optional jitter
- Retry conditions: network errors, 5xx, 429, timeout
- Non-retry conditions: 4xx (except 429) → log error, stop retry
- On all retries exhausted: log critical error for manual intervention

Enhanced with observability (Sub-tasks 3.2.2, 3.2.3, 3.2.4):
- Tracing spans for webhook delivery lifecycle
- Structured ``webhook.attempt``, ``webhook.success``, ``webhook.exhausted`` logs
- Metrics: delivery attempts (success/failure counters), delivery latency histogram
"""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import logging
import random
import time
from typing import Any

import httpx

from app.observability import log_job_lifecycle, metrics, trace_span

logger = logging.getLogger("klass-media-generator.webhook")

# ─── Constants ───────────────────────────────────────────────────────────────

MAX_WEBHOOK_ATTEMPTS = 5
"""Default maximum number of webhook delivery attempts before giving up."""

BACKOFF_SECONDS = [2, 4, 8, 16, 32]
"""Default exponential backoff delays between retry attempts (in seconds).

Total maximum wait time: ~62 seconds.
"""

WEBHOOK_TIMEOUT_SECONDS = 10.0
"""Default HTTP request timeout per webhook delivery attempt."""

# ─── Shared httpx client (connection pooling) ────────────────────────────────

_shared_client: httpx.AsyncClient | None = None


def _get_shared_client(timeout: float) -> httpx.AsyncClient:
    """Return a shared ``httpx.AsyncClient`` with connection pooling.

    Reuses a single client across webhook calls to avoid the overhead of
    creating/destroying TCP connections on every delivery attempt.
    The client is lazily created and cached at module level.
    """
    global _shared_client
    if _shared_client is None or _shared_client.is_closed:
        _shared_client = httpx.AsyncClient(
            timeout=timeout,
            limits=httpx.Limits(
                max_connections=10,
                max_keepalive_connections=5,
                keepalive_expiry=30,
            ),
        )
    return _shared_client


# ─── Public API ──────────────────────────────────────────────────────────────


def _build_backoff_sequence(
    base: float,
    max_backoff: float,
    max_attempts: int,
    jitter: bool,
) -> list[float]:
    """Build an exponential backoff sequence with optional jitter.

    Args:
        base: Base delay in seconds.
        max_backoff: Maximum delay cap in seconds.
        max_attempts: Number of retry attempts (sequence length = max_attempts - 1).
        jitter: If True, add random jitter (±25%) to each delay.

    Returns:
        List of delays in seconds for each retry attempt.
    """
    sequence: list[float] = []
    for i in range(max_attempts - 1):
        delay = min(base * (2 ** i), max_backoff)
        if jitter:
            delay = delay * (0.75 + random.random() * 0.5)
        sequence.append(round(delay, 2))
    return sequence


async def send_webhook_with_retry(
    webhook_url: str,
    payload: dict[str, Any],
    hmac_secret: str,
    max_attempts: int = MAX_WEBHOOK_ATTEMPTS,
    *,
    timeout: float | None = None,
    backoff_base: float | None = None,
    backoff_max: float | None = None,
    jitter: bool = True,
) -> bool:
    """Send a webhook to the Rust Gateway with exponential backoff retry.

    Args:
        webhook_url: Target URL (the Rust Gateway's internal webhook endpoint).
        payload: JSON-serialisable dict to send as the request body.
        hmac_secret: Shared secret for HMAC-SHA256 signing.
        max_attempts: Maximum number of delivery attempts (default 5).
        timeout: HTTP request timeout in seconds (default from settings).
        backoff_base: Base backoff delay in seconds (default 2).
        backoff_max: Maximum backoff delay in seconds (default 32).
        jitter: Whether to add random jitter to backoff delays (default True).

    Returns:
        ``True`` if the webhook was successfully delivered (HTTP 2xx),
        ``False`` if all retry attempts were exhausted.

    The payload is signed with HMAC-SHA256 and sent as ``X-Webhook-Signature``
    header. The Rust Gateway verifies this signature before accepting the
    callback.
    """
    # Lazy-import settings to avoid circular imports
    from app.settings import get_settings
    settings = get_settings()

    effective_timeout = timeout or settings.webhook_timeout_seconds
    effective_base = backoff_base or settings.webhook_base_backoff_seconds
    effective_max = backoff_max or settings.webhook_max_backoff_seconds
    effective_jitter = jitter and settings.webhook_jitter_enabled
    effective_max_attempts = max_attempts or settings.webhook_max_attempts

    # Extract job_id from payload for structured logging (Sub-task 3.2.4)
    job_id = payload.get("job_id", "unknown")
    generation_id = payload.get("generation_id", "unknown")
    payload_status = payload.get("status", "unknown")

    body_bytes = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    signature = _sign_payload(body_bytes, hmac_secret)

    last_error: str | None = None
    delivery_start = time.monotonic()

    backoff_sequence = _build_backoff_sequence(
        effective_base, effective_max, effective_max_attempts, effective_jitter,
    )

    # Sub-task 3.2.3: Wrap entire delivery lifecycle in a tracing span
    with trace_span(
        "webhook.delivery",
        job_id=job_id,
        generation_id=generation_id,
        webhook_url=webhook_url,
        payload_status=payload_status,
        max_attempts=effective_max_attempts,
    ) as span:
        client = _get_shared_client(effective_timeout)
        for attempt in range(1, effective_max_attempts + 1):
            attempt_start = time.monotonic()

            # Sub-task 3.2.4: Log webhook.attempt
            logger.info(
                "webhook.attempt | %s",
                {
                    "event": "webhook.attempt",
                    "job_id": job_id,
                    "attempt": attempt,
                    "max_attempts": effective_max_attempts,
                    "webhook_url": webhook_url,
                },
            )

            try:
                response = await client.post(
                    webhook_url,
                    content=body_bytes,
                    headers={
                        "Content-Type": "application/json",
                        "X-Webhook-Signature": signature,
                    },
                )

                status = response.status_code
                attempt_latency_ms = (time.monotonic() - attempt_start) * 1000

                if 200 <= status < 300:
                    # Sub-task 3.2.4: Log webhook.success
                    logger.info(
                        "webhook.success | %s",
                        {
                            "event": "webhook.success",
                            "job_id": job_id,
                            "attempt": attempt,
                            "latency_ms": round(attempt_latency_ms, 2),
                            "status_code": status,
                        },
                    )

                    # Sub-task 3.2.2: Record success metrics
                    total_latency = time.monotonic() - delivery_start
                    metrics.webhook_delivery_attempts_success.inc()
                    metrics.webhook_delivery_latency_seconds.observe(total_latency)

                    span.set_attribute("result", "success")
                    span.set_attribute("attempts_used", attempt)
                    span.set_attribute("total_latency_ms", round(total_latency * 1000, 2))

                    return True

                # Non-retryable client errors (except 429)
                if 400 <= status < 500 and status != 429:
                    logger.error(
                        "webhook: non-retryable error from %s "
                        "(attempt %d/%d, status %d, body=%s) — giving up",
                        webhook_url,
                        attempt,
                        effective_max_attempts,
                        status,
                        response.text[:500],
                    )

                    # Sub-task 3.2.2: Record failure metrics
                    total_latency = time.monotonic() - delivery_start
                    metrics.webhook_delivery_attempts_failure.inc()
                    metrics.webhook_delivery_latency_seconds.observe(total_latency)

                    span.set_attribute("result", "non_retryable_error")
                    span.set_attribute("status_code", status)

                    return False

                # Retryable: 5xx or 429
                logger.warning(
                    "webhook: retryable error from %s "
                    "(attempt %d/%d, status %d) — will retry",
                    webhook_url,
                    attempt,
                    effective_max_attempts,
                    status,
                )
                last_error = f"HTTP {status}"

            except (httpx.TimeoutException, httpx.ConnectError, httpx.RemoteProtocolError) as exc:
                attempt_latency_ms = (time.monotonic() - attempt_start) * 1000
                logger.warning(
                    "webhook: transport error for %s "
                    "(attempt %d/%d, error=%s, latency_ms=%.2f) — will retry",
                    webhook_url,
                    attempt,
                    effective_max_attempts,
                    exc,
                    attempt_latency_ms,
                )
                last_error = str(exc)

            # Wait before next attempt (exponential backoff with optional jitter)
            if attempt < effective_max_attempts:
                delay = backoff_sequence[attempt - 1] if attempt - 1 < len(backoff_sequence) else effective_max
                await asyncio.sleep(delay)

        # All retries exhausted
        total_latency_ms = (time.monotonic() - delivery_start) * 1000

        # Sub-task 3.2.4: Log webhook.exhausted
        logger.critical(
            "webhook.exhausted | %s",
            {
                "event": "webhook.exhausted",
                "job_id": job_id,
                "attempts": effective_max_attempts,
                "total_latency_ms": round(total_latency_ms, 2),
                "last_error": last_error or "unknown",
                "webhook_url": webhook_url,
            },
        )

        # Sub-task 3.2.1: Structured lifecycle log for webhook failure
        log_job_lifecycle(
            "job.webhook_exhausted",
            job_id=job_id,
            generation_id=generation_id,
            status="webhook_delivery_failed",
            duration_ms=total_latency_ms,
            error_code="WEBHOOK_DELIVERY_FAILED",
            error_message=f"All {effective_max_attempts} webhook attempts exhausted. Last error: {last_error}",
        )

        # Sub-task 3.2.2: Record failure metrics
        metrics.webhook_delivery_attempts_failure.inc()
        metrics.webhook_delivery_latency_seconds.observe(total_latency_ms / 1000)

        span.set_attribute("result", "exhausted")
        span.set_attribute("total_latency_ms", round(total_latency_ms, 2))
        span.set_attribute("last_error", last_error or "unknown")

    return False


# ─── Internal helpers ────────────────────────────────────────────────────────


def _sign_payload(body: bytes, secret: str) -> str:
    """Generate HMAC-SHA256 signature for the webhook payload.

    The Rust Gateway's webhook handler expects this in the
    ``X-Webhook-Signature`` header and validates it using the shared
    ``MEDIA_GEN_WEBHOOK_SECRET``.
    """
    return hmac.new(
        secret.encode("utf-8"),
        body,
        hashlib.sha256,
    ).hexdigest()


async def close_shared_client() -> None:
    """Close the shared httpx client (call during app shutdown)."""
    global _shared_client
    if _shared_client is not None and not _shared_client.is_closed:
        await _shared_client.aclose()
        _shared_client = None
