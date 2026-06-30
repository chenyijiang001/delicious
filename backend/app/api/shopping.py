from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.shopping import (
    ShoppingListResponse,
    ShoppingItemResponse,
    ShoppingItemCreate,
    ShoppingItemUpdate,
    ShoppingAddFromFoodRequest,
    ShoppingAddFromFoodResponse,
    ShoppingClearCheckedResponse,
    ShoppingExportResponse,
)
from app.services import shopping_service as svc

router = APIRouter(prefix="/shopping", tags=["shopping"])


def _to_response(item) -> ShoppingItemResponse:
    return ShoppingItemResponse(
        id=str(item.id),
        name=item.name,
        amount=float(item.amount),
        unit=item.unit,
        estimated_price=float(item.estimated_price),
        checked=item.checked,
        source=item.source,
        from_food_ids=[str(x) for x in (item.from_food_ids or [])],
        created_at=item.created_at.isoformat(),
        updated_at=item.updated_at.isoformat(),
    )


@router.get("/items", response_model=ShoppingListResponse)
async def list_items(
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    items, total, unchecked = await svc.list_items(db, user_id)
    return ShoppingListResponse(
        items=[_to_response(it) for it in items],
        total_estimated_cost=round(total, 2),
        unchecked_count=unchecked,
    )


@router.post("/items", response_model=ShoppingItemResponse, status_code=status.HTTP_201_CREATED)
async def add_item(
    data: ShoppingItemCreate,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    item = await svc.add_manual_item(
        db,
        user_id,
        name=data.name,
        amount=data.amount,
        unit=data.unit,
        estimated_price=data.estimated_price,
    )
    return _to_response(item)


@router.patch("/items/{item_id}", response_model=ShoppingItemResponse)
async def update_item(
    item_id: str,
    data: ShoppingItemUpdate,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    item = await svc.update_item(
        db,
        user_id,
        item_id,
        amount=data.amount,
        unit=data.unit,
        estimated_price=data.estimated_price,
        checked=data.checked,
    )
    if not item:
        raise HTTPException(status_code=404, detail={"detail": "Item not found", "code": "not_found"})
    return _to_response(item)


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(
    item_id: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    ok = await svc.delete_item(db, user_id, item_id)
    if not ok:
        raise HTTPException(status_code=404, detail={"detail": "Item not found", "code": "not_found"})


@router.post(
    "/items/from-food",
    response_model=ShoppingAddFromFoodResponse,
)
async def add_from_food(
    data: ShoppingAddFromFoodRequest,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    added, merged = await svc.add_from_food(db, user_id, data.food_id)
    if added + merged == 0:
        raise HTTPException(
            status_code=404,
            detail={"detail": "Food not found or has no ingredients", "code": "not_found"},
        )
    items, _, _ = await svc.list_items(db, user_id)
    return ShoppingAddFromFoodResponse(
        added_count=added,
        merged_count=merged,
        items=[_to_response(it) for it in items],
    )


@router.post("/clear-checked", response_model=ShoppingClearCheckedResponse)
async def clear_checked(
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    deleted = await svc.clear_checked(db, user_id)
    return ShoppingClearCheckedResponse(deleted_count=deleted)


@router.get("/export", response_model=ShoppingExportResponse)
async def export_shopping(
    format: str = Query(default="text", pattern="^(text)$"),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    items, _, _ = await svc.list_items(db, user_id)
    text = svc.export_text(items, date.today().isoformat())
    return ShoppingExportResponse(text=text)
