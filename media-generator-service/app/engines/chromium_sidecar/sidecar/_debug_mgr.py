"""Quick smoke test for the Chromium sidecar (html_to_pdf)."""
import asyncio
import logging
logging.basicConfig(level=logging.DEBUG)

from app.settings import get_settings
from app.engines.chromium_sidecar.sidecar.sidecar_manager import build_sidecar_manager


async def main():
    settings = get_settings()
    mgr = build_sidecar_manager(settings)
    await mgr.start()
    try:
        # Simple self-contained HTML that Chromium can render to PDF.
        html = (
            "<!DOCTYPE html>"
            "<html><head><meta charset='utf-8'>"
            "<style>body{font-family:sans-serif;padding:40px;}"
            "h1{color:#0B1F33}</style></head>"
            "<body><h1>Test PDF</h1><p>Hello from the sidecar.</p></body></html>"
        )
        print("HTML len", len(html))
        try:
            pdf = await mgr.html_to_pdf(html)
            print("PDF len", len(pdf))
        except Exception as e:
            print("HTML_TO_PDF ERROR:", repr(e))
    finally:
        await mgr.stop()


asyncio.run(main())
