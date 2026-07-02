from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.deps import get_db

router = APIRouter()

@router.post("/check/{donor_id}")
def check_eligibility(donor_id: int, data: dict, db: Session = Depends(get_db)):
    """
    Run health screening for a donor and determine eligibility.
    Pass all health fields in the request body.
    """
    try:
        result = db.execute(text("""
            CALL check_donor_eligibility(
                :donor_id, :hemoglobin, :bp, :weight,
                :tattoo, :malaria, :medication, :illness, :pregnant
            )
        """), {
            "donor_id":   donor_id,
            "hemoglobin": float(data.get("hemoglobin", 13.5)),
            "bp":         data.get("blood_pressure", "120/80"),
            "weight":     float(data.get("weight_kg", 60)),
            "tattoo":     int(data.get("recent_tattoo", False)),
            "malaria":    int(data.get("recent_travel_malaria", False)),
            "medication": int(data.get("on_medication", False)),
            "illness":    int(data.get("recent_illness", False)),
            "pregnant":   int(data.get("pregnant_or_nursing", False)),
        })
        row = result.fetchone()
        return {
            "donor_id":          donor_id,
            "eligibility_passed": bool(row[0]) if row else False,
            "fail_reason":        row[1] if row else None
        }
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.get("/history/{donor_id}")
def screening_history(donor_id: int, db: Session = Depends(get_db)):
    """Get all past health screenings for a donor."""
    rows = db.execute(text("""
        SELECT screening_id, screened_at, hemoglobin, blood_pressure,
               weight_kg, is_passed, fail_reason
        FROM donor_health_screenings
        WHERE donor_id = :did
        ORDER BY screened_at DESC
    """), {"did": donor_id}).fetchall()

    return [
        {
            "screening_id":   r[0],
            "screened_at":    str(r[1]),
            "hemoglobin":     float(r[2]) if r[2] else None,
            "blood_pressure": r[3],
            "weight_kg":      float(r[4]) if r[4] else None,
            "passed":         bool(r[5]),
            "fail_reason":    r[6],
        }
        for r in rows
    ]
