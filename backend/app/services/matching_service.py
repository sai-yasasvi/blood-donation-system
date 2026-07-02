def get_compatible_donors(db, blood_type: str):
    result = db.execute("""
        SELECT d.*
        FROM donors d
        JOIN blood_compatibility bc
        ON d.blood_type = bc.donor_blood_type
        WHERE bc.recipient_blood_type = :bt
        AND bc.can_donate = 1
        AND d.is_eligible = 1
    """, {"bt": blood_type})

    return result.fetchall()