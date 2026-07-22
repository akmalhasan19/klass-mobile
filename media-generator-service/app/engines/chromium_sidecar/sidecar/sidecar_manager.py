"""Long-running Node sidecar manager for Chromium PDF rendering.

This module owns the lifecycle of the Node sidecar process (``chromium_sidecar.js``),
spawned once at startup, kept warm for the process lifetime, and bridges it
to the asyncio world via a line-delimited JSON-RPC protocol over the child's
stdio.

After the Marp-to-Jinja2 migration (Fase 2) the sidecar's only rendering method
is ``html_to_pdf`` — it receives a self-contained HTML string (produced by the
:class:`app.engines.html_template.engine.HtmlTemplateEngine`) and returns PDF
bytes via Playwright's Chromium ``page.setContent()`` + ``page.pdf()``.

Design notes
------------
* **stdout is the only protocol channel.** The sidecar writes logs to stderr
  (drained separately), so the reader loop never has to scrub log lines out
  of the JSON stream. This keeps parsing trivial and robust.
* **Correlation by ``id``.** Every request gets a monotonic id; its response
  (or error) is matched back to the awaiting future. ``{"ready":true}`` has no
  id and is treated as a bootstrap signal.
* **Crash / unresponsive self-healing.** The reader loop detects EOF and the
  watchdog detects a dead or unresponsive process (or a render that exceeds
  ``render_timeout_seconds``); either triggers a supervised restart. A single
  ``_restarting`` guard prevents overlapping restarts.
* **Load + memory hygiene.** An ``asyncio.Semaphore`` caps concurrent renders
  (Chromium pages), and the sidecar is recycled after ``restart_render_count``
  renders or ``restart_idle_seconds`` of uptime to bound Chromium memory.
* **Decoupled errors.** Transport/Protocol issues raise :class:`SidecarError`.
  The wiring layer (``app/main.py`` lifespan) maps a failed ``start()`` to
  ``ServiceMisconfiguredError`` and renderers map runtime failures to
  ``GenerationError`` — keeping this module free of the domain error taxonomy.
"""
from __future__ import annotations

import asyncio
import base64
import json
import logging
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from app.settings import Settings

logger = logging.getLogger("klass-media-generator")


