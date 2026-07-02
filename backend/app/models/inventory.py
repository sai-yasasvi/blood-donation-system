from sqlalchemy import Column, Integer, Enum, DECIMAL, Date, ForeignKey, UniqueConstraint, text
from sqlalchemy.orm import relationship
from app.core.database import Base

class BloodInventory(Base):
    __tablename__ = "blood_inventory"

    __table_args__ = (
        UniqueConstraint('blood_bank_id', 'blood_type', 'expiry_date', name='unique_inventory'),
    )

    inventory_id = Column(Integer, primary_key=True)

    blood_bank_id = Column(Integer, ForeignKey("blood_banks.blood_bank_id"), nullable=False, index=True)
    blood_type = Column(Enum('A+','A-','B+','B-','AB+','AB-','O+','O-'), nullable=False, index=True)

    units_available = Column(DECIMAL(6,2), default=0, nullable=False)
    expiry_date = Column(Date, nullable=False)

    status = Column(Enum('Available','Low','Critical','Expired'), server_default=text("'Available'"), nullable=False)

    blood_bank = relationship("BloodBank")