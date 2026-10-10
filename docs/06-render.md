# 06. A PaaS in 15 minutes: Render + Neon

**Goal**: experience what happens when a platform (PaaS) does what you built yourself in Track 1, and compare what you gave up in exchange for the convenience.

## What is a PaaS?

**P**latform **a**s **a** **S**ervice. A service that says "we'll manage the servers, you just give us the code". Render, Railway, Heroku, and Fly.io are examples.

We use the same `Dockerfile` as is. The only thing that changes is **who manages the infrastructure**.

## Who does what

| Task | Track 1 (VPS) | Track 2 (Render) |
|---|---|---|
| Rent a server | Us (`create-vm.sh`) | Render |
| Install Docker, swap, users | Us (`setup.sh`) | Render |
| Build the image | GitHub Actions | Render |
| Image warehouse | ghcr.io | Inside Render |
| Domain | DuckDNS | `*.onrender.com` automatically |
| HTTPS certificate | Caddy | Render |
| Swap after a health check (zero downtime) | `deploy.sh` | Render |
| Rollback | `rollback.sh` | The Rollback button in the dashboard |
| Database | Postgres container on the server | Neon (another company) |
| Where secrets are kept | Server `.env` + GitHub Secrets | Environment in the Render dashboard |
| Config files | The whole `deploy/vps/` folder | One file: [`render.yaml`](../render.yaml) |

## Why Neon for the database?

Render has free Postgres too, but:

- It **expires 30 days after it's created**. 14 days after that, Render deletes it along with all its data.
- Each workspace can have only one free database, and free databases have no backups.

Neon's free plan has no time limit (1 GB of storage; it sleeps when unused and wakes up when a request comes in). For a course that runs a whole term, that matters.

Render Postgres does have one advantage. If you declare the database in `render.yaml`, Render puts the connection string into the app automatically (`fromDatabase`), so nobody has to copy a password. If your course ends within 30 days, or paying about $6 a month for Render's smallest paid database is fine, that setup is simpler.

## 1. Create the database on Neon

1. Sign up at <https://neon.com> with your GitHub account (no card needed).
2. **New Project** → name it `wejump`, and choose **AWS Asia Pacific (Singapore)** as the region.
3. Click **Connect** in the dashboard → copy the connection string.
   ```
   postgresql://neondb_owner:password@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
   ```
   This string contains the password. **This is a secret.** Don't paste it into a chat room or into code.

## 2. Deploy on Render

1. Sign up at <https://render.com> with your GitHub account (no card needed for the free plan).
2. **New** → **Blueprint** → choose the `wejump-deployment` repo.
3. Render reads `render.yaml` and shows you what it will create.
4. On that same Render page there is an input field for `DATABASE_URL`. **Paste the Neon connection string into that field on the Render page.**
   - Never write the connection string into `render.yaml` or anywhere else in the code. In `render.yaml`, `sync: false` means "the app needs this variable, but its value is entered in the Render dashboard, not stored in this file".
5. Click **Deploy Blueprint**.
6. A few minutes later you get an address like `https://wejump-xxxx.onrender.com`.

The badge at the bottom of the page is purple `render`, and the version is the first 7 characters of the commit.

To change the connection string later, go to your service in the Render dashboard → **Environment**. The value lives there, not in the repo.

## 3. Automatic deploys

Thanks to `autoDeployTrigger: checksPass` in `render.yaml`, when you push, Render deploys **after all GitHub Actions checks have passed**. Both tracks share the same test gate.

> ⚠️ "All checks" includes Track 1's `deploy` step. If the VPS server is turned off, that step fails and Render stops deploying too. When you aren't using the VPS, delete `VPS_HOST` from GitHub Variables. Then the `deploy` step is skipped (which counts as passing) and only Render deploys.

## What the free plan is like

- **It goes to sleep after 15 minutes with no visitors.** The next visitor waits about a minute while it wakes up. Open it once 5 minutes before class starts.
- Zero-downtime deploys, HTTPS, and the log screen all work on the free plan.
- Both Render and Neon give a monthly allowance of "time switched on". Used only during class, it's plenty. Leaving the site open for days can use up Neon's allowance. See [the free-tier limits appendix](appendix-free-tier-limits.md).

## Compare

| | Track 1 (VPS) | Track 2 (Render) |
|---|---|---|
| First-time setup | 1 to 2 hours | 15 minutes |
| Monthly cost | $0 | $0 |
| Card needed | Yes (GCP) | No |
| Sleeps | No | After 15 minutes of no activity |
| Can you see inside? | Everything (files, logs, containers, database) | Only what the dashboard shows |
| Moving somewhere else | Same files work on any Linux server | `render.yaml` only works on Render. The `Dockerfile` works anywhere |

## Think about it

- Because you did Track 1 first, you know what phrases on the Render screen like "Deploy live" and "Health check passed" mean. What if you had started with Render instead?
- Which one would be easier as the app grows? With 10,000 users a month? With 1,000,000?
- Other options and costs → [07-options](07-options.md)
