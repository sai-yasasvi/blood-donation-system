from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, text
from app.core.database import SessionLocal
from app.models.inventory import BloodInventory

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/")
def inventory(db: Session = Depends(get_db)):
    data = db.query(
        BloodInventory.blood_type,
        func.sum(BloodInventory.units_available)
    ).filter(BloodInventory.status != 'Expired')\
     .group_by(BloodInventory.blood_type).all()
    return [{"blood_group": d[0], "units": float(d[1])} for d in data]

@router.get("/expiring")
def expiring_inventory(db: Session = Depends(get_db)):
    try:
        rows = db.execute(text("SELECT * FROM vw_expiring_inventory")).fetchall()
        return [dict(r._mapping) for r in rows]
    except Exception as e:
        return {"error": str(e)}

@router.get("/all")
def all_inventory(db: Session = Depends(get_db)):
    rows = db.query(BloodInventory).filter(
        BloodInventory.status != 'Expired'
    ).all()
    return [{
        "inventory_id":   r.inventory_id,
        "blood_bank_id":  r.blood_bank_id,
        "blood_type":     r.blood_type,
        "units_available":float(r.units_available),
        "expiry_date":    str(r.expiry_date),
        "status":         r.status,
    } for r in rows]
@router.get("/redistribution")
def get_redistribution(db: Session = Depends(get_db)):
    from sqlalchemy import text
    rows = db.execute(text("""
        SELECT rs.suggestion_id, rs.blood_type,
               rs.units_to_transfer, rs.expiry_date, rs.status,
               fb.name AS from_bank, tb.name AS to_bank
        FROM redistribution_suggestions rs
        JOIN blood_banks fb ON fb.blood_bank_id = rs.from_bank_id
        JOIN blood_banks tb ON tb.blood_bank_id = rs.to_bank_id
        WHERE rs.status = 'Pending'
        ORDER BY rs.expiry_date ASC
    """)).fetchall()
    return [dict(r._mapping) for r in rows]