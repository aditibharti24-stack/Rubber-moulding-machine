from __future__ import annotations

import os


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "synapse-2026-dev")
    JSON_SORT_KEYS = False

    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres@127.0.0.1:5432/synapse2026")
    TARGET_MACHINE_ID = int(os.getenv("TARGET_MACHINE_ID", "7"))

    MQTT_ENABLED = os.getenv("MQTT_ENABLED", "true").lower() == "true"
    MQTT_SIMULATOR_ENABLED = os.getenv("MQTT_SIMULATOR_ENABLED", "true").lower() == "true"
    MQTT_BROKER_HOST = os.getenv("MQTT_BROKER_HOST", "127.0.0.1")
    MQTT_BROKER_PORT = int(os.getenv("MQTT_BROKER_PORT", "1883"))
    MQTT_TOPIC_ROOT = os.getenv("MQTT_TOPIC_ROOT", "factory/rubber_press")

    SOCKETIO_ASYNC_MODE = "threading"
