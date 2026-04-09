from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.costs import build_operator_summary_payload
from app.models import OperatorSummaryResponse
from app.settings import Settings, get_settings

router = APIRouter(tags=["ops"])


@router.get("/ops/summary", response_model=OperatorSummaryResponse)
def ops_summary(
    days: int = Query(default=1, ge=1, le=30),
    settings: Settings = Depends(get_settings),
) -> dict[str, object]:
    return build_operator_summary_payload(settings, days=days)


@router.get("/v1/ops/summary", response_model=OperatorSummaryResponse)
def versioned_ops_summary(
    days: int = Query(default=1, ge=1, le=30),
    settings: Settings = Depends(get_settings),
) -> dict[str, object]:
    return build_operator_summary_payload(settings, days=days)