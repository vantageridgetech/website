from flask import Blueprint, current_app, jsonify, render_template, request

from app.ai_assistant import get_chat_response
from app.contact_notifier import send_contact_message
from app.extensions import limiter

main_bp = Blueprint("main", __name__)

MAX_CHAT_HISTORY_MESSAGES = 12  # caps request size/cost; older turns just fall off client-side
MAX_MESSAGE_LENGTH = 2000


@main_bp.route("/")
def index():
    return render_template("index.html")


@main_bp.route("/services")
def services():
    return render_template("services.html")


@main_bp.route("/case-studies")
def case_studies():
    return render_template("case-studies.html")


@main_bp.route("/contact")
def contact():
    return render_template("contact.html")


@main_bp.route("/health")
def health():
    return jsonify(status="ok"), 200


@main_bp.route("/api/chat", methods=["POST"])
@limiter.limit("20 per hour")
def api_chat():
    data = request.get_json(silent=True) or {}
    messages = data.get("messages")

    if not isinstance(messages, list) or not messages:
        return jsonify(error="messages required"), 400
    if len(messages) > MAX_CHAT_HISTORY_MESSAGES:
        messages = messages[-MAX_CHAT_HISTORY_MESSAGES:]

    cleaned = []
    for m in messages:
        role = m.get("role") if isinstance(m, dict) else None
        content = m.get("content") if isinstance(m, dict) else None
        if role not in ("user", "assistant") or not isinstance(content, str) or not content.strip():
            return jsonify(error="invalid message format"), 400
        cleaned.append({"role": role, "content": content[:MAX_MESSAGE_LENGTH]})

    if not current_app.config.get("ANTHROPIC_API_KEY"):
        current_app.logger.warning("Chat requested but ANTHROPIC_API_KEY is not configured")
        return jsonify(error="chat is not configured yet"), 503

    try:
        reply = get_chat_response(cleaned)
    except Exception as exc:  # noqa: BLE001
        current_app.logger.error("Chat request failed: %s", exc, exc_info=exc)
        return jsonify(error="could not get a response, please try again"), 502

    return jsonify(reply=reply), 200


@main_bp.route("/api/contact", methods=["POST"])
@limiter.limit("10 per hour")
def api_contact():
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    email = (data.get("email") or "").strip()
    message = (data.get("message") or "").strip()

    if not name or not email or not message:
        return jsonify(error="name, email, and message are required"), 400
    if "@" not in email or len(email) > 255:
        return jsonify(error="please enter a valid email"), 400
    if len(message) > 5000:
        return jsonify(error="message is too long"), 400

    try:
        send_contact_message(name, email, message)
    except Exception as exc:  # noqa: BLE001
        current_app.logger.error("Contact email failed to send: %s", exc, exc_info=exc)
        return jsonify(error="could not send your message, please email hello@vantageridgetech.com directly"), 502

    return jsonify(status="sent"), 200
