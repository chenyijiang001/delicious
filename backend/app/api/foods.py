from datetime import date
from typing import Optional, Union

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.food import (
    FoodRecordCreate,
    FoodRecordUpdate,
    FoodRecordResponse,
    FoodListResponse,
    FoodDuplicateRequest,
    FoodDuplicateHint,
)
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
        total_cost=float(record.total_cost) if record.total_cost is not None else None,
        serving_size=record.serving_size or 1,
        difficulty=record.difficulty or "中等",
        tips=record.tips or [],
        notes=record.notes,
        cooked_at=record.cooked_at.isoformat(),
        source=record.source,
        created_at=record.created_at.isoformat(),
        updated_at=record.updated_at.isoformat(),
    )


@router.get("", response_model=FoodListResponse)
async def list_foods(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=50),
    q: Optional[str] = None,
    category: Optional[str] = None,
    ingredient: Optional[str] = None,
    date_from: Optional[date] = Query(default=None, alias="from"),
    date_to: Optional[date] = Query(default=None, alias="to"),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    items, total = await svc.list_foods(
        db,
        user_id,
        page=page,
        size=size,
        q=q,
        category=category,
        ingredient=ingredient,
        date_from=date_from,
        date_to=date_to,
    )
    return FoodListResponse(
        items=[_food_to_response(it) for it in items],
        total=total,
        page=page,
        size=size,
    )


@router.post(
    "",
    response_model=Union[FoodRecordResponse, FoodDuplicateHint],
    status_code=status.HTTP_201_CREATED,
)
async def create_food(
    data: FoodRecordCreate,
    response: Response,
    force: bool = Query(False),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    if not force:
        match = await svc.find_similar_record(db, user_id, data)
        if match:
            candidate, similarity = match
            # 200 而非 201：客户端弹窗让用户决定
            response.status_code = status.HTTP_200_OK
            return FoodDuplicateHint(
                duplicate_of=str(candidate.id),
                similarity=round(similarity, 2),
                candidate=_food_to_response(candidate),
            )
    record = await svc.create_food(db, user_id, data)
    return _food_to_response(record)


@router.get("/{food_id}", response_model=FoodRecordResponse)
async def get_food(
    food_id: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    record = await svc.get_food(db, food_id, user_id)
    if not record:
        raise HTTPException(status_code=404, detail={"detail": "Food not found", "code": "not_found"})
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
        raise HTTPException(status_code=404, detail={"detail": "Food not found", "code": "not_found"})
    return _food_to_response(record)


@router.delete("/{food_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_food(
    food_id: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    ok = await svc.delete_food(db, food_id, user_id)
    if not ok:
        raise HTTPException(status_code=404, detail={"detail": "Food not found", "code": "not_found"})


@router.post(
    "/{food_id}/duplicate",
    response_model=FoodRecordResponse,
    status_code=status.HTTP_201_CREATED,
)
async def duplicate_food(
    food_id: str,
    data: FoodDuplicateRequest,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    record = await svc.duplicate_food(db, food_id, user_id, new_serving=data.serving_size)
    if not record:
        raise HTTPException(status_code=404, detail={"detail": "Food not found", "code": "not_found"})
    return _food_to_response(record)
