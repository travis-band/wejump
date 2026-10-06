# 00. What is deployment?

## In one sentence

**Deployment means taking a program that only runs on your computer, putting it on another computer that is always on, and letting anyone use it through an internet address.**

A program you start with `python app.py` runs only on your laptop. Close the lid and it stops. A friend has no way to reach it from their phone. Deployment solves both problems.

## What happens when someone types a web address

```
Friend's phone (browser)
  │
  │ ① "Where is wejump.duckdns.org?"  ──▶  DNS: "It's 34.82.1.23"
  │
  │ ② Connect to port 443 at https://34.82.1.23
  ▼
Server (a computer that is always on)
  ├─ ③ Caddy     Front desk. Handles the HTTPS lock
  │     ▼
  ├─ ④ FastAPI   Where our code runs
  │     ▼
  └─ ⑤ Postgres  Where messages are stored
```

1. **DNS** turns a name like `wejump.duckdns.org` into an IP address like `34.82.1.23`. Think of it as the server's phone number.
2. **IP and port**: the IP is the building address, and the port is the room number. The web usually uses room 80 (HTTP) and room 443 (HTTPS).
3. **Proxy (Caddy)** is the server's front desk. It handles the HTTPS lock and sends each visitor to the right app.
4. **App (FastAPI)** is our code. It receives requests, reads and writes the database, and sends back results.
5. **Database (Postgres)** is where messages are actually stored. They stay there when the app restarts or is replaced by a new version.

## Words you will meet in this course

| Word | Plain meaning | Where it is in this repo |
|---|---|---|
| Server / VPS | A rented computer that is connected to the internet and on 24 hours a day | GCP e2-micro (`deploy/vps/create-vm.sh`) |
| Domain, DNS | The phone book between names people remember and addresses computers use (IPs) | DuckDNS |
| HTTPS, certificate | A lock that encrypts what is sent. The certificate proves "this site is the real one" | Caddy gets one from Let's Encrypt automatically |
| Process, port | A running program, and the number it waits on for visitors | uvicorn waits on port 8000 |
| Environment variable, secret | A setting passed in from outside the code. A value that must stay hidden, like a password, is a secret | `.env`, GitHub Secrets |
| Image, container | A box holding the app, Python, and libraries (image), and a running copy of that box (container) | `Dockerfile` |
| Registry | A warehouse where images are stored | ghcr.io (GitHub Container Registry) |
| Volume, persistence | Storage that survives when a container is deleted. The reason messages don't disappear | `pgdata` volume |
| CI/CD | A robot that tests (CI) and deploys (CD) your code automatically when you push it | `.github/workflows/deploy-vps.yml` |
| Health check | An address that answers "are you healthy?" | `/healthz` |
| Zero-downtime deploy (blue/green) | Swapping in a new version without visitors noticing | `deploy/vps/deploy.sh` |

## Course order

We deploy the same app, with the same single `Dockerfile`, in two different ways.

| Step | Doc | What you learn |
|---|---|---|
| 1 | [01-local](01-local.md) | Run the app on your computer, and the limits of localhost |
| 2 | [02-docker](02-docker.md) | Images, containers, volumes |
| 2-1 | [02-1-local-db](02-1-local-db.md) | Connect to the DB over localhost, volumes and the Docker Desktop VM |
| 3 | [03-server](03-server.md) | Create a real server, SSH, domain, HTTPS, first deploy by hand |
| 4 | [04-automation](04-automation.md) | Push and GitHub Actions deploys automatically, secrets |
| 5 | [05-blue-green](05-blue-green.md) | Zero-downtime deploys, rollback, load balancer |
| 6 | [06-render](06-render.md) | The same thing on a PaaS in 15 minutes. Who does what for you |
| Reference | [07-options](07-options.md) | Other options and their costs, and why we chose this setup |
| Appendix | [Free-tier limits](appendix-free-tier-limits.md) | Monthly usage allowances on Render and Neon |

**Track 1 (steps 1 to 5)**: you manage one server yourself. Every part is visible as a file. Cost: $0.
**Track 2 (step 6)**: Render handles the server, HTTPS, and zero-downtime deploys for you. Easy, but you can't see inside. Cost: $0.

Doing both tracks shows you why a PaaS is convenient, and who is doing what behind that convenience.
