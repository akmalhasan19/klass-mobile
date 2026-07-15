"""Unit tests for ``app.engines.chromium_sidecar.sidecar.sidecar_manager``.

Tests cover the full lifecycle of :class:`SidecarManager` using a mocked
subprocess.  Node.js is **not** required — ``asyncio.create_subprocess_exec``
is patched to return a controlled fake process whose stdout/stderr streams can
be fed from the test side.

Because ``SidecarManager`` is ``asyncio``‑based, each test runs inside
``asyncio.run()``.
"""
from __future__ import annotations

import asyncio
import json
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.engines.chromium_sidecar.sidecar.sidecar_manager import (
    SidecarConfig,
    SidecarError,
    SidecarManager,
    build_sidecar_manager,
)
from app.settings import Settings, clear_settings_cache


# ---------------------------------------------------------------------------
# Test helpers — fake subprocess streams
# ---------------------------------------------------------------------------

class _FakeStream:
    """Async-iterable stream that blocks until ``feed()`` is called.

    Simulates ``asyncio.subprocess.Process.stdout`` / ``stderr``.  Lines are
    yielded one at a time via ``async for``; the stream blocks on an internal
    ``asyncio.Event`` when no data is available.
    """

    def __init__(self) -> None:
        self._lines: list[bytes] = []
        self._pos = 0
        self._event: asyncio.Event | None = None
        self._closed = False

    def _ensure_event(self) -> asyncio.Event:
        if self._event is None:
            self._event = asyncio.Event()
        return self._event

    def __aiter__(self) -> "_FakeStream":
        return self

    async def __anext__(self) -> bytes:
        ev = self._ensure_event()
        while not self._closed:
            if self._pos < len(self._lines):
                break
            ev.clear()
            await ev.wait()
        if self._closed and self._pos >= len(self._lines):
            raise StopAsyncIteration
        line = self._lines[self._pos]
        self._pos += 1
        return line

    def feed(self, line: bytes) -> None:
        self._lines.append(line)
        if self._event is not None:
            self._event.set()

    def close(self) -> None:
        self._closed = True
        if self._event is not None:
            self._event.set()


def _make_fake_process(stdout: _FakeStream | None = None, stderr: _FakeStream | None = None) -> MagicMock:
    """Return a mock ``asyncio.subprocess.Process`` suitable for SidecarManager."""
    process = MagicMock()
    process.stdout = stdout or _FakeStream()
    process.stderr = stderr or _FakeStream()
    stdin_mock = MagicMock()
    stdin_mock.drain = AsyncMock()
    process.stdin = stdin_mock
    process.returncode = None
    process.terminate = MagicMock()
    process.kill = MagicMock()
    process.wait = AsyncMock(return_value=0)
    return process


def _make_config(**overrides: object) -> SidecarConfig:
    """Build a :class:`SidecarConfig` with tight timeouts suitable for tests."""
    kwargs: dict[str, object] = {
        "node_executable": "node",
        "script_path": Path("/fake/chromium_sidecar.js"),
        "ready_timeout_seconds": 1,
        "render_timeout_seconds": 2,
        "max_concurrent_renders": 2,
        "health_interval_seconds": 30,
        "restart_render_count": 100,
        "restart_idle_seconds": 3600,
    }
    kwargs.update(overrides)
    return SidecarConfig(**{k: v for k, v in kwargs.items() if k in SidecarConfig.__dataclass_fields__})


_PATCH_PATH = "app.engines.chromium_sidecar.sidecar.sidecar_manager.asyncio.create_subprocess_exec"


# ---------------------------------------------------------------------------
# 1. Configuration
# ---------------------------------------------------------------------------

