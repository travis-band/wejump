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

# A stand-in user for messages written before login existed, and for messages written by an
# old version of the app that doesn't know about users yet. GitHub user IDs start at 1, so 0 is never a real user.
GUEST_ID = 0

# Every statement here is safe to run again and again ("idempotent"): it only adds what is missing.
# That matters during a blue/green deploy, because each new server runs init() when it starts.
SCHEMA = [
    """
    CREATE TABLE IF NOT EXISTS messages (
        id         SERIAL PRIMARY KEY,
        name       TEXT NOT NULL,
        body       TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
    """,
    # Only public GitHub profile fields. No passwords and no GitHub access tokens are ever stored.
    """
    CREATE TABLE IF NOT EXISTS users (
        github_id     BIGINT PRIMARY KEY,
        login         TEXT NOT NULL,
        name          TEXT,
        avatar_url    TEXT,
        html_url      TEXT,
        created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
        last_login_at TIMESTAMPTZ
    )
    """,
    # The guest row has to exist before messages can point at it.
    f"INSERT INTO users (github_id, login) VALUES ({GUEST_ID}, 'guest') ON CONFLICT DO NOTHING",
    # Every message belongs to a user (NOT NULL). Existing messages are filled with the guest the moment
    # the column is added. DEFAULT keeps an old version of the app working too: it inserts without user_id,
    # and the row quietly becomes a guest message instead of failing. This is what makes rollback safe.
    f"""
    ALTER TABLE messages
        ADD COLUMN IF NOT EXISTS user_id BIGINT NOT NULL DEFAULT {GUEST_ID} REFERENCES users (github_id)
    """,
]

# The columns the page needs for one message, with the author's profile joined in
MESSAGE_COLUMNS = """
    m.id, m.name, m.body, m.created_at, m.user_id, u.login, u.avatar_url
"""


def connect():
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise RuntimeError("The DATABASE_URL environment variable is not set. See .env.example.")
    return psycopg.connect(url, row_factory=dict_row, connect_timeout=5)


def init():
    """Once, when the app starts: create the tables and columns that don't exist yet."""
    with connect() as conn:
        for statement in SCHEMA:
            conn.execute(statement)


def ping():
    """Check that the database is alive (for the health check)."""
    with connect() as conn:
        conn.execute("SELECT 1")


def list_messages(limit=50):
    with connect() as conn:
        return conn.execute(
            f"SELECT {MESSAGE_COLUMNS} FROM messages m JOIN users u ON u.github_id = m.user_id "
            "ORDER BY m.id DESC LIMIT %s",
            (limit,),
        ).fetchall()


def add_message(name, body, user_id):
    # Passing values separately for each %s lets psycopg insert them safely (prevents SQL injection).
    # Never build SQL by gluing strings together yourself.
    with connect() as conn:
        row = conn.execute(
            "INSERT INTO messages (name, body, user_id) VALUES (%s, %s, %s) RETURNING id",
            (name, body, user_id),
        ).fetchone()
        return conn.execute(
            f"SELECT {MESSAGE_COLUMNS} FROM messages m JOIN users u ON u.github_id = m.user_id WHERE m.id = %s",
            (row["id"],),
        ).fetchone()


def delete_message(message_id):
    with connect() as conn:
        conn.execute("DELETE FROM messages WHERE id = %s", (message_id,))

