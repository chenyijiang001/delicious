import uuid

from sqlalchemy import Column, String, DateTime, Numeric, Uuid, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import JSONB

from app.models.user import Base


class IngredientAlias(Base):
    """跨用户共享的食材语义归类知识库。
    冷启动时由 AI 填，命中即固化；confidence < 0.7 不固化，每次重查。
    """

    __tablename__ = "ingredient_aliases"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    alias = Column(String(120), nullable=False)
    alias_normalized = Column(String(120), nullable=False)
    canonical = Column(String(120), nullable=False)
    canonical_category = Column(String(60), nullable=False, server_default="other")
    # 形如 {"supermarket": true, "convenience": false, "market": true, "fresh": true}
    store_type_coverage = Column(JSONB, nullable=False, server_default="{}")
    confidence = Column(Numeric(3, 2), nullable=False, server_default="0.0")
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime, server_default=func.now(), onupdate=func.now(), nullable=False
    )

    __table_args__ = (
        UniqueConstraint("alias_normalized", name="uq_ingredient_aliases_norm"),
    )
