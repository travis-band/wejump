#!/usr/bin/env bash
# Rollback.
#
#   Usage:  ./rollback.sh
#
# Rollback isn't a special feature. It's just "deploy the previous version again".
# The previous version is still sitting, stopped, in the other color's slot, so calling deploy.sh with its tag is all it takes.

set -euo pipefail
cd "$(dirname "$0")"

ACTIVE=$(cat .active 2>/dev/null) || { echo "✗ Nothing has been deployed yet."; exit 1; }
if [ "$ACTIVE" = blue ]; then PREV=green; else PREV=blue; fi
PREV_TAG_KEY="$(echo "$PREV" | tr '[:lower:]' '[:upper:]')_TAG"
PREV_TAG=$(grep "^$PREV_TAG_KEY=" .env | cut -d= -f2-)

[ -n "$PREV_TAG" ] || { echo "✗ No previous version to go back to (this is the first deploy)."; exit 1; }

echo "▶ Rolling back: $ACTIVE → $PREV ($PREV_TAG)"
exec ./deploy.sh "$PREV_TAG"
