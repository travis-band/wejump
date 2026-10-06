# 05. Zero-downtime deploys (blue/green) and load balancers

**Goal**: understand how to swap in a new version without the site going down even once, and try rollback and load balancing yourself.

## Can't we just stop it and start it again?

The simplest deploy is "stop the old app → start the new app". In between, for a few seconds to a few tens of seconds, visitors see errors. And if the new version is broken, the site stays down.

## The idea: two slots and one switch

```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```
                        ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                        └ ─ app-green  (empty)
```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```

1. Start the new version (v2) in the slot with no visitors (green)
2. Check that green is healthy with `/healthz`
3. If it's healthy, flip the switch to green ← **this moment is the deploy**
4. Stop blue but don't delete it → if something goes wrong, just flip the switch back

If the new version is sick, step 3 never happens, so visitors keep using v1 as if nothing happened.

Open [`deploy/vps/deploy.sh`](../deploy/vps/deploy.sh) and you'll see steps 0 to 4 marked with comments. The switch is really one line in the Caddyfile.

```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```
wejump.duckdns.org {
	reverse_proxy app-green:8000      ← change this one word between blue ↔ green
}                                       then caddy reload (swaps the config without dropping connections)
```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```

## Classroom demo

1. Students open the site on their phones and turn on **Auto-refresh** at the top right. The badge at the bottom is blue: `blue`.
2. The teacher changes the code and pushes.
3. 2 to 3 minutes later, the badge on every student's phone changes to green `green` with a new version number, **without reloading the page**. Auto-refresh checks every 10 seconds, so it shows up within 10 seconds of the switch.
4. Posting messages never fails the whole time.

## Measure it: did it really never go down?

Run this in another terminal during a deploy. It hits the site every 0.2 seconds and prints the result.

```bash
while true; do
  curl -s -o /dev/null -w "%{http_code} " https://wejump.duckdns.org/healthz
  curl -s https://wejump.duckdns.org/api/version; echo
  sleep 0.2
done
```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```

You should see `200 {"color":"blue"...}` lines, then at some point `200 {"color":"green"...}`, with no line that isn't 200 in between.

The result of the same experiment run on a local computer while building this repo:

| Item | Result |
|---|---|
| Requests sent during the switch | 125 |
| Failed requests | 0 |
| Time to roll back | About 5 seconds |

## Rollback: going back

```bash
./rollback.sh
```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```

[`rollback.sh`](../deploy/vps/rollback.sh) does exactly one thing. It reads the version number of the stopped slot on the other side and passes it to `deploy.sh`. **Rollback isn't a special feature. It's just "deploy the previous version again".** The image is already on the server, so it takes a few seconds.

## Two safety nets

| Safety net | Where | What it stops |
|---|---|---|
| Tests | GitHub Actions `test` | Code whose features are wrong (the experiment in [04](04-automation.md)) |
| Health check | Step 2 of `deploy.sh` | A version that passed tests but won't start on the server (missing setting, can't reach the database, and so on) |

## Practice on your own computer

You can do exactly the same thing without a server. Instead of a registry, build the images on your computer.

```bash
cd deploy/vps
cp .env.example .env
```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```

Edit `.env` like this. `DOMAIN=:80` means "no domain, accept plain HTTP on port 80".

```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```
DOMAIN=:80
IMAGE=wejump-local
POSTGRES_PASSWORD=practice123
BLUE_TAG=
GREEN_TAG=
HTTP_PORT=8080
HTTPS_PORT=8443
```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```

```bash
# Build two versions
docker build -t wejump-local:v1 --build-arg APP_VERSION=v1 ../..
docker build -t wejump-local:v2 --build-arg APP_VERSION=v2 ../..

./deploy.sh v1        # http://localhost:8080 → blue, v1
./deploy.sh v2        # → green, v2 (try running the measuring loop against localhost:8080)
./rollback.sh         # → blue, v1

# A deliberately broken version: an image that dies as soon as it starts
printf 'FROM wejump-local:v2\nCMD ["python","-c","raise SystemExit(1)"]\n' \
  | docker build -t wejump-local:broken -
./deploy.sh broken    # ✗ not healthy → the site stays on blue

# Clean up
docker compose -f docker-compose.prod.yml down -v
```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```

## Experiment: build a load balancer

Right now Caddy is a **switch** that points at only one slot at a time. Point it at both slots at once and it becomes a **load balancer**.

On the server (or in the practice setup above):

```bash
dc start app-blue app-green      # turn on both slots (the dc alias is from 03)
```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```

Change the `Caddyfile` like this, then run `dc exec caddy caddy reload --config /etc/caddy/Caddyfile`:

```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```
wejump.duckdns.org {
	reverse_proxy app-blue:8000 app-green:8000 {
		lb_policy round_robin
	}
}
```
                            ┌─▶ app-blue   (v1, serving visitors)
visitors ──▶ Caddy (switch) ┤
                            └ ─ app-green  (empty)
```

Now turn on Auto-refresh and keep the site open. The badge switches blue, green, blue, green… every 10 seconds. You can see each request being shared between two servers.

- `lb_policy round_robin`: take turns in order. Without it, you get Caddy's default, **random** (blue may come up several times in a row).
- A real service's load balancer spreads requests across several **servers** and automatically drops servers that fail their health check. Here it's two containers inside one server, so if the server dies, both die.
- When you're done, run `./deploy.sh <current tag>` once to put the Caddyfile back.

## Limits and things to think about

- **The database is shared.** Blue and green look at the same database, so if the new version changes a table's structure, the old version can break. Real services change things "a little at a time, in a way the old version still understands".
- **There's only one server.** If the server goes down, the site goes down. Several servers plus a load balancer in front is the next step. GCP's managed load balancer costs about $18 a month, so this course doesn't use it.
- What if someone did all of this for you? → [06-render](06-render.md)
