from sqlalchemy import Column, Integer, Date, DECIMAL, Enum, ForeignKey
from app.core.database import Base

class Donation(Base):
    __tablename__ = "donations"

    donation_id = Column(Integer, primary_key=True)

    donor_id = Column(Integer, ForeignKey("donors.donor_id"))
    blood_bank_id = Column(Integer, ForeignKey("blood_banks.blood_bank_id"))

    donation_date = Column(Date, nullable=False)
    units_donated = Column(DECIMAL(4,2), default=1.0)

    status = Column(Enum('Pending','Completed','Rejected'), default='Pending')