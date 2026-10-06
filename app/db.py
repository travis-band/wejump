"""Code that talks to Postgres.

The database address and password are never written in the code.
They are read from an environment variable called DATABASE_URL.
  - Your computer: the .env file or docker-compose.yml
  - VPS server:    deploy/vps/.env, which exists only on the server
  - Render:        the Environment screen in the Render dashboard
Wherever the same code runs, you only swap the environment variable.
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
    """Once, when the app starts: create the table if it doesn't exist."""
    with connect() as conn:
        conn.execute(SCHEMA)


def ping():
    """Check that the database is alive (for the health check)."""
    with connect() as conn:
        conn.execute("SELECT 1")


def list_messages(limit=50):
    with connect() as conn:
        return conn.execute(
            "SELECT id, name, body, created_at FROM messages ORDER BY id DESC LIMIT %s",
            (limit,),
        ).fetchall()


def add_message(name, body):
    # Passing values separately for each %s lets psycopg insert them safely (prevents SQL injection).
    # Never build SQL by gluing strings together yourself.
    with connect() as conn:
        return conn.execute(
            "INSERT INTO messages (name, body) VALUES (%s, %s) "
            "RETURNING id, name, body, created_at",
            (name, body),
        ).fetchone()


def delete_message(message_id):
    with connect() as conn:
        conn.execute("DELETE FROM messages WHERE id = %s", (message_id,))
