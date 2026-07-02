from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime, timedelta
from app.core.database import SessionLocal
from app.models.alert import EmergencyAlert

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# GET all alerts
@router.get("/")
def get_alerts(db: Session = Depends(get_db)):
    rows = db.execute(text("""
        SELECT ea.alert_id, ea.blood_type_needed AS blood_type,
               ea.units_needed, ea.message, ea.radius_km,
               ea.golden_hour_deadline, ea.sent_at, ea.status,
               bb.name AS blood_bank_name,
               (SELECT COUNT(*) FROM alert_responses ar WHERE ar.alert_id = ea.alert_id) AS response_count
        FROM emergency_alerts ea
        LEFT JOIN blood_banks bb ON bb.blood_bank_id = ea.blood_bank_id
        ORDER BY ea.sent_at DESC
    """)).fetchall()
    return [dict(r._mapping) for r in rows]

# POST — Create a new golden hour alert
@router.post("/")
def create_alert(data: dict, db: Session = Depends(get_db)):
    try:
        deadline = datetime.now() + timedelta(hours=1)
        db.execute(text("""
            INSERT INTO emergency_alerts
                (blood_bank_id, blood_type_needed, units_needed, message,
                 radius_km, golden_hour_deadline, status)
            VALUES (:bank, :bt, :units, :msg, :radius, :deadline, 'Active')
        """), {
            "bank":     data.get("blood_bank_id", 1),
            "bt":       data.get("blood_type"),
            "units":    float(data.get("units_needed", 1)),
            "msg":      data.get("message", "Emergency blood needed"),
            "radius":   float(data.get("radius_km", 10)),
            "deadline": deadline
        })
        db.commit()
        return {"success": True, "message": "Alert broadcasted", "deadline": str(deadline)}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}

# POST — Donor responds to alert (Accept / Decline / On the way)
@router.post("/{alert_id}/respond")
def respond_to_alert(alert_id: int, data: dict, db: Session = Depends(get_db)):
    donor_id = data.get("donor_id")
    outcome  = data.get("outcome", "Accepted")
    valid_outcomes = ['Accepted', 'Declined', 'On the way', 'Donated', 'No-show', 'Ineligible']
    if outcome not in valid_outcomes:
        return {"error": f"outcome must be one of {valid_outcomes}"}
    try:
        # Upsert — update if already responded
        existing = db.execute(text("""
            SELECT response_id FROM alert_responses
            WHERE alert_id = :a AND donor_id = :d
        """), {"a": alert_id, "d": donor_id}).fetchone()

        if existing:
            db.execute(text("""
                UPDATE alert_responses SET outcome = :o, responded_at = NOW()
                WHERE alert_id = :a AND donor_id = :d
            """), {"o": outcome, "a": alert_id, "d": donor_id})
        else:
            db.execute(text("""
                INSERT INTO alert_responses (alert_id, donor_id, outcome)
                VALUES (:a, :d, :o)
            """), {"a": alert_id, "d": donor_id, "o": outcome})

        db.commit()
        return {"success": True, "alert_id": alert_id, "donor_id": donor_id, "outcome": outcome}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}

# GET — Live response count for an alert
@router.get("/{alert_id}/responses")
def get_responses(alert_id: int, db: Session = Depends(get_db)):
    rows = db.execute(text("""
        SELECT ar.outcome, COUNT(*) AS count
        FROM alert_responses ar
        WHERE ar.alert_id = :a
        GROUP BY ar.outcome
    """), {"a": alert_id}).fetchall()

    detail = db.execute(text("""
        SELECT u.name, d.blood_type, d.city, ar.outcome, ar.responded_at
        FROM alert_responses ar
        JOIN donors d ON d.donor_id = ar.donor_id
        JOIN users u  ON u.user_id  = d.user_id
        WHERE ar.alert_id = :a
        ORDER BY ar.responded_at DESC
    """), {"a": alert_id}).fetchall()

    return {
        "alert_id": alert_id,
        "summary": [dict(r._mapping) for r in rows],
        "donors": [dict(r._mapping) for r in detail]
    }

# POST — Resolve an alert
@router.post("/{alert_id}/resolve")
def resolve_alert(alert_id: int, db: Session = Depends(get_db)):
    try:
        db.execute(text(
            "UPDATE emergency_alerts SET status='Resolved' WHERE alert_id=:id"
        ), {"id": alert_id})
        db.commit()
        return {"success": True, "alert_id": alert_id, "status": "Resolved"}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}