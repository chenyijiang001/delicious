from pydantic import BaseModel
from typing import List, Optional


class AIRecipeResponse(BaseModel):
    dish_name: str
    category: str
    ingredients: List[dict]
    steps: List[dict]
    total_cost: float
    serving_size: int
    difficulty: str
    tips: List[str]
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
