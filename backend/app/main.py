from contextlib import asynccontextmanager

import redis.asyncio as aioredis
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import auth, foods, ai, shopping, prices, stats, events
from app.config import settings
from app.services.ai_service import ai_service
from app.services.amap_service import amap_service
from app.services.buy_suggestion_service import buy_suggestion_service
from app.utils.storage import ensure_bucket


@asynccontextmanager
async def lifespan(app: FastAPI):
    # S3 bucket（MinIO 启动慢时容忍失败）
    try:
        ensure_bucket()
    except Exception:
        pass

    # Redis：识别结果缓存 + POI 缓存 + AI 建议缓存 + 后续限流
    redis_client = None
    try:
        redis_client = aioredis.from_url(settings.redis_url, decode_responses=True)
        await redis_client.ping()
        ai_service.attach_redis(redis_client)
        amap_service.attach_redis(redis_client)
        buy_suggestion_service.attach_redis(redis_client)
    except Exception:
        redis_client = None  # Redis 不可用不影响主流程，仅丢失缓存

    app.state.redis = redis_client
    try:
        yield
    finally:
        await amap_service.aclose()
        if redis_client is not None:
            await redis_client.aclose()


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
prefix = "/api/v1"
app.include_router(auth.router, prefix=prefix)
app.include_router(foods.router, prefix=prefix)
app.include_router(ai.router, prefix=prefix)
app.include_router(shopping.router, prefix=prefix)
app.include_router(prices.router, prefix=prefix)
app.include_router(stats.router, prefix=prefix)
app.include_router(events.router, prefix=prefix)


@app.get("/api/v1/health")
async def health():
    return {"status": "ok", "app": settings.app_name, "version": "v1.0.0"}
