# Synapse 2026 Local Flask Stack

This folder now contains a working local Flask stack for the Synapse 2026 IIoT dashboard.

## Structure

- `app/__init__.py`: Flask app factory
- `app/config.py`: environment-driven Flask, PostgreSQL, and MQTT settings
- `app/extensions.py`: Socket.IO extension
- `app/routes.py`: dashboard and JSON API routes
- `app/services/dashboard_data.py`: PostgreSQL-backed dashboard payload builder with mock fallback
- `app/services/database.py`: psycopg connection helpers
- `app/services/ingestion.py`: sensor-reading ingestion into PostgreSQL
- `app/services/runtime.py`: MQTT subscriber and simulator startup
- `app/templates/dashboard.html`: dashboard template
- `app/static/css/styles.css`: dashboard styling
- `app/static/js/app.js`: frontend dashboard behavior
- `.env`: local runtime configuration
- `run.py`: local development entrypoint

## Endpoints

- `/`: dashboard UI
- `/health`: simple service health response
- `/api/dashboard`: complete dashboard payload
- `/api/telemetry?limit=48`: telemetry window
- `/api/alerts`: alerts payload
- `/api/batches`: batch payload
- `/api/maintenance`: maintenance payload

## Local runtime

- Python 3.12 is installed locally.
- PostgreSQL 17 is installed and running on `127.0.0.1:5432`.
- Mosquitto is installed and running as a Windows service on `127.0.0.1:1883`.
- The application database `synapse2026` is loaded from `C:\rubber\deliverables\synapse2026_postgres.sql`.

## How to run

1. Use the project virtual environment at `C:\rubber\synapse_flask\.venv`.
2. Start the app with `C:\rubber\synapse_flask\.venv\Scripts\python.exe run.py`.
3. Open `http://127.0.0.1:5000`.
4. The dashboard will use PostgreSQL-backed data and receive live refreshes from MQTT ingestion.

## VS Code quick start

1. Open `C:\rubber\synapse_flask` in VS Code.
2. Install the recommended extensions when prompted.
3. Press `F5` and choose `Synapse Flask: Launch App`.
4. Open `http://127.0.0.1:5000`.

The workspace now includes:

- `.vscode/settings.json`: points VS Code to the local `.venv` interpreter and enables Jinja HTML support
- `.vscode/launch.json`: one-click debug launch for the Flask app
- `.vscode/tasks.json`: install-requirements and run-app tasks
- `.vscode/extensions.json`: recommended Python and Jinja extensions

Available VS Code run modes:

- `Synapse Flask: Launch App`: development mode with debug enabled
- `Synapse Flask: Production-like`: local run with debug disabled and no reloader
- `Synapse: Run Flask App`: VS Code task for dev mode
- `Synapse: Run Production-like`: VS Code task for a cleaner local runtime

## Data flow

- MQTT simulator publishes local temperature, pressure, and vibration messages.
- The Flask MQTT subscriber ingests those messages into PostgreSQL.
- PostgreSQL stores readings and auto-generates alerts via the trigger from the project schema.
- Flask serves dashboard payloads from PostgreSQL.
- Socket.IO pushes refresh events to the browser when new MQTT readings arrive.

## Next backend steps

- Replace the remaining derived batch and maintenance approximations with full production logic
- Introduce authentication and operator roles
- Connect the R analysis outputs into dashboard insights
