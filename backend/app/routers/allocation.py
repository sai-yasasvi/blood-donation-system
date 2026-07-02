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


@router.post("/allocate")
def allocate(data: dict, db: Session = Depends(get_db)):
    """
    Run the AI allocation engine for a blood request.
    The procedure scores every blood bank by distance, expiry urgency,
    and request urgency — then saves the best recommendation to
    allocation_decisions. Result is read back from that table.
    """
    try:
        db.execute(text(
            "CALL ai_allocate_blood(:req, :bt, :units, :urgency, :lat, :lng)"
        ), {
            "req":    data.get("request_id", 0),
            "bt":     data.get("blood_type"),
            "units":  float(data.get("units_needed", 1)),
            "urgency":data.get("urgency", "Normal"),
            "lat":    data.get("hospital_lat"),
            "lng":    data.get("hospital_lng"),
        })
        db.commit()

        # Read the result from allocation_decisions
        # (procedure no longer returns a result set directly)
        row = db.execute(text("""
            SELECT ad.allocation_id, ad.request_id, ad.blood_type,
                   ad.units_to_allocate, ad.distance_km, ad.expiry_days,
                   ad.stock_score, ad.urgency_score, ad.final_score,
                   ad.decision_reason, ad.status,
                   bb.name AS bank_name, bb.city AS bank_city,
                   bb.phone AS bank_phone
            FROM allocation_decisions ad
            JOIN blood_banks bb ON bb.blood_bank_id = ad.recommended_bank_id
            WHERE ad.request_id = :req
            ORDER BY ad.created_at DESC
            LIMIT 1
        """), {"req": data.get("request_id", 0)}).fetchone()

        if row:
            return dict(row._mapping)
        return {"message": "No suitable blood bank found for this request"}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.get("/decisions")
def get_decisions(db: Session = Depends(get_db)):
    """Get all past AI allocation decisions with bank details."""
    rows = db.execute(text("""
        SELECT ad.allocation_id, ad.request_id, ad.blood_type,
               ad.units_to_allocate, ad.distance_km, ad.expiry_days,
               ad.final_score, ad.decision_reason, ad.status,
               ad.created_at, bb.name AS bank_name, bb.city AS bank_city
        FROM allocation_decisions ad
        JOIN blood_banks bb ON bb.blood_bank_id = ad.recommended_bank_id
        ORDER BY ad.created_at DESC
        LIMIT 50
    """)).fetchall()
    return [dict(r._mapping) for r in rows]


@router.post("/decisions/{allocation_id}/accept")
def accept_decision(allocation_id: int, db: Session = Depends(get_db)):
    """Accept an AI allocation suggestion."""
    try:
        db.execute(text(
            "UPDATE allocation_decisions SET status='Accepted' WHERE allocation_id=:id"
        ), {"id": allocation_id})
        db.commit()
        return {"success": True, "allocation_id": allocation_id, "status": "Accepted"}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.post("/decisions/{allocation_id}/reject")
def reject_decision(allocation_id: int, db: Session = Depends(get_db)):
    """Reject an AI allocation suggestion."""
    try:
        db.execute(text(
            "UPDATE allocation_decisions SET status='Rejected' WHERE allocation_id=:id"
        ), {"id": allocation_id})
        db.commit()
        return {"success": True, "allocation_id": allocation_id, "status": "Rejected"}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}