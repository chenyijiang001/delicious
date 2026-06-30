import uuid
from typing import Optional, List

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.feedback import AIFeedback


def _uid(s) -> Optional[uuid.UUID]:
    if s is None:
        return None
    return uuid.UUID(s) if isinstance(s, str) else s


async def create_feedback(
    db: AsyncSession,
    user_id: str,
    food_id: Optional[str],
    image_url: Optional[str],
    reasons: List[str],
    comment: Optional[str],
) -> AIFeedback:
    fb = AIFeedback(
        user_id=_uid(user_id),
        food_id=_uid(food_id),
        image_url=image_url,
        reasons=reasons or [],
        comment=comment,
    )
    db.add(fb)
    await db.commit()
    await db.refresh(fb)
    return fb
