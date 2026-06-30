import uuid
from typing import List, Optional, Tuple

from sqlalchemy import select, delete, func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.shopping import ShoppingListItem
from app.models.food import FoodRecord
from app.services.food_service import get_food
from app.utils.text import normalize_name


def _uid(s) -> uuid.UUID:
    return uuid.UUID(s) if isinstance(s, str) else s


async def list_items(
    db: AsyncSession, user_id: str
) -> Tuple[List[ShoppingListItem], float, int]:
    uid = _uid(user_id)
    result = await db.execute(
        select(ShoppingListItem)
        .where(ShoppingListItem.user_id == uid)
        .order_by(ShoppingListItem.checked.asc(), ShoppingListItem.updated_at.desc())
    )
    items = list(result.scalars().all())
    total_cost = float(sum(float(i.estimated_price) for i in items if not i.checked))
    unchecked = sum(1 for i in items if not i.checked)
    return items, total_cost, unchecked


async def add_manual_item(
    db: AsyncSession,
    user_id: str,
    name: str,
    amount: float,
    unit: str,
    estimated_price: float,
) -> ShoppingListItem:
    uid = _uid(user_id)
    norm = normalize_name(name)
    stmt = (
        pg_insert(ShoppingListItem)
        .values(
            id=uuid.uuid4(),
            user_id=uid,
            name=name,
            name_normalized=norm,
            amount=amount,
            unit=unit,
            estimated_price=estimated_price,
            source="manual",
            from_food_ids=[],
        )
        .on_conflict_do_update(
            constraint="uq_shopping_user_name_unit",
            set_={
                "amount": ShoppingListItem.__table__.c.amount + amount,
                "estimated_price": ShoppingListItem.__table__.c.estimated_price + estimated_price,
                "updated_at": func.now(),
            },
        )
    )
    await db.execute(stmt)
    await db.commit()
    result = await db.execute(
        select(ShoppingListItem).where(
            ShoppingListItem.user_id == uid,
            ShoppingListItem.name_normalized == norm,
            ShoppingListItem.unit == unit,
        )
    )
    return result.scalar_one()


async def update_item(
    db: AsyncSession,
    user_id: str,
    item_id: str,
    *,
    amount: Optional[float] = None,
    unit: Optional[str] = None,
    estimated_price: Optional[float] = None,
    checked: Optional[bool] = None,
) -> Optional[ShoppingListItem]:
    result = await db.execute(
        select(ShoppingListItem).where(
            ShoppingListItem.id == _uid(item_id),
            ShoppingListItem.user_id == _uid(user_id),
        )
    )
    item = result.scalar_one_or_none()
    if not item:
        return None
    if amount is not None:
        item.amount = amount
    if unit is not None:
        item.unit = unit
    if estimated_price is not None:
        item.estimated_price = estimated_price
    if checked is not None:
        item.checked = checked
    await db.commit()
    await db.refresh(item)
    return item


async def delete_item(db: AsyncSession, user_id: str, item_id: str) -> bool:
    result = await db.execute(
        select(ShoppingListItem).where(
            ShoppingListItem.id == _uid(item_id),
            ShoppingListItem.user_id == _uid(user_id),
        )
    )
    item = result.scalar_one_or_none()
    if not item:
        return False
    await db.delete(item)
    await db.commit()
    return True


async def clear_checked(db: AsyncSession, user_id: str) -> int:
    uid = _uid(user_id)
    result = await db.execute(
        delete(ShoppingListItem)
        .where(
            ShoppingListItem.user_id == uid,
            ShoppingListItem.checked == True,
        )
        .returning(ShoppingListItem.id)
    )
    deleted = len(list(result.scalars().all()))
    await db.commit()
    return deleted


async def add_from_food(
    db: AsyncSession, user_id: str, food_id: str
) -> Tuple[int, int]:
    """从一条菜的 ingredients 批量加入清单。返回 (added_count, merged_count)。
    合并规则：同 (user, name_normalized, unit) → 数量相加；已勾选的不参与累加，会新建一条。
    """
    uid = _uid(user_id)
    food: Optional[FoodRecord] = await get_food(db, food_id, user_id)
    if not food:
        return 0, 0

    added, merged = 0, 0
    food_uuid = _uid(food_id)

    # 预查现有清单，区分 「不存在 / 未勾选 / 已勾选」
    existing = await db.execute(
        select(
            ShoppingListItem.name_normalized,
            ShoppingListItem.unit,
            ShoppingListItem.checked,
        ).where(ShoppingListItem.user_id == uid)
    )
    existing_status: dict[tuple[str, str], bool] = {
        (r[0], r[1]): r[2] for r in existing.all()
    }

    for ing in food.ingredients or []:
        name = ing.get("name", "")
        if not name:
            continue
        unit = ing.get("unit", "") or ""
        amount = float(ing.get("amount", 0) or 0)
        price = float(ing.get("estimated_price", 0) or 0)
        norm = normalize_name(name)
        key = (norm, unit)

        # 已勾选 → 视为已买完，本次不累加，避免「买完了又被加进去」
        if existing_status.get(key) is True:
            continue

        stmt = (
            pg_insert(ShoppingListItem)
            .values(
                id=uuid.uuid4(),
                user_id=uid,
                name=name,
                name_normalized=norm,
                amount=amount,
                unit=unit,
                estimated_price=price,
                source="auto",
                from_food_ids=[food_uuid],
            )
            .on_conflict_do_update(
                constraint="uq_shopping_user_name_unit",
                set_={
                    "amount": ShoppingListItem.__table__.c.amount + amount,
                    "estimated_price": ShoppingListItem.__table__.c.estimated_price + price,
                    "from_food_ids": func.array_append(
                        ShoppingListItem.__table__.c.from_food_ids, food_uuid
                    ),
                    "updated_at": func.now(),
                },
            )
        )
        await db.execute(stmt)
        if key in existing_status:
            merged += 1
        else:
            added += 1
            existing_status[key] = False  # 同食材若在 ingredients 出现多次，第二次走 merged 分支

    await db.commit()
    return added, merged


def export_text(items: List[ShoppingListItem], today: str) -> str:
    lines = [f"🛒 购物清单 ({today})"]
    for it in items:
        if it.checked:
            continue
        amount = float(it.amount)
        amount_str = f"{int(amount)}" if amount.is_integer() else f"{amount:g}"
        lines.append(f"- {it.name} × {amount_str}{it.unit}")
    return "\n".join(lines)
