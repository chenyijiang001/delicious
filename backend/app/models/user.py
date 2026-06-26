import uuid
from datetime import datetime

from sqlalchemy import Column, String, DateTime, func, Uuid
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    nickname = Column(String(100), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    avatar_url = Column(String(1024), nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
