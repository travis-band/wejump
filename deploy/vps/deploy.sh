#!/usr/bin/env bash
# Zero-downtime (blue/green) deploy script.
#
#   Usage:  ./deploy.sh <image tag>        e.g. ./deploy.sh 3f2a9c1
#
# The idea: there are two server slots (blue, green), and visitors (traffic) go to only one.
#   1. Start the new version in the slot with no visitors
#   2. Check that the new version is healthy (/healthz)
#   3. If it is, tell Caddy "send visitors over there now"  ← this moment is the deploy
#   4. Stop the old version but don't delete it → if anything goes wrong, ./rollback.sh switches back right away
# If the new version is sick, step 3 never happens, so visitors keep using the old version without noticing.

set -euo pipefail
cd "$(dirname "$0")" # Run from the folder this script is in (deploy/vps)

TAG="${1:?usage: ./deploy.sh <image tag>}"
COMPOSE="docker compose -f docker-compose.prod.yml"

[ -f .env ] || { echo "✗ No .env file. Run setup.sh first, or copy .env.example."; exit 1; }
DOMAIN=$(grep '^DOMAIN=' .env | cut -d= -f2-)
[ -n "$DOMAIN" ] || { echo "✗ DOMAIN is empty in .env."; exit 1; }

# Change one KEY=value line in .env (add it if missing). Doing it this way instead of sed -i works on both Mac and Linux.
set_env() {
  if grep -q "^$1=" .env; then
    sed "s|^$1=.*|$1=$2|" .env > .env.tmp && cat .env.tmp > .env && rm .env.tmp
  else
    echo "$1=$2" >> .env
  fi
}

# Build the Caddyfile from the template. Overwriting with `>` keeps the container looking at the same file.
write_caddyfile() {
  [ -d Caddyfile ] && rmdir Caddyfile # Clean up if docker accidentally created a folder here
  {
    echo "# Generated automatically by deploy.sh. To change it, edit Caddyfile.template."
    echo "# Slot serving visitors now: $1   (generated at: $(date '+%Y-%m-%d %H:%M:%S'))"
    grep -v '^#' Caddyfile.template | sed -e "s|__DOMAIN__|$DOMAIN|" -e "s|__COLOR__|$1|"
  } > Caddyfile
}

# ── 0. The color serving visitors now (ACTIVE) and the color we deploy to (NEXT) ──
ACTIVE=$(cat .active 2>/dev/null || echo none)
if [ "$ACTIVE" = blue ]; then NEXT=green; else NEXT=blue; fi
NEXT_TAG_KEY="$(echo "$NEXT" | tr '[:lower:]' '[:upper:]')_TAG"

echo "▶ Currently serving visitors: $ACTIVE"
echo "▶ Deploying new version $TAG to $NEXT"

# ── 1. Start the new version in the NEXT slot ──────────────────────────────
OLD_NEXT_TAG=$(grep "^$NEXT_TAG_KEY=" .env | cut -d= -f2- || true) # The value to restore if this fails
set_env "$NEXT_TAG_KEY" "$TAG"
$COMPOSE up -d db "app-$NEXT" # Pulls the image from the registry (GHCR) if it isn't on the server

# ── 2. Health check: knock on /healthz up to 30 times (about 30 seconds) until it returns 200 ──
echo "▶ Health-checking $NEXT (/healthz)..."
healthy=no
for _ in $(seq 1 30); do
  if $COMPOSE exec -T "app-$NEXT" python -c \
    "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz', timeout=2)" \
    >/dev/null 2>&1; then
    healthy=yes
    break
  fi
  sleep 1
done

if [ "$healthy" != yes ]; then
  echo "✗ $NEXT is not healthy. Visitors stay on $ACTIVE. Recent logs:"
  $COMPOSE logs --tail 30 "app-$NEXT" || true
  $COMPOSE stop "app-$NEXT"
  set_env "$NEXT_TAG_KEY" "$OLD_NEXT_TAG" # Remove the broken tag from the record so rollback.sh doesn't get confused
  exit 1
fi
echo "✓ $NEXT is healthy"

# ── 3. The switch: point Caddy at NEXT ──────────────────────────────────────
write_caddyfile "$NEXT"
if [ -n "$($COMPOSE ps -q --status running caddy)" ]; then
  $COMPOSE exec -T caddy caddy reload --config /etc/caddy/Caddyfile # Swap the config without dropping connections
else
  $COMPOSE up -d caddy # First deploy: start Caddy for the first time (it also gets the HTTPS certificate now)
  sleep 2              # Caddy needs a little over a second to get ready the first time
fi
echo "$NEXT" > .active
echo "✓ Visitors now go to $NEXT ($TAG)"

# ── 4. Stop the old version (not deleted → rollback is possible) ────────────
if [ "$ACTIVE" != none ]; then
  sleep 2 # Time for the old server to finish requests it was handling
  $COMPOSE stop "app-$ACTIVE"
  echo "✓ $ACTIVE is stopped (not deleted). To go back: ./rollback.sh"
fi

echo "🎉 Deploy complete: https://$DOMAIN"
