# Vantage Ridge Technologies — Company Website

Flask app (converted from a static site once the site needed a real AI chat assistant and
a working contact form — both need a backend, so plain static HTML/S3 no longer fit).

## Local setup

```
python -m venv .venv
.venv/Scripts/activate        # Windows
pip install -r requirements.txt -r requirements-dev.txt
cp .env.example .env          # fill in SECRET_KEY at minimum
flask run
```

## What needs real credentials to fully work

- **AI chat assistant** (`/api/chat`): needs `ANTHROPIC_API_KEY` in `.env`. Without it, the
  endpoint returns a clean 503 rather than crashing — get a key at console.anthropic.com.
- **Contact form** (`/api/contact`): needs `MAIL_*` SMTP settings (Zoho credentials for
  `hello@vantageridgetech.com`) in `.env`. Without them, returns a clean 502.

## Testing

```
pytest -q
```

The Anthropic API and SMTP are both mocked in tests — no real network calls, no API key
needed to run the suite.

## Deferred

AWS/cloud deployment (ECS Fargate, matching devsecops-bootcamp and foodstore's pattern) —
not done yet, this repo is local-only so far.
