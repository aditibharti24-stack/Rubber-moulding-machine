from __future__ import annotations

import json
import os
import threading
import time

import paho.mqtt.client as mqtt

from ..extensions import socketio
from .dashboard_data import build_mock_dashboard_payload
from .database import database_available
from .ingestion import ingest_sensor_reading


_runtime_lock = threading.Lock()
_runtime_started = False
_mqtt_clients: list[mqtt.Client] = []


def _topic_for(app, machine_id: int, sensor_type: str) -> str:
    return f"{app.config['MQTT_TOPIC_ROOT']}/{machine_id}/{sensor_type}"


def _handle_mqtt_message(app, topic: str, payload: str) -> None:
    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        return

    topic_parts = topic.split("/")
    if len(topic_parts) < 4:
        return

    try:
        machine_id = int(data.get("machine_id") or topic_parts[-2])
    except ValueError:
        return

    sensor_type = data.get("sensor_type") or topic_parts[-1]
    value = data.get("value")
    timestamp = data.get("timestamp")
    sequence_no = data.get("sequence_no")
    status = data.get("status")

    if value is None or timestamp is None or sequence_no is None:
        return

    with app.app_context():
        if not database_available(app):
            return
        inserted = ingest_sensor_reading(
            app,
            machine_id=machine_id,
            sensor_type=sensor_type,
            timestamp=timestamp,
            value=float(value),
            sequence_no=int(sequence_no),
            status=status,
        )
        if inserted:
            socketio.emit("dashboard_refresh", {"source": "mqtt", "machine_id": machine_id})


def _start_subscriber(app) -> None:
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="synapse-dashboard-subscriber")

    def on_connect(client, userdata, flags, reason_code, properties):  # noqa: ANN001
        client.subscribe(f"{app.config['MQTT_TOPIC_ROOT']}/+/+")

    def on_message(client, userdata, message):  # noqa: ANN001
        _handle_mqtt_message(app, message.topic, message.payload.decode("utf-8"))

    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(app.config["MQTT_BROKER_HOST"], app.config["MQTT_BROKER_PORT"], 60)
    client.loop_start()
    _mqtt_clients.append(client)


def _simulator_loop(app) -> None:
    payload = build_mock_dashboard_payload()
    telemetry = payload["telemetry"]
    machine_id = app.config["TARGET_MACHINE_ID"]
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="synapse-dashboard-publisher")
    client.connect(app.config["MQTT_BROKER_HOST"], app.config["MQTT_BROKER_PORT"], 60)
    client.loop_start()
    _mqtt_clients.append(client)

    index = 0
    while True:
        point = telemetry[index]
        for sensor_type in ("temperature", "pressure", "vibration"):
            client.publish(
                _topic_for(app, machine_id, sensor_type),
                json.dumps(
                    {
                        "machine_id": machine_id,
                        "sensor_type": sensor_type,
                        "timestamp": point["timestamp"],
                        "sequence_no": point["sequence"],
                        "value": point[sensor_type],
                    }
                ),
                qos=1,
            )
        index = (index + 1) % len(telemetry)
        time.sleep(2.5)


def start_runtime_services(app) -> None:
    global _runtime_started

    with _runtime_lock:
        if _runtime_started:
            return

        if app.debug and os.environ.get("WERKZEUG_RUN_MAIN") != "true":
            return

        if app.config["MQTT_ENABLED"]:
            try:
                _start_subscriber(app)
                if app.config["MQTT_SIMULATOR_ENABLED"] and database_available(app):
                    socketio.start_background_task(_simulator_loop, app)
            except Exception:
                pass

        _runtime_started = True
