#!/usr/bin/env bash
# GCP에 무료 서버(e2-micro) 한 대를 만듭니다.  ※ 선생님 맥에서 실행 (서버 안이 아님)
#
#   준비:   brew install --cask google-cloud-sdk
#           gcloud auth login
#   사용법: PROJECT=<GCP 프로젝트 ID> ./deploy/vps/create-vm.sh
#
# 콘솔에서 클릭으로도 만들 수 있지만, 명령으로 남겨 두면
# "무엇을 어떻게 만들었는지"가 기록되고 똑같이 다시 만들 수 있습니다.

set -euo pipefail

PROJECT="${PROJECT:?PROJECT=<GCP 프로젝트 ID> 를 앞에 붙여서 실행하세요}"
ZONE="${ZONE:-us-west1-b}" # 무료 티어 리전: us-west1(오리건), us-central1(아이오와), us-east1(사우스캐롤라이나)
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
