import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.purchase_click import PurchaseClick


async def record(
    db: AsyncSession,
    user_id: str,
    channel: str,
    target: str,
    missing_count: int,
) -> PurchaseClick:
    row = PurchaseClick(
        user_id=uuid.UUID(user_id),
        channel=channel,
        target=target,
        missing_count=missing_count,
    )
    db.add(row)
    await db.commit()
    return row
