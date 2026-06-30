from pydantic import BaseModel, Field
from typing import Optional, List, Literal
from datetime import date


class IngredientSchema(BaseModel):
    name: str
    amount: float
    unit: str
    estimated_price: float
    price_source: Literal["ai", "user"] = "ai"


class StepSchema(BaseModel):
    step_num: int
    description: str
    duration_minutes: int = 0


class FoodRecordCreate(BaseModel):
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    dish_name: str = Field(min_length=1, max_length=200)
    category: str = "其他"
    ingredients: List[IngredientSchema] = []
    steps: List[StepSchema] = []
    total_cost: Optional[float] = None
    serving_size: int = 1
    difficulty: str = "中等"
    tips: List[str] = []
    notes: Optional[str] = None
    cooked_at: Optional[date] = None
    source: Literal["recognize", "manual", "duplicate"] = "recognize"


class FoodRecordUpdate(BaseModel):
    dish_name: Optional[str] = None
    category: Optional[str] = None
    ingredients: Optional[List[IngredientSchema]] = None
    steps: Optional[List[StepSchema]] = None
    total_cost: Optional[float] = None
    serving_size: Optional[int] = None
    difficulty: Optional[str] = None
    tips: Optional[List[str]] = None
    notes: Optional[str] = None
    cooked_at: Optional[date] = None


class FoodRecordResponse(BaseModel):
    id: str
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    dish_name: str
    category: str
    ingredients: List[IngredientSchema]
    steps: List[StepSchema]
    total_cost: Optional[float] = None
    serving_size: int
    difficulty: str
    tips: List[str]
    notes: Optional[str] = None
    cooked_at: str
    source: str
    created_at: str
    updated_at: str

    model_config = {"from_attributes": True}


class FoodListResponse(BaseModel):
    items: List[FoodRecordResponse]
    total: int
    page: int
    size: int


class FoodDuplicateRequest(BaseModel):
    serving_size: Optional[int] = Field(default=None, ge=1, le=20)


class FoodDuplicateHint(BaseModel):
    """POST /foods 检测到同月近似记录时返回，HTTP 200。"""
    duplicate_of: str
    similarity: float
    candidate: FoodRecordResponse
