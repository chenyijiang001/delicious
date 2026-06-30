from pydantic import BaseModel, Field, model_validator
from typing import List, Optional, Literal


class LatLng(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


class BuySuggestionRequest(BaseModel):
    location: Optional[LatLng] = None
    city_code: Optional[str] = Field(default=None, max_length=10)
    channels: List[Literal["offline", "online", "delivery"]] = Field(
        default_factory=lambda: ["offline", "online", "delivery"]
    )
    radius_m: int = Field(default=1500, ge=100, le=5000)

    @model_validator(mode="after")
    def _require_location_or_city(self) -> "BuySuggestionRequest":
        if self.location is None and not self.city_code:
            raise ValueError("location 或 city_code 至少需要一项")
        return self


class CoverageInfo(BaseModel):
    matched: int
    total: int
    missing: List[str] = []


class OfflineBlock(BaseModel):
    poi_id: str
    name: str
    category: str
    distance_m: int
    address: str = ""
    coverage: CoverageInfo
    estimated_cost: float
    navigate_url: str


class PlatformBlock(BaseModel):
    platform: str
    platform_name: str
    channel: Literal["online", "delivery"]
    coverage: CoverageInfo
    estimated_cost: float
    estimated_eta_minutes: int
    scheme: str
    web_fallback: str


class CacheHit(BaseModel):
    alias: bool
    poi: bool
    coverage: bool
    suggestion: bool


class BuySuggestionResponse(BaseModel):
    ai_suggestion: Optional[str] = None
    items_total: int
    offline: List[OfflineBlock] = []
    online: List[PlatformBlock] = []
    delivery: List[PlatformBlock] = []
    cache_hit: CacheHit


class BuySuggestionClickRequest(BaseModel):
    channel: Literal["offline", "online", "delivery"]
    target: str = Field(min_length=1, max_length=120)
    missing_count: int = Field(default=0, ge=0)
