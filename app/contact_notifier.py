from flask import current_app
from flask_mail import Message

from app.extensions import mail


def send_contact_message(name, email, message):
    recipient = current_app.config["CONTACT_RECIPIENT_EMAIL"]
    body = f"New contact form submission\n\nFrom: {name} <{email}>\n\n{message}\n"
    msg = Message(
        subject=f"New contact form message from {name}",
        recipients=[recipient],
        reply_to=email,
        body=body,
    )
    mail.send(msg)
