def test_contact_requires_all_fields(client):
    resp = client.post("/api/contact", json={"name": "Jane"})
    assert resp.status_code == 400


def test_contact_rejects_invalid_email(client):
    resp = client.post(
        "/api/contact",
        json={"name": "Jane", "email": "not-an-email", "message": "hi"},
    )
    assert resp.status_code == 400


def test_contact_sends_message(client, mocker):
    mock_send = mocker.patch("app.routes.send_contact_message")
    resp = client.post(
        "/api/contact",
        json={"name": "Jane Doe", "email": "jane@example.com", "message": "Need help with AWS."},
    )
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "sent"
    mock_send.assert_called_once_with("Jane Doe", "jane@example.com", "Need help with AWS.")


def test_contact_handles_send_failure_gracefully(client, mocker):
    mocker.patch("app.routes.send_contact_message", side_effect=Exception("smtp down"))
    resp = client.post(
        "/api/contact",
        json={"name": "Jane", "email": "jane@example.com", "message": "hi"},
    )
    assert resp.status_code == 502
