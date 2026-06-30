from sqlalchemy import Column, String, DateTime, Numeric, Index, func
from sqlalchemy.dialects.postgresql import JSONB

from app.models.user import Base


class PoiCache(Base):
    """高德 POI 结果按 geohash5 (约 5km) 缓存。
    cached_at 用于失效，但失败时仍可作为 stale fallback 返回。
    """

    __tablename__ = "pois_cache"

    id = Column(String(64), primary_key=True)  # 高德 poi_id
    name = Column(String(200), nullable=False)
    category = Column(String(20), nullable=False)  # supermarket / convenience / market / fresh
    lat = Column(Numeric(9, 6), nullable=False)
    lng = Column(Numeric(9, 6), nullable=False)
    city_code = Column(String(10), nullable=True)
    address = Column(String(255), nullable=True)
    business_hours = Column(JSONB, nullable=True)
    geohash5 = Column(String(5), nullable=False)
    cached_at = Column(DateTime, server_default=func.now(), nullable=False)

    __table_args__ = (
        Index("ix_pois_cache_geohash5", "geohash5"),
        Index("ix_pois_cache_geohash5_category", "geohash5", "category"),
    )
