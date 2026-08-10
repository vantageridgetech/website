import os


class BaseConfig:
    SERVICE_NAME = os.getenv("SERVICE_NAME", "vantageridgetech-website")
    APP_ENV = os.getenv("APP_ENV", "local")
    SECRET_KEY = os.getenv("SECRET_KEY", "local-dev-only-not-a-real-secret")

    MAIL_SERVER = os.getenv("MAIL_SERVER")
    MAIL_PORT = int(os.getenv("MAIL_PORT", "587"))
    MAIL_USE_TLS = os.getenv("MAIL_USE_TLS", "true").lower() == "true"
    MAIL_USERNAME = os.getenv("MAIL_USERNAME")
    MAIL_PASSWORD = os.getenv("MAIL_PASSWORD")
    MAIL_DEFAULT_SENDER = os.getenv("MAIL_DEFAULT_SENDER", MAIL_USERNAME)
    CONTACT_RECIPIENT_EMAIL = os.getenv("CONTACT_RECIPIENT_EMAIL", "hello@vantageridgetech.com")

    ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
    CHAT_MODEL = os.getenv("CHAT_MODEL", "claude-sonnet-5")
    CHAT_MAX_TOKENS = int(os.getenv("CHAT_MAX_TOKENS", "500"))

    RATELIMIT_STORAGE_URI = os.getenv("RATELIMIT_STORAGE_URI", "memory://")


class DevConfig(BaseConfig):
    DEBUG = True


class ProdConfig(BaseConfig):
    DEBUG = False


class TestConfig(BaseConfig):
    TESTING = True
    DEBUG = True
    WTF_CSRF_ENABLED = False
    SECRET_KEY = "test-secret-key"
    ANTHROPIC_API_KEY = "test-key"


CONFIG_BY_NAME = {
    "development": DevConfig,
    "production": ProdConfig,
    "testing": TestConfig,
}
