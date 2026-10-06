# wejump guestbook: a demo app for learning deployment

A repo for teaching middle and high school students **what it means to "deploy code"**.
The app is simple on purpose (a guestbook where you leave your name and a short message). The star isn't the app. It's **the process of getting the app onto the internet**.

- **App**: Python (FastAPI) + HTML/CSS/vanilla JS + PostgreSQL
- **Track 1**: a free GCP server + Docker + Caddy + GitHub Actions. Push, and it does a zero-downtime blue/green deploy ($0)
- **Track 2**: the same Dockerfile on Render + Neon ($0)

The badge at the bottom of the page shows whether the server that just answered is `blue` or `green`. Watching that color change during a deploy, without refreshing, is the highlight of the lesson.

## Run it in 30 seconds

```bash
docker compose up --build
```

<http://localhost:8000>

## Lesson docs

| | Doc | Contents |
|---|---|---|
| 0 | [What is deployment?](docs/00-what-is-deployment.md) | The big picture, vocabulary |
| 1 | [On your own computer](docs/01-local.md) | Running locally, the limits of localhost |
| 2 | [Docker](docs/02-docker.md) | Images, containers, volumes |
| 2-1 | [Local database](docs/02-1-local-db.md) | Connecting over localhost, where database files are stored |
| 3 | [A real server](docs/03-server.md) | VPS, SSH, domain, HTTPS |
| 4 | [Automatic deploys](docs/04-automation.md) | GitHub Actions, secrets |
| 5 | [Zero-downtime deploys](docs/05-blue-green.md) | Blue/green, rollback, load balancer |
| 6 | [PaaS](docs/06-render.md) | Render + Neon |
| Reference | [Comparing options](docs/07-options.md) | Costs and trade-offs of other approaches |

## Repo layout

```
app/                  The app (main.py backend, db.py SQL, static/ frontend, tests/)
Dockerfile            Recipe that turns the app into an image (shared by both tracks)
docker-compose.yml    For your computer: app + database
deploy/vps/           Track 1: scripts to create, prepare, deploy to, and roll back the server
.github/workflows/    Track 1: push → test → build → deploy
render.yaml           Track 2: Render settings
docs/                 Lesson docs
```

## Where the secrets live

| Secret | Where it lives | In git? |
|---|---|---|
| Local database password | `docker-compose.yml`, `.env` (local-only values) | Only the compose file. Fine, since it's local-only |
| Server database password | `deploy/vps/.env` on the server | No |
| Server login key | GitHub Secrets `VPS_SSH_KEY` | No |
| Neon database address | Render dashboard | No |
