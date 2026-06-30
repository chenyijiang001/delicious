import uuid

from sqlalchemy import (
    Column,
    String,
    DateTime,
    ForeignKey,
    Numeric,
    Text,
    Boolean,
    func,
    Uuid,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import ARRAY

from app.models.user import Base


class ShoppingListItem(Base):
    __tablename__ = "shopping_list_items"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String(120), nullable=False)
    name_normalized = Column(String(120), nullable=False)
    amount = Column(Numeric(10, 2), nullable=False, default=0)
    unit = Column(String(20), nullable=False, default="")
    estimated_price = Column(Numeric(8, 2), nullable=False, default=0)
    checked = Column(Boolean, nullable=False, server_default="false")
    source = Column(String(10), nullable=False, server_default="auto")  # auto | manual
    from_food_ids = Column(ARRAY(Uuid), nullable=False, server_default="{}")
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "name_normalized", "unit", name="uq_shopping_user_name_unit"),
    )
