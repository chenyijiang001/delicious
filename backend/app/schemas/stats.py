from pydantic import BaseModel
from typing import List


class CostItemBrief(BaseModel):
    food_id: str
    dish_name: str
    cost: float


class CostByCategory(BaseModel):
    category: str
    cost: float
    ratio: float


class CostByDay(BaseModel):
    date: str
    cost: float


class CostStatsResponse(BaseModel):
    range: str
    start: str
    end: str
    total_cost: float
    record_count: int
    avg_per_meal: float
    top_expensive: List[CostItemBrief]
    top_cheap: List[CostItemBrief]
    by_category: List[CostByCategory]
    by_day: List[CostByDay]
