#!/usr/bin/env bash
# Gets a new server ready for deploys. Run it exactly once per server.  ※ Run inside the server
#
#   Usage (after you ssh into the server):
#     git clone https://github.com/<github-id>/wejump.git /tmp/wejump
#     sudo DOMAIN=wejump.duckdns.org \
#          DEPLOY_PUBKEY="ssh-ed25519 AAAA... github-actions" \
#          bash /tmp/wejump/deploy/vps/setup.sh
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

[ "$(id -u)" -eq 0 ] || { echo "✗ sudo로 실행하세요."; exit 1; }
DOMAIN="${DOMAIN:?DOMAIN=<도메인> 을 지정하세요 (예: wejump.duckdns.org)}"
DEPLOY_PUBKEY="${DEPLOY_PUBKEY:?DEPLOY_PUBKEY=\"ssh-ed25519 ...\" 를 지정하세요 (docs/03-server.md 3단계 참고)}"

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_URL="$(git -C "$SRC" remote get-url origin)"
OWNER="$(echo "$REPO_URL" | sed -E 's#.*github\.com[:/]([^/]+)/.*#\1#' | tr '[:upper:]' '[:lower:]')"
APP_DIR=/opt/wejump

echo "━━ 1/5 Docker 설치"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
docker --version

echo "━━ 2/5 스왑 1GB"
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
free -h | head -3

echo "━━ 3/5 배포 전용 사용자 'deploy'"
id deploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy
usermod -aG docker deploy # The docker group = administrator-level power on the server. That's why this user's key lives only in a GitHub Secret.
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
echo "$DEPLOY_PUBKEY" > /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys

echo "━━ 4/5 코드 받기 → $APP_DIR"
[ -d "$APP_DIR/.git" ] || git clone "$REPO_URL" "$APP_DIR"
chown -R deploy:deploy "$APP_DIR"

echo "━━ 5/5 비밀 설정 파일 .env"
ENV_FILE="$APP_DIR/deploy/vps/.env"
if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" <<EOF
DOMAIN=$DOMAIN
IMAGE=ghcr.io/$OWNER/wejump
POSTGRES_PASSWORD=$(openssl rand -hex 16)
BLUE_TAG=
GREEN_TAG=
EOF
  chown deploy:deploy "$ENV_FILE"
  chmod 600 "$ENV_FILE" # Readable only by the deploy user
fi
echo "   $ENV_FILE 생성됨 (내용은 출력하지 않습니다)"

if [ -n "${DUCKDNS_TOKEN:-}" ]; then
  echo "━━ (선택) DuckDNS IP 자동 갱신 (5분마다)"
  SUB="${DOMAIN%%.duckdns.org}"
  install -m 700 -o deploy -g deploy /dev/null /home/deploy/duckdns.sh
  cat > /home/deploy/duckdns.sh <<EOF
#!/bin/sh
curl -fsS "https://www.duckdns.org/update?domains=$SUB&token=$DUCKDNS_TOKEN&ip=" -o /dev/null
EOF
  echo "*/5 * * * * deploy /home/deploy/duckdns.sh" > /etc/cron.d/duckdns
fi

cat <<EOF

✓ 서버 준비 끝.
  - 앱 위치:     $APP_DIR
  - 배포 사용자: deploy
  - 이미지:      ghcr.io/$OWNER/wejump

다음 단계 (docs/04-automation.md):
  GitHub 레포 → Settings → Secrets and variables → Actions 에서
    Variables: VPS_HOST = 서버 IP 또는 $DOMAIN
    Secrets:   VPS_SSH_KEY = (DEPLOY_PUBKEY 짝이 되는 개인키)
  그리고 Actions 탭에서 deploy-vps 워크플로우를 다시 실행하세요.
EOF
