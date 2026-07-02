from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.deps import get_db

router = APIRouter()


@router.get("/")
def get_donations(db: Session = Depends(get_db)):
    rows = db.execute(text("""
        SELECT d.donation_id, d.donor_id, d.blood_bank_id,
               d.donation_date, d.units_donated, d.status,
               u.name AS donor_name,
               bb.name AS blood_bank
        FROM donations d
        JOIN donors don     ON don.donor_id      = d.donor_id
        JOIN users u        ON u.user_id         = don.user_id
        JOIN blood_banks bb ON bb.blood_bank_id  = d.blood_bank_id
        ORDER BY d.donation_date DESC
    """)).fetchall()
    return [dict(r._mapping) for r in rows]


@router.post("/")
def create_donation(data: dict, db: Session = Depends(get_db)):
    donor_id = data.get("donor_id")
    status   = data.get("status", "Pending")

    if status not in ['Pending', 'Completed', 'Rejected']:
        status = 'Pending'

    last_screen = db.execute(text("""
        SELECT is_passed FROM donor_health_screenings
        WHERE donor_id = :d
        ORDER BY screened_at DESC LIMIT 1
    """), {"d": donor_id}).fetchone()

    if last_screen and not last_screen[0]:
        return {"error": "Donor failed last health screening"}

    eligible = db.execute(text(
        "SELECT is_eligible FROM donors WHERE donor_id = :d"
    ), {"d": donor_id}).fetchone()

    if eligible and not eligible[0]:
        return {"error": "Donor is in 90-day cooldown period"}

    try:
        db.execute(text("""
            INSERT INTO donations
                (donor_id, blood_bank_id, donation_date, units_donated, status)
            VALUES
                (:donor, :bank, :date, :units, :status)
        """), {
            "donor":  donor_id,
            "bank":   data.get("blood_bank_id", 1),
            "date":   data.get("donation_date"),
            "units":  float(data.get("units_donated", 1.0)),
            "status": status
        })
        db.commit()
        donation_id = db.execute(text("SELECT LAST_INSERT_ID()")).scalar()
        return {"status": "created", "donation_id": donation_id}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}

@router.post("/{donation_id}/complete")
def complete_donation(donation_id: int, db: Session = Depends(get_db)):
    """
    Mark a pending donation as Completed.
    This triggers the after_donation_update MySQL trigger which automatically:
    - increments donor's total_donations and points
    - sets is_eligible = FALSE (starts 90-day cooldown)
    - updates badge level
    - inserts into blood_inventory
    - updates leaderboard
    - updates demand_history
    - creates blood_unit_tracking entry
    """
    try:
        db.execute(text("""
            UPDATE donations
            SET status = 'Completed'
            WHERE donation_id = :id
              AND status = 'Pending'
        """), {"id": donation_id})
        db.commit()
        return {"status": "Completed", "donation_id": donation_id}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.post("/{donation_id}/reject")
def reject_donation(donation_id: int, db: Session = Depends(get_db)):
    """
    Mark a pending donation as Rejected.
    Used when blood collection fails (vein issue, donor fainted, etc.)
    Donor's is_eligible stays TRUE — they can try again.
    """
    try:
        db.execute(text("""
            UPDATE donations
            SET status = 'Rejected'
            WHERE donation_id = :id
              AND status = 'Pending'
        """), {"id": donation_id})
        db.commit()
        return {"status": "Rejected", "donation_id": donation_id}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}