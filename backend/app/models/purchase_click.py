from sqlalchemy import (
    Column,
    String,
    DateTime,
    BigInteger,
    Integer,
    ForeignKey,
    Uuid,
    Index,
    func,
)

from app.models.user import Base


class PurchaseClick(Base):
    """购物建议跳转点击埋点。
    跟 events 分开存——它是联盟分佣对账的雏形，需要独立可分析。
    """

    __tablename__ = "purchase_clicks"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    channel = Column(String(20), nullable=False)  # offline / online / delivery
    target = Column(String(120), nullable=False)  # poi_id 或 platform 名
    missing_count = Column(Integer, nullable=False, server_default="0")
    ts = Column(DateTime, nullable=False, server_default=func.now())

    __table_args__ = (
        Index("ix_purchase_clicks_user_ts", "user_id", "ts"),
        Index("ix_purchase_clicks_channel_ts", "channel", "ts"),
    )
