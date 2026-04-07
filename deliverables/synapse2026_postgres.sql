-- Synapse 2026
-- PostgreSQL implementation for the IoT-enabled rubber molding machine project
-- Covers DDL, DML, views, index, trigger, stored procedure, and sample queries

DROP TABLE IF EXISTS alert CASCADE;
DROP TABLE IF EXISTS sensor_reading CASCADE;
DROP TABLE IF EXISTS production_batch CASCADE;
DROP TABLE IF EXISTS maintenance_record CASCADE;
DROP TABLE IF EXISTS sensor CASCADE;
DROP TABLE IF EXISTS technician CASCADE;
DROP TABLE IF EXISTS machine CASCADE;

CREATE TABLE machine (
    machine_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(150) NOT NULL,
    installation_date DATE NOT NULL CHECK (installation_date >= DATE '2000-01-01'),
    model VARCHAR(80) NOT NULL
);

CREATE TABLE technician (
    technician_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    specialization VARCHAR(100) NOT NULL,
    contact VARCHAR(120) NOT NULL UNIQUE
);

CREATE TABLE sensor (
    sensor_id BIGSERIAL PRIMARY KEY,
    machine_id BIGINT NOT NULL REFERENCES machine(machine_id) ON DELETE CASCADE,
    sensor_type VARCHAR(20) NOT NULL CHECK (sensor_type IN ('temperature', 'pressure', 'vibration')),
    unit VARCHAR(20) NOT NULL CHECK (unit IN ('degC', 'bar', 'mm/s')),
    calibration_date DATE NOT NULL CHECK (calibration_date >= DATE '2000-01-01'),
    sensor_tag VARCHAR(30) NOT NULL UNIQUE,
    CHECK (
        (sensor_type = 'temperature' AND unit = 'degC') OR
        (sensor_type = 'pressure' AND unit = 'bar') OR
        (sensor_type = 'vibration' AND unit = 'mm/s')
    )
);

CREATE TABLE sensor_reading (
    reading_id BIGSERIAL PRIMARY KEY,
    sensor_id BIGINT NOT NULL REFERENCES sensor(sensor_id) ON DELETE CASCADE,
    "timestamp" TIMESTAMPTZ NOT NULL,
    value NUMERIC(10,3) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('OK', 'WARNING', 'CRITICAL', 'BUFFERED', 'OFFLINE')),
    sequence_no BIGINT NOT NULL CHECK (sequence_no > 0),
    checksum CHAR(32) NOT NULL,
    UNIQUE (sensor_id, sequence_no),
    UNIQUE (sensor_id, "timestamp")
);

CREATE TABLE maintenance_record (
    maintenance_id BIGSERIAL PRIMARY KEY,
    machine_id BIGINT NOT NULL REFERENCES machine(machine_id) ON DELETE CASCADE,
    technician_id BIGINT NOT NULL REFERENCES technician(technician_id),
    "date" DATE NOT NULL CHECK ("date" >= DATE '2000-01-01'),
    type VARCHAR(20) NOT NULL CHECK (type IN ('preventive', 'corrective', 'calibration', 'inspection', 'predictive')),
    description TEXT NOT NULL,
    cost NUMERIC(12,2) NOT NULL CHECK (cost >= 0)
);

