from pydantic import BaseModel, Field
from typing import List


class IngredientPriceResponse(BaseModel):
    id: str
    name: str
    unit: str
    unit_price: float
    last_used_at: str
    source: str

    model_config = {"from_attributes": True}


class IngredientPriceListResponse(BaseModel):
    items: List[IngredientPriceResponse]


class IngredientPriceUpsert(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    unit: str = ""
    unit_price: float = Field(gt=0)
