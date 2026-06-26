from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import auth, foods, ai
from app.config import settings
from app.utils.storage import ensure_bucket


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure S3 bucket exists
    try:
        ensure_bucket()
    except Exception:
        pass  # MinIO may not be ready at startup
    yield


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
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
app.include_router(auth.router, prefix="/api/v1")
app.include_router(foods.router, prefix="/api/v1")
app.include_router(ai.router, prefix="/api/v1")


@app.get("/api/v1/health")
async def health():
    return {"status": "ok", "app": settings.app_name}
