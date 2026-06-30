from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.price import (
    IngredientPriceListResponse,
    IngredientPriceResponse,
    IngredientPriceUpsert,
)
from app.services import price_service as svc

router = APIRouter(prefix="/user/ingredient-prices", tags=["prices"])


def _to_response(p) -> IngredientPriceResponse:
    return IngredientPriceResponse(
        id=str(p.id),
        name=p.name,
        unit=p.unit,
        unit_price=float(p.unit_price),
        last_used_at=p.last_used_at.isoformat(),
        source=p.source,
    )


@router.get("", response_model=IngredientPriceListResponse)
async def list_prices(
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    items = await svc.list_prices(db, user_id)
    return IngredientPriceListResponse(items=[_to_response(p) for p in items])


@router.post("", response_model=IngredientPriceResponse)
async def upsert_price(
    data: IngredientPriceUpsert,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    p = await svc.upsert_price(
        db,
        user_id,
        name=data.name,
        unit=data.unit,
        unit_price=data.unit_price,
        source="user_edit",
    )
    return _to_response(p)


@router.delete("/{price_id}", status_code=204)
async def delete_price(
    price_id: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    ok = await svc.delete_price(db, price_id, user_id)
    if not ok:
        raise HTTPException(status_code=404, detail={"detail": "Price not found", "code": "not_found"})
