from sqlalchemy import Column, Integer, String
from app.core.database import Base

class Hospital(Base):
    __tablename__ = "hospitals"

    hospital_id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100))
    location = Column(String(150))
    contact_number = Column(String(20))