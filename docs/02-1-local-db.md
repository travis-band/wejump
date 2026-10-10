# 02-1. Start the local database and connect to it

**Goal**: run Postgres on your computer with Docker and connect to it directly over localhost. Then understand where the database files are actually stored.

## 1. Turning it on and off

Run these in the repo folder.

| Command | What it does | Your data (messages)? |
|---|---|---|
| `docker compose up -d db` | Start only the database | Kept |
| `docker compose stop db` | Stop the database | Kept |
| `docker compose down` | Delete the containers | **Kept** (volumes are not deleted) |
| `docker compose down -v` | Delete the containers and volumes | **All gone** |

## 2. Connection details

These are the local-only values written in [`docker-compose.yml`](../docker-compose.yml).

| Item | Value |
|---|---|
| Host | `localhost` |
| Port | `5432` |
| User | `wejump` |
| Password | `localdev` |
| Database name | `wejump_deployment` |

Written as one line, it looks like this. This format is called a **connection string**.

```
postgresql://wejump:localdev@localhost:5432/wejump_deployment
          user   password  host      port  database
```

> **Set this up before the database was renamed?** Earlier versions called the database `wejump`. Postgres only reads `POSTGRES_DB` when the volume is first created, so an existing volume still has the old name and the app can't find `wejump_deployment`. Rename it once, keeping all your messages:
>
> ```bash
> docker compose stop app        # nothing may be connected while renaming
> docker compose exec db psql -U wejump -d postgres -c "ALTER DATABASE wejump RENAME TO wejump_deployment;"
> docker compose start app
> ```
>
> Also change the end of `DATABASE_URL` in your `.env` from `/wejump` to `/wejump_deployment`.

## 3. Three ways to connect

**Option 1. psql inside the container** (nothing to install)

```bash
docker compose exec db psql -U wejump -d wejump_deployment
```

**Option 2. psql on your own computer** (check that it's installed with `which psql`)

```bash
psql postgresql://wejump:localdev@localhost:5432/wejump_deployment
```

**Option 3. A GUI tool** (TablePlus, DBeaver, DataGrip, and so on)
Create a new connection and fill in each field with the values from the table above.

Options 2 and 3 work because of one line in the compose file: `ports: "5432:5432"`. It means "connect the container's port 5432 to port 5432 on my computer". Remove that line and nothing outside the container can reach the database. The real server's compose file leaves this line out on purpose.

## 4. Things to try once connected

Inside psql:

```
\dt                                  -- list tables
\d messages                          -- structure of the messages table
SELECT * FROM messages ORDER BY id;  -- show all messages
SELECT count(*) FROM messages;       -- count messages
\q                                   -- quit
```

Leave a message in the browser, then run the `SELECT` again. The message you just wrote appears in the table. You can see the screen, backend, and database are connected.

## 5. Why the same database has two addresses

| Who connects | Address | Where it's written |
|---|---|---|
| uvicorn, pytest, psql on your computer | `localhost:5432` | `.env` |
| The app running in a container | `db:5432` | `app` in `docker-compose.yml` |

Inside a container, `localhost` means "that container itself", and there is no database there. Containers in the same compose file find each other by service name (`db`).

## 6. Where are the database files stored?

### Not in the image, not in the container: in a "volume"

| Storage | What it's like | If you put database files here |
|---|---|---|
| Image | A read-only blueprint | You can't write to it |
| Inside the container | Writable, but disposable | Deleted along with the container |
| **Volume** | Storage outside the container | Survives when the container is deleted ✅ |

These two lines in the compose file create the volume and attach it.

```yaml
volumes:
  - pgdata:/var/lib/postgresql/data   # attach the pgdata volume to Postgres's data folder
```

Docker adds the project name in front and creates it as `wejump_pgdata`.

```bash
docker volume ls
```

```bash
docker volume inspect wejump_pgdata
```

### On Mac and Windows, it's inside a VM

Containers are built from features of the Linux kernel. The Mac and Windows kernels don't have those features, so **Docker Desktop starts a small Linux virtual machine (VM) and runs Docker Engine inside it.** Images, containers, and volumes all live inside that VM.

```
Your Mac (macOS)
 ├─ docker command ─── request ───┐      ← just a remote control
 └─ Docker Desktop's Linux VM  ◀──┘
     └─ Docker Engine
         ├─ images
         ├─ containers
         └─ volume wejump_pgdata    ← the database files are here
```

That is why the path `docker volume inspect` shows, `/var/lib/docker/volumes/wejump_pgdata/_data`, can't be found in the Mac Finder. It's a path inside the VM, not on the Mac. From the Mac's point of view, the entire VM disk is one file:

```
~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw
```

| Environment | VM for Docker | Where volumes live |
|---|---|---|
| Docker Desktop on Mac | Yes | Inside the VM (not visible in Finder) |
| Docker Desktop on Windows | Yes (WSL2) | Inside the VM |
| Linux (e.g. the GCP server in 03) | No | Directly in `/var/lib/docker/volumes/` on that computer |

This structure is also why you get a "Cannot connect to the Docker daemon" error. When Docker Desktop is off, the VM is off too, so the `docker` command has nowhere to send its request.

### Peeking inside the volume

Attach the volume to a tiny Linux container and look.

```bash
docker run --rm -v wejump_pgdata:/data alpine ls /data
```

You'll see files like `base`, `global`, and `PG_VERSION`. These are the real files Postgres uses to store messages. Editing them directly will break the database, so just look.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop is off | Start the Docker Desktop app |
| `port is already allocated` or `address already in use` | Postgres is already running on port 5432 on your computer | Check with `lsof -i :5432`. Change the compose port to `"5433:5432"` and change the address in `.env` to `5433` too |
| `connection refused` | The database is still starting | Try again in a few seconds. Check for `healthy` in `docker compose ps` |
| `password authentication failed` | You changed the password in compose, but the volume was created with the old one. The password setting only applies **when the volume is first created** | Connect with the old password, or, if losing the data is fine, run `docker compose down -v` and `up` again |
| All the messages are gone | The volume was deleted with `down -v` | A deleted volume can't be recovered. Use `-v` carefully |
