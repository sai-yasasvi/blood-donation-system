DROP DATABASE IF EXISTS blood_donation;
CREATE DATABASE blood_donation;
USE blood_donation;

CREATE TABLE blood_compatibility (
    donor_blood_type     VARCHAR(5) NOT NULL,
    recipient_blood_type VARCHAR(5) NOT NULL,
    can_donate           BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (donor_blood_type, recipient_blood_type)
);

CREATE TABLE users (
    user_id       INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role          ENUM('admin','donor','hospital','blood_bank') NOT NULL DEFAULT 'donor',
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE blood_banks (
    blood_bank_id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id               INT,
    name                  VARCHAR(150) NOT NULL,
    address               TEXT NOT NULL,
    city                  VARCHAR(100) NOT NULL,
    phone                 VARCHAR(20) NOT NULL,
    latitude              DECIMAL(10,7),
    longitude             DECIMAL(10,7),
    demand_forecast_score INT DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE hospitals (
    hospital_id    INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT NOT NULL,
    name           VARCHAR(150) NOT NULL,
    address        TEXT NOT NULL,
    city           VARCHAR(100) NOT NULL,
    phone          VARCHAR(20) NOT NULL,
    contact_person VARCHAR(100),
    latitude       DECIMAL(10,7),
    longitude      DECIMAL(10,7),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE donors (
    donor_id        INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL UNIQUE,
    dob             DATE NOT NULL,
    blood_type      ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    gender          ENUM('Male','Female','Other') NOT NULL,
    phone           VARCHAR(20) NOT NULL,
    address         TEXT,
    city            VARCHAR(100),
    latitude        DECIMAL(10,7),
    longitude       DECIMAL(10,7),
    is_eligible     BOOLEAN DEFAULT TRUE,
    last_donated    DATE,
    badge_level     ENUM('None','Bronze','Silver','Gold','Platinum') DEFAULT 'None',
    total_donations INT DEFAULT 0,
    points          INT DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE donor_health_screenings (
    screening_id          INT AUTO_INCREMENT PRIMARY KEY,
    donor_id              INT NOT NULL,
    screened_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    hemoglobin            DECIMAL(4,1),
    blood_pressure        VARCHAR(10),
    weight_kg             DECIMAL(5,2),
    recent_tattoo         BOOLEAN DEFAULT FALSE,
    recent_travel_malaria BOOLEAN DEFAULT FALSE,
    on_medication         BOOLEAN DEFAULT FALSE,
    medication_details    TEXT,
    recent_illness        BOOLEAN DEFAULT FALSE,
    illness_details       TEXT,
    pregnant_or_nursing   BOOLEAN DEFAULT FALSE,
    is_passed             BOOLEAN DEFAULT TRUE,
    fail_reason           TEXT,
    FOREIGN KEY (donor_id) REFERENCES donors(donor_id) ON DELETE CASCADE
);

CREATE TABLE donation_camps (
    camp_id        INT AUTO_INCREMENT PRIMARY KEY,
    blood_bank_id  INT NOT NULL,
    organizer_name VARCHAR(150) NOT NULL,
    organizer_type ENUM('NGO','College','Corporate','Hospital','Other') DEFAULT 'Other',
    location       TEXT NOT NULL,
    city           VARCHAR(100),
    camp_date      DATE NOT NULL,
    start_time     TIME,
    end_time       TIME,
    status         ENUM('Upcoming','Ongoing','Completed','Cancelled') DEFAULT 'Upcoming',
    FOREIGN KEY (blood_bank_id) REFERENCES blood_banks(blood_bank_id)
);

CREATE TABLE camp_registrations (
    reg_id        INT AUTO_INCREMENT PRIMARY KEY,
    camp_id       INT NOT NULL,
    donor_id      INT NOT NULL,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    attended      BOOLEAN DEFAULT FALSE,
    UNIQUE KEY unique_camp_donor (camp_id, donor_id),
    FOREIGN KEY (camp_id)  REFERENCES donation_camps(camp_id),
    FOREIGN KEY (donor_id) REFERENCES donors(donor_id)
);

CREATE TABLE donations (
    donation_id   INT AUTO_INCREMENT PRIMARY KEY,
    donor_id      INT NOT NULL,
    blood_bank_id INT NOT NULL,
    camp_id       INT,
    donation_date DATE NOT NULL,
    units_donated DECIMAL(4,2) NOT NULL DEFAULT 1.00,
    status        ENUM('Pending','Completed','Rejected') DEFAULT 'Pending',
    health_notes  TEXT,
    FOREIGN KEY (donor_id)      REFERENCES donors(donor_id),
    FOREIGN KEY (blood_bank_id) REFERENCES blood_banks(blood_bank_id),
    FOREIGN KEY (camp_id)       REFERENCES donation_camps(camp_id)
);

CREATE TABLE blood_inventory (
    inventory_id    INT AUTO_INCREMENT PRIMARY KEY,
    blood_bank_id   INT NOT NULL,
    blood_type      ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    units_available DECIMAL(6,2) NOT NULL DEFAULT 0,
    expiry_date     DATE NOT NULL,
    status          ENUM('Available','Low','Critical','Expired') DEFAULT 'Available',
    UNIQUE KEY unique_inventory (blood_bank_id, blood_type, expiry_date),
    FOREIGN KEY (blood_bank_id) REFERENCES blood_banks(blood_bank_id)
);

CREATE TABLE blood_unit_tracking (
    tracking_id             INT AUTO_INCREMENT PRIMARY KEY,
    inventory_id            INT NOT NULL,
    donor_id                INT NOT NULL,
    blood_bank_id           INT NOT NULL,
    blood_type              ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    units                   DECIMAL(4,2) NOT NULL DEFAULT 1.00,
    current_status          ENUM('Collected','Tested','Stored','Reserved','Dispatched','Delivered','Used','Expired') DEFAULT 'Collected',
    collected_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tested_at               TIMESTAMP NULL,
    stored_at               TIMESTAMP NULL,
    reserved_at             TIMESTAMP NULL,
    dispatched_at           TIMESTAMP NULL,
    delivered_at            TIMESTAMP NULL,
    used_at                 TIMESTAMP NULL,
    expiry_date             DATE NOT NULL,
    assigned_to_hospital_id INT NULL,
    staff_notes             TEXT,
    FOREIGN KEY (inventory_id)            REFERENCES blood_inventory(inventory_id),
    FOREIGN KEY (donor_id)                REFERENCES donors(donor_id),
    FOREIGN KEY (blood_bank_id)           REFERENCES blood_banks(blood_bank_id),
    FOREIGN KEY (assigned_to_hospital_id) REFERENCES hospitals(hospital_id)
);

CREATE TABLE blood_requests (
    request_id    INT AUTO_INCREMENT PRIMARY KEY,
    hospital_id   INT NOT NULL,
    blood_bank_id INT NOT NULL,
    blood_type    ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    units_needed  DECIMAL(6,2) NOT NULL,
    urgency_level ENUM('Normal','High','Critical') DEFAULT 'Normal',
    status        ENUM('Pending','Approved','Fulfilled','Rejected') DEFAULT 'Pending',
    requested_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fulfilled_at  TIMESTAMP NULL,
    FOREIGN KEY (hospital_id)   REFERENCES hospitals(hospital_id),
    FOREIGN KEY (blood_bank_id) REFERENCES blood_banks(blood_bank_id)
);

CREATE TABLE allocation_decisions (
    allocation_id       INT AUTO_INCREMENT PRIMARY KEY,
    request_id          INT NOT NULL,
    recommended_bank_id INT NOT NULL,
    blood_type          ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    units_to_allocate   DECIMAL(6,2) NOT NULL,
    distance_km         DECIMAL(6,2),
    expiry_days         INT,
    stock_score         INT,
    urgency_score       INT,
    final_score         DECIMAL(6,2),
    decision_reason     TEXT,
    status              ENUM('Suggested','Accepted','Rejected') DEFAULT 'Suggested',
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (request_id)          REFERENCES blood_requests(request_id),
    FOREIGN KEY (recommended_bank_id) REFERENCES blood_banks(blood_bank_id)
);

CREATE TABLE emergency_alerts (
    alert_id             INT AUTO_INCREMENT PRIMARY KEY,
    blood_bank_id        INT NOT NULL,
    hospital_id          INT,
    blood_type_needed    ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    units_needed         DECIMAL(6,2) NOT NULL,
    message              TEXT NOT NULL,
    radius_km            DECIMAL(6,2) DEFAULT 10.00,
    golden_hour_deadline TIMESTAMP,
    sent_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status               ENUM('Active','Resolved','Expired') DEFAULT 'Active',
    FOREIGN KEY (blood_bank_id) REFERENCES blood_banks(blood_bank_id),
    FOREIGN KEY (hospital_id)   REFERENCES hospitals(hospital_id)
);

CREATE TABLE alert_responses (
    response_id  INT AUTO_INCREMENT PRIMARY KEY,
    alert_id     INT NOT NULL,
    donor_id     INT NOT NULL,
    responded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    outcome      ENUM('Accepted','Declined','On the way','Donated','No-show','Ineligible') DEFAULT 'Accepted',
    FOREIGN KEY (alert_id)  REFERENCES emergency_alerts(alert_id),
    FOREIGN KEY (donor_id)  REFERENCES donors(donor_id)
);

CREATE TABLE demand_history (
    history_id      INT AUTO_INCREMENT PRIMARY KEY,
    blood_bank_id   INT NOT NULL,
    blood_type      ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    month           TINYINT NOT NULL,
    year            SMALLINT NOT NULL,
    units_requested DECIMAL(8,2) DEFAULT 0,
    units_fulfilled DECIMAL(8,2) DEFAULT 0,
    shortage_flag   BOOLEAN DEFAULT FALSE,
    UNIQUE KEY unique_demand (blood_bank_id, blood_type, year, month),
    FOREIGN KEY (blood_bank_id) REFERENCES blood_banks(blood_bank_id)
);

CREATE TABLE demand_forecasts (
    forecast_id     INT AUTO_INCREMENT PRIMARY KEY,
    blood_bank_id   INT NOT NULL,
    blood_type      ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    forecast_month  TINYINT NOT NULL,
    forecast_year   SMALLINT NOT NULL,
    predicted_units DECIMAL(8,2) NOT NULL,
    confidence_pct  TINYINT DEFAULT 70,
    alert_threshold DECIMAL(8,2),
    generated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_forecast (blood_bank_id, blood_type, forecast_year, forecast_month),
    FOREIGN KEY (blood_bank_id) REFERENCES blood_banks(blood_bank_id)
);

CREATE TABLE wastage_log (
    wastage_id    INT AUTO_INCREMENT PRIMARY KEY,
    blood_bank_id INT NOT NULL,
    blood_type    ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    units_wasted  DECIMAL(6,2) NOT NULL,
    expiry_date   DATE NOT NULL,
    logged_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason        ENUM('Expired','Contaminated','Damaged','Other') DEFAULT 'Expired',
    FOREIGN KEY (blood_bank_id) REFERENCES blood_banks(blood_bank_id)
);

CREATE TABLE leaderboard (
    leaderboard_id INT AUTO_INCREMENT PRIMARY KEY,
    donor_id       INT NOT NULL UNIQUE,
    city           VARCHAR(100),
    college        VARCHAR(150),
    total_points   INT DEFAULT 0,
    rank_city      INT,
    rank_overall   INT,
    updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (donor_id) REFERENCES donors(donor_id) ON DELETE CASCADE
);

CREATE TABLE badge_history (
    badge_id   INT AUTO_INCREMENT PRIMARY KEY,
    donor_id   INT NOT NULL,
    badge_name ENUM('First Drop','Bronze','Silver','Gold','Platinum','Emergency Hero','Camp Champion') NOT NULL,
    awarded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason     VARCHAR(255),
    FOREIGN KEY (donor_id) REFERENCES donors(donor_id) ON DELETE CASCADE
);


DELIMITER $$

CREATE TRIGGER after_donation_insert
AFTER INSERT ON donations
FOR EACH ROW
BEGIN
    DECLARE new_total  INT;
    DECLARE new_badge  ENUM('None','Bronze','Silver','Gold','Platinum');
    DECLARE d_blood    ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-');
    DECLARE inv_id     INT;
    DECLARE expiry_dt  DATE;

    IF NEW.status = 'Completed' THEN

        SELECT blood_type INTO d_blood FROM donors WHERE donor_id = NEW.donor_id;
        SET expiry_dt = DATE_ADD(NEW.donation_date, INTERVAL 42 DAY);

        UPDATE donors
        SET total_donations = total_donations + 1,
            last_donated    = NEW.donation_date,
            is_eligible     = FALSE,
            points          = points + 100
        WHERE donor_id = NEW.donor_id;

        SELECT total_donations INTO new_total FROM donors WHERE donor_id = NEW.donor_id;

        SET new_badge = CASE
            WHEN new_total >= 20 THEN 'Platinum'
            WHEN new_total >= 10 THEN 'Gold'
            WHEN new_total >= 5  THEN 'Silver'
            WHEN new_total >= 1  THEN 'Bronze'
            ELSE 'None'
        END;
        UPDATE donors SET badge_level = new_badge WHERE donor_id = NEW.donor_id;

        INSERT IGNORE INTO badge_history (donor_id, badge_name, reason)
        SELECT NEW.donor_id, new_badge,
               CONCAT('Reached ', new_badge, ' after ', new_total, ' donations')
        WHERE new_badge != 'None'
          AND NOT EXISTS (
              SELECT 1 FROM badge_history
              WHERE donor_id = NEW.donor_id AND badge_name = new_badge
          );

        INSERT INTO blood_inventory
            (blood_bank_id, blood_type, units_available, expiry_date, status)
        VALUES
            (NEW.blood_bank_id, d_blood, NEW.units_donated, expiry_dt, 'Available')
        ON DUPLICATE KEY UPDATE
            units_available = units_available + NEW.units_donated;

        SELECT inventory_id INTO inv_id
        FROM blood_inventory
        WHERE blood_bank_id = NEW.blood_bank_id
          AND blood_type    = d_blood
          AND expiry_date   = expiry_dt
        LIMIT 1;

        IF inv_id IS NOT NULL THEN
            INSERT INTO blood_unit_tracking
                (inventory_id, donor_id, blood_bank_id, blood_type,
                 units, current_status, expiry_date,
                 collected_at, tested_at, stored_at)
            VALUES
                (inv_id, NEW.donor_id, NEW.blood_bank_id, d_blood,
                 NEW.units_donated, 'Stored', expiry_dt,
                 NOW(), NOW(), NOW());
        END IF;

        INSERT INTO leaderboard (donor_id, city, total_points)
        SELECT NEW.donor_id, d.city, d.points
        FROM donors d WHERE d.donor_id = NEW.donor_id
        ON DUPLICATE KEY UPDATE
            total_points = (SELECT points FROM donors WHERE donor_id = NEW.donor_id),
            city         = (SELECT city  FROM donors WHERE donor_id = NEW.donor_id),
            updated_at   = NOW();

        INSERT INTO demand_history
            (blood_bank_id, blood_type, month, year, units_fulfilled)
        SELECT NEW.blood_bank_id, d_blood,
               MONTH(NEW.donation_date), YEAR(NEW.donation_date), NEW.units_donated
        ON DUPLICATE KEY UPDATE
            units_fulfilled = units_fulfilled + NEW.units_donated;

    END IF;
END$$

CREATE TRIGGER after_donation_update
AFTER UPDATE ON donations
FOR EACH ROW
BEGIN
    DECLARE new_total INT;
    DECLARE new_badge ENUM('None','Bronze','Silver','Gold','Platinum');
    DECLARE d_blood   ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-');
    DECLARE inv_id    INT;

    IF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN

        UPDATE donors
        SET total_donations = total_donations + 1,
            last_donated    = NEW.donation_date,
            is_eligible     = FALSE,
            points          = points + 100
        WHERE donor_id = NEW.donor_id;

        SELECT total_donations INTO new_total
        FROM donors WHERE donor_id = NEW.donor_id;

        SET new_badge = CASE
            WHEN new_total >= 20 THEN 'Platinum'
            WHEN new_total >= 10 THEN 'Gold'
            WHEN new_total >= 5  THEN 'Silver'
            WHEN new_total >= 1  THEN 'Bronze'
            ELSE 'None'
        END;
        UPDATE donors SET badge_level = new_badge
        WHERE donor_id = NEW.donor_id;

        INSERT IGNORE INTO badge_history (donor_id, badge_name, reason)
        SELECT NEW.donor_id, new_badge,
               CONCAT('Reached ', new_badge, ' after ', new_total, ' donations')
        WHERE new_badge != 'None'
          AND NOT EXISTS (
              SELECT 1 FROM badge_history
              WHERE donor_id = NEW.donor_id AND badge_name = new_badge
          );

        INSERT INTO blood_inventory
            (blood_bank_id, blood_type, units_available, expiry_date, status)
        SELECT NEW.blood_bank_id, d.blood_type, NEW.units_donated,
               DATE_ADD(NEW.donation_date, INTERVAL 42 DAY), 'Available'
        FROM donors d WHERE d.donor_id = NEW.donor_id
        ON DUPLICATE KEY UPDATE
            units_available = units_available + NEW.units_donated;

        INSERT INTO leaderboard (donor_id, city, total_points)
        SELECT NEW.donor_id, d.city, d.points FROM donors d
        WHERE d.donor_id = NEW.donor_id
        ON DUPLICATE KEY UPDATE
            total_points = (SELECT points FROM donors WHERE donor_id = NEW.donor_id),
            updated_at   = NOW();

        INSERT INTO demand_history
            (blood_bank_id, blood_type, month, year, units_fulfilled)
        SELECT NEW.blood_bank_id, d.blood_type,
               MONTH(NEW.donation_date), YEAR(NEW.donation_date), NEW.units_donated
        FROM donors d WHERE d.donor_id = NEW.donor_id
        ON DUPLICATE KEY UPDATE
            units_fulfilled = units_fulfilled + NEW.units_donated;

        SELECT d.blood_type INTO d_blood
        FROM donors d WHERE d.donor_id = NEW.donor_id;

        SELECT inventory_id INTO inv_id
        FROM blood_inventory
        WHERE blood_bank_id = NEW.blood_bank_id
          AND blood_type    = d_blood
          AND expiry_date   = DATE_ADD(NEW.donation_date, INTERVAL 42 DAY)
        LIMIT 1;

        IF inv_id IS NOT NULL THEN
            INSERT INTO blood_unit_tracking
                (inventory_id, donor_id, blood_bank_id, blood_type, units,
                 current_status, expiry_date, tested_at, stored_at)
            VALUES
                (inv_id, NEW.donor_id, NEW.blood_bank_id, d_blood,
                 NEW.units_donated, 'Stored',
                 DATE_ADD(NEW.donation_date, INTERVAL 42 DAY),
                 NEW.donation_date, NEW.donation_date);
        END IF;

    END IF;
END$$

CREATE TRIGGER after_request_insert
AFTER INSERT ON blood_requests
FOR EACH ROW
BEGIN
    INSERT INTO demand_history (blood_bank_id, blood_type, month, year, units_requested)
    VALUES (NEW.blood_bank_id, NEW.blood_type, MONTH(NOW()), YEAR(NOW()), NEW.units_needed)
    ON DUPLICATE KEY UPDATE units_requested = units_requested + NEW.units_needed;
END$$

CREATE TRIGGER update_inventory_status
BEFORE UPDATE ON blood_inventory
FOR EACH ROW
BEGIN
    IF NEW.status != 'Expired' THEN
        IF NEW.units_available <= 0 THEN
            SET NEW.status = 'Critical';
        ELSEIF NEW.units_available <= 5 THEN
            SET NEW.status = 'Low';
        ELSE
            SET NEW.status = 'Available';
        END IF;
    END IF;
END$$

CREATE TRIGGER log_wastage_on_expiry
AFTER UPDATE ON blood_inventory
FOR EACH ROW
BEGIN
    IF NEW.status = 'Expired' AND OLD.status != 'Expired' AND OLD.units_available > 0 THEN
        INSERT INTO wastage_log (blood_bank_id, blood_type, units_wasted, expiry_date, reason)
        VALUES (NEW.blood_bank_id, NEW.blood_type, OLD.units_available, NEW.expiry_date, 'Expired');

        UPDATE blood_unit_tracking
        SET current_status = 'Expired'
        WHERE inventory_id  = NEW.inventory_id
          AND current_status NOT IN ('Delivered','Used','Expired');
    END IF;
END$$

CREATE TRIGGER update_camp_stats
AFTER INSERT ON donations
FOR EACH ROW
BEGIN
    IF NEW.camp_id IS NOT NULL AND NEW.status = 'Completed' THEN

        UPDATE donation_camps
        SET status = 'Completed'
        WHERE camp_id   = NEW.camp_id
          AND camp_date < CURDATE()
          AND status   != 'Completed';

    END IF;
END$$

CREATE TRIGGER update_attendance_count
AFTER UPDATE ON camp_registrations
FOR EACH ROW
BEGIN
    IF NEW.attended != OLD.attended THEN
        UPDATE donation_camps
        SET actual_donors = (
            SELECT COUNT(*) FROM camp_registrations
            WHERE camp_id = NEW.camp_id AND attended = 1
        )
        WHERE camp_id = NEW.camp_id;
    END IF;
END$$

CREATE TRIGGER auto_allocate_blood
AFTER INSERT ON blood_requests
FOR EACH ROW
BEGIN
    DECLARE v_lat DECIMAL(10,7);
    DECLARE v_lng DECIMAL(10,7);

    SELECT latitude, longitude
    INTO v_lat, v_lng
    FROM hospitals
    WHERE hospital_id = NEW.hospital_id;

    CALL ai_allocate_blood(
        NEW.request_id,
        NEW.blood_type,
        NEW.units_needed,
        NEW.urgency_level,
        v_lat,
        v_lng
    );
END$$

DELIMITER ;


SET GLOBAL event_scheduler = ON;

DELIMITER $$

CREATE EVENT re_enable_donor_eligibility
ON SCHEDULE EVERY 1 DAY
DO
    UPDATE donors
    SET is_eligible = TRUE
    WHERE is_eligible = FALSE
      AND last_donated IS NOT NULL
      AND DATEDIFF(CURDATE(), last_donated) >= 90;$$

CREATE EVENT expire_blood_inventory
ON SCHEDULE EVERY 1 DAY
DO
    UPDATE blood_inventory
    SET status = 'Expired'
    WHERE expiry_date < CURDATE() AND status != 'Expired';$$

CREATE EVENT expire_golden_hour_alerts
ON SCHEDULE EVERY 5 MINUTE
DO
    UPDATE emergency_alerts
    SET status = 'Expired'
    WHERE status = 'Active'
      AND golden_hour_deadline IS NOT NULL
      AND golden_hour_deadline < NOW();$$

CREATE EVENT refresh_leaderboard_ranks
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    SET @rank := 0;
    UPDATE leaderboard l
    JOIN (
        SELECT donor_id, @rank := @rank + 1 AS r
        FROM leaderboard ORDER BY total_points DESC
    ) ranked ON l.donor_id = ranked.donor_id
    SET l.rank_overall = ranked.r;
END$$

CREATE EVENT IF NOT EXISTS monthly_forecast_generation
ON SCHEDULE EVERY 1 MONTH
STARTS DATE_ADD(DATE_FORMAT(NOW(),'%Y-%m-01'), INTERVAL 1 MONTH)
DO
BEGIN
    CALL generate_demand_forecast(1,'O+');
    CALL generate_demand_forecast(1,'O-');
    CALL generate_demand_forecast(1,'A+');
    CALL generate_demand_forecast(1,'A-');
    CALL generate_demand_forecast(1,'B+');
    CALL generate_demand_forecast(1,'B-');
    CALL generate_demand_forecast(1,'AB+');
    CALL generate_demand_forecast(1,'AB-');
END$$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE check_donor_eligibility(
    IN p_donor_id   INT,
    IN p_hemoglobin DECIMAL(4,1),
    IN p_bp         VARCHAR(10),
    IN p_weight_kg  DECIMAL(5,2),
    IN p_tattoo     BOOLEAN,
    IN p_malaria    BOOLEAN,
    IN p_medication BOOLEAN,
    IN p_illness    BOOLEAN,
    IN p_pregnant   BOOLEAN
)
BEGIN
    DECLARE fail_msg TEXT DEFAULT '';
    DECLARE passed   BOOLEAN DEFAULT TRUE;
    DECLARE donor_gender ENUM('Male','Female','Other');

    SELECT gender INTO donor_gender FROM donors WHERE donor_id = p_donor_id;

    IF p_weight_kg < 45 THEN
        SET passed = FALSE;
        SET fail_msg = CONCAT(fail_msg, 'Weight below 45kg. ');
    END IF;
    IF (donor_gender = 'Female' AND p_hemoglobin < 12.5)
    OR (donor_gender != 'Female' AND p_hemoglobin < 13.0) THEN
        SET passed = FALSE;
        SET fail_msg = CONCAT(fail_msg, 'Low hemoglobin. ');
    END IF;
    IF p_tattoo     THEN SET passed = FALSE; SET fail_msg = CONCAT(fail_msg, 'Recent tattoo in last 6 months. '); END IF;
    IF p_malaria    THEN SET passed = FALSE; SET fail_msg = CONCAT(fail_msg, 'Travelled to malaria zone in last 1 year. '); END IF;
    IF p_medication THEN SET passed = FALSE; SET fail_msg = CONCAT(fail_msg, 'Currently on medication. '); END IF;
    IF p_illness    THEN SET passed = FALSE; SET fail_msg = CONCAT(fail_msg, 'Recent illness reported. '); END IF;
    IF p_pregnant   THEN SET passed = FALSE; SET fail_msg = CONCAT(fail_msg, 'Currently pregnant or nursing. '); END IF;

    INSERT INTO donor_health_screenings
        (donor_id, hemoglobin, blood_pressure, weight_kg,
         recent_tattoo, recent_travel_malaria, on_medication,
         recent_illness, pregnant_or_nursing, is_passed, fail_reason)
    VALUES
        (p_donor_id, p_hemoglobin, p_bp, p_weight_kg,
         p_tattoo, p_malaria, p_medication,
         p_illness, p_pregnant, passed,
         IF(passed, NULL, TRIM(fail_msg)));

    UPDATE donors SET is_eligible = passed WHERE donor_id = p_donor_id;

    SELECT passed AS eligibility_passed, TRIM(fail_msg) AS fail_reason;
END$$

CREATE PROCEDURE find_compatible_donors(
    IN p_recipient_blood_type VARCHAR(5),
    IN p_city                 VARCHAR(100)
)
BEGIN
    SELECT
        d.donor_id,
        u.name,
        d.blood_type,
        d.phone,
        d.city,
        d.badge_level,
        d.total_donations,
        d.last_donated,
        bc.donor_blood_type AS compatible_as
    FROM donors d
    JOIN users u ON u.user_id = d.user_id
    JOIN blood_compatibility bc ON bc.donor_blood_type = d.blood_type
    WHERE bc.recipient_blood_type = p_recipient_blood_type
      AND bc.can_donate = 1
      AND d.is_eligible = 1
      AND (p_city IS NULL OR d.city = p_city)
    ORDER BY d.total_donations DESC;
END$$

CREATE PROCEDURE ai_allocate_blood(
    IN p_request_id   INT,
    IN p_blood_type   VARCHAR(5),
    IN p_units_needed DECIMAL(6,2),
    IN p_urgency      ENUM('Normal','High','Critical'),
    IN p_hospital_lat DECIMAL(10,7),
    IN p_hospital_lng DECIMAL(10,7)
)
BEGIN
    DECLARE done             INT DEFAULT FALSE;
    DECLARE v_bank_id        INT;
    DECLARE v_name           VARCHAR(150);
    DECLARE v_lat            DECIMAL(10,7);
    DECLARE v_lng            DECIMAL(10,7);
    DECLARE v_units          DECIMAL(6,2);
    DECLARE v_expiry         DATE;
    DECLARE v_distance       DECIMAL(6,2);
    DECLARE v_expiry_days    INT;
    DECLARE v_stock_score    INT;
    DECLARE v_urgency_score  INT;
    DECLARE v_distance_score INT;
    DECLARE v_final_score    DECIMAL(6,2);
    DECLARE v_best_bank_id   INT DEFAULT NULL;
    DECLARE v_best_score     DECIMAL(6,2) DEFAULT -1;
    DECLARE v_best_distance  DECIMAL(6,2);
    DECLARE v_best_expiry    INT;
    DECLARE v_best_units     DECIMAL(6,2);
    DECLARE v_best_name      VARCHAR(150);

    DECLARE bank_cur CURSOR FOR
        SELECT bb.blood_bank_id, bb.name, bb.latitude, bb.longitude,
               bi.units_available, bi.expiry_date
        FROM blood_banks bb
        JOIN blood_inventory bi ON bi.blood_bank_id = bb.blood_bank_id
        WHERE bi.blood_type      = p_blood_type
          AND bi.units_available >= p_units_needed
          AND bi.status         != 'Expired'
        ORDER BY bi.expiry_date ASC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN bank_cur;
    bank_loop: LOOP
        FETCH bank_cur INTO v_bank_id, v_name, v_lat, v_lng, v_units, v_expiry;
        IF done THEN LEAVE bank_loop; END IF;

        IF p_hospital_lat IS NOT NULL AND v_lat IS NOT NULL THEN
            SET v_distance = ROUND(
                6371 * ACOS(
                    COS(RADIANS(p_hospital_lat)) * COS(RADIANS(v_lat)) *
                    COS(RADIANS(v_lng) - RADIANS(p_hospital_lng)) +
                    SIN(RADIANS(p_hospital_lat)) * SIN(RADIANS(v_lat))
                ), 2);
        ELSE
            SET v_distance = 10;
        END IF;
        SET v_distance_score = GREATEST(0, 100 - ROUND(v_distance * 4));

        SET v_expiry_days = DATEDIFF(v_expiry, CURDATE());
        SET v_stock_score = CASE
            WHEN v_expiry_days BETWEEN 1 AND 7  THEN 90
            WHEN v_expiry_days BETWEEN 8 AND 20 THEN 70
            ELSE 50
        END;

        SET v_urgency_score = CASE p_urgency
            WHEN 'Critical' THEN 100
            WHEN 'High'     THEN 70
            ELSE 40
        END;

        SET v_final_score = (v_distance_score * 0.40) +
                            (v_stock_score    * 0.35) +
                            (v_urgency_score  * 0.25);

        IF v_final_score > v_best_score THEN
            SET v_best_score    = v_final_score;
            SET v_best_bank_id  = v_bank_id;
            SET v_best_name     = v_name;
            SET v_best_distance = v_distance;
            SET v_best_expiry   = v_expiry_days;
            SET v_best_units    = v_units;
        END IF;
    END LOOP;
    CLOSE bank_cur;

    IF v_best_bank_id IS NOT NULL THEN
        INSERT INTO allocation_decisions
            (request_id, recommended_bank_id, blood_type, units_to_allocate,
             distance_km, expiry_days, stock_score, urgency_score,
             final_score, decision_reason)
        VALUES
            (p_request_id, v_best_bank_id, p_blood_type, p_units_needed,
             v_best_distance, v_best_expiry, v_stock_score, v_urgency_score,
             ROUND(v_best_score, 1),
             CONCAT('Best: ', v_best_name,
                    ' | ', v_best_distance, 'km away',
                    ' | Expires in ', v_best_expiry, ' days',
                    ' | Score: ', ROUND(v_best_score, 1)));
    END IF;
END$$

CREATE PROCEDURE update_supply_chain(
    IN p_tracking_id INT,
    IN p_new_status  VARCHAR(20),
    IN p_notes       TEXT
)
BEGIN
    UPDATE blood_unit_tracking
    SET current_status = p_new_status,
        tested_at     = IF(p_new_status = 'Tested',     NOW(), tested_at),
        stored_at     = IF(p_new_status = 'Stored',     NOW(), stored_at),
        reserved_at   = IF(p_new_status = 'Reserved',   NOW(), reserved_at),
        dispatched_at = IF(p_new_status = 'Dispatched', NOW(), dispatched_at),
        delivered_at  = IF(p_new_status = 'Delivered',  NOW(), delivered_at),
        used_at       = IF(p_new_status = 'Used',       NOW(), used_at),
        staff_notes   = COALESCE(p_notes, staff_notes)
    WHERE tracking_id = p_tracking_id;

    SELECT tracking_id, current_status, blood_type, units, expiry_date
    FROM blood_unit_tracking WHERE tracking_id = p_tracking_id;
END$$

CREATE PROCEDURE generate_demand_forecast(
    IN p_blood_bank_id INT,
    IN p_blood_type    VARCHAR(5)
)
BEGIN
    DECLARE avg_units      DECIMAL(8,2);
    DECLARE shortage_rate  DECIMAL(5,2);
    DECLARE confidence     INT;
    DECLARE next_month     TINYINT;
    DECLARE next_year      SMALLINT;

    SET next_month = IF(MONTH(CURDATE()) = 12, 1, MONTH(CURDATE()) + 1);
    SET next_year  = IF(MONTH(CURDATE()) = 12, YEAR(CURDATE()) + 1, YEAR(CURDATE()));

    SELECT
        COALESCE(AVG(units_requested), 0),
        COALESCE(SUM(IF(shortage_flag,1,0)) / NULLIF(COUNT(*),0) * 100, 0)
    INTO avg_units, shortage_rate
    FROM demand_history
    WHERE blood_bank_id = p_blood_bank_id
      AND blood_type    = p_blood_type
      AND (year * 12 + month) >= (YEAR(CURDATE()) * 12 + MONTH(CURDATE()) - 3);

    SET confidence = GREATEST(50, 95 - ROUND(shortage_rate));

    INSERT INTO demand_forecasts
        (blood_bank_id, blood_type, forecast_month, forecast_year,
         predicted_units, confidence_pct, alert_threshold)
    VALUES
        (p_blood_bank_id, p_blood_type, next_month, next_year,
         ROUND(avg_units * 1.05, 2), confidence, ROUND(avg_units * 0.3, 2))
    ON DUPLICATE KEY UPDATE
        predicted_units = ROUND(avg_units * 1.05, 2),
        confidence_pct  = confidence,
        alert_threshold = ROUND(avg_units * 0.3, 2),
        generated_at    = NOW();

    SELECT next_month AS forecast_month, next_year AS forecast_year,
           ROUND(avg_units * 1.05, 2) AS predicted_units, confidence AS confidence_pct;
END$$

CREATE PROCEDURE award_emergency_hero(IN p_donor_id INT)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM badge_history
        WHERE donor_id = p_donor_id AND badge_name = 'Emergency Hero'
    ) THEN
        INSERT INTO badge_history (donor_id, badge_name, reason)
        VALUES (p_donor_id, 'Emergency Hero', 'Responded to a Golden Hour emergency alert');
        UPDATE donors      SET points       = points       + 500 WHERE donor_id = p_donor_id;
        UPDATE leaderboard SET total_points = total_points + 500 WHERE donor_id = p_donor_id;
    END IF;
END$$

CREATE PROCEDURE approve_blood_request(
    IN p_request_id  INT,
    IN p_approved_by INT
)
BEGIN
    DECLARE v_blood_type VARCHAR(5);
    DECLARE v_units      DECIMAL(6,2);
    DECLARE v_bank_id    INT;
    DECLARE v_available  DECIMAL(6,2);

    SELECT blood_type, units_needed, blood_bank_id
    INTO v_blood_type, v_units, v_bank_id
    FROM blood_requests WHERE request_id = p_request_id;

    SELECT COALESCE(SUM(units_available), 0) INTO v_available
    FROM blood_inventory
    WHERE blood_type = v_blood_type
      AND status    != 'Expired';

    IF v_available >= v_units THEN
        UPDATE blood_requests
        SET status = 'Approved'
        WHERE request_id = p_request_id;

        UPDATE blood_inventory
        SET units_available = units_available - v_units
        WHERE blood_type = v_blood_type
          AND status    != 'Expired'
          AND units_available >= v_units
        ORDER BY units_available DESC
        LIMIT 1;

        SELECT 'Approved' AS result,
               CONCAT('Stock deducted. ', v_units, ' units of ',
                      v_blood_type, ' allocated.') AS message;
    ELSE
        UPDATE blood_requests
        SET status = 'Rejected'
        WHERE request_id = p_request_id;

        SELECT 'Rejected' AS result,
               CONCAT('Insufficient stock. Available: ',
                      v_available, ' units of ', v_blood_type) AS message;
    END IF;
END$$

DELIMITER ;


CREATE VIEW vw_admin_dashboard AS
SELECT
    (SELECT COUNT(*) FROM donors)                                    AS total_donors,
    (SELECT COUNT(*) FROM donors WHERE is_eligible = 1)              AS eligible_donors,
    (SELECT COALESCE(SUM(units_available),0) FROM blood_inventory
     WHERE status != 'Expired')                                      AS total_units,
    (SELECT COUNT(*) FROM blood_requests WHERE status = 'Pending')   AS pending_requests,
    (SELECT COUNT(*) FROM emergency_alerts WHERE status = 'Active')  AS active_alerts,
    (SELECT COUNT(*) FROM donation_camps WHERE status = 'Upcoming')  AS upcoming_camps,
    (SELECT COUNT(*) FROM blood_inventory
     WHERE DATEDIFF(expiry_date, CURDATE()) BETWEEN 0 AND 7
       AND status != 'Expired')                                      AS expiring_soon_units;

CREATE VIEW vw_leaderboard AS
SELECT l.rank_overall, u.name, d.blood_type, d.city,
       d.badge_level, d.total_donations, l.total_points
FROM leaderboard l
JOIN donors d ON d.donor_id = l.donor_id
JOIN users  u ON u.user_id  = d.user_id
ORDER BY l.rank_overall;

CREATE VIEW vw_expiring_inventory AS
SELECT bi.inventory_id, bb.name AS blood_bank, bb.city,
       bi.blood_type, bi.units_available, bi.expiry_date,
       DATEDIFF(bi.expiry_date, CURDATE()) AS days_until_expiry
FROM blood_inventory bi
JOIN blood_banks bb ON bb.blood_bank_id = bi.blood_bank_id
WHERE bi.status != 'Expired'
  AND DATEDIFF(bi.expiry_date, CURDATE()) <= 10
ORDER BY days_until_expiry;

CREATE VIEW vw_active_emergency_alerts AS
SELECT ea.alert_id, bb.name AS blood_bank, h.name AS hospital,
       ea.blood_type_needed, ea.units_needed, ea.message,
       ea.radius_km, ea.golden_hour_deadline,
       TIMESTAMPDIFF(MINUTE, NOW(), ea.golden_hour_deadline) AS minutes_remaining,
       ea.status
FROM emergency_alerts ea
JOIN blood_banks bb ON bb.blood_bank_id = ea.blood_bank_id
LEFT JOIN hospitals h ON h.hospital_id = ea.hospital_id
WHERE ea.status = 'Active'
ORDER BY ea.golden_hour_deadline;

CREATE VIEW vw_supply_chain AS
SELECT bt.tracking_id, u.name AS donor_name, bt.blood_type, bt.units,
       bt.current_status, bb.name AS blood_bank,
       h.name AS assigned_hospital,
       bt.collected_at, bt.expiry_date,
       DATEDIFF(bt.expiry_date, CURDATE()) AS days_until_expiry,
       bt.staff_notes
FROM blood_unit_tracking bt
JOIN donors    d  ON d.donor_id      = bt.donor_id
JOIN users     u  ON u.user_id       = d.user_id
JOIN blood_banks bb ON bb.blood_bank_id = bt.blood_bank_id
LEFT JOIN hospitals h ON h.hospital_id  = bt.assigned_to_hospital_id
ORDER BY bt.collected_at DESC;

CREATE VIEW vw_wastage_analytics AS
SELECT bb.name AS blood_bank, wl.blood_type,
       YEAR(wl.logged_at) AS year, MONTH(wl.logged_at) AS month,
       SUM(wl.units_wasted)  AS total_wasted,
       COUNT(*)              AS wastage_events
FROM wastage_log wl
JOIN blood_banks bb ON bb.blood_bank_id = wl.blood_bank_id
GROUP BY wl.blood_bank_id, wl.blood_type, YEAR(wl.logged_at), MONTH(wl.logged_at)
ORDER BY total_wasted DESC;

CREATE VIEW vw_donor_cooldown AS
SELECT d.donor_id, u.name, d.blood_type, d.city,
       d.last_donated, d.is_eligible,
       CASE WHEN d.last_donated IS NULL THEN NULL
            ELSE DATE_ADD(d.last_donated, INTERVAL 90 DAY)
       END AS eligible_again_date,
       CASE WHEN d.is_eligible = TRUE   THEN 0
            WHEN d.last_donated IS NULL THEN 0
            ELSE GREATEST(0, 90 - DATEDIFF(CURDATE(), d.last_donated))
       END AS cooldown_days_remaining,
       d.badge_level, d.total_donations
FROM donors d
JOIN users u ON u.user_id = d.user_id
ORDER BY cooldown_days_remaining DESC;


INSERT INTO blood_compatibility VALUES
('O-','O-',1),('O-','O+',1),('O-','A-',1),('O-','A+',1),
('O-','B-',1),('O-','B+',1),('O-','AB-',1),('O-','AB+',1),
('O+','O+',1),('O+','A+',1),('O+','B+',1),('O+','AB+',1),
('A-','A-',1),('A-','A+',1),('A-','AB-',1),('A-','AB+',1),
('A+','A+',1),('A+','AB+',1),
('B-','B-',1),('B-','B+',1),('B-','AB-',1),('B-','AB+',1),
('B+','B+',1),('B+','AB+',1),
('AB-','AB-',1),('AB-','AB+',1),
('AB+','AB+',1);

INSERT IGNORE INTO blood_compatibility
SELECT a.bt, b.bt, 0
FROM (SELECT 'A+' AS bt UNION SELECT 'A-' UNION SELECT 'B+' UNION SELECT 'B-'
      UNION SELECT 'AB+' UNION SELECT 'AB-' UNION SELECT 'O+' UNION SELECT 'O-') a
CROSS JOIN
     (SELECT 'A+' AS bt UNION SELECT 'A-' UNION SELECT 'B+' UNION SELECT 'B-'
      UNION SELECT 'AB+' UNION SELECT 'AB-' UNION SELECT 'O+' UNION SELECT 'O-') b;

INSERT INTO users (name, email, password_hash, role) VALUES
('Admin User',           'admin@bloodbank.com',      '$2b$12$KIXnK6qNz8yR1wqA7kL3.uXzXpVmYnOdP4tQw6aJ9rB2sC5eH0iG2', 'admin'),
('Victoria Hospital BB', 'bank@victoriabb.com',      '$2b$12$placeholder_hash_bb1',   'blood_bank'),
('St Johns Medical BB',  'bank@stjohnsbb.com',       '$2b$12$placeholder_hash_bb2',   'blood_bank'),
('Manipal Hospital BB',  'bank@manipalbb.com',       '$2b$12$placeholder_hash_bb3',   'blood_bank'),
('Apollo Hospital BB',   'bank@apollobb.com',         '$2b$12$placeholder_hash_bb4',   'blood_bank'),
('Narayana Health BB',   'bank@narayanabb.com',      '$2b$12$placeholder_hash_bb5',   'blood_bank'),
('Fortis Hospital BB',   'bank@fortisbb.com',         '$2b$12$placeholder_hash_bb6',   'blood_bank'),
('Kidwai Memorial BB',   'bank@kidwaibb.com',         '$2b$12$placeholder_hash_bb7',   'blood_bank'),
('NIMHANS Blood Bank',   'bank@nimhansbb.com',        '$2b$12$placeholder_hash_bb8',   'blood_bank'),
('Apollo Hospital',      'admin@apollohosp.com',      '$2b$12$placeholder_hash_h1',    'hospital'),
('Victoria Hospital',    'admin@victoriahosp.com',    '$2b$12$placeholder_hash_h2',    'hospital'),
('Manipal Hospital',     'admin@manipalhosp.com',     '$2b$12$placeholder_hash_h3',    'hospital'),
('Fortis Hospital',      'admin@fortishosp.com',      '$2b$12$placeholder_hash_h4',    'hospital'),
('Narayana Health',      'admin@narayanahosp.com',    '$2b$12$placeholder_hash_h5',    'hospital'),
('Ravi Kumar',           'ravi@donor.com',            '$2b$12$placeholder_hash_donor1','donor'),
('Priya Sharma',         'priya@donor.com',           '$2b$12$placeholder_hash_donor2','donor'),
('Suresh Gowda',         'suresh@donor.com',          '$2b$12$placeholder_hash_donor3','donor');

-- blood_bank_id 1–8 match exactly what the JS frontend hardcodes
INSERT INTO blood_banks (user_id, name, address, city, phone, latitude, longitude, demand_forecast_score) VALUES
(2,  'Victoria Hospital BB',  'K.R. Road, Fort',              'Bengaluru', '080-22203050', 12.9605, 77.5754, 80),
(3,  'St. Johns Medical BB',  'Sarjapur Road, Koramangala',   'Bengaluru', '080-22065000', 12.9259, 77.6229, 70),
(4,  'Manipal Hospital BB',   'HAL Airport Road',             'Bengaluru', '080-25023456', 12.9591, 77.6491, 75),
(5,  'Apollo Hospital BB',    'Bannerghatta Road',            'Bengaluru', '080-26304050', 12.8987, 77.5967, 65),
(6,  'Narayana Health BB',    'Bommasandra Industrial Area',  'Bengaluru', '080-71222222', 12.8110, 77.6869, 60),
(7,  'Fortis Hospital BB',    'Bannerghatta, Banashankari',   'Bengaluru', '080-66214444', 12.8951, 77.5975, 68),
(8,  'Kidwai Memorial BB',    'Dr. M.H. Marigowda Road',      'Bengaluru', '080-26094000', 12.9288, 77.5975, 72),
(9,  'NIMHANS Blood Bank',    'Hosur Road, Lakkasandra',      'Bengaluru', '080-46110007', 12.9394, 77.5960, 55);

-- hospital_id 1–5
INSERT INTO hospitals (user_id, name, address, city, phone, contact_person, latitude, longitude) VALUES
(10, 'Apollo Hospital',   '154 Bannerghatta Road',        'Bengaluru', '080-26304050', 'Dr. Sharma',  12.8987, 77.5967),
(11, 'Victoria Hospital', 'K.R. Road, Fort',              'Bengaluru', '080-22203050', 'Dr. Reddy',   12.9605, 77.5754),
(12, 'Manipal Hospital',  'HAL Airport Road',             'Bengaluru', '080-25023456', 'Dr. Patel',   12.9591, 77.6491),
(13, 'Fortis Hospital',   'Bannerghatta Road, Banashankari','Bengaluru','080-66214444', 'Dr. Menon',   12.8951, 77.5975),
(14, 'Narayana Health',   'Bommasandra Industrial Area',  'Bengaluru', '080-71222222', 'Dr. Gowda',   12.8110, 77.6869);

INSERT INTO donors (user_id, dob, blood_type, gender, phone, city, latitude, longitude, badge_level, total_donations, points) VALUES
(15, '1995-06-15', 'O+', 'Male',   '9876543210', 'Bengaluru', 12.9352, 77.6245, 'Bronze',  2,  200),
(16, '1998-03-22', 'A+', 'Female', '9845123456', 'Bengaluru', 12.9716, 77.5946, 'Silver',  6,  650),
(17, '1993-11-10', 'O-', 'Male',   '9731234567', 'Bengaluru', 12.9120, 77.6420, 'Gold',   11, 1150);

INSERT INTO leaderboard (donor_id, city, total_points) VALUES
(1, 'Bengaluru',  200),
(2, 'Bengaluru',  650),
(3, 'Bengaluru', 1150);

-- Inventory matches exactly what the JS frontend hardcodes (SAMPLE_INVENTORY / BANKS stocks)
-- bank 1 = Victoria Hospital BB
INSERT INTO blood_inventory (blood_bank_id, blood_type, units_available, expiry_date, status) VALUES
(1, 'A+',  480, DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'Available'),
(1, 'A-',   70, DATE_ADD(CURDATE(), INTERVAL 12 DAY), 'Low'),
(1, 'B+',  390, DATE_ADD(CURDATE(), INTERVAL 25 DAY), 'Available'),
(1, 'B-',   55, DATE_ADD(CURDATE(), INTERVAL 18 DAY), 'Low'),
(1, 'AB+', 210, DATE_ADD(CURDATE(), INTERVAL 28 DAY), 'Available'),
(1, 'AB-',  20, DATE_ADD(CURDATE(), INTERVAL 4  DAY), 'Low'),
(1, 'O+',  620, DATE_ADD(CURDATE(), INTERVAL 35 DAY), 'Available'),
(1, 'O-',   85, DATE_ADD(CURDATE(), INTERVAL 9  DAY), 'Low'),
-- bank 2 = St. Johns Medical BB
(2, 'A+',  410, DATE_ADD(CURDATE(), INTERVAL 22 DAY), 'Available'),
(2, 'A-',   55, DATE_ADD(CURDATE(), INTERVAL 8  DAY), 'Low'),
(2, 'B+',  320, DATE_ADD(CURDATE(), INTERVAL 20 DAY), 'Available'),
(2, 'B-',   40, DATE_ADD(CURDATE(), INTERVAL 14 DAY), 'Low'),
(2, 'AB+', 180, DATE_ADD(CURDATE(), INTERVAL 26 DAY), 'Available'),
(2, 'AB-',  15, DATE_ADD(CURDATE(), INTERVAL 5  DAY), 'Low'),
(2, 'O+',  540, DATE_ADD(CURDATE(), INTERVAL 32 DAY), 'Available'),
(2, 'O-',   65, DATE_ADD(CURDATE(), INTERVAL 7  DAY), 'Low'),
-- bank 3 = Manipal Hospital BB
(3, 'A+',  500, DATE_ADD(CURDATE(), INTERVAL 28 DAY), 'Available'),
(3, 'A-',   80, DATE_ADD(CURDATE(), INTERVAL 10 DAY), 'Low'),
(3, 'B+',  430, DATE_ADD(CURDATE(), INTERVAL 24 DAY), 'Available'),
(3, 'B-',   60, DATE_ADD(CURDATE(), INTERVAL 16 DAY), 'Low'),
(3, 'AB+', 240, DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'Available'),
(3, 'AB-',  25, DATE_ADD(CURDATE(), INTERVAL 6  DAY), 'Low'),
(3, 'O+',  710, DATE_ADD(CURDATE(), INTERVAL 38 DAY), 'Available'),
(3, 'O-',   90, DATE_ADD(CURDATE(), INTERVAL 11 DAY), 'Low'),
-- bank 4 = Apollo Hospital BB
(4, 'A+',  440, DATE_ADD(CURDATE(), INTERVAL 20 DAY), 'Available'),
(4, 'A-',   65, DATE_ADD(CURDATE(), INTERVAL 9  DAY), 'Low'),
(4, 'B+',  360, DATE_ADD(CURDATE(), INTERVAL 22 DAY), 'Available'),
(4, 'B-',   50, DATE_ADD(CURDATE(), INTERVAL 15 DAY), 'Low'),
(4, 'AB+', 200, DATE_ADD(CURDATE(), INTERVAL 27 DAY), 'Available'),
(4, 'AB-',  18, DATE_ADD(CURDATE(), INTERVAL 3  DAY), 'Low'),
(4, 'O+',  580, DATE_ADD(CURDATE(), INTERVAL 33 DAY), 'Available'),
(4, 'O-',   75, DATE_ADD(CURDATE(), INTERVAL 8  DAY), 'Low'),
-- bank 5 = Narayana Health BB
(5, 'A+',  370, DATE_ADD(CURDATE(), INTERVAL 18 DAY), 'Available'),
(5, 'A-',   45, DATE_ADD(CURDATE(), INTERVAL 7  DAY), 'Low'),
(5, 'B+',  280, DATE_ADD(CURDATE(), INTERVAL 19 DAY), 'Available'),
(5, 'B-',   35, DATE_ADD(CURDATE(), INTERVAL 13 DAY), 'Low'),
(5, 'AB+', 150, DATE_ADD(CURDATE(), INTERVAL 24 DAY), 'Available'),
(5, 'AB-',  10, DATE_ADD(CURDATE(), INTERVAL 3  DAY), 'Low'),
(5, 'O+',  450, DATE_ADD(CURDATE(), INTERVAL 29 DAY), 'Available'),
(5, 'O-',   50, DATE_ADD(CURDATE(), INTERVAL 6  DAY), 'Low'),
-- bank 6 = Fortis Hospital BB
(6, 'A+',  380, DATE_ADD(CURDATE(), INTERVAL 21 DAY), 'Available'),
(6, 'A-',   52, DATE_ADD(CURDATE(), INTERVAL 8  DAY), 'Low'),
(6, 'B+',  300, DATE_ADD(CURDATE(), INTERVAL 20 DAY), 'Available'),
(6, 'B-',   42, DATE_ADD(CURDATE(), INTERVAL 14 DAY), 'Low'),
(6, 'AB+', 165, DATE_ADD(CURDATE(), INTERVAL 25 DAY), 'Available'),
(6, 'AB-',  14, DATE_ADD(CURDATE(), INTERVAL 4  DAY), 'Low'),
(6, 'O+',  490, DATE_ADD(CURDATE(), INTERVAL 31 DAY), 'Available'),
(6, 'O-',   60, DATE_ADD(CURDATE(), INTERVAL 7  DAY), 'Low'),
-- bank 7 = Kidwai Memorial BB
(7, 'A+',  260, DATE_ADD(CURDATE(), INTERVAL 17 DAY), 'Available'),
(7, 'A-',   35, DATE_ADD(CURDATE(), INTERVAL 6  DAY), 'Low'),
(7, 'B+',  200, DATE_ADD(CURDATE(), INTERVAL 16 DAY), 'Available'),
(7, 'B-',   25, DATE_ADD(CURDATE(), INTERVAL 11 DAY), 'Low'),
(7, 'AB+', 120, DATE_ADD(CURDATE(), INTERVAL 22 DAY), 'Available'),
(7, 'AB-',   8, DATE_ADD(CURDATE(), INTERVAL 3  DAY), 'Low'),
(7, 'O+',  330, DATE_ADD(CURDATE(), INTERVAL 27 DAY), 'Available'),
(7, 'O-',   40, DATE_ADD(CURDATE(), INTERVAL 5  DAY), 'Low'),
-- bank 8 = NIMHANS Blood Bank
(8, 'A+',  220, DATE_ADD(CURDATE(), INTERVAL 15 DAY), 'Available'),
(8, 'A-',   30, DATE_ADD(CURDATE(), INTERVAL 5  DAY), 'Low'),
(8, 'B+',  170, DATE_ADD(CURDATE(), INTERVAL 14 DAY), 'Available'),
(8, 'B-',   22, DATE_ADD(CURDATE(), INTERVAL 10 DAY), 'Low'),
(8, 'AB+',  95, DATE_ADD(CURDATE(), INTERVAL 20 DAY), 'Available'),
(8, 'AB-',   7, DATE_ADD(CURDATE(), INTERVAL 3  DAY), 'Low'),
(8, 'O+',  290, DATE_ADD(CURDATE(), INTERVAL 25 DAY), 'Available'),
(8, 'O-',   35, DATE_ADD(CURDATE(), INTERVAL 5  DAY), 'Low');

INSERT INTO donation_camps (blood_bank_id, organizer_name, organizer_type, location, city, camp_date, start_time, end_time, status) VALUES
(1, 'IIM Bangalore',      'College',   'IIMB Campus, Bannerghatta Road', 'Bengaluru', DATE_ADD(CURDATE(), INTERVAL 7  DAY), '09:00:00', '17:00:00', 'Upcoming'),
(3, 'Infosys Foundation', 'Corporate', 'Infosys, Electronic City',       'Bengaluru', DATE_ADD(CURDATE(), INTERVAL 14 DAY), '10:00:00', '16:00:00', 'Upcoming'),
(7, 'Rotary Club BLR',    'NGO',       'Town Hall, MG Road',             'Bengaluru', DATE_ADD(CURDATE(), INTERVAL 21 DAY), '08:00:00', '14:00:00', 'Upcoming'),
(4, 'PESIT College',      'College',   'PESIT Campus, BSK III Stage',    'Bengaluru', DATE_ADD(CURDATE(), INTERVAL 25 DAY), '09:00:00', '15:00:00', 'Upcoming');

-- hospital_id: 1=Apollo, 2=Victoria, 3=Manipal, 4=Fortis, 5=Narayana
-- blood_bank_id: 1=Victoria BB, 3=Manipal BB, 4=Apollo BB, 6=Fortis BB, 5=Narayana BB
INSERT INTO blood_requests (hospital_id, blood_bank_id, blood_type, units_needed, urgency_level, status) VALUES
(1, 4, 'O-',  2.00, 'Critical', 'Pending'),
(2, 1, 'AB-', 1.00, 'High',     'Pending'),
(3, 3, 'B+',  3.00, 'Normal',   'Approved'),
(4, 6, 'A+',  2.00, 'High',     'Pending'),
(5, 5, 'O+',  4.00, 'Normal',   'Fulfilled');

INSERT INTO emergency_alerts (blood_bank_id, hospital_id, blood_type_needed, units_needed, message, radius_km, golden_hour_deadline, status) VALUES
(4, 1, 'O-',  2.00,
 'URGENT: O- blood needed for trauma patient at Apollo Hospital. Please respond immediately.',
 15.00, DATE_ADD(NOW(), INTERVAL 60 MINUTE), 'Active'),
(1, 2, 'AB-', 1.00,
 'Critical AB- shortage at Victoria Hospital — surgery patient waiting.',
 10.00, DATE_ADD(NOW(), INTERVAL 90 MINUTE), 'Active');

INSERT INTO demand_history (blood_bank_id, blood_type, month, year, units_requested, units_fulfilled, shortage_flag) VALUES
(1,'O+', MONTH(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), 45, 40, 1),
(1,'O+', MONTH(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), 38, 38, 0),
(1,'O+', MONTH(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), 52, 45, 1),
(1,'O-', MONTH(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), 20, 15, 1),
(1,'O-', MONTH(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), 18, 18, 0),
(1,'O-', MONTH(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), 22, 16, 1),
(1,'A+', MONTH(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), 35, 35, 0),
(1,'A+', MONTH(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), 40, 38, 1),
(1,'A+', MONTH(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), 38, 38, 0),
(1,'B+', MONTH(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), 28, 25, 1),
(1,'B+', MONTH(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), 30, 30, 0),
(1,'B+', MONTH(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), 32, 28, 1),
(1,'AB-',MONTH(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)),  8,  5, 1),
(1,'AB-',MONTH(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)),  7,  7, 0),
(1,'AB-',MONTH(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), 10,  6, 1),
(1,'A-', MONTH(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), 12, 10, 1),
(1,'A-', MONTH(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), 10, 10, 0),
(1,'A-', MONTH(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), 14,  9, 1),
(1,'B-', MONTH(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)),  9,  7, 1),
(1,'B-', MONTH(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)),  8,  8, 0),
(1,'B-', MONTH(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), 11,  7, 1),
(1,'AB+',MONTH(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 3 MONTH)), 18, 18, 0),
(1,'AB+',MONTH(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 2 MONTH)), 20, 17, 1),
(1,'AB+',MONTH(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), YEAR(DATE_SUB(CURDATE(),INTERVAL 1 MONTH)), 22, 20, 1);