def test_build_sidecar_manager_from_settings() -> None:
    """``build_sidecar_manager`` reads values from ``Settings``."""
    clear_settings_cache()
    settings = Settings(
        service_name="test",
        service_version="0.1.0",
        shared_secret="s",
        accepted_shared_secrets=("s",),
        request_max_age_seconds=300,
        artifact_url_ttl_seconds=900,
        public_base_url="",
        log_level="info",
        marp_sidecar_node_executable="custom-node",
        marp_sidecar_script_path="/custom/script.js",
        marp_sidecar_ready_timeout_seconds=5,
        marp_sidecar_render_timeout_seconds=10,
        marp_sidecar_max_concurrent_renders=3,
        marp_sidecar_health_interval_seconds=60,
        marp_sidecar_restart_render_count=200,
        marp_sidecar_restart_idle_seconds=7200,
    )

    manager = build_sidecar_manager(settings)

    assert manager._config.node_executable == "custom-node"
    assert manager._config.script_path == Path("/custom/script.js")
    assert manager._config.ready_timeout_seconds == 5
    assert manager._config.render_timeout_seconds == 10
    assert manager._config.max_concurrent_renders == 3
    assert manager._config.health_interval_seconds == 60
    assert manager._config.restart_render_count == 200
    assert manager._config.restart_idle_seconds == 7200


def test_sidecar_config_defaults() -> None:
    config = SidecarConfig()
    assert config.node_executable == "node"
    assert config.ready_timeout_seconds == 30
    assert config.render_timeout_seconds == 30
    assert config.max_concurrent_renders == 4
    assert config.restart_render_count == 100


# ---------------------------------------------------------------------------
# 2. Lifecycle — start / stop
# ---------------------------------------------------------------------------

def test_start_emits_ready_and_is_ready_after_start() -> None:
    """start() returns after receiving ``{"ready":true}`` from the sidecar."""

    async def _test() -> None:
        stdout = _FakeStream()
        stderr = _FakeStream()
        process = _make_fake_process(stdout=stdout, stderr=stderr)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config(ready_timeout_seconds=2))

            start_task = asyncio.create_task(manager.start())
            await asyncio.sleep(0)

            stdout.feed(b'{"ready":true}')

            await asyncio.wait_for(start_task, timeout=5)
            assert manager.is_ready
            assert manager.is_running
            assert manager.uptime_seconds > 0

            await manager.stop()

    asyncio.run(_test())


def test_start_timeout_when_no_ready_signal() -> None:
    """Raises ``SidecarError`` if the sidecar never sends ``ready``."""

    async def _test() -> None:
        stdout = _FakeStream()
        process = _make_fake_process(stdout=stdout)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config(ready_timeout_seconds=0.1))

            with pytest.raises(SidecarError, match="did not become ready"):
                await manager.start()

            assert not manager._running
            await manager.stop()

    asyncio.run(_test())


def test_start_spawn_failure_raises_sidecar_error() -> None:
    """If the subprocess cannot be launched, a ``SidecarError`` is raised."""

    async def _test() -> None:
        with patch(_PATCH_PATH, new_callable=AsyncMock, side_effect=FileNotFoundError("no node")):
            manager = SidecarManager(_make_config())
            with pytest.raises(SidecarError, match="failed to launch sidecar"):
                await manager.start()
            assert not manager.is_running

    asyncio.run(_test())


def test_start_when_already_running_is_noop() -> None:
    """Calling start() on an already-running manager does nothing."""

    async def _test() -> None:
        stdout = _FakeStream()
        process = _make_fake_process(stdout=stdout)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config())

            start_task = asyncio.create_task(manager.start())
            await asyncio.sleep(0)
            stdout.feed(b'{"ready":true}')
            await start_task

            # Second start should be a no-op.
            await manager.start()
            assert manager.is_ready

            await manager.stop()

    asyncio.run(_test())


def test_stop_cleans_up_process_and_tasks() -> None:
    """stop() terminates the subprocess and clears pending futures."""

    async def _test() -> None:
        stdout = _FakeStream()
        process = _make_fake_process(stdout=stdout)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config())

            start_task = asyncio.create_task(manager.start())
            await asyncio.sleep(0)
            stdout.feed(b'{"ready":true}')
            await start_task

            await manager.stop()

            assert not manager.is_running
            assert not manager.is_ready
            assert manager.uptime_seconds == 0.0
            process.terminate.assert_called()

    asyncio.run(_test())


def test_stop_when_not_running_is_noop() -> None:
    """Calling stop() on a not-running manager does nothing."""

    async def _test() -> None:
        manager = SidecarManager(_make_config())
        await manager.stop()
        # No exception — just returns silently.

    asyncio.run(_test())


