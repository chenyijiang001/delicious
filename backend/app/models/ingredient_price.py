import uuid

from sqlalchemy import (
    Column,
    String,
    DateTime,
    ForeignKey,
    Numeric,
    func,
    Uuid,
    UniqueConstraint,
)

from app.models.user import Base


class UserIngredientPrice(Base):
    __tablename__ = "user_ingredient_prices"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String(120), nullable=False)
    name_normalized = Column(String(120), nullable=False)
    unit = Column(String(20), nullable=False, default="")
    unit_price = Column(Numeric(8, 2), nullable=False)
    last_used_at = Column(DateTime, server_default=func.now(), nullable=False)
    source = Column(String(20), nullable=False, server_default="user_edit")  # user_edit | user_confirm
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "name_normalized", "unit", name="uq_price_user_name_unit"),
    )
