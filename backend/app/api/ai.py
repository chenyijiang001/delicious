from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user_id
from app.schemas.ai import AIRecipeResponse
from app.services.ai_service import ai_service as ai_svc
from app.utils.storage import upload_image, make_thumbnail

router = APIRouter(prefix="/ai", tags=["AI"])


@router.post("/recognize", response_model=AIRecipeResponse)
async def recognize_food(
    image: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
):
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are accepted")

    image_bytes = await image.read()
    if len(image_bytes) > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(status_code=400, detail="Image too large (max 10MB)")

    try:
        result = await ai_svc.recognize_food(image_bytes)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI recognition failed: {str(e)}")

    # Upload to storage (background-friendly — fire and forget on thumbnail)
    try:
        image_url = upload_image(image_bytes)
        thumb_bytes = make_thumbnail(image_bytes)
        thumb_url = upload_image(thumb_bytes)
    except Exception:
        image_url = None
        thumb_url = None

    return AIRecipeResponse(
        dish_name=result.get("dish_name", "未知菜品"),
        category=result.get("category", "其他"),
        ingredients=result.get("ingredients", []),
        steps=result.get("steps", []),
        total_cost=result.get("total_cost", 0),
        serving_size=result.get("serving_size", 1),
        difficulty=result.get("difficulty", "中等"),
        tips=result.get("tips", []),
        image_url=image_url,
        thumbnail_url=thumb_url,
    )
