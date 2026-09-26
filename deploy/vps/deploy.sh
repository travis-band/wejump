#!/usr/bin/env bash
# 무중단(blue/green) 배포 스크립트.
#
#   사용법:  ./deploy.sh <이미지 태그>        예) ./deploy.sh 3f2a9c1
#
# 아이디어: 서버 칸이 두 개(blue, green) 있고, 손님(트래픽)은 한쪽에만 보냅니다.
#   1. 손님이 없는 쪽에 새 버전을 띄운다
#   2. 새 버전이 건강한지 확인한다 (/healthz)
#   3. 건강하면 Caddy에게 "이제 손님을 저쪽으로 보내"라고 알려준다  ← 이 순간이 배포
#   4. 옛 버전은 끄되 지우지 않는다 → 문제가 생기면 ./rollback.sh 로 즉시 되돌림
# 새 버전이 아프면 3번을 안 하므로, 손님은 아무것도 모른 채 옛 버전을 계속 씁니다.

set -euo pipefail
cd "$(dirname "$0")" # 이 스크립트가 있는 폴더(deploy/vps)에서 실행

TAG="${1:?사용법: ./deploy.sh <이미지 태그>}"
COMPOSE="docker compose -f docker-compose.prod.yml"

[ -f .env ] || { echo "✗ .env 파일이 없습니다. setup.sh를 먼저 실행하거나 .env.example을 복사하세요."; exit 1; }
DOMAIN=$(grep '^DOMAIN=' .env | cut -d= -f2-)
[ -n "$DOMAIN" ] || { echo "✗ .env에 DOMAIN이 비어 있습니다."; exit 1; }

# .env 안의 KEY=값 한 줄을 바꾼다 (없으면 추가). sed -i 대신 이렇게 하면 맥/리눅스 모두 동작.
set_env() {
  if grep -q "^$1=" .env; then
    sed "s|^$1=.*|$1=$2|" .env > .env.tmp && cat .env.tmp > .env && rm .env.tmp
  else
    echo "$1=$2" >> .env
  fi
}

# Caddyfile을 템플릿에서 만든다. `>`로 덮어써야 컨테이너가 같은 파일을 계속 봅니다.
write_caddyfile() {
  [ -d Caddyfile ] && rmdir Caddyfile # docker가 실수로 폴더를 만들어 둔 경우 정리
  {
    echo "# deploy.sh가 자동으로 만든 파일입니다. 고치려면 Caddyfile.template을 고치세요."
    echo "# 지금 손님을 받는 쪽: $1   (만든 시각: $(date '+%Y-%m-%d %H:%M:%S'))"
    grep -v '^#' Caddyfile.template | sed -e "s|__DOMAIN__|$DOMAIN|" -e "s|__COLOR__|$1|"
  } > Caddyfile
}

# ── 0. 지금 손님을 받는 색(ACTIVE)과 이번에 올릴 색(NEXT) ─────────────────
ACTIVE=$(cat .active 2>/dev/null || echo none)
if [ "$ACTIVE" = blue ]; then NEXT=green; else NEXT=blue; fi
NEXT_TAG_KEY="$(echo "$NEXT" | tr '[:lower:]' '[:upper:]')_TAG"

echo "▶ 현재 손님을 받는 쪽: $ACTIVE"
echo "▶ 새 버전 $TAG 을(를) $NEXT 에 올립니다"

# ── 1. NEXT 칸에 새 버전 띄우기 ─────────────────────────────────────────
OLD_NEXT_TAG=$(grep "^$NEXT_TAG_KEY=" .env | cut -d= -f2- || true) # 실패하면 되돌려 놓을 값
set_env "$NEXT_TAG_KEY" "$TAG"
$COMPOSE up -d db "app-$NEXT" # 이미지가 서버에 없으면 레지스트리(GHCR)에서 받아 옵니다

# ── 2. 건강검진: /healthz 가 200을 줄 때까지 최대 30번(약 30초) 두드려 보기 ──
echo "▶ $NEXT 건강검진 중 (/healthz)..."
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
  echo "✗ $NEXT 가 건강하지 않습니다. 손님은 그대로 $ACTIVE 에 남아 있습니다. 최근 로그:"
  $COMPOSE logs --tail 30 "app-$NEXT" || true
  $COMPOSE stop "app-$NEXT"
  set_env "$NEXT_TAG_KEY" "$OLD_NEXT_TAG" # 망가진 태그를 기록에서 지워야 rollback.sh가 헷갈리지 않음
  exit 1
fi
echo "✓ $NEXT 건강함"

# ── 3. 스위치: Caddy가 NEXT를 가리키게 바꾸기 ─────────────────────────────
write_caddyfile "$NEXT"
if [ -n "$($COMPOSE ps -q --status running caddy)" ]; then
  $COMPOSE exec -T caddy caddy reload --config /etc/caddy/Caddyfile # 연결을 끊지 않고 설정만 교체
else
  $COMPOSE up -d caddy # 첫 배포: Caddy를 처음 켬 (HTTPS 인증서도 이때 발급)
  sleep 2              # Caddy가 처음 켜질 때는 준비에 1초 남짓 걸림
fi
echo "$NEXT" > .active
echo "✓ 이제 손님은 $NEXT($TAG) 로 갑니다"

# ── 4. 옛 버전 끄기 (지우지 않음 → rollback 가능) ────────────────────────
if [ "$ACTIVE" != none ]; then
  sleep 2 # 옛 서버가 처리 중이던 요청을 마무리할 시간
  $COMPOSE stop "app-$ACTIVE"
  echo "✓ $ACTIVE 는 꺼 두었습니다. 되돌리려면: ./rollback.sh"
fi

echo "🎉 배포 완료: https://$DOMAIN"
