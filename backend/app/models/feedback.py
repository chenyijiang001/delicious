import uuid

from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Text,
    func,
    Uuid,
)
from sqlalchemy.dialects.postgresql import ARRAY

from app.models.user import Base


class AIFeedback(Base):
    __tablename__ = "ai_feedback"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    food_id = Column(Uuid, ForeignKey("food_records.id", ondelete="SET NULL"), nullable=True)
    image_url = Column(Text, nullable=True)
    reasons = Column(ARRAY(Text), nullable=False, server_default="{}")
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
