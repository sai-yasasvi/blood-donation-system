from sqlalchemy import Column, Integer, String, Date, Enum, Boolean, ForeignKey, DECIMAL
from sqlalchemy.orm import relationship
from app.core.database import Base

class Donor(Base):
    __tablename__ = "donors"

    donor_id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.user_id"), unique=True)

    dob = Column(Date, nullable=False)
    blood_type = Column(Enum('A+','A-','B+','B-','AB+','AB-','O+','O-'), nullable=False)
    gender = Column(Enum('Male','Female','Other'), nullable=False)

    phone = Column(String(20))
    city = Column(String(100))

    latitude  = Column(DECIMAL(10, 7))
    longitude = Column(DECIMAL(10, 7))

    is_eligible = Column(Boolean, default=True)
    last_donated = Column(Date)

    badge_level = Column(Enum('None', 'Bronze', 'Silver', 'Gold', 'Platinum'), default='None')
    total_donations = Column(Integer, default=0)
    points = Column(Integer, default=0)

    user = relationship("User")