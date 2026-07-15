import asyncio
import logging
logging.basicConfig(level=logging.DEBUG)

from app.settings import get_settings
from app.engines.marp.sidecar.sidecar_manager import build_sidecar_manager
from app.engines.marp.marp_renderer import MarpRenderer
from app.engines.marp.marp_markdown_builder import build_marp_markdown
from app.document_model import build_render_document
from app.engines.blueprint_builder import build_slide_blueprint
from tests.helpers import sample_request


async def main():
    settings = get_settings()
    mgr = build_sidecar_manager(settings)
    await mgr.start()
    try:
        bp = build_slide_blueprint(build_render_document(sample_request("pdf").generation_spec))
        md = build_marp_markdown(bp)
        renderer = MarpRenderer(mgr)
        html = await renderer._sidecar.render_html(md, theme_css=renderer._theme_css)
        print("HTML len", len(html))
        try:
            pdf = await mgr.render_pdf(html)
            print("PDF len", len(pdf))
        except Exception as e:
            print("RENDER_PDF ERROR:", repr(e))
    finally:
        await mgr.stop()


asyncio.run(main())
