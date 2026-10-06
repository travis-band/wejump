#!/usr/bin/env bash
# Rollback.
#
#   Usage:  ./rollback.sh
#
# Rollback isn't a special feature. It's just "deploy the previous version again".
# The previous version is still sitting, stopped, in the other color's slot, so calling deploy.sh with its tag is all it takes.

set -euo pipefail
cd "$(dirname "$0")"

ACTIVE=$(cat .active 2>/dev/null) || { echo "✗ 아직 배포한 적이 없습니다."; exit 1; }
if [ "$ACTIVE" = blue ]; then PREV=green; else PREV=blue; fi
PREV_TAG_KEY="$(echo "$PREV" | tr '[:lower:]' '[:upper:]')_TAG"
PREV_TAG=$(grep "^$PREV_TAG_KEY=" .env | cut -d= -f2-)

[ -n "$PREV_TAG" ] || { echo "✗ 되돌아갈 이전 버전이 없습니다 (첫 배포 상태)."; exit 1; }

echo "▶ 되돌리기: $ACTIVE → $PREV ($PREV_TAG)"
exec ./deploy.sh "$PREV_TAG"
