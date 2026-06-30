"""购物建议主编排：把购物清单 → 三渠道推荐 → AI 一句话策略。

实现 ARCHITECTURE.md §5 的 5 步数据流：
  1. 食材规范化（DB ingredient_aliases + Redis alias:{name} + AI 兜底）
  2. POI 查询（amap_service，已带 Redis 缓存）
  3. 覆盖度判断（规则）
  4. AI 一句话推荐（Redis suggest:{key} 缓存 4h）
  5. 组装 deeplink + 返回
"""
import hashlib
import json
import uuid
from typing import Optional

from openai import AsyncOpenAI
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.configs.store_deeplinks import available_in_city
from app.models.ingredient_alias import IngredientAlias
from app.models.poi import PoiCache
from app.models.shopping import ShoppingListItem
from app.services.amap_service import amap_service
from app.utils.geohash import encode as geohash_encode
from app.utils.text import normalize_name

ALIAS_PROMPT = """你是食材归类助手。对输入的食材名列表，返回严格 JSON 对象：

输入示例：["西红柿", "紫苏", "鸡蛋"]
输出（items 数组与输入顺序一一对应）：
{
  "items": [
    {"canonical":"番茄","category":"蔬菜",
     "store_type_coverage":{"supermarket":true,"convenience":false,"market":true,"fresh":true},
     "confidence":0.95},
    {"canonical":"紫苏","category":"蔬菜",
     "store_type_coverage":{"supermarket":false,"convenience":false,"market":true,"fresh":true},
     "confidence":0.9},
    {"canonical":"鸡蛋","category":"肉蛋",
     "store_type_coverage":{"supermarket":true,"convenience":true,"market":true,"fresh":true},
     "confidence":0.99}
  ]
}

规则：
- 便利店覆盖：调味料/酒水/零食/常见乳制品；不覆盖：生鲜、蔬菜、肉类
- 超市覆盖：除小众食材外都有
- 菜市场覆盖：生鲜全有、调味料部分
- 生鲜专卖：蔬菜肉类齐全、调味料部分
- 小众食材（紫苏、抹茶粉、特殊香料）→ supermarket: false
- confidence < 0.7 表示你拿不准（不会被固化进数据库）
"""

SUGGEST_PROMPT = """你是购物路线规划助手。基于以下信息给出一句中文推荐（≤ 30 字）：

输出严格 JSON：
{"suggestion":"...", "primary_store":"<name>", "supplement":[]}

要求：
- suggestion 直接告诉用户去哪家最省事，不解释
- 单店全覆盖：建议这一家 + 估价
- 单店缺货：推荐主店 + 用 online 补缺
- 都没覆盖到：建议 online 平台
"""


