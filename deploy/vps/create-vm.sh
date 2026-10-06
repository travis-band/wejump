#!/usr/bin/env bash
# Creates one free server (e2-micro) on GCP.  ※ Run on the teacher's Mac (not inside the server)
#
#   Setup:  brew install --cask google-cloud-sdk
#           gcloud auth login
#   Usage:  PROJECT=<GCP project ID> ./deploy/vps/create-vm.sh
#
# You could also click through the console, but keeping it as commands
# records "what was created and how", and lets you create it again exactly the same way.

set -euo pipefail

PROJECT="${PROJECT:?PROJECT=<GCP 프로젝트 ID> 를 앞에 붙여서 실행하세요}"
ZONE="${ZONE:-us-west1-b}" # Free-tier regions: us-west1 (Oregon), us-central1 (Iowa), us-east1 (South Carolina)
NAME="${NAME:-wejump}"

echo "1) Compute Engine API 켜기"
gcloud services enable compute.googleapis.com --project "$PROJECT"

echo "2) 서버(VM) 만들기: e2-micro, 우분투 24.04, 디스크 30GB(standard) → 무료 티어 범위"
gcloud compute instances create "$NAME" \
  --project "$PROJECT" \
  --zone "$ZONE" \
  --machine-type e2-micro \
  --image-family ubuntu-2404-lts-amd64 \
  --image-project ubuntu-os-cloud \
  --boot-disk-size 30GB \
  --boot-disk-type pd-standard \
  --tags wejump-web

echo "3) 방화벽: 인터넷에서 80(HTTP), 443(HTTPS)만 열기. DB 포트(5432)는 열지 않습니다."
if ! gcloud compute firewall-rules describe wejump-allow-web --project "$PROJECT" >/dev/null 2>&1; then
  gcloud compute firewall-rules create wejump-allow-web \
    --project "$PROJECT" \
    --allow tcp:80,tcp:443 \
    --target-tags wejump-web \
    --source-ranges 0.0.0.0/0
fi

IP=$(gcloud compute instances describe "$NAME" --project "$PROJECT" --zone "$ZONE" \
  --format 'get(networkInterfaces[0].accessConfigs[0].natIP)')

cat <<EOF

✓ 서버가 만들어졌습니다.  공인 IP: $IP

다음 단계:
  1. DuckDNS(https://www.duckdns.org)에서 도메인을 만들고 IP 칸에 $IP 를 넣으세요.
  2. 서버에 접속:  gcloud compute ssh $NAME --project $PROJECT --zone $ZONE
  3. docs/03-server.md 의 setup.sh 단계를 따라가세요.
EOF
