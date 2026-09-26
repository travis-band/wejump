#!/usr/bin/env bash
# 되돌리기(rollback).
#
#   사용법:  ./rollback.sh
#
# 되돌리기는 특별한 기능이 아닙니다. "직전 버전을 다시 배포"하는 것뿐입니다.
# 직전 버전은 꺼진 채로 반대쪽 색 칸에 남아 있으므로, 그 태그로 deploy.sh를 부르면 끝.

set -euo pipefail
cd "$(dirname "$0")"

ACTIVE=$(cat .active 2>/dev/null) || { echo "✗ 아직 배포한 적이 없습니다."; exit 1; }
if [ "$ACTIVE" = blue ]; then PREV=green; else PREV=blue; fi
PREV_TAG_KEY="$(echo "$PREV" | tr '[:lower:]' '[:upper:]')_TAG"
PREV_TAG=$(grep "^$PREV_TAG_KEY=" .env | cut -d= -f2-)

[ -n "$PREV_TAG" ] || { echo "✗ 되돌아갈 이전 버전이 없습니다 (첫 배포 상태)."; exit 1; }

echo "▶ 되돌리기: $ACTIVE → $PREV ($PREV_TAG)"
exec ./deploy.sh "$PREV_TAG"
