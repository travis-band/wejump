"""Backend of the guestbook app. It receives browser requests, reads and writes the database,
and sends the page files (static/) to the browser.

Run: uvicorn app.main:app --reload --env-file .env
"""

import os
from contextlib import asynccontextmanager
from pathlib import Path

from authlib.integrations.starlette_client import OAuth, OAuthError
from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.responses import RedirectResponse, Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field
from starlette.middleware.sessions import SessionMiddleware

from app import db

# Which version and which color this running server is. Shown at the bottom of the page.
#   APP_VERSION: the git commit stamped in when the image is built (see the Dockerfile)
#   RENDER_GIT_COMMIT: the commit Render sets automatically
#   APP_COLOR: blue / green (VPS), render (Render), local (your computer)
VERSION = os.environ.get("APP_VERSION") or os.environ.get("RENDER_GIT_COMMIT", "")[:7] or "dev"
COLOR = os.environ.get("APP_COLOR", "local")

# ── Login settings (secrets come from environment variables, like DATABASE_URL) ──
#   SESSION_SECRET: the key that signs the login cookie. Blue and green must get the SAME value,
#                   or switching colors during a deploy would log everyone out.
#   GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET: from the GitHub OAuth App made for this environment.
SESSION_SECRET = os.environ.get("SESSION_SECRET")
if not SESSION_SECRET:
    raise RuntimeError("The SESSION_SECRET environment variable is not set. See .env.example.")
GITHUB_CLIENT_ID = os.environ.get("GITHUB_CLIENT_ID", "")
GITHUB_CLIENT_SECRET = os.environ.get("GITHUB_CLIENT_SECRET", "")


@asynccontextmanager
async def lifespan(app):
    db.init()  # Prepare the tables when the server starts
    yield


app = FastAPI(title="wejump guestbook", lifespan=lifespan)

# The session lives in a signed cookie in the browser, not in this server's memory.
# Any server that knows SESSION_SECRET can read it, so blue, green, and a rolled-back version all agree on who you are.
# Signed means the browser can see it but can't change it: editing the cookie breaks the signature.
app.add_middleware(
    SessionMiddleware,
    secret_key=SESSION_SECRET,
    same_site="lax",  # The cookie isn't sent with form posts from other sites (protects against CSRF)
    https_only=COLOR != "local",  # Real servers use HTTPS; your computer uses plain http://localhost
    max_age=7 * 24 * 60 * 60,  # Stay signed in for 7 days
)

oauth = OAuth()
oauth.register(
    "github",
    client_id=GITHUB_CLIENT_ID,
    client_secret=GITHUB_CLIENT_SECRET,
    authorize_url="https://github.com/login/oauth/authorize",
    access_token_url="https://github.com/login/oauth/access_token",
    api_base_url="https://api.github.com/",
    client_kwargs={"scope": "read:user"},  # Only ask to read the public profile
)


def current_user(request: Request):
    """Who is signed in, read from the session cookie. Answers 401 if nobody is."""
    uid = request.session.get("uid")
    user = db.get_user(uid) if uid and uid != db.GUEST_ID else None
    if user is None:
        raise HTTPException(status_code=401, detail="Please sign in")
    return user


class NewMessage(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)  # Strip leading/trailing spaces before validating

    body: str = Field(min_length=1, max_length=200)


@app.get("/api/messages")
def list_messages():
    return db.list_messages()


@app.post("/api/messages", status_code=201)
def create_message(msg: NewMessage, user=Depends(current_user)):
    # The name is no longer typed in. It's the GitHub username of whoever is signed in.
    return db.add_message(user["login"], msg.body, user["github_id"])


@app.get("/api/me")
def me(request: Request):
    """The signed-in user's profile, or null if nobody is signed in."""
    try:
        return current_user(request)
    except HTTPException:
        return None


@app.get("/api/me/messages")
def my_messages(user=Depends(current_user)):
    return db.list_messages_by_user(user["github_id"])


# ── GitHub login (OAuth) ──────────────────────────────────────────────────────
#   1. /auth/login     sends you to GitHub, with a random "state" saved in your session cookie
#   2. You approve on GitHub, and GitHub sends you back to /auth/callback with a one-time code
#   3. /auth/callback  checks the state, trades the code for a token, and asks GitHub who you are
# Our server never sees your GitHub password.


@app.get("/auth/login")
async def auth_login(request: Request):
    if not GITHUB_CLIENT_ID:
        raise HTTPException(status_code=503, detail="Login is not configured (GITHUB_CLIENT_ID is empty)")
    # The address GitHub sends you back to. It must match the callback URL registered in the OAuth App exactly.
    redirect_uri = request.url_for("auth_callback")
    return await oauth.github.authorize_redirect(request, str(redirect_uri))


@app.get("/auth/callback")
async def auth_callback(request: Request):
    try:
        token = await oauth.github.authorize_access_token(request)
        profile = (await oauth.github.get("user", token=token)).json()
    except OAuthError:
        # You pressed "Cancel" on GitHub, or the state didn't match. Go home without signing in.
        return RedirectResponse("/?login=failed")
    db.upsert_user(
        profile["id"], profile["login"], profile.get("name"), profile.get("avatar_url"), profile.get("html_url")
    )
    # Keep only the user ID in the cookie. The profile is read from the database on each request.
    # The GitHub token isn't kept anywhere: we only needed it once, to ask who you are.
    request.session.clear()
    request.session["uid"] = profile["id"]
    return RedirectResponse("/")


@app.post("/auth/logout", status_code=204)
def auth_logout(request: Request):
    request.session.clear()  # An empty session makes the middleware delete the cookie
    return Response(status_code=204)


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
