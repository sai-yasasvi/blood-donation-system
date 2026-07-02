from datetime import date, timedelta
from fastapi import HTTPException
from app.models.donation import Donation
from app.models.donor import Donor
from app.models.blood_bank import BloodBank

def create_donation(db, donor_id: int, blood_bank_id: int, units: float):
    # Check donor
    donor = db.query(Donor).filter(Donor.donor_id == donor_id).first()
    if not donor:
        raise HTTPException(status_code=404, detail="Donor not found")

    # Check blood bank
    blood_bank = db.query(BloodBank).filter(BloodBank.blood_bank_id == blood_bank_id).first()
    if not blood_bank:
        raise HTTPException(status_code=404, detail="Blood bank not found")

    # Validate units
    if units <= 0 or units > 5:
        raise HTTPException(status_code=400, detail="Invalid donation units")

    # Eligibility check
    if not donor.is_eligible:
        raise HTTPException(status_code=400, detail="Donor not eligible")

    # Optional: prevent early donation
    if donor.last_donated:
        if (date.today() - donor.last_donated).days < 90:
            raise HTTPException(status_code=400, detail="Donation too soon")

    donation = Donation(
        donor_id=donor_id,
        blood_bank_id=blood_bank_id,
        donation_date=date.today(),
        units_donated=units,
        status="Completed"   # or "Pending"
    )

    try:
        db.add(donation)
        db.commit()
        db.refresh(donation)
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create donation")

    return donation