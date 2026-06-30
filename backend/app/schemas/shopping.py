from pydantic import BaseModel, Field
from typing import List, Optional


class ShoppingItemResponse(BaseModel):
    id: str
    name: str
    amount: float
    unit: str
    estimated_price: float
    checked: bool
    source: str
    from_food_ids: List[str] = []
    created_at: str
    updated_at: str

    model_config = {"from_attributes": True}


class ShoppingListResponse(BaseModel):
    items: List[ShoppingItemResponse]
    total_estimated_cost: float
    unchecked_count: int


class ShoppingItemCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    amount: float = Field(ge=0)
    unit: str = ""
    estimated_price: float = Field(default=0, ge=0)


class ShoppingItemUpdate(BaseModel):
    amount: Optional[float] = Field(default=None, ge=0)
    unit: Optional[str] = None
    estimated_price: Optional[float] = Field(default=None, ge=0)
    checked: Optional[bool] = None


class ShoppingAddFromFoodRequest(BaseModel):
    food_id: str


class ShoppingAddFromFoodResponse(BaseModel):
    added_count: int
    merged_count: int
    items: List[ShoppingItemResponse]


class ShoppingClearCheckedResponse(BaseModel):
    deleted_count: int


class ShoppingExportResponse(BaseModel):
    text: str
