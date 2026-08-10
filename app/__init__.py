import os

from flask import Flask

from app.config import CONFIG_BY_NAME
from app.extensions import csrf, limiter, mail
from app.logging_config import configure_logging
from app.security_headers import register_security_headers


def create_app(config_name=None):
    config_name = config_name or os.getenv("FLASK_ENV", "development")
    app = Flask(__name__)
    app.config.from_object(CONFIG_BY_NAME[config_name])

    mail.init_app(app)
    csrf.init_app(app)
    limiter.init_app(app)

    configure_logging(app)
    register_security_headers(app)

    from app.routes import main_bp

    app.register_blueprint(main_bp)

    return app