class SidecarError(Exception):
    """Transport/protocol failure talking to the Chromium sidecar process."""

    def __init__(self, message: str, code: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.code = code


@dataclass
class SidecarConfig:
    """Tunable sidecar parameters, sourced from :class:`app.settings.Settings`."""

    node_executable: str = "node"
    script_path: Path = field(
        default_factory=lambda: Path(__file__).resolve().parent / "chromium_sidecar.js"
    )
    ready_timeout_seconds: int = 30
    render_timeout_seconds: int = 30
    max_concurrent_renders: int = 4
    health_interval_seconds: int = 30
    restart_render_count: int = 100
    restart_idle_seconds: int = 3600


def build_sidecar_manager(settings: Settings) -> "SidecarManager":
    """Construct a :class:`SidecarManager` from service settings."""
    config = SidecarConfig(
        node_executable=settings.marp_sidecar_node_executable,
        script_path=Path(settings.marp_sidecar_script_path),
        ready_timeout_seconds=settings.marp_sidecar_ready_timeout_seconds,
        render_timeout_seconds=settings.marp_sidecar_render_timeout_seconds,
        max_concurrent_renders=settings.marp_sidecar_max_concurrent_renders,
        health_interval_seconds=settings.marp_sidecar_health_interval_seconds,
        restart_render_count=settings.marp_sidecar_restart_render_count,
        restart_idle_seconds=settings.marp_sidecar_restart_idle_seconds,
    )
    return SidecarManager(config)


class SidecarManager:
    """Spawn, supervise, and RPC-proxy the Chromium Node sidecar."""

    def __init__(self, config: SidecarConfig | None = None) -> None:
        self._config = config or SidecarConfig()
        self._process: asyncio.subprocess.Process | None = None
        self._reader_task: asyncio.Task[None] | None = None
        self._stderr_task: asyncio.Task[None] | None = None
        self._watchdog_task: asyncio.Task[None] | None = None
        self._pending: dict[int, asyncio.Future[Any]] = {}
        self._next_id = 1
        self._lock = asyncio.Lock()
        self._semaphore = asyncio.Semaphore(self._config.max_concurrent_renders)
        self._ready = asyncio.Event()
        self._running = False
        self._restarting = False
        self._render_count = 0
        self._started_at = 0.0

    # ------------------------------------------------------------------ lifecycle

    async def start(self) -> None:
        """Spawn the sidecar and block until it signals readiness."""
        async with self._lock:
            if self._running:
                return
            self._running = True
            self._restarting = False
            self._render_count = 0
            self._started_at = time.monotonic()
            try:
                await self._spawn()
            except Exception:
                self._running = False
                raise
            self._watchdog_task = asyncio.create_task(self._watchdog_loop())

    async def stop(self) -> None:
        """Gracefully terminate the sidecar and cancel background tasks."""
        async with self._lock:
            if not self._running:
                return
            self._running = False
            self._ready.clear()
            for task in (self._watchdog_task, self._reader_task, self._stderr_task):
                if task is not None and not task.done():
                    task.cancel()
            await self._terminate_process()
            for future in list(self._pending.values()):
                if not future.done():
                    future.set_exception(SidecarError("sidecar stopped"))
            self._pending.clear()

    async def __aenter__(self) -> "SidecarManager":
        await self.start()
        return self

    async def __aexit__(self, *_exc: object) -> None:
        await self.stop()

    # ------------------------------------------------------------------ public API

    @property
    def is_running(self) -> bool:
        return self._running

    @property
    def is_ready(self) -> bool:
        return self._ready.is_set()

    @property
    def uptime_seconds(self) -> float:
        """Seconds since the sidecar was last started (0.0 if not running)."""
        if not self._running or self._started_at == 0.0:
            return 0.0
        return time.monotonic() - self._started_at

    async def html_to_pdf(self, html: str) -> bytes:
        """Render self-contained HTML to PDF bytes via warm Chromium.

        This is the only rendering method on the sidecar after the Marp-to-Jinja2
        migration (Fase 2).  The ``HtmlTemplateEngine`` (Fase 2A) now produces the
        HTML string; this method feeds it to Chromium ``page.setContent()`` +
        ``page.pdf()`` via the sidecar.
        """
        result = await self._request("html_to_pdf", {"html": html})
        if not isinstance(result, dict) or "pdf" not in result:
            raise SidecarError("sidecar html_to_pdf returned no pdf field")
        return base64.b64decode(result["pdf"])

    async def generate_pptx(self, spec: dict[str, Any]) -> bytes:
        """Generate PPTX via warm Node.js + PptxGenJS."""
        result = await self._request("generate_pptx", {"spec": spec})
        if not isinstance(result, dict) or "pptx" not in result:
            raise SidecarError("sidecar generate_pptx returned no pptx field")
        return base64.b64decode(result["pptx"])

    async def health(self) -> dict[str, Any]:
        """Lightweight liveness probe (does not consume a render slot)."""
        return await self._request("health", {}, counts_as_render=False)

    # ------------------------------------------------------------------ transport

    async def _request(
        self,
        method: str,
        params: dict[str, Any],
        *,
        timeout: int | None = None,
        counts_as_render: bool = True,
    ) -> Any:
        if counts_as_render:
            await self._semaphore.acquire()
        try:
            return await self._request_inner(
                method, params, timeout=timeout, counts_as_render=counts_as_render
            )
        finally:
            if counts_as_render:
                self._semaphore.release()

    async def _request_inner(
        self,
        method: str,
        params: dict[str, Any],
        *,
        timeout: int | None = None,
        counts_as_render: bool = True,
    ) -> Any:
        await self._ready.wait()

        request_id = self._alloc_id()
        loop = asyncio.get_running_loop()
        future: asyncio.Future[Any] = loop.create_future()
        self._pending[request_id] = future

        try:
            await self._write(
                {"id": request_id, "method": method, "params": params}
            )
        except (BrokenPipeError, ConnectionError, ValueError) as exc:
            self._pending.pop(request_id, None)
            raise SidecarError(f"failed to send request to sidecar: {exc}") from exc

        effective_timeout = timeout or self._config.render_timeout_seconds
        try:
            result = await asyncio.wait_for(future, timeout=effective_timeout)
        except asyncio.TimeoutError:
            self._pending.pop(request_id, None)
            future.cancel()
            if self._running:
                asyncio.create_task(self._restart(f"render-timeout:{method}"))
            raise SidecarError(
                f"sidecar {method} timed out after {effective_timeout}s"
            )

        if counts_as_render:
            self._render_count += 1
            if self._render_count >= self._config.restart_render_count and self._running:
                asyncio.create_task(self._restart("render-count"))

        return result

    def _alloc_id(self) -> int:
        request_id = self._next_id
        self._next_id = (self._next_id % 2_000_000_000) + 1
        return request_id

    async def _write(self, message: dict[str, Any]) -> None:
        if self._process is None or self._process.stdin is None:
            raise SidecarError("sidecar process is not running")
        payload = (json.dumps(message, ensure_ascii=False) + "\n").encode("utf-8")
        self._process.stdin.write(payload)
        await self._process.stdin.drain()

    # ------------------------------------------------------------------ spawning

    async def _spawn(self) -> None:
        self._ready.clear()
        try:
            self._process = await asyncio.create_subprocess_exec(
                self._config.node_executable,
                str(self._config.script_path),
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                limit=1024 * 1024,  # 1MB buffer for Windows compatibility
            )
        except (FileNotFoundError, OSError) as exc:
            raise SidecarError(
                f"failed to launch sidecar node process "
                f"'{self._config.node_executable} {self._config.script_path}': {exc}"
            ) from exc

        self._reader_task = asyncio.create_task(self._reader_loop())
        self._stderr_task = asyncio.create_task(self._drain_stderr())

        try:
            await asyncio.wait_for(self._ready.wait(), timeout=self._config.ready_timeout_seconds)
        except asyncio.TimeoutError:
            await self._terminate_process()
            raise SidecarError(
                f"sidecar did not become ready within "
                f"{self._config.ready_timeout_seconds}s"
            )

    async def _terminate_process(self) -> None:
        process = self._process
        self._process = None
        if process is None:
            return
        if process.returncode is not None:
            return
        try:
            process.terminate()
        except ProcessLookupError:
            return
        try:
            await asyncio.wait_for(process.wait(), timeout=10)
        except asyncio.TimeoutError:
            process.kill()
            try:
                await asyncio.wait_for(process.wait(), timeout=5)
            except asyncio.TimeoutError:
                pass

    # ------------------------------------------------------------------ readers

    async def _reader_loop(self) -> None:
        assert self._process is not None and self._process.stdout is not None
        stdout = self._process.stdout
        try:
            async for raw in stdout:
                self._handle_line(raw)
        except asyncio.CancelledError:
            raise
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("chromium sidecar stdout reader error: %s", exc)
        finally:
            self._on_process_exited()

    async def _drain_stderr(self) -> None:
        assert self._process is not None and self._process.stderr is not None
        stderr = self._process.stderr
        try:
            async for raw in stderr:
                text = raw.decode("utf-8", errors="replace").rstrip()
                if text:
                    logger.debug("chromium-sidecar: %s", text)
        except asyncio.CancelledError:
            raise
        except Exception:  # pragma: no cover - defensive
            pass

    def _handle_line(self, raw: bytes) -> None:
        line = raw.decode("utf-8", errors="replace").strip()
        if not line:
            return
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            logger.warning("non-JSON line from chromium sidecar: %s", line[:200])
            return

        if message.get("ready") is True:
            self._ready.set()
            return

        request_id = message.get("id")
        if request_id is None:
            return

        future = self._pending.pop(request_id, None)
        if future is None or future.done():
            return

        if "error" in message:
            error = message["error"]
            future.set_exception(
                SidecarError(
                    str(error.get("message", "unknown sidecar error")),
                    code=error.get("code"),
                )
            )
        else:
            future.set_result(message.get("result"))

    def _on_process_exited(self) -> None:
        self._ready.clear()
        for future in list(self._pending.values()):
            if not future.done():
                future.set_exception(
                    SidecarError("sidecar process exited unexpectedly")
                )
        self._pending.clear()
        if self._running:
            asyncio.create_task(self._restart("process-exit"))

    # ------------------------------------------------------------------ supervision

    async def _watchdog_loop(self) -> None:
        while self._running:
            await asyncio.sleep(self._config.health_interval_seconds)
            if not self._running:
                break
            await self._maybe_restart_for_health()

    async def _maybe_restart_for_health(self) -> None:
        if self._process is None or self._process.returncode is not None:
            asyncio.create_task(self._restart("process-not-alive"))
            return
        if time.monotonic() - self._started_at >= self._config.restart_idle_seconds:
            asyncio.create_task(self._restart("idle-timeout"))
            return
        if self._render_count >= self._config.restart_render_count:
            asyncio.create_task(self._restart("render-count"))
            return
        try:
            await self._request("health", {}, counts_as_render=False)
        except SidecarError:
            asyncio.create_task(self._restart("health-ping-failed"))

    async def _restart(self, reason: str) -> None:
        async with self._lock:
            if not self._running or self._restarting:
                return
            self._restarting = True
        try:
            logger.warning("restarting chromium sidecar (reason: %s)", reason)
            await self._terminate_process()
            self._ready.clear()
            self._render_count = 0
            self._started_at = time.monotonic()
            await self._spawn()
        except Exception as exc:  # pragma: no cover - supervisor resilience
            logger.exception("failed to restart marp sidecar: %s", exc)
        finally:
            self._restarting = False
