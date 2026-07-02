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


@router.get("/")
def get_supply_chain(db: Session = Depends(get_db)):
    """Get all blood units and their current lifecycle status."""
    rows = db.execute(text("SELECT * FROM vw_supply_chain LIMIT 100")).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/donor/{donor_id}")
def get_donor_chain(donor_id: int, db: Session = Depends(get_db)):
    """Get supply chain entries for a specific donor's blood units."""
    rows = db.execute(text("""
        SELECT * FROM vw_supply_chain
        WHERE tracking_id IN (
            SELECT tracking_id FROM blood_unit_tracking
            WHERE donor_id = :d
        )
    """), {"d": donor_id}).fetchall()
    return [dict(r._mapping) for r in rows]


@router.post("/{tracking_id}/status")
def update_status(tracking_id: int, data: dict, db: Session = Depends(get_db)):
    """
    Move a blood unit to the next lifecycle stage.
    Valid statuses: Collected → Tested → Stored → Reserved → Dispatched → Delivered → Used
    """
    new_status = data.get("status")
    notes      = data.get("notes", "")
    valid = ['Collected', 'Tested', 'Stored', 'Reserved',
             'Dispatched', 'Delivered', 'Used', 'Expired']

    if new_status not in valid:
        return {"error": f"Invalid status. Choose from: {valid}"}

    try:
        db.execute(
            text("CALL update_supply_chain(:tid, :status, :notes)"),
            {"tid": tracking_id, "status": new_status, "notes": notes}
        )
        db.commit()
        return {"success": True, "tracking_id": tracking_id, "new_status": new_status}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}