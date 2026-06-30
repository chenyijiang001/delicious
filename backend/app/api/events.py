from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.event import EventsBatchRequest, EventsBatchResponse
from app.services import event_service as svc

router = APIRouter(prefix="/events", tags=["events"])


@router.post(
    "",
    response_model=EventsBatchResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def ingest(
    data: EventsBatchRequest,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    accepted = await svc.ingest(db, user_id, data.events)
    return EventsBatchResponse(accepted=accepted)
