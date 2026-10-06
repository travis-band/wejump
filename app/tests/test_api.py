"""Tests that run automatically before every deploy. If even one fails, GitHub Actions stops the deploy.

Run (start the database first with docker compose up -d db):
    pytest -v
"""

import os

# If DATABASE_URL isn't set, use the local database from docker-compose.yml
os.environ.setdefault("DATABASE_URL", "postgresql://wejump:localdev@localhost:5432/wejump")

from fastapi.testclient import TestClient  # noqa: E402

from app import db  # noqa: E402
from app.main import app  # noqa: E402


def test_healthz():
    with TestClient(app) as client:
        r = client.get("/healthz")
        assert r.status_code == 200
        assert r.json()["ok"] is True


def test_write_then_read():
    with TestClient(app) as client:
        r = client.post("/api/messages", json={"name": "테스트봇", "body": "안녕하세요"})
        assert r.status_code == 201
        new_id = r.json()["id"]
        try:
            ids = [m["id"] for m in client.get("/api/messages").json()]
            assert new_id in ids
        finally:
            db.delete_message(new_id)  # Clean up the message the test left behind


def test_rejects_blank_message():
    with TestClient(app) as client:
        r = client.post("/api/messages", json={"name": "   ", "body": "이름이 공백"})
        assert r.status_code == 422
