"""배포 전에 자동으로 돌아가는 테스트. 하나라도 실패하면 GitHub Actions가 배포를 멈춥니다.

실행 (먼저 docker compose up -d db 로 DB를 켜 두세요):
    pytest -v
"""

import os

# DATABASE_URL이 없으면 docker-compose.yml의 로컬 DB를 쓴다
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
            db.delete_message(new_id)  # 테스트가 남긴 글은 치운다


def test_rejects_blank_message():
    with TestClient(app) as client:
        r = client.post("/api/messages", json={"name": "   ", "body": "이름이 공백"})
        assert r.status_code == 422