INSERT INTO wastage_log (blood_bank_id, blood_type, units_wasted, expiry_date, reason) VALUES
(7, 'AB-', 2.00, DATE_SUB(CURDATE(), INTERVAL 2 DAY), 'Expired'),
(8, 'B-',  1.00, DATE_SUB(CURDATE(), INTERVAL 5 DAY), 'Expired');

INSERT INTO donations (donor_id, blood_bank_id, donation_date, units_donated, status) VALUES
(1, 1, CURDATE(),                               1.00, 'Completed'),
(2, 3, DATE_SUB(CURDATE(), INTERVAL 5   DAY),   1.00, 'Completed'),
(3, 4, DATE_SUB(CURDATE(), INTERVAL 10  DAY),   1.00, 'Completed'),
(1, 1, DATE_SUB(CURDATE(), INTERVAL 100 DAY),   1.00, 'Completed'),
(2, 3, DATE_SUB(CURDATE(), INTERVAL 95  DAY),   1.00, 'Completed');

CALL generate_demand_forecast(1, 'O+'); CALL generate_demand_forecast(1, 'O-');
CALL generate_demand_forecast(1, 'A+'); CALL generate_demand_forecast(1, 'A-');
CALL generate_demand_forecast(1, 'B+'); CALL generate_demand_forecast(1, 'B-');
CALL generate_demand_forecast(1, 'AB+'); CALL generate_demand_forecast(1, 'AB-');

