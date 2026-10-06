# 01. Run it on your own computer

**Goal**: start the guestbook app on your computer and understand how the code is split up. Then feel why this alone is not enough.

## What you need

- Python 3.12
- Docker Desktop (for now it's just the switch that turns the database on; [02-docker](02-docker.md) explains how it works)
- This repo: `git clone https://github.com/<github-id>/wejump.git && cd wejump`

## Follow along

```bash
# 1. Turn on the database (Postgres waits on port 5432)
docker compose up -d db

# 2. Python virtual environment + libraries
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt

# 3. Create the settings file (it holds the database address)
cp .env.example .env

# 4. Run the app
uvicorn app.main:app --reload --env-file .env
```

Open <http://localhost:8000> in your browser and leave a message. You'll see a `local` badge at the bottom of the page.

To connect to the database directly and watch messages being stored, see [02-1-local-db](02-1-local-db.md).

## How the code is organized

```
app/
├── main.py      Backend. Decides what to do for each address (/api/messages and so on)
├── db.py        The SQL that talks to the database
├── static/      Frontend. Sent to the browser and runs in the browser
│   ├── index.html
│   ├── style.css
│   └── app.js   Calls the backend with fetch('/api/messages')
└── tests/       Automated tests
```

When you leave a message, it flows like this:

```
app.js  ──POST /api/messages──▶  main.py  ──INSERT──▶  Postgres
(browser)                        (server)               (database)
```

## Tests

```bash
pytest -v
```

All 3 should pass. Later, in [04-automation](04-automation.md), GitHub runs these for you before every deploy.

## Experiments

1. **Persistence**: stop uvicorn with `Ctrl+C` and start it again. Are the messages still there? They are, because messages live in the database, not in the app (the Python process).
2. **The limit of localhost**: open `http://localhost:8000` on your phone. It doesn't work. `localhost` means "this machine itself", so on your phone it points to the phone.
3. **Your laptop as a server**: on the same Wi-Fi, you can try this.
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --env-file .env
   ipconfig getifaddr en0          # your Mac's local IP, e.g. 192.168.0.12
   ```
   Open `http://192.168.0.12:8000` on your phone. Your laptop just became a server. But it stops when you close the lid, it doesn't work outside your Wi-Fi, and there is no lock (HTTPS).

   (Tools like ngrok can let people in from outside, but the laptop still has to stay on.)

## Think about it

- We need a computer that is on 24 hours a day, reachable from anywhere, with a lock → [03-server](03-server.md)
- But how do we make the server have exactly the same Python version and libraries as my laptop? → [02-docker](02-docker.md)
