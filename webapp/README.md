# Synapse 2026 Local Web App

This folder contains a zero-dependency local dashboard for the IoT-enabled 4-pillar compression rubber molding machine project.

## What it includes

- Industrial-style monitoring dashboard
- Simulated live telemetry for temperature, pressure, and vibration
- MQTT reliability indicators such as broker status, buffered frames, and acknowledgments
- Production batch quality table
- Alert feed
- Maintenance outlook and analytics summary cards

## How to run right now

Because this environment does not currently have Node.js or a working Python runtime, this version is intentionally browser-openable.

1. Open `C:\rubber\webapp\index.html` in any modern browser.
2. The dashboard will start simulating live updates automatically.

## Recommended next step

When you are ready, we can upgrade this static demonstrator into a full local application with:

- Backend API for machine, sensor, batch, and alert data
- PostgreSQL or SQLite persistence
- MQTT broker integration
- User authentication and role-based access
- Real-time websocket updates

At that point we can choose one of these stacks:

- Python Flask + SQLite/PostgreSQL
- Python FastAPI + PostgreSQL
- React frontend + API backend once Node.js is available
