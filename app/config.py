import os


class BaseConfig:
    SERVICE_NAME = os.getenv("SERVICE_NAME", "vantageridgetech-website")
    APP_ENV = os.getenv("APP_ENV", "local")
    SECRET_KEY = os.getenv("SECRET_KEY", "local-dev-only-not-a-real-secret")

    # ZeptoMail (Zoho's transactional email API) — used instead of Mail Lite's mailbox
    # SMTP, which turned out to need account-level access this app shouldn't hold anyway.
    ZEPTOMAIL_API_KEY = os.getenv("ZEPTOMAIL_API_KEY")
    ZEPTOMAIL_API_URL = os.getenv("ZEPTOMAIL_API_URL", "https://api.zeptomail.ca/v1.1/email")
    ZEPTOMAIL_SENDER_EMAIL = os.getenv("ZEPTOMAIL_SENDER_EMAIL", "hello@vantageridgetech.com")
    ZEPTOMAIL_SENDER_NAME = os.getenv("ZEPTOMAIL_SENDER_NAME", "Vantage Ridge Technologies")
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
    ZEPTOMAIL_API_KEY = "test-key"


CONFIG_BY_NAME = {
    "development": DevConfig,
    "production": ProdConfig,
    "testing": TestConfig,
}
