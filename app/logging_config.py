import json
import logging
import sys


class JsonLogFormatter(logging.Formatter):
    def __init__(self, service_name, environment):
        super().__init__()
        self.service_name = service_name
        self.environment = environment

    def format(self, record):
        payload = {
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "service": self.service_name,
            "environment": self.environment,
        }
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload)


def configure_logging(app):
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonLogFormatter(app.config["SERVICE_NAME"], app.config["APP_ENV"]))
    app.logger.handlers = [handler]
    app.logger.setLevel("DEBUG" if app.config.get("DEBUG") else "INFO")
