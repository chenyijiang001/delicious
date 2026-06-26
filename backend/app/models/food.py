import uuid
from datetime import datetime

from sqlalchemy import Column, String, DateTime, ForeignKey, Numeric, Integer, Text, func, Uuid, JSON
from sqlalchemy.orm import relationship

from app.models.user import Base


class FoodRecord(Base):
    __tablename__ = "food_records"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    image_url = Column(Text, nullable=True)
    thumbnail_url = Column(Text, nullable=True)
    dish_name = Column(String(200), nullable=False)
    category = Column(String(50), nullable=False, default="其他")
    ingredients = Column(JSON, nullable=False, default=list)
    steps = Column(JSON, nullable=False, default=list)
    total_cost = Column(Numeric(10, 2), nullable=True)
    serving_size = Column(Integer, nullable=True, default=1)
    difficulty = Column(String(10), nullable=True, default="中等")
    tips = Column(JSON, nullable=True, default=list)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False, index=True)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)

    user = relationship("User", backref="food_records")
