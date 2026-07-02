from sqlalchemy import Column, Integer, Enum, DECIMAL, ForeignKey, TIMESTAMP
from sqlalchemy.sql import func
from app.core.database import Base

class BloodRequest(Base):
    __tablename__ = "blood_requests"

    request_id    = Column(Integer, primary_key=True)
    hospital_id   = Column(Integer, nullable=True)
    blood_bank_id = Column(Integer, nullable=True)
    blood_type    = Column(Enum('A+','A-','B+','B-','AB+','AB-','O+','O-'))
    units_needed  = Column(DECIMAL(6,2))
    urgency_level = Column(Enum('Normal','High','Critical'), default='Normal')
    status        = Column(Enum('Pending','Approved','Fulfilled','Rejected'), default='Pending')
    requested_at  = Column(TIMESTAMP, server_default=func.now())