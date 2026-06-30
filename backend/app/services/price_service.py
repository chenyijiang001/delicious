import uuid
from typing import Optional, List, Iterable

from sqlalchemy import select, func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ingredient_price import UserIngredientPrice
from app.utils.text import normalize_name


def _uid(s) -> uuid.UUID:
    return uuid.UUID(s) if isinstance(s, str) else s


async def list_prices(db: AsyncSession, user_id: str) -> List[UserIngredientPrice]:
    result = await db.execute(
        select(UserIngredientPrice)
        .where(UserIngredientPrice.user_id == _uid(user_id))
        .order_by(UserIngredientPrice.last_used_at.desc())
    )
    return list(result.scalars().all())


async def upsert_price(
    db: AsyncSession,
    user_id: str,
    name: str,
    unit: str,
    unit_price: float,
    source: str = "user_edit",
) -> UserIngredientPrice:
    uid = _uid(user_id)
    norm = normalize_name(name)
    stmt = (
        pg_insert(UserIngredientPrice)
        .values(
            id=uuid.uuid4(),
            user_id=uid,
            name=name,
            name_normalized=norm,
            unit=unit,
            unit_price=unit_price,
            source=source,
        )
        .on_conflict_do_update(
            constraint="uq_price_user_name_unit",
            set_={
                "unit_price": unit_price,
                "last_used_at": func.now(),
                "source": source,
            },
        )
    )
    await db.execute(stmt)
    await db.commit()
    result = await db.execute(
        select(UserIngredientPrice).where(
            UserIngredientPrice.user_id == uid,
            UserIngredientPrice.name_normalized == norm,
            UserIngredientPrice.unit == unit,
        )
    )
    return result.scalar_one()


async def delete_price(db: AsyncSession, price_id: str, user_id: str) -> bool:
    result = await db.execute(
        select(UserIngredientPrice).where(
            UserIngredientPrice.id == _uid(price_id),
            UserIngredientPrice.user_id == _uid(user_id),
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        return False
    await db.delete(record)
    await db.commit()
    return True


async def apply_user_prices(
    db: AsyncSession,
    user_id: str,
    ingredients: List[dict],
) -> List[dict]:
    """对 AI 返回的 ingredients 应用用户个人价格表。
    覆盖规则（见 ARCHITECTURE §4.1）：
    - 同 (name_normalized, unit) 命中时用 user_ingredient_prices.unit_price * amount
    - 仅在 user 价格在 [0.2x, 5x] AI 估算单价之间时生效，防脏数据
    返回新列表，原列表不修改。
    """
    if not ingredients:
        return ingredients

    uid = _uid(user_id)
    norms = [normalize_name(i.get("name", "")) for i in ingredients]
    result = await db.execute(
        select(UserIngredientPrice).where(
            UserIngredientPrice.user_id == uid,
            UserIngredientPrice.name_normalized.in_(norms),
        )
    )
    price_map = {
        (p.name_normalized, p.unit): float(p.unit_price)
        for p in result.scalars()
    }
    used_keys = []
    out = []
    for ing in ingredients:
        name = ing.get("name", "")
        unit = ing.get("unit", "") or ""
        amount = float(ing.get("amount", 0) or 0)
        ai_price = float(ing.get("estimated_price", 0) or 0)
        norm = normalize_name(name)
        key = (norm, unit)
        new_ing = dict(ing)
        new_ing.setdefault("price_source", "ai")
        user_unit_price = price_map.get(key)
        if user_unit_price is not None and amount > 0:
            user_total = round(user_unit_price * amount, 2)
            # 合理区间防脏数据
            ai_unit = ai_price / amount if amount > 0 else 0
            in_range = ai_unit == 0 or (0.2 * ai_unit <= user_unit_price <= 5 * ai_unit)
            if in_range:
                new_ing["estimated_price"] = user_total
                new_ing["price_source"] = "user"
                used_keys.append(key)
        out.append(new_ing)

    # 刷新 last_used_at
    if used_keys:
        for name_norm, unit in used_keys:
            await db.execute(
                UserIngredientPrice.__table__.update()
                .where(
                    UserIngredientPrice.user_id == uid,
                    UserIngredientPrice.name_normalized == name_norm,
                    UserIngredientPrice.unit == unit,
                )
                .values(last_used_at=func.now())
            )
        await db.commit()

    return out
