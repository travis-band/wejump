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

PROJECT="${PROJECT:?put PROJECT=<GCP project ID> in front of the command}"
ZONE="${ZONE:-us-west1-b}" # Free-tier regions: us-west1 (Oregon), us-central1 (Iowa), us-east1 (South Carolina)
NAME="${NAME:-wejump}"

echo "1) Enable the Compute Engine API"
gcloud services enable compute.googleapis.com --project "$PROJECT"

echo "2) Create the server (VM): e2-micro, Ubuntu 24.04, 30GB standard disk → within the free tier"
gcloud compute instances create "$NAME" \
  --project "$PROJECT" \
  --zone "$ZONE" \
  --machine-type e2-micro \
  --image-family ubuntu-2404-lts-amd64 \
  --image-project ubuntu-os-cloud \
  --boot-disk-size 30GB \
  --boot-disk-type pd-standard \
  --tags wejump-web

echo "3) Firewall: open only 80 (HTTP) and 443 (HTTPS) to the internet. The database port (5432) stays closed."
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

✓ The server has been created.  Public IP: $IP

Next steps:
  1. Create a domain on DuckDNS (https://www.duckdns.org) and put $IP in the IP field.
  2. Log in to the server:  gcloud compute ssh $NAME --project $PROJECT --zone $ZONE
  3. Follow the setup.sh steps in docs/03-server.md.
EOF
