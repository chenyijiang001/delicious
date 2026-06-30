from sqlalchemy import (
    Column,
    String,
    DateTime,
    BigInteger,
    func,
    Uuid,
    Index,
)
from sqlalchemy.dialects.postgresql import JSONB

from app.models.user import Base


class Event(Base):
    __tablename__ = "events"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(Uuid, nullable=True)  # 不加 FK：用户删除后仍保留埋点用于离线分析
    name = Column(String(64), nullable=False)
    ts = Column(DateTime, nullable=False, server_default=func.now())
    props = Column(JSONB, nullable=False, server_default="{}")

    __table_args__ = (
        Index("ix_events_name_ts", "name", "ts"),
        Index("ix_events_user_ts", "user_id", "ts"),
    )