def test_context_manager() -> None:
    """``async with SidecarManager(...)`` starts and stops automatically."""

    async def _test() -> None:
        stdout = _FakeStream()
        stderr = _FakeStream()
        process = _make_fake_process(stdout=stdout, stderr=stderr)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config(ready_timeout_seconds=2))

            # Feed the ready signal from a background task so it arrives
            # while ``__aenter__`` (→ ``start()``) is awaiting.
            async def _feed_ready() -> None:
                await asyncio.sleep(0.05)
                stdout.feed(b'{"ready":true}')

            feed_task = asyncio.create_task(_feed_ready())

            async with manager:
                assert manager.is_ready
                assert manager.is_running

            await feed_task
            assert not manager.is_running

    asyncio.run(_test())


# ---------------------------------------------------------------------------
# 3. Properties
# ---------------------------------------------------------------------------

def test_properties_before_start() -> None:
    async def _test() -> None:
        manager = SidecarManager(_make_config())
        assert not manager.is_running
        assert not manager.is_ready
        assert manager.uptime_seconds == 0.0

    asyncio.run(_test())


# ---------------------------------------------------------------------------
# 4. RPC — html_to_pdf, health
# ---------------------------------------------------------------------------

def test_html_to_pdf_returns_pdf_bytes_from_sidecar() -> None:
    """``html_to_pdf()`` sends an RPC request, decodes base64 PDF, and returns bytes."""

    async def _test() -> None:
        stdout = _FakeStream()
        process = _make_fake_process(stdout=stdout)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config())

            start_task = asyncio.create_task(manager.start())
            await asyncio.sleep(0)
            stdout.feed(b'{"ready":true}')
            await start_task

            pdf_task = asyncio.create_task(
                manager.html_to_pdf("<html><body>Hello</body></html>")
            )
            await asyncio.sleep(0)

            # Read what was written to stdin to extract the request id.
            write_args = process.stdin.write.call_args
            assert write_args is not None
            written = json.loads(write_args[0][0].decode("utf-8").strip())
            assert written["method"] == "html_to_pdf"
            assert written["params"]["html"] == "<html><body>Hello</body></html>"
            req_id = written["id"]

            # Feed back a base64-encoded PDF result.
            import base64
            pdf_bytes = b"%PDF-1.4-mock-content"
            pdf_b64 = base64.b64encode(pdf_bytes).decode()
            stdout.feed(
                json.dumps({"id": req_id, "result": {"pdf": pdf_b64}}).encode()
            )

            result = await asyncio.wait_for(pdf_task, timeout=2)
            assert result == pdf_bytes
            assert result.startswith(b"%PDF")

            await manager.stop()

    asyncio.run(_test())


def test_html_to_pdf_handles_empty_html() -> None:
    """``html_to_pdf()`` works with an empty HTML string."""

    async def _test() -> None:
        import base64

        stdout = _FakeStream()
        process = _make_fake_process(stdout=stdout)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config())

            start_task = asyncio.create_task(manager.start())
            await asyncio.sleep(0)
            stdout.feed(b'{"ready":true}')
            await start_task

            pdf_task = asyncio.create_task(manager.html_to_pdf(""))
            await asyncio.sleep(0)

            write_args = process.stdin.write.call_args
            written = json.loads(write_args[0][0].decode("utf-8").strip())
            req_id = written["id"]

            pdf_b64 = base64.b64encode(b"%PDF-empty").decode()
            stdout.feed(
                json.dumps({"id": req_id, "result": {"pdf": pdf_b64}}).encode()
            )

            result = await asyncio.wait_for(pdf_task, timeout=2)
            assert result == b"%PDF-empty"

            await manager.stop()

    asyncio.run(_test())


def test_health_returns_status_from_sidecar() -> None:
    """``health()`` sends a probe and returns the status dict."""

    async def _test() -> None:
        stdout = _FakeStream()
        process = _make_fake_process(stdout=stdout)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config())

            start_task = asyncio.create_task(manager.start())
            await asyncio.sleep(0)
            stdout.feed(b'{"ready":true}')
            await start_task

            health_task = asyncio.create_task(manager.health())
            await asyncio.sleep(0)

            write_args = process.stdin.write.call_args
            written = json.loads(write_args[0][0].decode("utf-8").strip())
            assert written["method"] == "health"
            req_id = written["id"]

            stdout.feed(
                json.dumps({"id": req_id, "result": {"status": "ok", "browser": True}}).encode()
            )

            result = await asyncio.wait_for(health_task, timeout=2)
            assert result == {"status": "ok", "browser": True}

            await manager.stop()

    asyncio.run(_test())


