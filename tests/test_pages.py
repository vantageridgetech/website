def test_index_loads(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert b"Vantage Ridge" in resp.data


def test_services_page_lists_all_eight(client):
    resp = client.get("/services")
    assert resp.status_code == 200
    for title in [
        "Cloud Infrastructure Setup",
        "Cloud Cost Optimization",
        "Cloud Security",
        "CI/CD",
        "Custom Web",
        "Secure Website Design",
        "Applied AI Automation",
        "Ongoing Cloud",
    ]:
        assert title.encode() in resp.data


def test_services_page_is_multi_cloud(client):
    resp = client.get("/services")
    assert b"Google Cloud" in resp.data
    assert b"Azure" in resp.data


def test_case_studies_page_loads(client):
    resp = client.get("/case-studies")
    assert resp.status_code == 200


def test_contact_page_has_form(client):
    resp = client.get("/contact")
    assert resp.status_code == 200
    assert b'id="contact-form"' in resp.data


def test_health_endpoint(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_chat_widget_present_on_every_page(client):
    for path in ["/", "/services", "/case-studies", "/contact"]:
        resp = client.get(path)
        assert b'id="chat-launcher"' in resp.data, f"chat widget missing on {path}"
