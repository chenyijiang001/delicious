import uuid
from datetime import date, timedelta
from typing import List

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.food import FoodRecord


def _uid(s) -> uuid.UUID:
    return uuid.UUID(s) if isinstance(s, str) else s


def _range_bounds(range_: str) -> tuple[date, date]:
    today = date.today()
    if range_ == "month":
        start = today.replace(day=1)
    else:
        # week: 周一 ~ 今天
        start = today - timedelta(days=today.weekday())
    return start, today


async def cost_summary(db: AsyncSession, user_id: str, range_: str = "week") -> dict:
    start, end = _range_bounds(range_)
    uid = _uid(user_id)
    rows = (
        await db.execute(
            select(FoodRecord).where(
                FoodRecord.user_id == uid,
                FoodRecord.cooked_at >= start,
                FoodRecord.cooked_at <= end,
                FoodRecord.total_cost.is_not(None),
            )
        )
    ).scalars().all()

    total_cost = float(sum(float(r.total_cost or 0) for r in rows))
    count = len(rows)
    avg = round(total_cost / count, 2) if count else 0.0

    # Top 3 贵 / 便宜
    sorted_rows = sorted(rows, key=lambda r: float(r.total_cost or 0), reverse=True)
    top_expensive = [
        {"food_id": str(r.id), "dish_name": r.dish_name, "cost": float(r.total_cost or 0)}
        for r in sorted_rows[:3]
    ]
    top_cheap = [
        {"food_id": str(r.id), "dish_name": r.dish_name, "cost": float(r.total_cost or 0)}
        for r in sorted_rows[::-1][:3]
    ]

    # By category
    cat_total: dict[str, float] = {}
    for r in rows:
        cat_total[r.category] = cat_total.get(r.category, 0.0) + float(r.total_cost or 0)
    by_category = [
        {
            "category": cat,
            "cost": round(v, 2),
            "ratio": round(v / total_cost, 2) if total_cost else 0,
        }
        for cat, v in sorted(cat_total.items(), key=lambda kv: kv[1], reverse=True)
    ]

    # By day
    day_total: dict[date, float] = {}
    for r in rows:
        day_total[r.cooked_at] = day_total.get(r.cooked_at, 0.0) + float(r.total_cost or 0)
    cursor = start
    by_day: List[dict] = []
    while cursor <= end:
        by_day.append({"date": cursor.isoformat(), "cost": round(day_total.get(cursor, 0.0), 2)})
        cursor += timedelta(days=1)

    return {
        "range": range_,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "total_cost": round(total_cost, 2),
        "record_count": count,
        "avg_per_meal": avg,
        "top_expensive": top_expensive,
        "top_cheap": top_cheap,
        "by_category": by_category,
        "by_day": by_day,
    }
