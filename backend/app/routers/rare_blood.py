from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.database import SessionLocal

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# GET all rare blood donors
@router.get("/")
def get_rare_donors(db: Session = Depends(get_db)):
    rows = db.execute(text("SELECT * FROM vw_rare_donors")).fetchall()
    return [dict(r._mapping) for r in rows]

# POST — Register a donor as rare blood type
@router.post("/register")
def register_rare(data: dict, db: Session = Depends(get_db)):
    try:
        db.execute(text("""
            INSERT IGNORE INTO rare_blood_registry (donor_id, rare_type, verified, notes)
            VALUES (:donor_id, :rare_type, :verified, :notes)
        """), {
            "donor_id":  data.get("donor_id"),
            "rare_type": data.get("rare_type", "O-"),
            "verified":  int(data.get("verified", False)),
            "notes":     data.get("notes", "")
        })
        db.commit()
        return {"success": True, "message": "Donor registered in rare blood registry"}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}

# POST — Send SOS broadcast to all eligible rare donors
@router.post("/sos")
def rare_sos(data: dict, db: Session = Depends(get_db)):
    """Send emergency alert targeting only rare blood donors"""
    rare_type = data.get("rare_type", "O-")
    try:
        # Get all eligible rare donors of this type
        rows = db.execute(text("""
            SELECT rr.donor_id, u.name, d.phone, d.city
            FROM rare_blood_registry rr
            JOIN donors d ON d.donor_id = rr.donor_id
            JOIN users u  ON u.user_id  = d.user_id
            WHERE rr.rare_type = :rt AND d.is_eligible = 1
        """), {"rt": rare_type}).fetchall()

        donors = [dict(r._mapping) for r in rows]

        # Create a critical emergency alert
        db.execute(text("""
            INSERT INTO emergency_alerts
                (blood_bank_id, blood_type_needed, units_needed, message, radius_km,
                 golden_hour_deadline, status)
            VALUES
                (:bank, :bt, :units, :msg, 50,
                 DATE_ADD(NOW(), INTERVAL 1 HOUR), 'Active')
        """), {
            "bank":  data.get("blood_bank_id", 1),
            "bt":    rare_type if rare_type not in ['Bombay(hh)','Other'] else 'O-',
            "units": float(data.get("units_needed", 1)),
            "msg":   f"🚨 RARE BLOOD SOS: {rare_type} blood urgently needed. "
                     f"{data.get('message', 'Please contact immediately.')}"
        })
        db.commit()

        return {
            "success": True,
            "rare_type": rare_type,
            "donors_notified": len(donors),
            "eligible_donors": donors
        }
    except Exception as e:
        db.rollback()
        return {"error": str(e)}