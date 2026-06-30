from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.stats import CostStatsResponse
from app.services import stats_service as svc

router = APIRouter(prefix="/stats", tags=["stats"])


@router.get("/cost", response_model=CostStatsResponse)
async def cost(
    range: str = Query(default="week", pattern="^(week|month)$"),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    data = await svc.cost_summary(db, user_id, range)
    return CostStatsResponse(**data)
