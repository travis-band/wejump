"""Postgres와 이야기하는 코드.

DB 주소와 비밀번호는 코드에 적지 않습니다.
DATABASE_URL 이라는 환경변수에서 읽어옵니다.
  - 내 컴퓨터: .env 파일 또는 docker-compose.yml
  - VPS 서버: 서버에만 있는 deploy/vps/.env
  - Render:   Render 대시보드의 Environment 화면
같은 코드가 어디서 돌든, 환경변수만 바꿔 끼우면 됩니다.
"""

import os

import psycopg
from psycopg.rows import dict_row

SCHEMA = """
CREATE TABLE IF NOT EXISTS messages (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    body       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
)
"""


def connect():
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise RuntimeError("DATABASE_URL 환경변수가 없습니다. .env.example 을 참고하세요.")
    return psycopg.connect(url, row_factory=dict_row, connect_timeout=5)


def init():
    """앱이 켜질 때 한 번: 테이블이 없으면 만든다."""
    with connect() as conn:
        conn.execute(SCHEMA)


def ping():
    """DB가 살아 있는지 확인 (헬스체크용)."""
    with connect() as conn:
        conn.execute("SELECT 1")


def list_messages(limit=50):
    with connect() as conn:
        return conn.execute(
            "SELECT id, name, body, created_at FROM messages ORDER BY id DESC LIMIT %s",
            (limit,),
        ).fetchall()


def add_message(name, body):
    # %s 자리에 값을 따로 넘기면 psycopg가 안전하게 끼워 넣습니다 (SQL 인젝션 방지).
    # 문자열을 직접 이어 붙여 SQL을 만들면 절대 안 됩니다.
    with connect() as conn:
        return conn.execute(
            "INSERT INTO messages (name, body) VALUES (%s, %s) "
            "RETURNING id, name, body, created_at",
            (name, body),
        ).fetchone()


def delete_message(message_id):
    with connect() as conn:
        conn.execute("DELETE FROM messages WHERE id = %s", (message_id,))
