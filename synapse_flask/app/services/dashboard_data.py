from __future__ import annotations

from datetime import datetime, timedelta, timezone
from math import sin
from random import Random

from flask import current_app

from .database import database_available, db_connection


IST = timezone(timedelta(hours=5, minutes=30))


def clamp(value: float, minimum: float, maximum: float) -> float:
    return min(maximum, max(minimum, value))


def _derive_process_metrics(temperature: float, pressure: float, vibration: float) -> tuple[float, int, float]:
    defect_count = max(
        0,
        round(
            1.2
            + abs(temperature - 180) * 0.09
            + abs(pressure - 100) * 0.04
            + vibration * 0.95
        ),
    )

    quality_score = clamp(
        98.6
        - abs(temperature - 180) * 0.32
        - abs(pressure - 110) * 0.06
        - vibration * 1.35
        - defect_count * 0.65,
        82,
        99.4,
    )

    energy = clamp(
        52 + max(0, pressure - 80) * 0.06 + max(0, temperature - 170) * 0.025 + vibration * 0.8,
        47,
        62,
    )
    return round(quality_score, 2), defect_count, round(energy, 2)


def build_mock_dashboard_payload() -> dict:
    rand = Random(2026)
    base_time = datetime(2026, 4, 6, 9, 0, tzinfo=IST)
    phase_cycle = ["Pre-Heat", "Compression", "Cooling"]
    telemetry = []

    for index in range(96):
        timestamp = base_time - timedelta(minutes=(95 - index) * 30)
        phase = phase_cycle[(index // 4) % len(phase_cycle)]
        hour = timestamp.hour
        shift_bias = 1.1 if 14 <= hour < 22 else -0.6 if 6 <= hour < 14 else -0.2
        wave = sin(index / 5.2) * 2.6

        temperature = 180 + wave + shift_bias + ((rand.random() - 0.5) * 4.8)
        pressure = (123 if phase == "Compression" else 72 if phase == "Pre-Heat" else 84) + ((rand.random() - 0.5) * 12)
        vibration = 1.05 + (0.55 if phase == "Compression" else 0.12) + abs((rand.random() - 0.5) * 0.9)

        if index in {18, 19, 57}:
            temperature += 13 + rand.random() * 4
        if index in {41, 66}:
            pressure += 20 + rand.random() * 8
        if index in {72, 73, 74, 89}:
            vibration += 2.3 + rand.random() * 1.2

        temperature = clamp(temperature, 147, 202)
        pressure = clamp(pressure, 52, 152)
        vibration = clamp(vibration, 0.12, 5.2)
        quality_score, defect_count, energy = _derive_process_metrics(temperature, pressure, vibration)

        telemetry.append(
            {
                "timestamp": timestamp.isoformat(),
                "sequence": 10400 + index,
                "phase": phase,
                "temperature": round(temperature, 2),
                "pressure": round(pressure, 2),
                "vibration": round(vibration, 2),
                "qualityScore": quality_score,
                "defectCount": defect_count,
                "energy": energy,
            }
        )

    alerts = []
    for point in telemetry:
        if point["temperature"] <= 195 and point["pressure"] <= 140 and point["vibration"] <= 4.0:
            continue

        if point["temperature"] > 195:
            alert_type = "High Temperature"
            severity = "high"
            message = "Mold temperature exceeded the recommended control ceiling."
            value = f"{point['temperature']} degC"
        elif point["pressure"] > 140:
            alert_type = "High Pressure"
            severity = "high"
            message = "Compression pressure spiked above the safe process band."
            value = f"{point['pressure']} bar"
        else:
            alert_type = "Vibration Spike"
            severity = "critical"
            message = "Mechanical vibration suggests emerging wear or misalignment."
            value = f"{point['vibration']} mm/s"

        alerts.append(
            {
                "id": f"ALT-{len(alerts) + 1:03d}",
                "type": alert_type,
                "severity": severity,
                "timestamp": point["timestamp"],
                "message": message,
                "value": value,
            }
        )

    alerts = list(reversed(alerts[-8:]))

    batches = []
    for index in range(8):
        slice_end = 95 - index * 8
        slice_start = max(0, slice_end - 7)
        window = telemetry[slice_start : slice_end + 1]
        quantity = 438 + ((index * 13) % 34) + round(rand.random() * 12)
        defects = sum(item["defectCount"] for item in window)
        avg_quality = sum(item["qualityScore"] for item in window) / len(window)

        phase_counts: dict[str, int] = {}
        for item in window:
            phase_counts[item["phase"]] = phase_counts.get(item["phase"], 0) + 1
        phase_label = max(phase_counts, key=phase_counts.get)

        batches.append(
            {
                "batchId": f"BT-{208 + index:03d}",
                "start": window[0]["timestamp"],
                "end": window[-1]["timestamp"],
                "quantity": quantity,
                "defects": defects,
                "quality": round(avg_quality, 2),
                "phaseLabel": phase_label,
            }
        )

    batches.reverse()

    maintenance = [
        {
            "component": "Hydraulic Pack",
            "condition": 88,
            "note": "Pressure hold is stable. Next seal check due in 11 days.",
        },
        {
            "component": "Heater Platens",
            "condition": 91,
            "note": "Thermal drift remains low. PID tuning still within tolerance.",
        },
        {
            "component": "Guide Pillars",
            "condition": 84,
            "note": "Lubrication window approaching. Plan grease inspection this week.",
        },
        {
            "component": "Pump Bearings",
            "condition": 73,
            "note": "Vibration signature is rising slightly under compression load.",
        },
    ]

    return {
        "machine": {
            "id": "M-07",
            "name": "Rubber Press 07",
            "subtitle": "Plant A / Line 2 | Model RPC-4P-220",
            "plcIp": "192.168.10.21",
            "brokerPort": "8883 / TLS",
            "qos": "Telemetry QoS 1 | Alerts QoS 2",
        },
        "telemetry": telemetry,
        "alerts": alerts,
        "batches": batches,
        "maintenance": maintenance,
        "summary": {
            "generatedAt": datetime.now(tz=IST).isoformat(),
            "telemetryCount": len(telemetry),
            "alertCount": len(alerts),
            "batchCount": len(batches),
            "source": "mock",
        },
    }


def build_db_dashboard_payload() -> dict | None:
    app = current_app._get_current_object()
    machine_id = app.config["TARGET_MACHINE_ID"]

    if not database_available(app):
        return None

    try:
        with db_connection(app) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT machine_id, name, location, model
                    FROM machine
                    WHERE machine_id = %s
                    """,
                    (machine_id,),
                )
                machine = cursor.fetchone()

                if machine is None:
                    return None

                cursor.execute(
                    """
                    WITH grouped AS (
                        SELECT
                            sr."timestamp",
                            MAX(sr.sequence_no) AS sequence,
                            MAX(CASE WHEN s.sensor_type = 'temperature' THEN sr.value END) AS temperature,
                            MAX(CASE WHEN s.sensor_type = 'pressure' THEN sr.value END) AS pressure,
                            MAX(CASE WHEN s.sensor_type = 'vibration' THEN sr.value END) AS vibration
                        FROM sensor_reading sr
                        JOIN sensor s
                          ON s.sensor_id = sr.sensor_id
                        WHERE s.machine_id = %s
                        GROUP BY sr."timestamp"
                        ORDER BY sr."timestamp" DESC
                        LIMIT 96
                    )
                    SELECT *
                    FROM grouped
                    ORDER BY "timestamp" ASC
                    """,
                    (machine_id,),
                )
                rows = cursor.fetchall()

                if not rows:
                    return None

                telemetry = []
                phase_cycle = ["Pre-Heat", "Compression", "Cooling"]
                for index, row in enumerate(rows):
                    phase = phase_cycle[(index // 4) % len(phase_cycle)]
                    temperature = float(row["temperature"] or 180.0)
                    pressure = float(row["pressure"] or 100.0)
                    vibration = float(row["vibration"] or 1.1)
                    quality_score, defect_count, energy = _derive_process_metrics(temperature, pressure, vibration)

                    telemetry.append(
                        {
                            "timestamp": row["timestamp"].astimezone(IST).isoformat(),
                            "sequence": int(row["sequence"] or (10400 + index)),
                            "phase": phase,
                            "temperature": round(temperature, 2),
                            "pressure": round(pressure, 2),
                            "vibration": round(vibration, 2),
                            "qualityScore": quality_score,
                            "defectCount": defect_count,
                            "energy": energy,
                        }
                    )

                cursor.execute(
                    """
                    SELECT
                        a.alert_id,
                        a.triggered_at,
                        a.alert_type,
                        a.actual_value
                    FROM alert a
                    JOIN sensor s
                      ON s.sensor_id = a.sensor_id
                    WHERE s.machine_id = %s
                    ORDER BY a.triggered_at DESC
                    LIMIT 8
                    """,
                    (machine_id,),
                )
                alert_rows = cursor.fetchall()

                alerts = []
                for row in alert_rows:
                    alert_type = row["alert_type"].replace("_", " ").title()
                    severity = "critical" if "Vibration" in alert_type else "high"
                    unit = "degC" if "Temperature" in alert_type else "bar" if "Pressure" in alert_type else "mm/s"
                    alerts.append(
                        {
                            "id": f"ALT-{int(row['alert_id']):03d}",
                            "type": alert_type,
                            "severity": severity,
                            "timestamp": row["triggered_at"].astimezone(IST).isoformat(),
                            "message": f"{alert_type} detected from live telemetry.",
                            "value": f"{float(row['actual_value']):.2f} {unit}",
                        }
                    )

                cursor.execute(
                    """
                    SELECT
                        batch_id,
                        start_time,
                        end_time,
                        quantity_produced,
                        defect_count,
                        quality_score
                    FROM production_batch
                    WHERE machine_id = %s
                    ORDER BY end_time DESC
                    LIMIT 8
                    """,
                    (machine_id,),
                )
                batch_rows = cursor.fetchall()

                batches = [
                    {
                        "batchId": f"BT-{int(row['batch_id']):03d}",
                        "start": row["start_time"].astimezone(IST).isoformat(),
                        "end": row["end_time"].astimezone(IST).isoformat(),
                        "quantity": int(row["quantity_produced"]),
                        "defects": int(row["defect_count"]),
                        "quality": round(float(row["quality_score"]), 2),
                        "phaseLabel": "Compression",
                    }
                    for row in reversed(batch_rows)
                ]

                cursor.execute(
                    """
                    SELECT
                        MAX(mr."date") AS last_maintenance_date
                    FROM maintenance_record mr
                    WHERE mr.machine_id = %s
                    """,
                    (machine_id,),
                )
                maintenance_summary = cursor.fetchone()

                latest = telemetry[-1]
                last_date = maintenance_summary["last_maintenance_date"]
                days_since_service = (
                    (datetime.now(tz=IST).date() - last_date).days if last_date else 45
                )

                maintenance = [
                    {
                        "component": "Hydraulic Pack",
                        "condition": max(55, min(96, round(92 - max(0, latest["pressure"] - 135) * 0.6))),
                        "note": "Pressure stability is derived from recent compression readings.",
                    },
                    {
                        "component": "Heater Platens",
                        "condition": max(55, min(97, round(95 - abs(latest["temperature"] - 180) * 1.1))),
                        "note": "Thermal balance is derived from live temperature drift versus target.",
                    },
                    {
                        "component": "Guide Pillars",
                        "condition": max(52, min(94, round(90 - days_since_service * 0.35))),
                        "note": f"Days since last maintenance record: {days_since_service}.",
                    },
                    {
                        "component": "Pump Bearings",
                        "condition": max(48, min(95, round(93 - max(0, latest['vibration'] - 1.2) * 14))),
                        "note": "Condition follows the latest vibration signature and alert history.",
                    },
                ]

                return {
                    "machine": {
                        "id": f"M-{int(machine['machine_id']):02d}",
                        "name": machine["name"],
                        "subtitle": f"{machine['location']} | Model {machine['model']}",
                        "plcIp": "192.168.10.21",
                        "brokerPort": "1883 / MQTT",
                        "qos": "Telemetry QoS 1 | Alerts QoS 2",
                    },
                    "telemetry": telemetry,
                    "alerts": alerts,
                    "batches": batches,
                    "maintenance": maintenance,
                    "summary": {
                        "generatedAt": datetime.now(tz=IST).isoformat(),
                        "telemetryCount": len(telemetry),
                        "alertCount": len(alerts),
                        "batchCount": len(batches),
                        "source": "postgres",
                    },
                }
    except Exception:
        return None


def build_dashboard_payload() -> dict:
    return build_db_dashboard_payload() or build_mock_dashboard_payload()
