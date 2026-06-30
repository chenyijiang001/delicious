from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class EventIn(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    ts: Optional[datetime] = None
    props: dict = Field(default_factory=dict)


class EventsBatchRequest(BaseModel):
    events: List[EventIn] = Field(default_factory=list, max_length=200)


class EventsBatchResponse(BaseModel):
    accepted: int
