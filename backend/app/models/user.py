from sqlalchemy import Column, Integer, String, Enum, TIMESTAMP
from sqlalchemy.sql import func
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    user_id      = Column(Integer, primary_key=True, autoincrement=True)
    name         = Column(String(100), nullable=False)
    email        = Column(String(150), nullable=False, unique=True)
    password_hash = Column(String(255), nullable=False)
    role         = Column(Enum('admin', 'donor', 'hospital'), nullable=False, default='donor')
    created_at   = Column(TIMESTAMP, server_default=func.now())