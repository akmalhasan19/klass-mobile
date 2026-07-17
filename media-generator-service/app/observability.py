"""Centralized observability module for async media generation.

Sub-tasks 3.2.1, 3.2.2, 3.2.3 of the async media generation migration plan.

Provides:
- **Structured job lifecycle logging** (3.2.1): JSON-structured log events for
  each job state transition (created → processing → completed/failed).
- **In-process metrics registry** (3.2.2): Thread-safe counters, histograms,
  and gauges for job duration, queue depth, success/failure rates, webhook
  delivery attempts/latency, and DLQ depth.
- **Tracing spans** (3.2.3): Decorator and context manager for creating
  structured spans that log entry/exit/error with timing.
"""

from __future__ import annotations

import functools
import logging
import threading
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger("klass-media-generator.observability")


# ═════════════════════════════════════════════════════════════════════════════
# Sub-task 3.2.1: Structured Job Lifecycle Logger
# ═════════════════════════════════════════════════════════════════════════════


def log_job_lifecycle(
    event: str,
    *,
    job_id: str,
    generation_id: str = "",
    status: str = "",
    duration_ms: float | None = None,
    error_code: str | None = None,
    error_message: str | None = None,
    extra: dict[str, Any] | None = None,
) -> None:
    """Emit a structured log event for a job lifecycle transition.

    Events follow the convention ``job.<phase>`` where phase is one of:
    ``created``, ``processing``, ``completed``, ``failed``, ``dlq``.

    All events include ``job_id``, ``generation_id``, ``status``, and
    ``timestamp_utc``. Optional fields: ``duration_ms``, ``error_code``,
    ``error_message``, and arbitrary ``extra`` metadata.

    Args:
        event: Lifecycle event name (e.g. ``"job.created"``).
        job_id: The async job tracking UUID.
        generation_id: The media generation UUID.
        status: Current job status (``pending``, ``processing``, etc.).
        duration_ms: Elapsed time in milliseconds (for completed/failed).
        error_code: Error code string (for failed events).
        error_message: Human-readable error description.
        extra: Additional key-value pairs to include in the log.
    """
    record: dict[str, Any] = {
        "event": event,
        "job_id": job_id,
        "generation_id": generation_id,
        "status": status,
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
    }

    if duration_ms is not None:
        record["duration_ms"] = round(duration_ms, 2)
    if error_code is not None:
        record["error_code"] = error_code
    if error_message is not None:
        record["error_message"] = error_message
    if extra:
        record.update(extra)

    # Choose log level based on event type
    if "failed" in event or "exhausted" in event or "dlq" in event:
        logger.error("lifecycle: %s | %s", event, record)
    elif "completed" in event or "success" in event:
        logger.info("lifecycle: %s | %s", event, record)
    else:
        logger.info("lifecycle: %s | %s", event, record)


# ═════════════════════════════════════════════════════════════════════════════
# Sub-task 3.2.2: In-Process Metrics Registry
# ═════════════════════════════════════════════════════════════════════════════


class _Counter:
    """Thread-safe monotonically increasing counter."""

    __slots__ = ("_value", "_lock")

    def __init__(self) -> None:
        self._value: int = 0
        self._lock = threading.Lock()

    def inc(self, amount: int = 1) -> None:
        with self._lock:
            self._value += amount

    @property
    def value(self) -> int:
        return self._value


