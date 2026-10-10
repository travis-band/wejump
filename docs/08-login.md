# 08. Signing in with GitHub

**Goal**: add a login without ever storing a password, and see why a login has to be designed with deploys in mind.

## What changes for visitors

- **Anyone can read** the guestbook, signed in or not.
- **Only signed-in people can post.** The name is no longer typed in; it's your GitHub username, with your avatar next to it.
- **My page** (`/me.html`) shows your GitHub profile, when you joined, and the messages you wrote. The Logout button is there and at the top right.

## Why GitHub, and why not our own passwords?

Storing passwords means storing them safely (slow hashing, rate limits, reset emails...). One mistake and real people's passwords leak.
With "Sign in with GitHub", **GitHub checks the password, not us.** We only learn "this is GitHub user #583231, called octocat". This way of borrowing someone else's login is called **OAuth**.

## How it works

```
 1. You click "Sign in with GitHub"
    browser ──▶ our server /auth/login
                └─ saves a random "state" in your cookie, then sends you to github.com

 2. You approve on GitHub
    github.com ──▶ our server /auth/callback?code=...&state=...
                   └─ checks the state matches, trades the one-time code for a token,
                      asks GitHub "who is this?", saves the profile in the users table

 3. Our server puts your user ID in a signed cookie and sends you home
```

The code is in [`app/main.py`](../app/main.py) under "GitHub login (OAuth)".
The `state` check stops another site from finishing a login on your behalf. The GitHub token is used once and thrown away; we never store it.

## Where the login lives: a signed cookie

After step 3, your browser holds a cookie that says `{"uid": 583231}` plus a **signature**.
The signature is made with `SESSION_SECRET`. You can read the cookie, but if you change even one character, the signature no longer matches and the server treats you as signed out.

The server keeps **nothing** in its memory about who is signed in. That turns out to matter a lot for deploys ↓

## Login and blue/green

| What happens | Why it's fine |
|---|---|
| Caddy switches from blue to green while you're signed in | Green has the same `SESSION_SECRET` (both read it from the server's `.env`), so it trusts the cookie blue signed |
| You start signing in on blue and GitHub sends you back to green | The `state` is in the cookie too, not in blue's memory |
| `./rollback.sh` goes back to a version from before login existed | The new database column has a default (see below), so the old version can still save messages |

**What if we had kept logins in the server's memory?** Each container has its own memory. Every deploy would start a fresh container with empty memory, and **everyone would be logged out on every deploy.** With a load balancer (05) it's worse: each request could land on a server that has never heard of you.

There's a test for this: `test_cookie_from_the_other_color_is_trusted` in [`app/tests/test_api.py`](../app/tests/test_api.py) signs a cookie the way "the other color" would and checks this server accepts it.

**Changing `SESSION_SECRET` logs everyone out at once**, because every old signature stops matching. That's the emergency button if the secret ever leaks.

## The database change, done so the old version still works

Every message now belongs to a user (`messages.user_id`, which can't be empty). But:

- Messages written before login existed have no author.
- During a deploy, blue (the old version) is still running for a few seconds after green has changed the table. And after a rollback, the old version runs for good. The old version doesn't know about `user_id`, so it saves messages without it.

The fix is a **guest user** (ID `0`; real GitHub IDs start at 1) and a **default**:

```sql
INSERT INTO users (github_id, login) VALUES (0, 'guest') ON CONFLICT DO NOTHING;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS user_id BIGINT NOT NULL DEFAULT 0 REFERENCES users (github_id);
```

Old messages become guest messages the moment the column is added, and an old version's messages quietly become guest messages too. They show up as `name (guest)`.
This is the "change things a little at a time, in a way the old version still understands" idea from the end of [05](05-blue-green.md#limits-and-things-to-think-about), for real.
`test_old_app_version_can_still_insert` checks it.

## Setting it up: one GitHub OAuth App per place

GitHub sends you back to exactly one **callback URL** per OAuth App, so make one app for each place the guestbook runs.
GitHub → Settings → Developer settings → **OAuth Apps** → New OAuth App:

| Where | Homepage URL | Authorization callback URL | Where the values go |
|---|---|---|---|
| Your computer | `http://localhost:8000` | `http://localhost:8000/auth/callback` | `.env` |
| VPS (Track 1) | `https://<DOMAIN>` | `https://<DOMAIN>/auth/callback` | `deploy/vps/.env` on the server |
| Render (Track 2) | `https://<service>.onrender.com` | `https://<service>.onrender.com/auth/callback` | Render dashboard → Environment |

Each app gives you a **Client ID** (not secret) and a **Client secret** (secret!). Put them in `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`.

- **Your computer**: put them in `.env`, then `docker compose up --build`. Without them the app still runs; only "Sign in with GitHub" says it isn't configured.
- **VPS**: `setup.sh` already wrote a random `SESSION_SECRET` into `deploy/vps/.env`. SSH in, fill in the two GitHub lines, and deploy again (`./deploy/vps/deploy.sh <tag>`). Never put these in GitHub Secrets or git; the server's `.env` is their only home.
- **Render**: `render.yaml` makes a random `SESSION_SECRET` for you (`generateValue: true`). Fill in the two GitHub values in the dashboard.

If you see **"The redirect_uri is not associated with this application"** on GitHub, the callback URL in the OAuth App doesn't exactly match the address you're visiting (http vs https, a missing `/auth/callback`, a different domain).

## Why the Dockerfile changed: HTTPS behind a proxy

On the VPS, Caddy handles HTTPS and passes the request to our app over plain `http`. Render does the same. So the app thinks it's on `http://...` and would tell GitHub "send them back to `http://wejump.duckdns.org/auth/callback`", which doesn't match the `https://` callback URL.
The proxy adds a header, `X-Forwarded-Proto: https`, that says "this was really HTTPS". `--forwarded-allow-ips='*'` in the [`Dockerfile`](../Dockerfile) tells uvicorn to believe it. That's safe because the app's port is never reachable from the internet, only through the proxy.

## Think about it

- Open your browser's developer tools → Application → Cookies after signing in. Can you read the cookie? Base64-decode the first part. What's inside? Why is it fine that you can read it?
- What would happen if blue and green had **different** `SESSION_SECRET`s? Try it locally with two uvicorns on different ports.
- We kept the `name` column and still fill it in. Which version of the app needs it?
