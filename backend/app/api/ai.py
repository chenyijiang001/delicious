from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.ai import (
    AIRecipeResponse,
    AIFeedbackCreate,
    AIFeedbackResponse,
)
from app.services.ai_service import ai_service as ai_svc, NoFoodDetected
from app.services import price_service, feedback_service
from app.utils.storage import upload_image, make_thumbnail

router = APIRouter(prefix="/ai", tags=["AI"])


@router.post("/recognize", response_model=AIRecipeResponse)
async def recognize_food(
    image: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail={"detail": "Only image files are accepted", "code": "bad_request"},
        )

    image_bytes = await image.read()
    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail={"detail": "Image too large (max 10MB)", "code": "payload_too_large"},
        )

    try:
        result, cache_hit, latency_ms = await ai_svc.recognize_food(image_bytes)
    except NoFoodDetected:
        raise HTTPException(
            status_code=422,
            detail={"detail": "图片中未识别到食物", "code": "no_food_detected"},
        )
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail={"detail": f"AI recognition failed: {e}", "code": "ai_upstream_error"},
        )

    # 用户个人价格覆盖（见 ARCHITECTURE §4.1）
    ingredients = await price_service.apply_user_prices(
        db, user_id, result.get("ingredients", [])
    )
    total_cost = round(
        sum(float(i.get("estimated_price") or 0) for i in ingredients), 2
    )

    # 图片上传到 S3
    try:
        image_url = upload_image(image_bytes)
        thumb_url = upload_image(make_thumbnail(image_bytes))
    except Exception:
        image_url = None
        thumb_url = None

    return AIRecipeResponse(
        dish_name=result.get("dish_name", "未知菜品"),
        category=result.get("category", "其他"),
        ingredients=ingredients,
        steps=result.get("steps", []),
        total_cost=total_cost or result.get("total_cost", 0),
        serving_size=result.get("serving_size", 1),
        difficulty=result.get("difficulty", "中等"),
        tips=result.get("tips", []),
        image_url=image_url,
        thumbnail_url=thumb_url,
        cache_hit=cache_hit,
        latency_ms=latency_ms,
    )


@router.post(
    "/feedback",
    response_model=AIFeedbackResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_feedback(
    data: AIFeedbackCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if not data.food_id and not data.image_url:
        raise HTTPException(
            status_code=422,
            detail={
                "detail": "food_id 或 image_url 至少需要一项",
                "code": "validation_error",
            },
        )
    fb = await feedback_service.create_feedback(
        db,
        user_id=user_id,
        food_id=data.food_id,
        image_url=data.image_url,
        reasons=data.reasons,
        comment=data.comment,
    )
    return AIFeedbackResponse(id=str(fb.id), created_at=fb.created_at.isoformat())
