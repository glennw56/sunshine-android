#!/usr/bin/env bash
# Phase 2 patio: one always-on e2-micro. Not spot (preemption would drop the room).
# Phase 1 Cloud Run stays the client fallback.
#
# Cost (us-east1, public on-demand, before tax):
#   e2-micro ~ $6.11/mo (730h × ~$0.0084)
#   10 GB standard disk ~ $0.40/mo
#   $0 compute if the billing account's free e2-micro in us-east1 is unused
# Do not run this if that plus current bakery-444323 spend would pass $15/mo.
#
#   EXPLORE_VM_CONFIRM=1 GCP_PROJECT=bakery-444323 bash tools/deploy_explore_phase2_vm.sh
#
# Prints the health URL. Then set SUNSHINE_EXPLORE_PHASE2_URL to http://EXTERNAL_IP:8080
set -euo pipefail

PROJECT="${GCP_PROJECT:-bakery-444323}"
ZONE="${GCP_ZONE:-us-east1-b}"
NAME="${EXPLORE_VM_NAME:-sunshine-explore-vm}"
MACHINE="${EXPLORE_VM_MACHINE:-e2-micro}"

if [[ "$MACHINE" != "e2-micro" ]]; then
  echo "Refusing machine type $MACHINE. Phase 2 stays on e2-micro under the \$15 cap." >&2
  exit 2
fi
if [[ "${EXPLORE_VM_CONFIRM:-}" != "1" ]]; then
  echo "Not creating a VM. Set EXPLORE_VM_CONFIRM=1 after checking bakery-444323 spend stays under \$15/mo." >&2
  echo "Estimate: e2-micro us-east1 ~\$6.11/mo on-demand, or \$0 on the free-tier e2-micro, plus ~\$0.40 disk." >&2
  echo "Spot is intentionally not used." >&2
  exit 2
fi
if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is not on PATH." >&2
  exit 2
fi
ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
if [[ -z "$ACCOUNT" ]]; then
  echo "No gcloud login. Refusing to create $NAME." >&2
  exit 2
fi

STARTUP='#!/bin/bash
set -eux
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3 python3-venv
id -u explore >/dev/null 2>&1 || useradd --system --create-home explore
install -d -o explore -g explore /opt/sunshine-explore
if [[ ! -d /opt/sunshine-explore/venv ]]; then
  sudo -u explore python3 -m venv /opt/sunshine-explore/venv
fi
sudo -u explore /opt/sunshine-explore/venv/bin/pip install --upgrade pip
sudo -u explore /opt/sunshine-explore/venv/bin/pip install "fastapi>=0.110" "uvicorn>=0.27"
cat >/etc/systemd/system/sunshine-explore.service <<EOF
[Unit]
Description=Sunshine patio room
After=network-online.target
[Service]
User=explore
WorkingDirectory=/opt/sunshine-explore
Environment=PORT=8080
ExecStart=/opt/sunshine-explore/venv/bin/uvicorn explore_app:app --host 0.0.0.0 --port 8080
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable sunshine-explore
'

echo "Creating $NAME ($MACHINE, $ZONE) in $PROJECT as $ACCOUNT"
echo "Copy server/explore_app.py and server/explore_sim.py to /opt/sunshine-explore/ before systemctl start."
gcloud compute instances create "$NAME" \
  --project "$PROJECT" \
  --zone "$ZONE" \
  --machine-type "$MACHINE" \
  --provisioning-model STANDARD \
  --boot-disk-size 10GB \
  --boot-disk-type pd-standard \
  --image-family debian-12 \
  --image-project debian-cloud \
  --tags sunshine-explore \
  --metadata startup-script="$STARTUP"

gcloud compute firewall-rules describe sunshine-explore-8080 --project "$PROJECT" >/dev/null 2>&1 || \
  gcloud compute firewall-rules create sunshine-explore-8080 \
    --project "$PROJECT" \
    --direction INGRESS \
    --action ALLOW \
    --rules tcp:8080 \
    --target-tags sunshine-explore \
    --source-ranges 0.0.0.0/0

IP="$(gcloud compute instances describe "$NAME" --project "$PROJECT" --zone "$ZONE" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
echo "Health (after the server files are on the box and the unit is started):"
echo "  curl -s http://${IP}:8080/explore/health"
echo "Client:"
echo "  SUNSHINE_EXPLORE_PHASE2_URL=http://${IP}:8080"
