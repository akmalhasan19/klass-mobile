from app.routes.draft import router as draft_router
from app.routes.health import router as health_router
from app.routes.interpret import router as interpret_router
from app.routes.ops import router as ops_router
from app.routes.respond import router as respond_router

__all__ = ["draft_router", "health_router", "interpret_router", "ops_router", "respond_router"]
