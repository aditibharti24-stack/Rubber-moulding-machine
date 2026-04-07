from flask import Flask
from dotenv import load_dotenv

from .config import Config
from .extensions import socketio


def create_app() -> Flask:
    load_dotenv()

    app = Flask(__name__, static_folder="static", template_folder="templates")
    app.config.from_object(Config)

    socketio.init_app(app)

    from .routes import main_bp

    app.register_blueprint(main_bp)

    from .services.runtime import start_runtime_services

    start_runtime_services(app)
    return app
