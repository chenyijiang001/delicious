from pydantic import BaseModel, Field
from typing import List, Optional, Literal


class AIRecipeIngredient(BaseModel):
    name: str
    amount: float
    unit: str
    estimated_price: float
    price_source: Literal["ai", "user"] = "ai"


class AIRecipeStep(BaseModel):
    step_num: int
    description: str
    duration_minutes: int = 0


class AIRecipeResponse(BaseModel):
    dish_name: str
    category: str
    ingredients: List[AIRecipeIngredient]
    steps: List[AIRecipeStep]
    total_cost: float
    serving_size: int
    difficulty: str
    tips: List[str]
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    cache_hit: bool = False
    latency_ms: int = 0


class AIFeedbackCreate(BaseModel):
    food_id: Optional[str] = None
    image_url: Optional[str] = None
    reasons: List[str] = Field(default_factory=list)
    comment: Optional[str] = None


class AIFeedbackResponse(BaseModel):
    id: str
    created_at: str
