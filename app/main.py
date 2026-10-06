"""Backend of the guestbook app. It receives browser requests, reads and writes the database,
and sends the page files (static/) to the browser.

Run: uvicorn app.main:app --reload --env-file .env
"""

import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field

from app import db

# Which version and which color this running server is. Shown at the bottom of the page.
#   APP_VERSION: the git commit stamped in when the image is built (see the Dockerfile)
#   RENDER_GIT_COMMIT: the commit Render sets automatically
#   APP_COLOR: blue / green (VPS), render (Render), local (your computer)
VERSION = os.environ.get("APP_VERSION") or os.environ.get("RENDER_GIT_COMMIT", "")[:7] or "dev"
COLOR = os.environ.get("APP_COLOR", "local")


@asynccontextmanager
async def lifespan(app):
    db.init()  # Prepare the table when the server starts
    yield


app = FastAPI(title="wejump 방명록", lifespan=lifespan)


class NewMessage(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)  # Strip leading/trailing spaces before validating

    name: str = Field(min_length=1, max_length=30)
    body: str = Field(min_length=1, max_length=200)


@app.get("/api/messages")
def list_messages():
    return db.list_messages()


@app.post("/api/messages", status_code=201)
def create_message(msg: NewMessage):
    return db.add_message(msg.name, msg.body)


@app.get("/api/version")
def version():
    return {"version": VERSION, "color": COLOR}


@app.get("/healthz")
def healthz():
    """Health check: the address that answers "I'm healthy".
    The deploy script and Render knock on this address before sending traffic to a new server.
    If the database can't be reached, it returns 503 to say "don't send visitors here yet".
    """
    try:
        db.ping()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"db unavailable: {type(e).__name__}")
    return {"ok": True, "version": VERSION, "color": COLOR}


# Every other address not handled above (/, /app.js, /style.css ...) is answered with a file from the static folder
app.mount("/", StaticFiles(directory=Path(__file__).parent / "static", html=True), name="static")
