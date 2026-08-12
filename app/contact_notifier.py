import requests
from flask import current_app


def send_contact_message(name, email, message):
    api_key = current_app.config["ZEPTOMAIL_API_KEY"]
    if not api_key:
        raise RuntimeError("ZEPTOMAIL_API_KEY is not configured")

    # Zoho provisions accounts into regional data centers (Canada here — same as Zoho
    # Mail); the API host must match, or every request gets rejected as an invalid
    # token even though the key itself is correct.
    endpoint = current_app.config["ZEPTOMAIL_API_URL"]

    payload = {
        "from": {
            "address": current_app.config["ZEPTOMAIL_SENDER_EMAIL"],
            "name": current_app.config["ZEPTOMAIL_SENDER_NAME"],
        },
        "to": [
            {
                "email_address": {
                    "address": current_app.config["CONTACT_RECIPIENT_EMAIL"],
                    "name": "Vantage Ridge Technologies",
                }
            }
        ],
        "reply_to": [{"address": email, "name": name}],
        "subject": f"New contact form message from {name}",
        "textbody": f"From: {name} <{email}>\n\n{message}",
    }
    headers = {
        "Authorization": f"Zoho-enczapikey {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    resp = requests.post(endpoint, json=payload, headers=headers, timeout=10)
    if resp.status_code >= 300:
        current_app.logger.error(
            "ZeptoMail send failed: %s %s", resp.status_code, resp.text
        )
        resp.raise_for_status()
