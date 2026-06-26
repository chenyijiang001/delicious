from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.food import FoodRecordCreate, FoodRecordUpdate, FoodRecordResponse, FoodListResponse
from app.services import food_service as svc

router = APIRouter(prefix="/foods", tags=["foods"])


def _food_to_response(record) -> FoodRecordResponse:
    return FoodRecordResponse(
        id=str(record.id),
        image_url=record.image_url,
        thumbnail_url=record.thumbnail_url,
        dish_name=record.dish_name,
        category=record.category,
        ingredients=record.ingredients or [],
        steps=record.steps or [],
        total_cost=float(record.total_cost) if record.total_cost else None,
        serving_size=record.serving_size or 1,
        difficulty=record.difficulty or "中等",
        tips=record.tips or [],
        notes=record.notes,
        created_at=record.created_at.isoformat(),
        updated_at=record.updated_at.isoformat(),
    )


@router.get("", response_model=FoodListResponse)
async def list_foods(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    q: Optional[str] = None,
    category: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    items, total = await svc.list_foods(db, user_id, page, size, q, category)
    return FoodListResponse(
        items=[_food_to_response(item) for item in items],
        total=total,
        page=page,
        size=size,
    )


@router.get("/{food_id}", response_model=FoodRecordResponse)
async def get_food(
    food_id: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    record = await svc.get_food(db, food_id, user_id)
    if not record:
        raise HTTPException(status_code=404, detail="Food record not found")
    return _food_to_response(record)


@router.post("", response_model=FoodRecordResponse, status_code=status.HTTP_201_CREATED)
async def create_food(
    data: FoodRecordCreate,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    record = await svc.create_food(db, user_id, data)
    return _food_to_response(record)


@router.put("/{food_id}", response_model=FoodRecordResponse)
async def update_food(
    food_id: str,
    data: FoodRecordUpdate,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    record = await svc.update_food(db, food_id, user_id, data)
    if not record:
        raise HTTPException(status_code=404, detail="Food record not found")
    return _food_to_response(record)


@router.delete("/{food_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_food(
    food_id: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    deleted = await svc.delete_food(db, food_id, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Food record not found")
