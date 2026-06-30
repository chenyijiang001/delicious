import uuid
from datetime import date
from typing import Optional, Tuple, List

from sqlalchemy import select, func, and_, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.food import FoodRecord
from app.schemas.food import FoodRecordCreate, FoodRecordUpdate
from app.utils.text import normalize_name


def _uid(s: str) -> uuid.UUID:
    return uuid.UUID(s) if isinstance(s, str) else s


async def list_foods(
    db: AsyncSession,
    user_id: str,
    page: int = 1,
    size: int = 20,
    q: Optional[str] = None,
    category: Optional[str] = None,
    ingredient: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
) -> Tuple[List[FoodRecord], int]:
    uid = _uid(user_id)
    base = [FoodRecord.user_id == uid]

    if q:
        base.append(FoodRecord.dish_name.ilike(f"%{q}%"))
    if category:
        base.append(FoodRecord.category == category)
    if date_from:
        base.append(FoodRecord.cooked_at >= date_from)
    if date_to:
        base.append(FoodRecord.cooked_at <= date_to)

    if ingredient:
        # JSONB containment: ingredients @> '[{"name": "番茄"}]'
        norm = normalize_name(ingredient)
        # 用 jsonb_path_exists 做大小写不敏感的匹配
        base.append(
            text(
                "EXISTS (SELECT 1 FROM jsonb_array_elements(food_records.ingredients) AS ing "
                "WHERE lower(trim(ing->>'name')) = :ing_norm)"
            ).bindparams(ing_norm=norm)
        )

    where_clause = and_(*base)

    total_result = await db.execute(select(func.count(FoodRecord.id)).where(where_clause))
    total = total_result.scalar() or 0

    offset = (page - 1) * size
    result = await db.execute(
        select(FoodRecord)
        .where(where_clause)
        .order_by(FoodRecord.cooked_at.desc(), FoodRecord.created_at.desc())
        .offset(offset)
        .limit(size)
    )
    return list(result.scalars().all()), total


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
        cooked_at=data.cooked_at or date.today(),
        source=data.source,
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


# ---- V1.0 新增 ----

def _ingredient_overlap(a: list, b: list) -> float:
    """两个 ingredient 列表的食材交集占并集比例（按 name_normalized）。"""
    if not a or not b:
        return 0.0
    sa = {normalize_name(i.get("name", "")) for i in a if i.get("name")}
    sb = {normalize_name(i.get("name", "")) for i in b if i.get("name")}
    if not sa or not sb:
        return 0.0
    inter = sa & sb
    union = sa | sb
    return len(inter) / len(union)


def _dish_name_score(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    na, nb = normalize_name(a), normalize_name(b)
    if na == nb:
        return 1.0
    if na in nb or nb in na:
        return 0.85
    # 简单编辑距离阈值
    if abs(len(na) - len(nb)) <= 1 and sum(c1 != c2 for c1, c2 in zip(na, nb)) <= 1:
        return 0.7
    return 0.0


async def find_similar_record(
    db: AsyncSession,
    user_id: str,
    data: FoodRecordCreate,
    threshold: float = 0.85,
) -> Optional[Tuple[FoodRecord, float]]:
    """同月范围内找相似度最高的一条；返回 (record, similarity) 或 None。"""
    uid = _uid(user_id)
    today = data.cooked_at or date.today()
    month_start = today.replace(day=1)

    candidates = await db.execute(
        select(FoodRecord).where(
            FoodRecord.user_id == uid,
            FoodRecord.cooked_at >= month_start,
        )
    )

    best: Optional[Tuple[FoodRecord, float]] = None
    target_ings = [i.model_dump() for i in data.ingredients]
    for c in candidates.scalars():
        score = 0.6 * _dish_name_score(c.dish_name, data.dish_name) + 0.4 * _ingredient_overlap(
            c.ingredients or [], target_ings
        )
        if score >= threshold and (best is None or score > best[1]):
            best = (c, score)
    return best


async def duplicate_food(
    db: AsyncSession,
    food_id: str,
    user_id: str,
    new_serving: Optional[int] = None,
) -> Optional[FoodRecord]:
    original = await get_food(db, food_id, user_id)
    if not original:
        return None

    ratio = 1.0
    if new_serving and original.serving_size and new_serving != original.serving_size:
        ratio = new_serving / original.serving_size

    def _scale_ing(i: dict) -> dict:
        out = dict(i)
        out["amount"] = round(float(i.get("amount", 0)) * ratio, 1)
        out["estimated_price"] = round(float(i.get("estimated_price", 0)) * ratio, 2)
        return out

    new_total = (
        round(float(original.total_cost) * ratio, 2)
        if original.total_cost is not None
        else None
    )

    record = FoodRecord(
        user_id=_uid(user_id),
        image_url=original.image_url,
        thumbnail_url=original.thumbnail_url,
        dish_name=original.dish_name,
        category=original.category,
        ingredients=[_scale_ing(i) for i in (original.ingredients or [])],
        steps=list(original.steps or []),
        total_cost=new_total,
        serving_size=new_serving or original.serving_size,
        difficulty=original.difficulty,
        tips=list(original.tips or []),
        notes=original.notes,
        cooked_at=date.today(),
        source="duplicate",
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return record
