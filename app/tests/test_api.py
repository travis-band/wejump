"""Tests that run automatically before every deploy. If even one fails, GitHub Actions stops the deploy.

Run (start the database first with docker compose up -d db):
    pytest -v
"""

import json
import os
from base64 import b64encode

# If these aren't set, use the local database from docker-compose.yml and a test-only cookie key
os.environ.setdefault("DATABASE_URL", "postgresql://wejump:localdev@localhost:5432/wejump")
os.environ.setdefault("SESSION_SECRET", "test-only-secret")

import itsdangerous  # noqa: E402
import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app import db  # noqa: E402
from app.main import app  # noqa: E402

# A made-up GitHub user. Real GitHub IDs are much smaller, so this never collides with a real person.
TEST_USER_ID = 9_999_000_001


def signed_cookie(session, secret):
    """Build a login cookie the same way the server does (Starlette's SessionMiddleware).
    This is how the tests "sign in" without going to GitHub. It's also exactly what
    another server holding the same SESSION_SECRET (the other color) would produce."""
    data = b64encode(json.dumps(session).encode("utf-8"))
    return itsdangerous.TimestampSigner(secret).sign(data).decode("utf-8")


def set_session(client, value):
    # "testserver.local" is the domain the test client files the server's own cookies under,
    # so the server's "delete this cookie" on logout replaces this one instead of sitting next to it.
    client.cookies.set("session", value, domain="testserver.local")


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


@pytest.fixture
def signed_in(client):
    """A client signed in as the test user. Everything the user wrote is deleted afterwards."""
    db.upsert_user(TEST_USER_ID, "test-bot", "Test Bot", "https://example.com/a.png", "https://github.com/test-bot")
    set_session(client, signed_cookie({"uid": TEST_USER_ID}, os.environ["SESSION_SECRET"]))
    try:
        yield client
    finally:
        db.delete_user(TEST_USER_ID)


def test_healthz(client):
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["ok"] is True


def test_anyone_can_read(client):
    assert client.get("/api/messages").status_code == 200


def test_posting_needs_sign_in(client):
    r = client.post("/api/messages", json={"body": "hello"})
    assert r.status_code == 401


def test_me_is_null_when_signed_out(client):
    r = client.get("/api/me")
    assert r.status_code == 200
    assert r.json() is None


def test_write_then_read(signed_in):
    r = signed_in.post("/api/messages", json={"body": "hello"})
    assert r.status_code == 201
    new = r.json()
    # The author comes from the login, not from anything the browser typed in
    assert new["user_id"] == TEST_USER_ID
    assert new["login"] == "test-bot"
    assert new["name"] == "test-bot"

    listed = {m["id"]: m for m in signed_in.get("/api/messages").json()}
    assert listed[new["id"]]["avatar_url"] == "https://example.com/a.png"


def test_user_page_data(signed_in):
    signed_in.post("/api/messages", json={"body": "first"})
    signed_in.post("/api/messages", json={"body": "second"})

    me = signed_in.get("/api/me").json()
    assert me["login"] == "test-bot"
    assert me["name"] == "Test Bot"
    assert me["message_count"] == 2

    mine = signed_in.get("/api/me/messages").json()
    assert [m["body"] for m in mine] == ["second", "first"]


def test_logout(signed_in):
    assert signed_in.get("/api/me").json() is not None
    r = signed_in.post("/auth/logout")
    assert r.status_code == 204
    assert signed_in.get("/api/me").json() is None


def test_rejects_blank_message(signed_in):
    r = signed_in.post("/api/messages", json={"body": "   "})
    assert r.status_code == 422


def test_cookie_from_the_other_color_is_trusted(client):
    """Blue/green: a cookie signed by blue must work on green, because both share SESSION_SECRET.
    A cookie signed with a different secret (a forged one, or one from before the secret changed) must not."""
    db.upsert_user(TEST_USER_ID, "test-bot", None, None, None)
    try:
        set_session(client, signed_cookie({"uid": TEST_USER_ID}, os.environ["SESSION_SECRET"]))
        assert client.get("/api/me").json()["login"] == "test-bot"

        set_session(client, signed_cookie({"uid": TEST_USER_ID}, "some-other-secret"))
        assert client.get("/api/me").json() is None
    finally:
        db.delete_user(TEST_USER_ID)


def test_old_app_version_can_still_insert(client):
    """Rollback safety: an older version of the app doesn't know about user_id and inserts without it.
    That must still work (the message becomes a guest message) instead of failing."""
    with db.connect() as conn:
        row = conn.execute(
            "INSERT INTO messages (name, body) VALUES ('old-app', 'from an old version') RETURNING id, user_id"
        ).fetchone()
    try:
        assert row["user_id"] == db.GUEST_ID
    finally:
        db.delete_message(row["id"])


def test_login_not_configured(client, monkeypatch):
    monkeypatch.setattr("app.main.GITHUB_CLIENT_ID", "")
    r = client.get("/auth/login", follow_redirects=False)
    assert r.status_code == 503
