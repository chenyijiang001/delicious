import uuid
from datetime import datetime
from typing import List, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event
from app.schemas.event import EventIn


def _uid(s) -> Optional[uuid.UUID]:
    if s is None:
        return None
    return uuid.UUID(s) if isinstance(s, str) else s


async def ingest(
    db: AsyncSession,
    user_id: Optional[str],
    events: List[EventIn],
) -> int:
    if not events:
        return 0
    uid = _uid(user_id)
    rows = [
        Event(
            user_id=uid,
            name=e.name,
            ts=e.ts or datetime.utcnow(),
            props=e.props or {},
        )
        for e in events
    ]
    db.add_all(rows)
    await db.commit()
    return len(rows)