CALL generate_demand_forecast(2, 'O+'); CALL generate_demand_forecast(2, 'O-');
CALL generate_demand_forecast(2, 'A+'); CALL generate_demand_forecast(2, 'A-');
CALL generate_demand_forecast(2, 'B+'); CALL generate_demand_forecast(2, 'B-');
CALL generate_demand_forecast(2, 'AB+'); CALL generate_demand_forecast(2, 'AB-');

CALL generate_demand_forecast(3, 'O+'); CALL generate_demand_forecast(3, 'O-');
CALL generate_demand_forecast(3, 'A+'); CALL generate_demand_forecast(3, 'A-');
CALL generate_demand_forecast(3, 'B+'); CALL generate_demand_forecast(3, 'B-');
CALL generate_demand_forecast(3, 'AB+'); CALL generate_demand_forecast(3, 'AB-');

CALL generate_demand_forecast(4, 'O+'); CALL generate_demand_forecast(4, 'O-');
CALL generate_demand_forecast(4, 'A+'); CALL generate_demand_forecast(4, 'A-');
CALL generate_demand_forecast(4, 'B+'); CALL generate_demand_forecast(4, 'B-');
CALL generate_demand_forecast(4, 'AB+'); CALL generate_demand_forecast(4, 'AB-');

CALL generate_demand_forecast(5, 'O+'); CALL generate_demand_forecast(5, 'O-');
CALL generate_demand_forecast(5, 'A+'); CALL generate_demand_forecast(5, 'A-');
CALL generate_demand_forecast(5, 'B+'); CALL generate_demand_forecast(5, 'B-');
CALL generate_demand_forecast(5, 'AB+'); CALL generate_demand_forecast(5, 'AB-');

