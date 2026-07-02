from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.deps import get_db

router = APIRouter()


@router.get("/")
def get_camps(db: Session = Depends(get_db)):
    rows = db.execute(text("""
        SELECT camp_id, blood_bank_id, organizer_name, organizer_type,
               location, city, camp_date, start_time, end_time,
               status
        FROM donation_camps
        ORDER BY camp_date ASC
    """)).fetchall()
    return [dict(r._mapping) for r in rows]


@router.post("/")
def create_camp(data: dict, db: Session = Depends(get_db)):
    try:
        db.execute(text("""
            INSERT INTO donation_camps
                (blood_bank_id, organizer_name, organizer_type, location,
                 city, camp_date, start_time, end_time, status)
            VALUES
                (:bank, :org, :type, :loc, :city, :date, :start, :end, 'Upcoming')
        """), {
            "bank":  data.get("blood_bank_id", 1),
            "org":   data.get("organizer_name", ""),
            "type":  data.get("organizer_type", "Other"),
            "loc":   data.get("location", ""),
            "city":  data.get("city", "Bengaluru"),
            "date":  data.get("camp_date"),
            "start": data.get("start_time", "09:00:00"),
            "end":   data.get("end_time", "17:00:00"),
        })
        db.commit()
        return {"status": "created", "message": "Camp scheduled successfully"}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.post("/{camp_id}/register/{donor_id}")
def register_for_camp(camp_id: int, donor_id: int, db: Session = Depends(get_db)):
    try:
        db.execute(text("""
            INSERT IGNORE INTO camp_registrations (camp_id, donor_id)
            VALUES (:c, :d)
        """), {"c": camp_id, "d": donor_id})
        db.commit()
        return {"status": "registered", "camp_id": camp_id, "donor_id": donor_id}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.get("/{camp_id}/registrations")
def camp_registrations(camp_id: int, db: Session = Depends(get_db)):
    try:
        rows = db.execute(text("""
            SELECT cr.reg_id, u.name, d.blood_type, d.phone,
                   cr.registered_at, cr.attended
            FROM camp_registrations cr
            JOIN donors d ON d.donor_id = cr.donor_id
            JOIN users  u ON u.user_id  = d.user_id
            WHERE cr.camp_id = :c
            ORDER BY cr.registered_at DESC
        """), {"c": camp_id}).fetchall()
        return [dict(r._mapping) for r in rows]
    except Exception as e:
        return {"error": str(e)}


@router.post("/{camp_id}/attend/{donor_id}")
def mark_attendance(camp_id: int, donor_id: int, db: Session = Depends(get_db)):
    """Mark a specific donor as attended and update actual_donors count."""
    try:
        db.execute(text("""
            UPDATE camp_registrations
            SET attended = 1
            WHERE camp_id  = :c
              AND donor_id = :d
        """), {"c": camp_id, "d": donor_id})

        # Recalculate actual_donors from attendance records
        db.execute(text("""
            UPDATE donation_camps
            SET actual_donors = (
                SELECT COUNT(*) FROM camp_registrations
                WHERE camp_id = :c AND attended = 1
            )
            WHERE camp_id = :c
        """), {"c": camp_id})

        db.commit()
        return {"status": "marked attended", "camp_id": camp_id, "donor_id": donor_id}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.post("/{camp_id}/attend-all")
def mark_all_attended(camp_id: int, db: Session = Depends(get_db)):
    """Mark ALL registered donors as attended."""
    try:
        db.execute(text("""
            UPDATE camp_registrations
            SET attended = 1
            WHERE camp_id = :c
        """), {"c": camp_id})

        db.execute(text("""
            UPDATE donation_camps
            SET actual_donors = (
                SELECT COUNT(*) FROM camp_registrations
                WHERE camp_id = :c AND attended = 1
            )
            WHERE camp_id = :c
        """), {"c": camp_id})

        db.commit()
        return {"status": "all marked attended", "camp_id": camp_id}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.post("/{camp_id}/complete")
def complete_camp(camp_id: int, data: dict, db: Session = Depends(get_db)):
    """
    Mark a camp as Completed.
    actual_donors is calculated from real attendance records, not passed manually.
    collected_units column was removed from this table — use donations table for real unit data.
    """
    try:
        db.execute(text("""
            UPDATE donation_camps
            SET status        = 'Completed',
                actual_donors = (
                    SELECT COUNT(*) FROM camp_registrations
                    WHERE camp_id = :id AND attended = 1
                )
            WHERE camp_id = :id
        """), {"id": camp_id})
        db.commit()
        return {"status": "completed", "camp_id": camp_id}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}