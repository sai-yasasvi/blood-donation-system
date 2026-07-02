from sqlalchemy import Column, Integer, String, Enum, DECIMAL, TIMESTAMP, ForeignKey
from sqlalchemy.sql import func
from app.core.database import Base

class EmergencyAlert(Base):
    __tablename__ = "emergency_alerts"

    alert_id        = Column(Integer, primary_key=True)
    blood_bank_id   = Column(Integer, ForeignKey("blood_banks.blood_bank_id"))
    blood_type_needed = Column(Enum('A+','A-','B+','B-','AB+','AB-','O+','O-'))
    units_needed    = Column(DECIMAL(6,2))
    message         = Column(String(500))
    radius_km       = Column(DECIMAL(6,2), default=10.0)
    sent_at         = Column(TIMESTAMP, server_default=func.now())
    status          = Column(Enum('Active','Resolved'), default='Active')