# ---------------------------------------------------------------------------
# 5. Message handling — _handle_line
# ---------------------------------------------------------------------------

def test_handle_line_sets_ready() -> None:
    """``_handle_line`` with ``{"ready":true}`` sets the ready event."""

    async def _test() -> None:
        manager = SidecarManager(_make_config())
        manager._handle_line(b'{"ready":true}')
        assert manager._ready.is_set()

    asyncio.run(_test())


def test_handle_line_resolves_pending_future() -> None:
    """``_handle_line`` with a result resolves the corresponding future."""

    async def _test() -> None:
        manager = SidecarManager(_make_config())
        loop = asyncio.get_running_loop()
        future: asyncio.Future[object] = loop.create_future()
        manager._pending[42] = future

        manager._handle_line(b'{"id":42,"result":{"html":"ok"}}')
        assert future.done()
        assert future.result()["html"] == "ok"

    asyncio.run(_test())


def test_handle_line_rejects_future_on_error() -> None:
    """``_handle_line`` with an error message rejects the future."""

    async def _test() -> None:
        manager = SidecarManager(_make_config())
        loop = asyncio.get_running_loop()
        future: asyncio.Future[object] = loop.create_future()
        manager._pending[99] = future

        manager._handle_line(b'{"id":99,"error":{"code":"-32000","message":"boom"}}')
        assert future.done()
        with pytest.raises(SidecarError, match="boom"):
            future.result()

    asyncio.run(_test())


def test_handle_line_ignores_non_json() -> None:
    """Non-JSON lines are logged and ignored — they do not crash the reader."""

    async def _test() -> None:
        manager = SidecarManager(_make_config())
        manager._handle_line(b"not valid json at all")
        # Must not raise.

    asyncio.run(_test())


def test_handle_line_ignores_empty_line() -> None:
    """Empty or whitespace-only lines are ignored."""

    async def _test() -> None:
        manager = SidecarManager(_make_config())
        manager._handle_line(b"")
        manager._handle_line(b"   ")
        manager._handle_line(b"\n")
        # Must not raise.

    asyncio.run(_test())


def test_handle_line_ignores_message_without_id() -> None:
    """Messages without ``id`` (but not ``ready``) are silently ignored."""

    async def _test() -> None:
        manager = SidecarManager(_make_config())
        manager._handle_line(b'{"event":"log","data":"hello"}')
        # Must not raise or create side effects.

    asyncio.run(_test())


# ---------------------------------------------------------------------------
# 6. Error handling & timeouts
# ---------------------------------------------------------------------------

def test_request_timeout_raises_sidecar_error() -> None:
    """A render request that times out raises ``SidecarError``."""

    async def _test() -> None:
        stdout = _FakeStream()
        process = _make_fake_process(stdout=stdout)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config(render_timeout_seconds=0.1))

            start_task = asyncio.create_task(manager.start())
            await asyncio.sleep(0)
            stdout.feed(b'{"ready":true}')
            await start_task

            # html_to_pdf with a 0.1s timeout — we never feed a response.
            with pytest.raises(SidecarError, match="timed out"):
                await manager.html_to_pdf("<html></html>")

            await manager.stop()

    asyncio.run(_test())


def test_sidecar_error_preserves_code() -> None:
    """``SidecarError.code`` is preserved for upstream mapping."""
    exc = SidecarError("something went wrong", code="NODE_CRASH")
    assert exc.code == "NODE_CRASH"
    assert str(exc) == "something went wrong"


