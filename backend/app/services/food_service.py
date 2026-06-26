import uuid
from typing import Optional, Tuple, List

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.food import FoodRecord
from app.schemas.food import FoodRecordCreate, FoodRecordUpdate


def _uid(s: str) -> uuid.UUID:
    return uuid.UUID(s)


async def list_foods(
    db: AsyncSession,
    user_id: str,
    page: int = 1,
    size: int = 20,
    q: Optional[str] = None,
    category: Optional[str] = None,
) -> Tuple[List[FoodRecord], int]:
    uid = _uid(user_id)
    query = select(FoodRecord).where(FoodRecord.user_id == uid)
    count_query = select(func.count(FoodRecord.id)).where(FoodRecord.user_id == uid)

    if q:
        query = query.where(FoodRecord.dish_name.ilike(f"%{q}%"))
        count_query = count_query.where(FoodRecord.dish_name.ilike(f"%{q}%"))
    if category:
        query = query.where(FoodRecord.category == category)
        count_query = count_query.where(FoodRecord.category == category)

    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    offset = (page - 1) * size
    query = query.order_by(FoodRecord.created_at.desc()).offset(offset).limit(size)
    result = await db.execute(query)
    items = list(result.scalars().all())

    return items, total


async def get_food(db: AsyncSession, food_id: str, user_id: str) -> Optional[FoodRecord]:
    result = await db.execute(
        select(FoodRecord).where(
            FoodRecord.id == _uid(food_id),
            FoodRecord.user_id == _uid(user_id),
        )
    )
    return result.scalar_one_or_none()


async def create_food(db: AsyncSession, user_id: str, data: FoodRecordCreate) -> FoodRecord:
    record = FoodRecord(
        user_id=_uid(user_id),
        image_url=data.image_url,
        thumbnail_url=data.thumbnail_url,
        dish_name=data.dish_name,
        category=data.category,
        ingredients=[i.model_dump() for i in data.ingredients],
        steps=[s.model_dump() for s in data.steps],
        total_cost=data.total_cost,
        serving_size=data.serving_size,
        difficulty=data.difficulty,
        tips=data.tips,
        notes=data.notes,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return record


async def update_food(
    db: AsyncSession, food_id: str, user_id: str, data: FoodRecordUpdate
) -> Optional[FoodRecord]:
    record = await get_food(db, food_id, user_id)
    if not record:
        return None
    for field, value in data.model_dump(exclude_unset=True).items():
        if field in ("ingredients", "steps", "tips") and value is not None:
            value = [v if isinstance(v, dict) else v.model_dump() for v in value]
        setattr(record, field, value)
    await db.commit()
    await db.refresh(record)
    return record


async def delete_food(db: AsyncSession, food_id: str, user_id: str) -> bool:
    record = await get_food(db, food_id, user_id)
    if not record:
        return False
    await db.delete(record)
    await db.commit()
    return True