CREATE TABLE production_batch (
    batch_id BIGSERIAL PRIMARY KEY,
    machine_id BIGINT NOT NULL REFERENCES machine(machine_id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    quantity_produced INTEGER NOT NULL CHECK (quantity_produced >= 0),
    defect_count INTEGER NOT NULL CHECK (defect_count >= 0 AND defect_count <= quantity_produced),
    quality_score NUMERIC(5,2) NOT NULL CHECK (quality_score BETWEEN 0 AND 100),
    CHECK (end_time > start_time)
);

CREATE TABLE alert (
    alert_id BIGSERIAL PRIMARY KEY,
    sensor_id BIGINT NOT NULL REFERENCES sensor(sensor_id) ON DELETE CASCADE,
    reading_id BIGINT REFERENCES sensor_reading(reading_id) ON DELETE SET NULL,
    triggered_at TIMESTAMPTZ NOT NULL,
    alert_type VARCHAR(30) NOT NULL CHECK (
        alert_type IN (
            'HIGH_TEMPERATURE',
            'LOW_TEMPERATURE',
            'HIGH_PRESSURE',
            'LOW_PRESSURE',
            'HIGH_VIBRATION',
            'SENSOR_FAULT'
        )
    ),
    threshold_value NUMERIC(10,3) NOT NULL,
    actual_value NUMERIC(10,3) NOT NULL,
    resolved BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_sensor_reading_timestamp ON sensor_reading ("timestamp");

CREATE OR REPLACE FUNCTION fn_create_alert_on_threshold()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_sensor_type VARCHAR(20);
    v_alert_type VARCHAR(30);
    v_threshold NUMERIC(10,3);
BEGIN
    SELECT sensor_type
    INTO v_sensor_type
    FROM sensor
    WHERE sensor_id = NEW.sensor_id;

    IF v_sensor_type = 'temperature' AND NEW.value > 195 THEN
        v_alert_type := 'HIGH_TEMPERATURE';
        v_threshold := 195;
    ELSIF v_sensor_type = 'temperature' AND NEW.value < 150 THEN
        v_alert_type := 'LOW_TEMPERATURE';
        v_threshold := 150;
    ELSIF v_sensor_type = 'pressure' AND NEW.value > 140 THEN
        v_alert_type := 'HIGH_PRESSURE';
        v_threshold := 140;
    ELSIF v_sensor_type = 'pressure' AND NEW.value < 55 THEN
        v_alert_type := 'LOW_PRESSURE';
        v_threshold := 55;
    ELSIF v_sensor_type = 'vibration' AND NEW.value > 4.0 THEN
        v_alert_type := 'HIGH_VIBRATION';
        v_threshold := 4.0;
    END IF;

    IF v_alert_type IS NOT NULL THEN
        INSERT INTO alert (sensor_id, reading_id, triggered_at, alert_type, threshold_value, actual_value, resolved)
        VALUES (NEW.sensor_id, NEW.reading_id, NEW."timestamp", v_alert_type, v_threshold, NEW.value, FALSE);
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_create_alert_on_sensor_reading
AFTER INSERT ON sensor_reading
FOR EACH ROW
EXECUTE FUNCTION fn_create_alert_on_threshold();

CREATE OR REPLACE VIEW live_sensor_status AS
SELECT DISTINCT ON (s.sensor_id)
    m.machine_id,
    m.name AS machine_name,
    s.sensor_id,
    s.sensor_tag,
    s.sensor_type,
    s.unit,
    sr."timestamp" AS latest_timestamp,
    sr.value AS latest_value,
    sr.status AS latest_status,
    sr.sequence_no
FROM sensor s
JOIN machine m
    ON m.machine_id = s.machine_id
LEFT JOIN sensor_reading sr
    ON sr.sensor_id = s.sensor_id
ORDER BY s.sensor_id, sr."timestamp" DESC NULLS LAST;

CREATE OR REPLACE VIEW machine_health_summary AS
WITH sensor_metrics AS (
    SELECT
        s.machine_id,
        ROUND(AVG(CASE WHEN s.sensor_type = 'temperature' THEN sr.value END), 2) AS avg_temperature,
        ROUND(AVG(CASE WHEN s.sensor_type = 'pressure' THEN sr.value END), 2) AS avg_pressure,
        ROUND(AVG(CASE WHEN s.sensor_type = 'vibration' THEN sr.value END), 2) AS avg_vibration
    FROM sensor s
    LEFT JOIN sensor_reading sr
        ON sr.sensor_id = s.sensor_id
    GROUP BY s.machine_id
),
batch_metrics AS (
    SELECT
        machine_id,
        COUNT(*) AS batch_count,
        SUM(quantity_produced) AS total_quantity,
        SUM(defect_count) AS total_defects,
        ROUND(AVG(quality_score), 2) AS avg_quality_score
    FROM production_batch
    GROUP BY machine_id
),
alert_metrics AS (
    SELECT
        s.machine_id,
        COUNT(*) FILTER (WHERE a.resolved = FALSE) AS unresolved_alerts
    FROM sensor s
    LEFT JOIN alert a
        ON a.sensor_id = s.sensor_id
    GROUP BY s.machine_id
),
maintenance_metrics AS (
    SELECT
        machine_id,
        MAX("date") AS last_maintenance_date
    FROM maintenance_record
    GROUP BY machine_id
)
SELECT
    m.machine_id,
    m.name AS machine_name,
    COALESCE(sm.avg_temperature, 0) AS avg_temperature,
    COALESCE(sm.avg_pressure, 0) AS avg_pressure,
    COALESCE(sm.avg_vibration, 0) AS avg_vibration,
    COALESCE(bm.batch_count, 0) AS batch_count,
    COALESCE(bm.total_quantity, 0) AS total_quantity,
    COALESCE(bm.total_defects, 0) AS total_defects,
    COALESCE(bm.avg_quality_score, 0) AS avg_quality_score,
    COALESCE(am.unresolved_alerts, 0) AS unresolved_alerts,
    mm.last_maintenance_date
FROM machine m
LEFT JOIN sensor_metrics sm
    ON sm.machine_id = m.machine_id
LEFT JOIN batch_metrics bm
    ON bm.machine_id = m.machine_id
LEFT JOIN alert_metrics am
    ON am.machine_id = m.machine_id
LEFT JOIN maintenance_metrics mm
    ON mm.machine_id = m.machine_id;

CREATE OR REPLACE PROCEDURE get_maintenance_due_machines(IN p_due_days INTEGER, INOUT result_cursor REFCURSOR)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN result_cursor FOR
    SELECT
        m.machine_id,
        m.name,
        m.location,
        COALESCE(MAX(mr."date"), m.installation_date) AS last_service_date,
        CURRENT_DATE - COALESCE(MAX(mr."date"), m.installation_date) AS days_since_service
    FROM machine m
    LEFT JOIN maintenance_record mr
        ON mr.machine_id = m.machine_id
    GROUP BY m.machine_id, m.name, m.location, m.installation_date
    HAVING CURRENT_DATE - COALESCE(MAX(mr."date"), m.installation_date) >= p_due_days
    ORDER BY days_since_service DESC, m.machine_id;
END;
$$;

SELECT setseed(0.2026);

INSERT INTO machine (name, location, installation_date, model)
SELECT
    'Rubber Press ' || LPAD(gs::TEXT, 2, '0'),
    'Plant A / Line ' || (((gs - 1) % 5) + 1),
    DATE '2022-01-01' + ((gs - 1) * 15),
    CASE WHEN gs % 2 = 0 THEN 'RPC-4P-220' ELSE 'RPC-4P-180' END
FROM generate_series(1, 25) AS gs;

INSERT INTO technician (name, specialization, contact)
SELECT
    'Technician ' || LPAD(gs::TEXT, 2, '0'),
    (ARRAY['Hydraulics', 'PLC Controls', 'Thermal Systems', 'Vibration Analysis', 'Calibration'])[((gs - 1) % 5) + 1],
    'tech' || LPAD(gs::TEXT, 2, '0') || '@nucoeet.example'
FROM generate_series(1, 25) AS gs;

INSERT INTO sensor (machine_id, sensor_type, unit, calibration_date, sensor_tag)
SELECT
    m.machine_id,
    v.sensor_type,
    v.unit,
    DATE '2026-03-20' - ((m.machine_id::INT * 2) + v.day_offset),
    'M' || LPAD(m.machine_id::TEXT, 2, '0') || '-' || v.tag
FROM machine m
CROSS JOIN (
    VALUES
        ('temperature', 'degC', 10, 'TEMP'),
        ('pressure', 'bar', 12, 'PRES'),
        ('vibration', 'mm/s', 14, 'VIB')
) AS v(sensor_type, unit, day_offset, tag);

WITH batch_seed AS (
    SELECT
        gs,
        ((gs - 1) % 25) + 1 AS machine_id,
        TIMESTAMPTZ '2026-03-01 06:00:00+05:30' + make_interval(hours => (gs - 1) * 12) AS start_time
    FROM generate_series(1, 50) AS gs
),
batch_values AS (
    SELECT
        gs,
        machine_id,
        start_time,
        (430 + ((gs - 1) % 8) * 14 + FLOOR(random() * 18))::INT AS quantity_produced,
        (2 + ((gs - 1) % 5) + FLOOR(random() * 4))::INT AS defect_count
    FROM batch_seed
)
INSERT INTO production_batch (machine_id, start_time, end_time, quantity_produced, defect_count, quality_score)
SELECT
    machine_id,
    start_time,
    start_time + INTERVAL '2 hours 45 minutes',
    quantity_produced,
    defect_count,
    ROUND(
        GREATEST(
            75,
            LEAST(
                99.50,
                97.5 - (defect_count * 1.25) + (random() * 1.75)
            )
        )::NUMERIC,
        2
    ) AS quality_score
FROM batch_values;

WITH maintenance_seed AS (
    SELECT
        gs,
        ((gs - 1) % 25) + 1 AS machine_id,
        ((gs * 3 - 1) % 25) + 1 AS technician_id,
        DATE '2025-09-01' + ((gs - 1) * 4) AS service_date,
        (ARRAY['preventive', 'inspection', 'calibration', 'predictive', 'corrective'])[((gs - 1) % 5) + 1] AS service_type
    FROM generate_series(1, 50) AS gs
)
INSERT INTO maintenance_record (machine_id, technician_id, "date", type, description, cost)
SELECT
    machine_id,
    technician_id,
    service_date,
    service_type,
    CASE service_type
        WHEN 'preventive' THEN 'Preventive maintenance on heating platens, hydraulic seals, and guide pillars.'
        WHEN 'inspection' THEN 'Routine inspection of compression frame alignment, hoses, and electrical terminations.'
        WHEN 'calibration' THEN 'Calibration of temperature, pressure, and vibration sensing channels.'
        WHEN 'predictive' THEN 'Predictive maintenance triggered by rising vibration and thermal drift indicators.'
        WHEN 'corrective' THEN 'Corrective maintenance for abnormal pressure hold and platen temperature imbalance.'
    END,
    ROUND(
        CASE service_type
            WHEN 'preventive' THEN 420 + random() * 80
            WHEN 'inspection' THEN 180 + random() * 50
            WHEN 'calibration' THEN 260 + random() * 70
            WHEN 'predictive' THEN 350 + random() * 90
            WHEN 'corrective' THEN 600 + random() * 180
        END::NUMERIC,
        2
    ) AS cost
FROM maintenance_seed;

WITH generated_readings AS (
    SELECT
        s.sensor_id,
        s.machine_id,
        s.sensor_type,
        gs AS sequence_no,
        TIMESTAMPTZ '2026-04-01 00:00:00+05:30'
            + make_interval(hours => gs * 2, mins => (s.sensor_id % 25)::INT) AS reading_time,
        CASE
            WHEN s.sensor_type = 'temperature' AND s.machine_id % 3 = 1 AND gs IN (6, 12) THEN ROUND((196 + random() * 4)::NUMERIC, 3)
            WHEN s.sensor_type = 'pressure' AND s.machine_id % 4 = 0 AND gs = 9 THEN ROUND((145 + random() * 5)::NUMERIC, 3)
            WHEN s.sensor_type = 'vibration' AND s.machine_id % 5 IN (0, 1) AND gs = 10 THEN ROUND((4.30 + random() * 0.90)::NUMERIC, 3)
            WHEN s.sensor_type = 'temperature' THEN ROUND((172 + random() * 16)::NUMERIC, 3)
            WHEN s.sensor_type = 'pressure' THEN ROUND((80 + random() * 40)::NUMERIC, 3)
            ELSE ROUND((0.40 + random() * 2.20)::NUMERIC, 3)
        END AS reading_value
    FROM sensor s
    CROSS JOIN generate_series(1, 12) AS gs
)
INSERT INTO sensor_reading (sensor_id, "timestamp", value, status, sequence_no, checksum)
SELECT
    sensor_id,
    reading_time,
    reading_value,
    CASE
        WHEN sensor_type = 'temperature' AND reading_value > 195 THEN 'CRITICAL'
        WHEN sensor_type = 'pressure' AND reading_value > 140 THEN 'CRITICAL'
        WHEN sensor_type = 'vibration' AND reading_value > 4.0 THEN 'CRITICAL'
        WHEN sensor_type = 'vibration' AND reading_value > 2.8 THEN 'WARNING'
        ELSE 'OK'
    END AS status,
    sequence_no,
    md5(CONCAT_WS('|', sensor_id, reading_time, reading_value, sequence_no))
FROM generated_readings;

-- Selection and projection
SELECT machine_id, name, location, model
FROM machine
WHERE model = 'RPC-4P-220'
ORDER BY machine_id;

-- INNER JOIN across 3 tables
SELECT
    m.name AS machine_name,
    s.sensor_type,
    sr."timestamp",
    sr.value,
    sr.status
FROM machine m
INNER JOIN sensor s
    ON s.machine_id = m.machine_id
INNER JOIN sensor_reading sr
    ON sr.sensor_id = s.sensor_id
WHERE m.machine_id = 1
ORDER BY sr."timestamp" DESC
LIMIT 15;

-- LEFT JOIN across 3 tables
SELECT
    m.machine_id,
    m.name AS machine_name,
    mr.maintenance_id,
    mr."date",
    mr.type,
    t.name AS technician_name
FROM machine m
LEFT JOIN maintenance_record mr
    ON mr.machine_id = m.machine_id
LEFT JOIN technician t
    ON t.technician_id = mr.technician_id
ORDER BY m.machine_id, mr."date" DESC NULLS LAST;

-- Aggregation with GROUP BY and HAVING
SELECT
    m.machine_id,
    m.name AS machine_name,
    ROUND(AVG(pb.quality_score), 2) AS avg_quality_score,
    SUM(pb.defect_count) AS total_defects
FROM machine m
JOIN production_batch pb
    ON pb.machine_id = m.machine_id
GROUP BY m.machine_id, m.name
HAVING AVG(pb.quality_score) < 94 OR SUM(pb.defect_count) > 12
ORDER BY avg_quality_score ASC, total_defects DESC;

-- Nested subquery
SELECT
    s.sensor_id,
    s.machine_id,
    s.sensor_tag
FROM sensor s
WHERE s.sensor_type = 'vibration'
  AND s.sensor_id IN (
      SELECT sr.sensor_id
      FROM sensor_reading sr
      GROUP BY sr.sensor_id
      HAVING AVG(sr.value) > (
          SELECT AVG(sr2.value)
          FROM sensor_reading sr2
          JOIN sensor s2
              ON s2.sensor_id = sr2.sensor_id
          WHERE s2.sensor_type = 'vibration'
      )
  )
ORDER BY s.sensor_id;

-- Correlated subquery
SELECT
    s.sensor_id,
    s.sensor_tag,
    sr."timestamp",
    sr.value
FROM sensor s
JOIN sensor_reading sr
    ON sr.sensor_id = s.sensor_id
WHERE sr."timestamp" = (
    SELECT MAX(sr2."timestamp")
    FROM sensor_reading sr2
    WHERE sr2.sensor_id = s.sensor_id
)
ORDER BY s.sensor_id;

-- View usage
SELECT *
FROM live_sensor_status
ORDER BY machine_id, sensor_type;

SELECT *
FROM machine_health_summary
ORDER BY unresolved_alerts DESC, avg_quality_score ASC;

-- Stored procedure usage
BEGIN;
CALL get_maintenance_due_machines(90, 'due_cursor');
FETCH ALL FROM due_cursor;
COMMIT;

-- Record counts to verify seeded volume
SELECT 'machine' AS table_name, COUNT(*) AS row_count FROM machine
UNION ALL
SELECT 'technician', COUNT(*) FROM technician
UNION ALL
SELECT 'sensor', COUNT(*) FROM sensor
UNION ALL
SELECT 'sensor_reading', COUNT(*) FROM sensor_reading
UNION ALL
SELECT 'maintenance_record', COUNT(*) FROM maintenance_record
UNION ALL
SELECT 'production_batch', COUNT(*) FROM production_batch
UNION ALL
SELECT 'alert', COUNT(*) FROM alert;
