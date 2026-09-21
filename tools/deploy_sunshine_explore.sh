#!/usr/bin/env bash
# Persist the patio on Cloud Run under the $15/mo bakery GCP cap.
# min-instances 0 / max-instances 1 → $0 idle, one shared room when anyone is on the lawn.
#
#   GCP_PROJECT=your-project bash tools/deploy_sunshine_explore.sh
#
# Prints the HTTPS origin. Point sunshine/explore_base_url at that URL.
# Transport: WSS /explore/ws (Google TLS) with HTTPS POST /explore/tick fallback.
# No e2-micro game VM. No Play upload.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="${GCP_PROJECT:-${GOOGLE_CLOUD_PROJECT:-}}"
REGION="${GCP_REGION:-us-east1}"
SERVICE="${EXPLORE_SERVICE:-sunshine-explore}"
MEMORY="${EXPLORE_MEMORY:-512Mi}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is not on PATH. Install the Google Cloud SDK, then retry." >&2
  exit 2
fi
if [[ -z "$PROJECT" ]]; then
  PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
fi
if [[ -z "$PROJECT" || "$PROJECT" == "(unset)" ]]; then
  echo "Set GCP_PROJECT to the bakery Cloud Run project (same one as bakery-drinks)." >&2
  exit 2
fi

IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/bakery/${SERVICE}:latest"
echo "Building $IMAGE"
gcloud builds submit --project "$PROJECT" --tag "$IMAGE" --file server/Dockerfile.explore "$ROOT"

ARGS=(
  --project "$PROJECT"
  --image "$IMAGE"
  --region "$REGION"
  --platform managed
  --min-instances 0
  --max-instances 1
  --concurrency 80
  --cpu 1
  --memory "$MEMORY"
  --timeout 3600
  --session-affinity
  --allow-unauthenticated
  --port 8080
  --cpu-throttling
)
if [[ -n "${EXPLORE_TICKET_SECRET:-}" ]]; then
  ARGS+=(--set-env-vars "EXPLORE_TICKET_SECRET=${EXPLORE_TICKET_SECRET}")
fi

echo "Deploying $SERVICE (min 0 / max 1)"
gcloud run deploy "$SERVICE" "${ARGS[@]}"

ORIGIN="$(gcloud run services describe "$SERVICE" --project "$PROJECT" --region "$REGION" --format='value(status.url)')"
echo
echo "Persistent patio origin: $ORIGIN"
echo "Health: $ORIGIN/explore/health"
echo "Wire project.godot sunshine/explore_base_url to that origin, then export a debug APK."
echo "Monthly add: ~\$0 idle, typically under \$2 if the patio is used a few hours. Stays inside the \$15 cap."
