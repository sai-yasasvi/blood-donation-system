from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, text
from app.core.database import SessionLocal
from app.models.donor import Donor
from app.models.inventory import BloodInventory
from app.models.request import BloodRequest
from app.models.alert import EmergencyAlert

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/")
def dashboard(db: Session = Depends(get_db)):
    return {
        "total_donors":     db.query(func.count(Donor.donor_id)).scalar(),
        "active_donors":    db.query(func.count(Donor.donor_id)).filter(Donor.is_eligible == True).scalar(),
        "total_units":      float(db.query(func.sum(BloodInventory.units_available)).scalar() or 0),
        "pending_requests": db.query(func.count(BloodRequest.request_id)).filter(BloodRequest.status == "Pending").scalar(),
        "active_alerts":    db.query(func.count(EmergencyAlert.alert_id)).filter(EmergencyAlert.status == "Active").scalar()
    }


@router.get("/admin")
def admin_dashboard(db: Session = Depends(get_db)):
    row = db.execute(text("SELECT * FROM vw_admin_dashboard")).fetchone()
    return dict(row._mapping)


@router.get("/leaderboard")
def leaderboard(db: Session = Depends(get_db)):
    rows = db.execute(text("""
        SELECT * FROM vw_leaderboard 
        ORDER BY total_points DESC   -- ← add this
        LIMIT 20
    """)).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/wastage")
def wastage_summary(db: Session = Depends(get_db)):
    rows = db.execute(text("SELECT * FROM vw_wastage_analytics LIMIT 50")).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/forecast")
def get_forecast(db: Session = Depends(get_db)):
    rows = db.execute(text("""
        SELECT
            df.blood_type,
            df.predicted_units,
            df.confidence_pct,
            df.alert_threshold,
            df.forecast_month,
            df.forecast_year,
            CASE
                WHEN df.predicted_units > COALESCE(bi.units_available, 0) * 1.5 THEN 'Critical'
                WHEN df.predicted_units > COALESCE(bi.units_available, 0)        THEN 'High'
                ELSE 'Low'
            END AS shortage_risk
        FROM demand_forecasts df
        LEFT JOIN blood_inventory bi
            ON  bi.blood_bank_id = df.blood_bank_id
            AND bi.blood_type    = df.blood_type
            AND bi.status       != 'Expired'
        WHERE df.blood_bank_id = 1
        ORDER BY df.blood_type
    """)).fetchall()
    return [dict(r._mapping) for r in rows]