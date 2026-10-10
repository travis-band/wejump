# 04. Automatic deploys with GitHub Actions

**Goal**: make testing → image build → server deploy happen automatically whenever you push to the `main` branch. Learn how to keep secrets safely outside your code.

## What is CI/CD?

- **CI (continuous integration)**: a robot tests your code automatically every time you push it.
- **CD (continuous deployment)**: when the tests pass, the robot deploys automatically.

GitHub Actions is that robot. Its instructions are one file: [`.github/workflows/deploy-vps.yml`](../.github/workflows/deploy-vps.yml).

```
git push (main)
   │
   ▼
[test]    Start a database briefly and run pytest  ── stops here on failure. Broken code never reaches the server
   │
   ▼
[build]   Build the image from the Dockerfile → push it as ghcr.io/<id>/wejump-deployment:<first 7 chars of the commit>
   │
   ▼
[deploy]  SSH into the server → git pull → ./deploy/vps/deploy.sh <first 7 chars of the commit>
```

Look at the `deploy` step. It's exactly the same commands a person typed by hand in [03-server](03-server.md). Automation isn't magic. It's **having a robot run the commands a person used to run**.

## What's secret and what isn't

| Value | Secret? | Where it goes |
|---|---|---|
| Server address (`VPS_HOST`) | No. Anyone can find it through DNS | GitHub **Variables** |
| Login user (`VPS_USER`, default `deploy`) | No | GitHub **Variables** (optional) |
| Private key for the server (`VPS_SSH_KEY`) | **Yes**. Whoever has it can do anything on the server | GitHub **Secrets** |
| Database password | **Yes** | Only in `.env` on the server. Not on GitHub either |
| Registry login | **Yes** | `GITHUB_TOKEN`. GitHub creates it for each run and throws it away afterwards |

You can't view a value again after putting it in Secrets, and if it tries to show up in a log it's masked as `***`. The goal is that **no secret is left anywhere: not in code, images, or logs**.

## Setting it up

Repo → **Settings** → **Secrets and variables** → **Actions**

1. **Variables** tab → New repository variable
   - `VPS_HOST` = `wejump.duckdns.org` (or the server IP)
2. **Secrets** tab → New repository secret
   - `VPS_SSH_KEY` = the entire output of `cat ~/.ssh/wejump_deploy` on your Mac (from the `-----BEGIN` line to the `-----END` line)

Before setting them, you can be sure by logging in from your Mac exactly the way the robot will.
```bash
ssh -i ~/.ssh/wejump_deploy deploy@wejump.duckdns.org "cat /opt/wejump/deploy/vps/.active"
```

## Check: change the code and push

1. Change the `<h1>` text in `app/static/index.html`.
2. ```bash
   git commit -am "Change the title"
   git push
   ```
3. In GitHub → **Actions**, watch the three steps turn green one by one (2 to 3 minutes).
4. Turn on **Auto-refresh** at the top right of the site and keep it open. Within about 10 seconds of the deploy finishing, the badge color and version number at the bottom of the page change, without reloading the page.

## Experiment: tests block the deploy

1. Change `max_length=30` to `max_length=0` in `app/main.py` and push.
2. `test` turns red → `build` and `deploy` don't run.
3. The site is still fine. The broken code never got near the server.
4. Change it back and push again.

## Common errors

| Symptom | Cause | Fix |
|---|---|---|
| The deploy step is gray (skipped) | There is no `VPS_HOST` variable | Add it under Variables |
| `Permission denied (publickey)` | The private key was pasted incorrectly, or the public key isn't on the server | Start with the Mac ssh test above |
| `denied` / `manifest unknown` (during deploy.sh) | The ghcr package is private | The Public setting in step 0 of [03](03-server.md) |
| `✗ blue is not healthy` | The new version can't return 200 from `/healthz` | The log is printed with it. The old version is still serving, so stay calm |
| On a Mac, `docker pull ghcr.io/...` fails with `no matching manifest for linux/arm64` | The image is built only for the server's CPU (amd64, the Intel/AMD family). M1 to M4 Macs are arm64 | `docker pull --platform linux/amd64 ...` (it runs under slow emulation). A good example of why each CPU type needs its own image |

## Think about it

- Did anyone looking at the site during the deploy see an error? → [05-blue-green](05-blue-green.md)
