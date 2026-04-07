from __future__ import annotations

import hashlib

from .database import db_connection


def infer_status(sensor_type: str, value: float) -> str:
    if sensor_type == "temperature":
        if value > 195 or value < 150:
            return "CRITICAL"
    elif sensor_type == "pressure":
        if value > 140 or value < 55:
            return "CRITICAL"
    elif sensor_type == "vibration":
        if value > 4.0:
            return "CRITICAL"
        if value > 2.8:
            return "WARNING"
    return "OK"


def get_sensor_id(app, machine_id: int, sensor_type: str) -> int | None:
    with db_connection(app) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT sensor_id
                FROM sensor
                WHERE machine_id = %s
                  AND sensor_type = %s
                ORDER BY sensor_id
                LIMIT 1
                """,
                (machine_id, sensor_type),
            )
            row = cursor.fetchone()
            return int(row["sensor_id"]) if row else None


def ingest_sensor_reading(
    app,
    *,
    machine_id: int,
    sensor_type: str,
    timestamp: str,
    value: float,
    sequence_no: int,
    status: str | None = None,
) -> bool:
    sensor_id = get_sensor_id(app, machine_id, sensor_type)
    if sensor_id is None:
        return False

    reading_status = status or infer_status(sensor_type, value)
    checksum = hashlib.md5(f"{sensor_id}|{timestamp}|{value}|{sequence_no}".encode("utf-8")).hexdigest()

    with db_connection(app) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO sensor_reading (sensor_id, "timestamp", value, status, sequence_no, checksum)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (sensor_id, sequence_no) DO NOTHING
                """,
                (sensor_id, timestamp, value, reading_status, sequence_no, checksum),
            )
    return True
