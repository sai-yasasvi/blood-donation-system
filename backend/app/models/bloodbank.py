from sqlalchemy import Column, Integer, String, DECIMAL, Text
from app.core.database import Base

class BloodBank(Base):
    __tablename__ = "blood_banks"

    blood_bank_id         = Column(Integer, primary_key=True)
    name                  = Column(String(150), nullable=False)
    address               = Column(Text)
    city                  = Column(String(100))
    phone                 = Column(String(20))
    latitude              = Column(DECIMAL(10,7))
    longitude             = Column(DECIMAL(10,7))
    demand_forecast_score = Column(Integer, default=0)