class _Histogram:
    """Thread-safe histogram that records observations and computes stats.

    Stores raw observations to compute count, sum, min, max, average, and
    percentile approximations (p50, p95, p99).
    """

    __slots__ = ("_observations", "_lock")

    # Cap the number of stored observations to prevent unbounded memory growth.
    _MAX_OBSERVATIONS = 10_000

    def __init__(self) -> None:
        self._observations: list[float] = []
        self._lock = threading.Lock()

    def observe(self, value: float) -> None:
        with self._lock:
            if len(self._observations) >= self._MAX_OBSERVATIONS:
                # Drop the oldest half when the buffer is full.
                self._observations = self._observations[self._MAX_OBSERVATIONS // 2 :]
            self._observations.append(value)

    def snapshot(self) -> dict[str, Any]:
        """Return a snapshot of the histogram stats."""
        with self._lock:
            if not self._observations:
                return {
                    "count": 0,
                    "sum": 0.0,
                    "min": 0.0,
                    "max": 0.0,
                    "avg": 0.0,
                    "p50": 0.0,
                    "p95": 0.0,
                    "p99": 0.0,
                }
            sorted_obs = sorted(self._observations)
            count = len(sorted_obs)
            total = sum(sorted_obs)
            return {
                "count": count,
                "sum": round(total, 4),
                "min": round(sorted_obs[0], 4),
                "max": round(sorted_obs[-1], 4),
                "avg": round(total / count, 4),
                "p50": round(sorted_obs[int(count * 0.5)], 4),
                "p95": round(sorted_obs[min(int(count * 0.95), count - 1)], 4),
                "p99": round(sorted_obs[min(int(count * 0.99), count - 1)], 4),
            }


class _Gauge:
    """Thread-safe gauge that can be set, incremented, and decremented."""

    __slots__ = ("_value", "_lock")

    def __init__(self) -> None:
        self._value: float = 0.0
        self._lock = threading.Lock()

    def set(self, value: float) -> None:
        with self._lock:
            self._value = value

    def inc(self, amount: float = 1.0) -> None:
        with self._lock:
            self._value += amount

    def dec(self, amount: float = 1.0) -> None:
        with self._lock:
            self._value -= amount

    @property
    def value(self) -> float:
        return self._value


class MetricsRegistry:
    """Singleton in-process metrics registry.

    Tracks:
    - ``job_duration_seconds``: Histogram of total job processing time.
    - ``job_success_total``: Counter of successfully completed jobs.
    - ``job_failure_total``: Counter of failed jobs.
    - ``queue_depth``: Gauge of pending jobs (updated from Redis on demand).
    - ``webhook_delivery_attempts_success``: Counter of successful webhook deliveries.
    - ``webhook_delivery_attempts_failure``: Counter of failed webhook deliveries.
    - ``webhook_delivery_latency_seconds``: Histogram of webhook delivery latency.
    - ``dlq_depth``: Gauge of jobs in the dead-letter queue.
    """

    def __init__(self) -> None:
        # Job metrics
        self.job_duration_seconds = _Histogram()
        self.job_success_total = _Counter()
        self.job_failure_total = _Counter()
        self.queue_depth = _Gauge()

        # Webhook metrics
        self.webhook_delivery_attempts_success = _Counter()
        self.webhook_delivery_attempts_failure = _Counter()
        self.webhook_delivery_latency_seconds = _Histogram()

        # DLQ metrics
        self.dlq_depth = _Gauge()

    def snapshot(self) -> dict[str, Any]:
        """Return a JSON-serialisable snapshot of all metrics."""
        return {
            "job_duration_seconds": self.job_duration_seconds.snapshot(),
            "job_success_total": self.job_success_total.value,
            "job_failure_total": self.job_failure_total.value,
            "queue_depth": self.queue_depth.value,
            "webhook_delivery_attempts_success": self.webhook_delivery_attempts_success.value,
            "webhook_delivery_attempts_failure": self.webhook_delivery_attempts_failure.value,
            "webhook_delivery_latency_seconds": self.webhook_delivery_latency_seconds.snapshot(),
            "dlq_depth": self.dlq_depth.value,
        }


# Module-level singleton — import and use directly.
metrics = MetricsRegistry()


async def refresh_redis_gauges(redis: Any) -> None:
    """Update queue_depth and dlq_depth gauges from Redis.

    Called by the metrics endpoint or periodically by the worker.

    Args:
        redis: An ``aioredis.Redis`` or ``arq.connections.ArqRedis`` instance.
    """
    try:
        # Queue depth: count pending jobs in the Arq queue sorted set.
        # Arq uses a sorted set for the queue.
        queue_depth = await redis.zcard("arq:queue:gen:jobs:queue")
        metrics.queue_depth.set(float(queue_depth))
    except Exception:
        # Fallback: try Redis list length if sorted set doesn't exist.
        try:
            queue_depth = await redis.llen("gen:jobs:queue")
            metrics.queue_depth.set(float(queue_depth))
        except Exception:
            pass

    try:
        dlq_depth = await redis.llen("gen:jobs:dlq")
        metrics.dlq_depth.set(float(dlq_depth))
    except Exception:
        pass


# ═════════════════════════════════════════════════════════════════════════════
# Sub-task 3.2.3: Tracing Spans
# ═════════════════════════════════════════════════════════════════════════════


class TraceSpan:
    """A structured tracing span that logs entry, exit, and errors with timing.

    Usage as a context manager::

        with TraceSpan("generation.render", job_id=job_id) as span:
            # ... do work ...
            span.set_attribute("format", "pdf")

    Usage as a decorator::

        @trace_span("generation.render")
        async def render(job_id: str):
            ...
    """

    __slots__ = ("name", "attributes", "_start_time", "_logger")

    def __init__(self, name: str, **attributes: Any) -> None:
        self.name = name
        self.attributes: dict[str, Any] = dict(attributes)
        self._start_time: float = 0.0
        self._logger = logging.getLogger("klass-media-generator.tracing")

    def set_attribute(self, key: str, value: Any) -> None:
        """Add or update an attribute on this span."""
        self.attributes[key] = value

    def __enter__(self) -> TraceSpan:
        self._start_time = time.monotonic()
        self._logger.info(
            "span.start: %s | %s",
            self.name,
            {"span": self.name, "phase": "start", **self.attributes},
        )
        return self

    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        elapsed_ms = (time.monotonic() - self._start_time) * 1000
        self.attributes["duration_ms"] = round(elapsed_ms, 2)

        if exc_type is not None:
            self.attributes["error"] = str(exc_val)
            self.attributes["error_type"] = exc_type.__name__
            self._logger.error(
                "span.error: %s | %s",
                self.name,
                {"span": self.name, "phase": "error", **self.attributes},
            )
        else:
            self._logger.info(
                "span.end: %s | %s",
                self.name,
                {"span": self.name, "phase": "end", **self.attributes},
            )


@contextmanager
def trace_span(name: str, **attributes: Any):
    """Context manager that creates a structured tracing span.

    Args:
        name: Span name (e.g. ``"generation.process"``, ``"webhook.delivery"``).
        **attributes: Initial key-value attributes to attach to the span.

    Yields:
        A ``TraceSpan`` instance that can be used to set additional attributes.
    """
    span = TraceSpan(name, **attributes)
    with span:
        yield span


def trace_span_decorator(name: str):
    """Decorator that wraps an async function in a tracing span.

    The decorated function's keyword arguments are captured as span attributes.

    Usage::

        @trace_span_decorator("generation.render")
        async def render(job_id: str, format: str):
            ...
    """
    def decorator(func):
        @functools.wraps(func)
        async def wrapper(*args, **kwargs):
            with TraceSpan(name, **kwargs):
                return await func(*args, **kwargs)
        return wrapper
    return decorator
