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
from app.schemas.buy_suggestion import (
    BuySuggestionRequest,
    BuySuggestionResponse,
    BuySuggestionClickRequest,
)
from app.services import shopping_service as svc
from app.services.buy_suggestion_service import buy_suggestion_service
from app.services import purchase_click_service

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


# ---------------- V1.1 购物建议 ----------------

@router.post("/buy-suggestions", response_model=BuySuggestionResponse)
async def buy_suggestions(
    body: BuySuggestionRequest,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    """基于当前购物清单 + 位置，返回三个渠道的购买建议 + AI 一句话推荐。
    详见 ARCHITECTURE §5。
    """
    if body.location is None and not body.city_code:
        raise HTTPException(
            status_code=422,
            detail={
                "detail": "需要位置信息或城市编码",
                "code": "location_required",
            },
        )
    lat = body.location.lat if body.location else None
    lng = body.location.lng if body.location else None
    try:
        result = await buy_suggestion_service.build(
            db=db,
            user_id=user_id,
            lat=lat,
            lng=lng,
            city_code=body.city_code,
            radius_m=body.radius_m,
            channels=body.channels,
        )
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail={"detail": f"购物建议生成失败: {e}", "code": "poi_upstream_error"},
        )
    return BuySuggestionResponse(**result)


@router.post("/buy-suggestions/click", status_code=204)
async def buy_suggestions_click(
    body: BuySuggestionClickRequest,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    """轻量埋点：用户跳转任何渠道之前调用一次。"""
    await purchase_click_service.record(
        db,
        user_id=user_id,
        channel=body.channel,
        target=body.target,
        missing_count=body.missing_count,
    )
