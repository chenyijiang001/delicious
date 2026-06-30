"""高德 Web API 客户端。
免费额度 5000 次/日，配合 6h Redis 缓存 + geohash 批量取。
失败时返回 stale 缓存（即使过期），保证降级可用。
"""
import json
import time
from typing import Optional

import httpx

from app.config import settings
from app.utils.geohash import encode as geohash_encode

# 高德 v5 周边搜索 typecode 白名单
CATEGORY_TYPECODE = {
    "supermarket": "060100",  # 综合超市
    "convenience": "060101",  # 便利店
    "market": "060102",  # 菜市场
    "fresh": "060103",  # 生鲜专卖
}
# 反向映射，从高德 typecode 头三位回推内部 category
TYPECODE_PREFIX_TO_CATEGORY = {
    "060100": "supermarket",
    "060101": "convenience",
    "060102": "market",
    "060103": "fresh",
}

CACHE_TTL_SECONDS = 6 * 3600  # 6h


class AmapService:
    def __init__(self):
        self.redis = None
        self._client = httpx.AsyncClient(timeout=5.0)

    def attach_redis(self, redis_client) -> None:
        self.redis = redis_client

    async def aclose(self) -> None:
        await self._client.aclose()

    async def nearby_pois(
        self,
        lat: float,
        lng: float,
        radius: int = 1500,
        categories: Optional[list[str]] = None,
    ) -> tuple[list[dict], bool]:
        """搜索附近 POI。返回 (pois, stale)。
        stale=True 表示高德调用失败、用了过期缓存兜底。
        """
        cats = categories or list(CATEGORY_TYPECODE.keys())
        geohash5 = geohash_encode(lat, lng, 5)
        cache_key = f"poi:{geohash5}:{radius}:{','.join(sorted(cats))}"

        # L2: Redis 缓存
        if self.redis is not None:
            try:
                cached = await self.redis.get(cache_key)
                if cached:
                    return json.loads(cached), False
            except Exception:
                pass

        # 调高德
        try:
            pois = await self._fetch_from_amap(lat, lng, radius, cats)
            if self.redis is not None:
                try:
                    await self.redis.setex(
                        cache_key, CACHE_TTL_SECONDS, json.dumps(pois, ensure_ascii=False)
                    )
                    # stale 兜底用：单独存一份 7 天 TTL 的副本，便于高德挂时降级
                    await self.redis.setex(
                        f"{cache_key}:stale",
                        7 * 24 * 3600,
                        json.dumps(pois, ensure_ascii=False),
                    )
                except Exception:
                    pass
            return pois, False
        except Exception:
            # 降级：取 stale 副本
            if self.redis is not None:
                try:
                    stale = await self.redis.get(f"{cache_key}:stale")
                    if stale:
                        return json.loads(stale), True
                except Exception:
                    pass
            return [], True

    async def _fetch_from_amap(
        self, lat: float, lng: float, radius: int, cats: list[str]
    ) -> list[dict]:
        types = "|".join(CATEGORY_TYPECODE[c] for c in cats if c in CATEGORY_TYPECODE)
        params = {
            "key": settings.amap_api_key,
            "location": f"{lng},{lat}",  # 注意：高德是 lng,lat 顺序
            "radius": radius,
            "types": types,
            "sortrule": "distance",
            "page_size": 25,
        }
        url = f"{settings.amap_api_base}/place/around"
        resp = await self._client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()
        if str(data.get("status")) != "1":
            raise RuntimeError(f"amap_error: {data.get('info')}")

        out = []
        for p in data.get("pois", []):
            location = p.get("location", "")
            if "," not in location:
                continue
            lng_s, lat_s = location.split(",", 1)
            typecode = (p.get("typecode") or "")[:6]
            category = TYPECODE_PREFIX_TO_CATEGORY.get(typecode, "supermarket")
            out.append(
                {
                    "id": p.get("id"),
                    "name": p.get("name"),
                    "category": category,
                    "lat": float(lat_s),
                    "lng": float(lng_s),
                    "address": p.get("address") or "",
                    "distance_m": int(p.get("distance") or 0),
                    "city_code": p.get("adcode"),
                }
            )
        return out


amap_service = AmapService()
