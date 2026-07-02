from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import text
from app.core.database import SessionLocal
from app.models.donor import Donor
from app.models.user import User
import uuid

router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/")
def get_donors(db: Session = Depends(get_db)):
    """Get all donors with their user details."""
    donors = db.query(Donor).options(joinedload(Donor.user)).all()
    return [
        {
            "donor_id":        d.donor_id,
            "name":            d.user.name if d.user else "Unknown",
            "blood_type":      d.blood_type,
            "city":            d.city or "",
            "phone":           d.phone or "",
            "is_eligible":     bool(d.is_eligible),
            "badge_level":     d.badge_level or "None",
            "total_donations": d.total_donations or 0,
            "points":          d.points or 0,
            "last_donated":    str(d.last_donated) if d.last_donated else None,
            "latitude":        float(d.latitude)  if d.latitude  else None,
            "longitude":       float(d.longitude) if d.longitude else None,
        }
        for d in donors
    ]


@router.get("/compatible/{blood_type}")
def compatible_donors(blood_type: str, city: str = None, db: Session = Depends(get_db)):
    """
    Returns all eligible donors whose blood type is compatible
    with the given recipient blood type.
    Uses the find_compatible_donors stored procedure.
    """
    try:
        rows = db.execute(
            text("CALL find_compatible_donors(:bt, :city)"),
            {"bt": blood_type, "city": city}
        ).fetchall()
        return [dict(r._mapping) for r in rows]
    except Exception as e:
        return {"error": str(e)}


@router.get("/{donor_id}")
def get_donor(donor_id: int, db: Session = Depends(get_db)):
    """Get a single donor's full profile."""
    d = db.query(Donor).options(joinedload(Donor.user)).filter(
        Donor.donor_id == donor_id
    ).first()
    if not d:
        return {"error": "Donor not found"}
    return {
        "donor_id":        d.donor_id,
        "name":            d.user.name if d.user else "Unknown",
        "blood_type":      d.blood_type,
        "city":            d.city or "",
        "phone":           d.phone or "",
        "is_eligible":     bool(d.is_eligible),
        "badge_level":     d.badge_level or "None",
        "total_donations": d.total_donations or 0,
        "points":          d.points or 0,
        "last_donated":    str(d.last_donated) if d.last_donated else None,
        "latitude":        float(d.latitude)  if d.latitude  else None,
        "longitude":       float(d.longitude) if d.longitude else None,
    }


@router.post("/")
def add_donor(data: dict, db: Session = Depends(get_db)):
    """Register a new donor — creates both a user account and donor profile."""
    try:
        unique_email = (
            data.get("email") or
            f"{data.get('name','donor').lower().replace(' ', '')}"
            f".{str(uuid.uuid4())[:6]}@bloodconnect.com"
        )

        # Step 1 — create user account
        u = User(
            name          = data.get("name", ""),
            email         = unique_email,
            password_hash = "$2b$12$placeholder_hash_donor",
            role          = "donor"
        )
        db.add(u)
        db.flush()

        # Step 2 — create donor profile
        d = Donor(
            user_id         = u.user_id,
            dob             = data.get("dob", "2000-01-01"),
            blood_type      = data.get("blood_group") or data.get("blood_type", "O+"),
            gender          = data.get("gender", "Male"),
            phone           = data.get("phone", ""),
            city            = data.get("city", "Bengaluru"),
            latitude        = float(data["latitude"])  if data.get("latitude")  else None,
            longitude       = float(data["longitude"]) if data.get("longitude") else None,
            is_eligible     = True,
            badge_level     = "None",
            total_donations = 0,
            points          = 0,
        )
        db.add(d)
        db.flush()

        # Step 3 — create leaderboard entry
        db.execute(text("""
            INSERT INTO leaderboard (donor_id, city, total_points)
            VALUES (:did, :city, 0)
            ON DUPLICATE KEY UPDATE city = :city
        """), {
            "did":  d.donor_id,
            "city": data.get("city", "Bengaluru"),
        })

        db.commit()
        return {
            "status":   "created",
            "donor_id": d.donor_id,
            "name":     u.name,
            "message":  "Donor registered successfully"
        }
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.put("/{donor_id}/location")
def update_location(donor_id: int, data: dict, db: Session = Depends(get_db)):
    """Update a donor's GPS coordinates and city."""
    try:
        db.execute(text("""
            UPDATE donors
            SET latitude  = :lat,
                longitude = :lng,
                city      = COALESCE(:city, city)
            WHERE donor_id = :did
        """), {
            "lat":  data.get("latitude"),
            "lng":  data.get("longitude"),
            "city": data.get("city"),
            "did":  donor_id,
        })
        db.commit()
        return {"status": "updated", "donor_id": donor_id}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}


@router.get("/{donor_id}/screenings")
def donor_screenings(donor_id: int, db: Session = Depends(get_db)):
    """Get all past health screenings for a donor."""
    rows = db.execute(text("""
        SELECT screening_id, screened_at, hemoglobin, blood_pressure,
               weight_kg, is_passed, fail_reason
        FROM donor_health_screenings
        WHERE donor_id = :d
        ORDER BY screened_at DESC
    """), {"d": donor_id}).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/{donor_id}/donations")
def donor_donations(donor_id: int, db: Session = Depends(get_db)):
    """Get all donations made by a donor."""
    rows = db.execute(text("""
        SELECT d.donation_id, d.donation_date, d.units_donated,
               d.status, bb.name AS blood_bank,
               dc.organizer_name AS camp
        FROM donations d
        JOIN blood_banks bb ON bb.blood_bank_id = d.blood_bank_id
        LEFT JOIN donation_camps dc ON dc.camp_id = d.camp_id
        WHERE d.donor_id = :d
        ORDER BY d.donation_date DESC
    """), {"d": donor_id}).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/{donor_id}/supply-chain")
def donor_supply_chain(donor_id: int, db: Session = Depends(get_db)):
    """Get blood unit tracking entries for a specific donor."""
    rows = db.execute(text("""
        SELECT tracking_id, blood_type, units, current_status,
               collected_at, expiry_date, days_until_expiry,
               blood_bank, assigned_hospital
        FROM vw_supply_chain
        WHERE donor_name = (
            SELECT u.name FROM users u
            JOIN donors d ON d.user_id = u.user_id
            WHERE d.donor_id = :d
        )
        ORDER BY collected_at DESC
    """), {"d": donor_id}).fetchall()
    return [dict(r._mapping) for r in rows]


@router.get("/{donor_id}/badges")
def donor_badges(donor_id: int, db: Session = Depends(get_db)):
    """Get all badges earned by a donor."""
    rows = db.execute(text("""
        SELECT badge_id, badge_name, awarded_at, reason
        FROM badge_history
        WHERE donor_id = :d
        ORDER BY awarded_at DESC
    """), {"d": donor_id}).fetchall()
    return [dict(r._mapping) for r in rows]