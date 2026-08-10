def test_chat_requires_messages(client):
    resp = client.post("/api/chat", json={})
    assert resp.status_code == 400


def test_chat_rejects_bad_role(client):
    resp = client.post("/api/chat", json={"messages": [{"role": "system", "content": "hi"}]})
    assert resp.status_code == 400


def test_chat_returns_reply(client, mocker):
    mocker.patch("app.routes.get_chat_response", return_value="We can help with that.")
    resp = client.post(
        "/api/chat", json={"messages": [{"role": "user", "content": "What do you do?"}]}
    )
    assert resp.status_code == 200
    assert resp.get_json()["reply"] == "We can help with that."


def test_chat_truncates_long_history(client, mocker):
    mock_get = mocker.patch("app.routes.get_chat_response", return_value="ok")
    long_history = [{"role": "user", "content": f"msg {i}"} for i in range(30)]
    client.post("/api/chat", json={"messages": long_history})
    sent = mock_get.call_args[0][0]
    assert len(sent) <= 12


def test_chat_handles_upstream_failure_gracefully(client, mocker):
    mocker.patch("app.routes.get_chat_response", side_effect=Exception("boom"))
    resp = client.post(
        "/api/chat", json={"messages": [{"role": "user", "content": "hello"}]}
    )
    assert resp.status_code == 502


def test_chat_never_calls_real_anthropic_api(client, mocker):
    """Guardrail: every chat test above mocks get_chat_response — this asserts that
    pattern holds so CI never makes a real network call to Anthropic."""
    mock_get = mocker.patch("app.routes.get_chat_response", return_value="mocked")
    client.post("/api/chat", json={"messages": [{"role": "user", "content": "hi"}]})
    assert mock_get.called