CALL generate_demand_forecast(6, 'O+'); CALL generate_demand_forecast(6, 'O-');
CALL generate_demand_forecast(6, 'A+'); CALL generate_demand_forecast(6, 'A-');
CALL generate_demand_forecast(6, 'B+'); CALL generate_demand_forecast(6, 'B-');
CALL generate_demand_forecast(6, 'AB+'); CALL generate_demand_forecast(6, 'AB-');

CALL generate_demand_forecast(7, 'O+'); CALL generate_demand_forecast(7, 'O-');
CALL generate_demand_forecast(7, 'A+'); CALL generate_demand_forecast(7, 'A-');
CALL generate_demand_forecast(7, 'B+'); CALL generate_demand_forecast(7, 'B-');
CALL generate_demand_forecast(7, 'AB+'); CALL generate_demand_forecast(7, 'AB-');

CALL generate_demand_forecast(8, 'O+'); CALL generate_demand_forecast(8, 'O-');
CALL generate_demand_forecast(8, 'A+'); CALL generate_demand_forecast(8, 'A-');
CALL generate_demand_forecast(8, 'B+'); CALL generate_demand_forecast(8, 'B-');
CALL generate_demand_forecast(8, 'AB+'); CALL generate_demand_forecast(8, 'AB-');

show tables;
select * from users;
select *from donors;
select *from blood_requests;


  