class BuySuggestionService:
    def __init__(self):
        self.redis = None
        self._openai = AsyncOpenAI(
            api_key=settings.openai_api_key,
            base_url=settings.openai_api_base,
        )

    def attach_redis(self, redis_client) -> None:
        self.redis = redis_client

    # ---------- 入口 ----------
    async def build(
        self,
        db: AsyncSession,
        user_id: str,
        lat: Optional[float],
        lng: Optional[float],
        city_code: Optional[str],
        radius_m: int,
        channels: list[str],
    ) -> dict:
        # 监控用的缓存命中标志，由各步骤就地填写
        cache_hits = {
            "alias": False,
            "poi": False,
            "coverage": True,  # 覆盖度纯规则，恒为 hit
            "suggestion": False,
        }

        # 1. 取用户当前购物清单（未勾选）
        items = await self._load_shopping_items(db, user_id)
        if not items:
            return self._empty_response(items_total=0)

        # 2. 食材语义归类
        aliases = await self._resolve_aliases(db, items, cache_hits)

        # 3. POI 查询（仅 offline 渠道，需要 lat/lng）
        offline_blocks: list[dict] = []
        if "offline" in channels and lat is not None and lng is not None:
            pois, poi_stale = await amap_service.nearby_pois(
                lat=lat, lng=lng, radius=radius_m
            )
            cache_hits["poi"] = not poi_stale and bool(pois)
            await self._cache_pois(db, pois, lat, lng)
            offline_blocks = self._build_offline_blocks(pois, items, aliases)

        # 4. 线上 / 外卖渠道
        online_blocks = []
        delivery_blocks = []
        platforms = available_in_city(city_code)
        for p in platforms:
            block = self._build_platform_block(p, items, aliases)
            if p["channel"] == "online" and "online" in channels:
                online_blocks.append(block)
            elif p["channel"] == "delivery" and "delivery" in channels:
                delivery_blocks.append(block)

        # 5. AI 一句话文案（缓存 4h）
        ai_suggestion = await self._ai_suggestion(
            user_id, items, aliases, offline_blocks, online_blocks, lat, lng,
            cache_hits,
        )

        return {
            "ai_suggestion": ai_suggestion,
            "items_total": len(items),
            "offline": offline_blocks,
            "online": online_blocks,
            "delivery": delivery_blocks,
            "cache_hit": cache_hits,
        }

    # ---------- Step 1: 加载清单 ----------
    async def _load_shopping_items(
        self, db: AsyncSession, user_id: str
    ) -> list[dict]:
        rows = await db.execute(
            select(ShoppingListItem).where(
                ShoppingListItem.user_id == uuid.UUID(user_id),
                ShoppingListItem.checked.is_(False),
            )
        )
        return [
            {
                "name": r.name,
                "name_normalized": r.name_normalized,
                "amount": float(r.amount),
                "unit": r.unit,
                "estimated_price": float(r.estimated_price),
            }
            for r in rows.scalars()
        ]

    # ---------- Step 2: 食材别名归类 ----------
    async def _resolve_aliases(
        self,
        db: AsyncSession,
        items: list[dict],
        cache_hits: dict,
    ) -> dict[str, dict]:
        """返回 {name_normalized: alias_info}。alias_info 缺失时表示降级为"未知食材"。
        cache_hits["alias"] = True 仅当所有食材都从 DB 命中（未调用 AI）。
        """
        names_norm = [it["name_normalized"] for it in items]
        if not names_norm:
            cache_hits["alias"] = True
            return {}

        # 先查 DB（一次性）
        rows = await db.execute(
            select(IngredientAlias).where(
                IngredientAlias.alias_normalized.in_(names_norm)
            )
        )
        out: dict[str, dict] = {}
        for r in rows.scalars():
            out[r.alias_normalized] = {
                "canonical": r.canonical,
                "category": r.canonical_category,
                "store_type_coverage": r.store_type_coverage or {},
                "confidence": float(r.confidence),
            }

        # 缺的食材交给 AI 一次性查
        missing_items = [it for it in items if it["name_normalized"] not in out]
        if not missing_items:
            cache_hits["alias"] = True
            return out

        ai_result = await self._ai_classify(missing_items)
        for it, info in zip(missing_items, ai_result):
            if info is None:
                continue
            norm = it["name_normalized"]
            out[norm] = info
            # confidence >= 0.7 才固化
            if info["confidence"] >= 0.7:
                await self._upsert_alias(db, it["name"], norm, info)

        return out

    async def _ai_classify(self, items: list[dict]) -> list[Optional[dict]]:
        try:
            payload = json.dumps([it["name"] for it in items], ensure_ascii=False)
            response = await self._openai.chat.completions.create(
                model=settings.openai_model,
                messages=[
                    {"role": "system", "content": ALIAS_PROMPT},
                    {"role": "user", "content": payload},
                ],
                response_format={"type": "json_object"},
                max_tokens=800,
            )
            content = response.choices[0].message.content or "{}"
            data = json.loads(content)
            # 后端要求 array，但 response_format=json_object 强制对象；prompt 写明 array → 包一层
            arr = data if isinstance(data, list) else data.get("items") or data.get("result") or []
            result: list[Optional[dict]] = []
            for i, _ in enumerate(items):
                if i >= len(arr):
                    result.append(None)
                    continue
                entry = arr[i]
                result.append(
                    {
                        "canonical": entry.get("canonical") or items[i]["name"],
                        "category": entry.get("category") or "其他",
                        "store_type_coverage": entry.get("store_type_coverage") or {},
                        "confidence": float(entry.get("confidence") or 0),
                    }
                )
            return result
        except Exception:
            return [None] * len(items)

    async def _upsert_alias(
        self, db: AsyncSession, alias_raw: str, alias_norm: str, info: dict
    ) -> None:
        stmt = (
            pg_insert(IngredientAlias)
            .values(
                id=uuid.uuid4(),
                alias=alias_raw,
                alias_normalized=alias_norm,
                canonical=info["canonical"],
                canonical_category=info["category"],
                store_type_coverage=info["store_type_coverage"],
                confidence=info["confidence"],
            )
            .on_conflict_do_update(
                constraint="uq_ingredient_aliases_norm",
                set_={
                    "canonical": info["canonical"],
                    "canonical_category": info["category"],
                    "store_type_coverage": info["store_type_coverage"],
                    "confidence": info["confidence"],
                },
            )
        )
        try:
            await db.execute(stmt)
            await db.commit()
        except Exception:
            await db.rollback()

    # ---------- Step 3: 覆盖度 ----------
    def _coverage(
        self, poi_category: str, items: list[dict], aliases: dict[str, dict]
    ) -> tuple[int, int, list[str], float]:
        matched, missing = 0, []
        est_cost = 0.0
        for it in items:
            alias = aliases.get(it["name_normalized"])
            covered = (alias or {}).get("store_type_coverage", {}).get(
                poi_category, True
            )
            if covered:
                matched += 1
                est_cost += it["estimated_price"]
            else:
                missing.append(it["name"])
        return matched, len(items), missing, round(est_cost, 2)

    # ---------- Step 3a: 线下 ----------
    def _build_offline_blocks(
        self, pois: list[dict], items: list[dict], aliases: dict[str, dict]
    ) -> list[dict]:
        out = []
        for p in pois[:8]:  # 前 8 家足够展示
            matched, total, missing, cost = self._coverage(
                p["category"], items, aliases
            )
            out.append(
                {
                    "poi_id": p["id"],
                    "name": p["name"],
                    "category": p["category"],
                    "distance_m": p["distance_m"],
                    "address": p["address"],
                    "coverage": {
                        "matched": matched,
                        "total": total,
                        "missing": missing,
                    },
                    "estimated_cost": cost,
                    "navigate_url": _amap_marker_url(p["lat"], p["lng"], p["name"]),
                }
            )
        # 排序：覆盖优先于距离
        max_dist = max((b["distance_m"] for b in out), default=1) or 1
        out.sort(
            key=lambda b: -(
                0.6 * b["coverage"]["matched"] / max(b["coverage"]["total"], 1)
                + 0.4 * (1 - b["distance_m"] / max_dist)
            )
        )
        return out

    # ---------- Step 3b: 线上 / 外卖 ----------
    def _build_platform_block(
        self, platform: dict, items: list[dict], aliases: dict[str, dict]
    ) -> dict:
        # platform["channel"] 已包含正确的归属（online / delivery）, 前端按 Tab 显式带回
        # 线上平台默认覆盖度高（除非有特别小众食材，AI 标了 supermarket=false 也可能在叮咚找不到）
        matched, total, missing, cost = self._coverage(
            "supermarket", items, aliases  # 线上视为 supermarket 级覆盖
        )
        # 用第一个食材生成跳转关键词
        query = items[0]["name"] if items else "食材"
        scheme = platform["scheme"].replace("{query}", query)
        web = platform["web_fallback"].replace("{query}", query)
        return {
            "platform": platform["platform"],
            "platform_name": platform["name"],
            "channel": platform["channel"],
            "coverage": {"matched": matched, "total": total, "missing": missing},
            "estimated_cost": cost,
            "estimated_eta_minutes": platform.get("eta_minutes_default", 40),
            "scheme": scheme,
            "web_fallback": web,
        }

    # ---------- Step 4: AI 一句话 ----------
    async def _ai_suggestion(
        self,
        user_id: str,
        items: list[dict],
        aliases: dict[str, dict],
        offline_blocks: list[dict],
        online_blocks: list[dict],
        lat: Optional[float],
        lng: Optional[float],
        cache_hits: dict,
    ) -> Optional[str]:
        geohash5 = geohash_encode(lat, lng, 5) if (lat and lng) else "_"
        ings_hash = hashlib.sha1(
            ",".join(sorted(it["name_normalized"] for it in items)).encode()
        ).hexdigest()[:12]
        cache_key = f"suggest:{user_id}:{ings_hash}:{geohash5}"

        # 缓存
        if self.redis is not None:
            try:
                cached = await self.redis.get(cache_key)
                if cached:
                    cache_hits["suggestion"] = True
                    return cached
            except Exception:
                pass

        # 调 AI
        try:
            payload = {
                "shopping_list": [
                    {"name": it["name"], "amount": it["amount"], "unit": it["unit"]}
                    for it in items
                ],
                "offline": [
                    {
                        "name": b["name"],
                        "matched": b["coverage"]["matched"],
                        "total": b["coverage"]["total"],
                        "missing": b["coverage"]["missing"],
                        "cost": b["estimated_cost"],
                        "distance_m": b["distance_m"],
                    }
                    for b in offline_blocks[:3]
                ],
                "online": [
                    {
                        "name": b["platform_name"],
                        "matched": b["coverage"]["matched"],
                        "total": b["coverage"]["total"],
                        "eta": b["estimated_eta_minutes"],
                    }
                    for b in online_blocks[:3]
                ],
            }
            response = await self._openai.chat.completions.create(
                model=settings.openai_model,
                messages=[
                    {"role": "system", "content": SUGGEST_PROMPT},
                    {"role": "user", "content": json.dumps(payload, ensure_ascii=False)},
                ],
                response_format={"type": "json_object"},
                max_tokens=200,
            )
            content = response.choices[0].message.content or "{}"
            data = json.loads(content)
            text = data.get("suggestion")
            if text and self.redis is not None:
                try:
                    await self.redis.setex(cache_key, 4 * 3600, text)
                except Exception:
                    pass
            return text
        except Exception:
            return None

    # ---------- POI 落库 ----------
    async def _cache_pois(
        self, db: AsyncSession, pois: list[dict], origin_lat: float, origin_lng: float
    ) -> None:
        """高德返回的 POI 顺手写 pois_cache，便于后续按 geohash5 + category 直接 SQL 取。"""
        if not pois:
            return
        for p in pois:
            if not p.get("id"):
                continue
            stmt = pg_insert(PoiCache).values(
                id=p["id"],
                name=p["name"],
                category=p["category"],
                lat=p["lat"],
                lng=p["lng"],
                city_code=p.get("city_code"),
                address=p.get("address") or "",
                geohash5=geohash_encode(p["lat"], p["lng"], 5),
            )
            stmt = stmt.on_conflict_do_nothing(index_elements=["id"])
            try:
                await db.execute(stmt)
            except Exception:
                pass
        try:
            await db.commit()
        except Exception:
            await db.rollback()

    def _empty_response(self, items_total: int) -> dict:
        return {
            "ai_suggestion": None,
            "items_total": items_total,
            "offline": [],
            "online": [],
            "delivery": [],
            "cache_hit": {
                "alias": False,
                "poi": False,
                "coverage": False,
                "suggestion": False,
            },
        }


def _amap_marker_url(lat: float, lng: float, name: str) -> str:
    """生成高德导航 deeplink（http 形式跨平台兼容）。"""
    return (
        f"https://uri.amap.com/marker?position={lng},{lat}"
        f"&name={name}&coordinate=gaode&src=delicious"
    )


buy_suggestion_service = BuySuggestionService()