def test_html_to_pdf_missing_pdf_field_raises() -> None:
    """If the result dict lacks a ``pdf`` key, ``SidecarError`` is raised."""

    async def _test() -> None:
        stdout = _FakeStream()
        process = _make_fake_process(stdout=stdout)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config())

            start_task = asyncio.create_task(manager.start())
            await asyncio.sleep(0)
            stdout.feed(b'{"ready":true}')
            await start_task

            pdf_task = asyncio.create_task(manager.html_to_pdf("<html></html>"))
            await asyncio.sleep(0)

            write_args = process.stdin.write.call_args
            written = json.loads(write_args[0][0].decode("utf-8").strip())
            req_id = written["id"]

            stdout.feed(json.dumps({"id": req_id, "result": {}}).encode())

            with pytest.raises(SidecarError, match="no pdf field"):
                await asyncio.wait_for(pdf_task, timeout=2)

            await manager.stop()

    asyncio.run(_test())


# ---------------------------------------------------------------------------
# 7. Concurrency
# ---------------------------------------------------------------------------

def test_semaphore_limits_concurrent_renders() -> None:
    """When ``max_concurrent_renders`` is reached, further renders are queued."""

    async def _test() -> None:
        stdout = _FakeStream()
        process = _make_fake_process(stdout=stdout)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config(
                max_concurrent_renders=2, render_timeout_seconds=5,
            ))

            start_task = asyncio.create_task(manager.start())
            await asyncio.sleep(0)
            stdout.feed(b'{"ready":true}')
            await start_task

            # Launch first two renders — both should acquire semaphore immediately.
            t1 = asyncio.create_task(manager.html_to_pdf("<html>a</html>"))
            t2 = asyncio.create_task(manager.html_to_pdf("<html>b</html>"))
            await asyncio.sleep(0)
            await asyncio.sleep(0)
            # Two writes on stdin (one per acquired semaphore slot).
            assert len(process.stdin.write.call_args_list) == 2

            # Launch third — should be queued (semaphore exhausted).
            t3 = asyncio.create_task(manager.html_to_pdf("<html>c</html>"))
            await asyncio.sleep(0)
            await asyncio.sleep(0)
            # Still only two — third is still waiting for semaphore.
            assert len(process.stdin.write.call_args_list) == 2

            # Resolve t1 — feed back a base64 PDF result.
            import base64
            msg1 = json.loads(process.stdin.write.call_args_list[0][0][0].decode("utf-8").strip())
            pdf1 = base64.b64encode(b"%PDF-1")
            stdout.feed(json.dumps({"id": msg1["id"], "result": {"pdf": pdf1.decode()}}).encode())
            await t1

            # Now t3 should have acquired the semaphore — write count becomes 3.
            await asyncio.sleep(0)
            await asyncio.sleep(0)
            assert len(process.stdin.write.call_args_list) == 3

            # Resolve t2.
            msg2 = json.loads(process.stdin.write.call_args_list[1][0][0].decode("utf-8").strip())
            pdf2 = base64.b64encode(b"%PDF-2")
            stdout.feed(json.dumps({"id": msg2["id"], "result": {"pdf": pdf2.decode()}}).encode())
            await t2

            # Resolve t3.
            msg3 = json.loads(process.stdin.write.call_args_list[2][0][0].decode("utf-8").strip())
            pdf3 = base64.b64encode(b"%PDF-3")
            stdout.feed(json.dumps({"id": msg3["id"], "result": {"pdf": pdf3.decode()}}).encode())
            await t3

            assert t1.done() and t2.done() and t3.done()

            await manager.stop()

    asyncio.run(_test())


# ---------------------------------------------------------------------------
# 8. Edge cases
# ---------------------------------------------------------------------------

def test_stderr_is_drained_without_error() -> None:
    """Stderr lines are consumed by the drain task without crashing."""

    async def _test() -> None:
        stdout = _FakeStream()
        stderr = _FakeStream()
        process = _make_fake_process(stdout=stdout, stderr=stderr)

        with patch(_PATCH_PATH, new_callable=AsyncMock, return_value=process):
            manager = SidecarManager(_make_config())

            start_task = asyncio.create_task(manager.start())
            await asyncio.sleep(0)
            stdout.feed(b'{"ready":true}')
            await start_task

            # Feed some stderr lines — drain task should handle them.
            stderr.feed(b"node: info message")
            stderr.feed(b"Warning: deprecated API")
            await asyncio.sleep(0)
            await asyncio.sleep(0)

            assert manager.is_ready

            await manager.stop()

    asyncio.run(_test())
