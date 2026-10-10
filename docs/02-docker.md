# 02. Docker: putting the app in a box

**Goal**: understand how to get rid of "it works on my computer but not on the server". Get hands-on with images, containers, and volumes.

## Why we need it

Code alone is not enough to run an app. Python 3.12, fastapi 0.141, psycopg 3.3… all of it has to be installed exactly the same way. Instead of setting this up by hand on every server, we **put the app and everything it needs into one box** and move the box.

- **Image**: the box (a read-only bundle of files, packed according to a recipe)
- **Container**: the box opened and running (one image can run as many containers)
- **Dockerfile**: the packing recipe

## Reading the Dockerfile

Open the [`Dockerfile`](../Dockerfile) and read it line by line.

| Line | What it does |
|---|---|
| `FROM python:3.12-slim` | Start from a small Linux with Python 3.12 installed |
| `COPY requirements.txt` + `RUN pip install` | Install libraries. This comes before the code, so when only the code changes, this step is reused from cache |
| `COPY app ./app` | Add our code |
| `ARG/ENV APP_VERSION` | Stamp the version number in at build time |
| `USER appuser` | Run without administrator (root) rights, for security |
| `CMD uvicorn ...` | The command to run when the container starts |

Also look at [`.dockerignore`](../.dockerignore). It keeps `.env` (passwords) out of the box. **Images get uploaded to a registry where many people can download them, so secrets never go into an image.**

## Follow along

```bash
# Build an image
docker build -t wejump --build-arg APP_VERSION=my-first .
docker images wejump

# App + database together (docker-compose.yml describes both)
docker compose up --build
```

Open <http://localhost:8000>. This time there is no Python virtual environment. The Python inside the container runs the app.

## Editing code while it runs

For development, [`docker-compose.yml`](../docker-compose.yml) connects your `app/` folder straight into the container. This is called a **bind mount**:

```yaml
volumes:
  - ./app:/srv/app
```

It also starts uvicorn with `--reload`. Together, this means:

| What you change | What you do |
|---|---|
| HTML, CSS, JS in `app/static/` | Just refresh the browser |
| Python files in `app/` | Nothing. The server restarts itself within a second |
| `requirements.txt` or `Dockerfile` | `docker compose up -d --build` |

### Experiment: an image is a snapshot

Without the bind mount, the container only sees the copy of your code that `COPY app ./app` put into the image **at build time**.

1. Put a `#` in front of the `- ./app:/srv/app` line in `docker-compose.yml`, then run `docker compose up -d`.
2. Change the `<h1>` text in `app/static/index.html` and refresh. Nothing changes.
3. Run `docker compose up -d --build` and refresh. Now it changes.
4. Remove the `#` again and run `docker compose up -d`.

A real server works like step 2. It has no bind mount and runs only what's inside the image. That's why every deploy starts by building a new image.

## How containers find each other

Look at the app's database address in [`docker-compose.yml`](../docker-compose.yml).

```
DATABASE_URL: postgresql://wejump:localdev@db:5432/wejump_deployment
```

The host is `db`, not `localhost`. Inside a container, `localhost` means "this container itself", and there is no database there. Containers in the same compose file find each other by **service name**.

## Experiment: where do messages live?

```bash
docker compose restart app     # restart only the app → messages are still there
docker compose down            # delete all containers → after up again, messages are still there!
docker compose up -d
docker volume ls               # you can see the wejump_pgdata volume
docker compose down -v         # also delete volumes → after up again, all messages are gone
```

Containers are disposable. You throw them away and make new ones any time. Data that must last goes in a **volume** (disk space outside the container). This separation is what makes the next step, "swap in a new version", possible.

## Experiment: look inside the database

```bash
docker compose up -d
docker compose exec db psql -U wejump -d wejump_deployment -c "SELECT * FROM messages;"
```

The messages you saw on screen come out as a table. How to connect from your own computer over localhost, and where the volume is actually stored, are covered in [02-1-local-db](02-1-local-db.md).

## Think about it

- Now we move this box to a server that is on 24 hours a day → [03-server](03-server.md)
