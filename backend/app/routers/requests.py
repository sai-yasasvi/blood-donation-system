from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.deps import get_db
from app.models.request import BloodRequest

router = APIRouter()


@router.get("/")
def get_requests(db: Session = Depends(get_db)):
    rows = db.query(BloodRequest).all()
    return [{
        "request_id":    r.request_id,
        "blood_group":   r.blood_type,
        "blood_type":    r.blood_type,
        "units":         float(r.units_needed or 0),
        "units_needed":  float(r.units_needed or 0),
        "status":        r.status,
        "urgency":       r.urgency_level,
        "urgency_level": r.urgency_level,
    } for r in rows]


@router.post("/")
def create_request(data: dict, db: Session = Depends(get_db)):
    try:
        hospital = db.execute(text(
            "SELECT hospital_id, latitude, longitude FROM hospitals LIMIT 1"
        )).fetchone()
        bank = db.execute(text(
            "SELECT blood_bank_id FROM blood_banks LIMIT 1"
        )).fetchone()

        if not hospital or not bank:
            return {"error": "No hospital or blood bank found. Run seed.py first."}

        # Insert the blood request
        db.execute(text("""
            INSERT INTO blood_requests
                (hospital_id, blood_bank_id, blood_type, units_needed, urgency_level, status)
            VALUES
                (:hid, :bid, :bt, :units, :urgency, 'Pending')
        """), {
            "hid":    hospital[0],
            "bid":    bank[0],
            "bt":     data.get("blood_type", "O+"),
            "units":  float(data.get("units_needed", 1)),
            "urgency":data.get("urgency_level", "Normal"),
        })
        db.flush()

        # Get the newly created request_id
        request_id = db.execute(text("SELECT LAST_INSERT_ID()")).scalar()

        # Auto-run AI allocation immediately after request is created
        db.execute(text(
            "CALL ai_allocate_blood(:req, :bt, :units, :urgency, :lat, :lng)"
        ), {
            "req":    request_id,
            "bt":     data.get("blood_type", "O+"),
            "units":  float(data.get("units_needed", 1)),
            "urgency":data.get("urgency_level", "Normal"),
            "lat":    hospital[1] if hospital else None,
            "lng":    hospital[2] if hospital else None,
        })

        db.commit()
        return {
            "status":     "created",
            "request_id": request_id,
            "message":    "Request created and AI allocation ran"
        }
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.post("/{request_id}/approve")
def approve_request(request_id: int, db: Session = Depends(get_db)):
    try:
        result = db.execute(
            text("CALL approve_blood_request(:rid, 1)"),
            {"rid": request_id}
        )
        row = result.fetchone()
        db.commit()
        return {"request_id": request_id, "result": row[0], "message": row[1]}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.post("/{request_id}/reject")
def reject_request(request_id: int, db: Session = Depends(get_db)):
    try:
        db.execute(text(
            "UPDATE blood_requests SET status='Rejected' WHERE request_id=:rid"
        ), {"rid": request_id})
        db.commit()
        return {"request_id": request_id, "status": "Rejected"}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.post("/{request_id}/fulfill")
def fulfill_request(request_id: int, db: Session = Depends(get_db)):
    try:
        db.execute(text("""
            UPDATE blood_requests
            SET status       = 'Fulfilled',
                fulfilled_at = NOW()
            WHERE request_id = :rid
              AND status      = 'Approved'
        """), {"rid": request_id})
        db.commit()
        return {"request_id": request_id, "status": "Fulfilled"}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}