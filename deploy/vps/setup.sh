#!/usr/bin/env bash
# Gets a new server ready for deploys. Run it exactly once per server.  ※ Run inside the server
#
#   Usage (after you ssh into the server):
#     git clone https://github.com/<github-id>/wejump-deployment.git /tmp/wejump-deployment
#     sudo DOMAIN=wejump.duckdns.org \
#          DEPLOY_PUBKEY="ssh-ed25519 AAAA... github-actions" \
#          bash /tmp/wejump-deployment/deploy/vps/setup.sh
#
#   (Optional) automatic DuckDNS IP updates: also pass DUCKDNS_TOKEN=<token>.
#
# What it does:
#   1. Install Docker
#   2. Add 1GB of swap memory (the e2-micro has only 1GB of RAM)
#   3. Create a deploy-only user 'deploy' + register the public key for GitHub Actions
#   4. Download the code to /opt/wejump
#   5. Create the secret settings file (.env). The database password is generated randomly; nobody types it

set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "✗ Run this with sudo."; exit 1; }
DOMAIN="${DOMAIN:?set DOMAIN=<domain> (e.g. wejump.duckdns.org)}"
DEPLOY_PUBKEY="${DEPLOY_PUBKEY:?set DEPLOY_PUBKEY=\"ssh-ed25519 ...\" (see step 3 of docs/03-server.md)}"

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_URL="$(git -C "$SRC" remote get-url origin)"
OWNER="$(echo "$REPO_URL" | sed -E 's#.*github\.com[:/]([^/]+)/.*#\1#' | tr '[:upper:]' '[:lower:]')"
APP_DIR=/opt/wejump # Kept from before the repo was renamed, so existing servers keep working

echo "━━ 1/5 Install Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
docker --version

echo "━━ 2/5 Add 1GB of swap"
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
free -h | head -3

echo "━━ 3/5 Deploy-only user 'deploy'"
id deploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy
usermod -aG docker deploy # The docker group = administrator-level power on the server. That's why this user's key lives only in a GitHub Secret.
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
echo "$DEPLOY_PUBKEY" > /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys

echo "━━ 4/5 Download the code → $APP_DIR"
[ -d "$APP_DIR/.git" ] || git clone "$REPO_URL" "$APP_DIR"
chown -R deploy:deploy "$APP_DIR"

echo "━━ 5/5 Secret settings file .env"
ENV_FILE="$APP_DIR/deploy/vps/.env"
if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" <<EOF
DOMAIN=$DOMAIN
IMAGE=ghcr.io/$OWNER/wejump-deployment
POSTGRES_PASSWORD=$(openssl rand -hex 16)
BLUE_TAG=
GREEN_TAG=
EOF
  chown deploy:deploy "$ENV_FILE"
  chmod 600 "$ENV_FILE" # Readable only by the deploy user
fi
echo "   Created $ENV_FILE (contents not printed)"

if [ -n "${DUCKDNS_TOKEN:-}" ]; then
  echo "━━ (Optional) Automatic DuckDNS IP updates (every 5 minutes)"
  SUB="${DOMAIN%%.duckdns.org}"
  install -m 700 -o deploy -g deploy /dev/null /home/deploy/duckdns.sh
  cat > /home/deploy/duckdns.sh <<EOF
#!/bin/sh
curl -fsS "https://www.duckdns.org/update?domains=$SUB&token=$DUCKDNS_TOKEN&ip=" -o /dev/null
EOF
  echo "*/5 * * * * deploy /home/deploy/duckdns.sh" > /etc/cron.d/duckdns
fi

cat <<EOF

✓ The server is ready.
  - App location: $APP_DIR
  - Deploy user:  deploy
  - Image:        ghcr.io/$OWNER/wejump-deployment

Next step (docs/04-automation.md):
  In the GitHub repo → Settings → Secrets and variables → Actions, add
    Variables: VPS_HOST = the server IP or $DOMAIN
    Secrets:   VPS_SSH_KEY = (the private key that pairs with DEPLOY_PUBKEY)
  Then re-run the deploy-vps workflow from the Actions tab.
EOF
