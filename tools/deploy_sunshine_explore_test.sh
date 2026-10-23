#!/usr/bin/env bash
# Deploy the TEST patio only. Never sunshine-explore, bakery-drinks, or the Phase 2 VM.
#
#   GCP_PROJECT=bakery-444323 bash tools/deploy_sunshine_explore_test.sh
#
# Service: sunshine-explore-test
# Region:  us-east1
# Scale:   min-instances 0 / max-instances 1 (same JSON file store as avatars, no Firestore)
#
# Phone session tokens verify only when ACCOUNT_SESSION_SECRET is already in the
# environment and matches bakery-drinks. This script does not read Secret Manager
# and does not print the secret. Without it, a phone gets 401, keeps the retry
# queue, and the gate board stays on the saved list.
#
# Do not point sunshine/explore_base_url or sunshine/minigolf_test_url in
# project.godot at this origin until the deploy has actually finished.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="${GCP_PROJECT:-${GOOGLE_CLOUD_PROJECT:-}}"
REGION="us-east1"
SERVICE="sunshine-explore-test"
MEMORY="${EXPLORE_MEMORY:-512Mi}"

if [[ "${EXPLORE_SERVICE:-sunshine-explore-test}" != "sunshine-explore-test" ]]; then
  echo "Refusing to deploy ${EXPLORE_SERVICE}. This script only deploys sunshine-explore-test." >&2
  exit 2
fi
if [[ "$SERVICE" == "sunshine-explore" || "$SERVICE" == "bakery-drinks" ]]; then
  echo "Refusing to deploy $SERVICE." >&2
  exit 2
fi
if [[ -n "${GCP_REGION:-}" && "${GCP_REGION}" != "us-east1" ]]; then
  echo "Refusing region ${GCP_REGION}. The test service stays in us-east1." >&2
  exit 2
fi
if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is not on PATH. Install the Google Cloud SDK and auth to bakery-444323, then retry." >&2
  exit 2
fi
if [[ -z "$PROJECT" ]]; then
  PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
fi
if [[ -z "$PROJECT" || "$PROJECT" == "(unset)" ]]; then
  echo "Set GCP_PROJECT=bakery-444323. This script does not guess a project." >&2
  exit 2
fi

IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/bakery/${SERVICE}:latest"
echo "Building $IMAGE"
gcloud builds submit \
  --project "$PROJECT" \
  --config "$ROOT/tools/cloudbuild.explore.yaml" \
  --substitutions "_REGION=${REGION},_SERVICE=${SERVICE}" \
  "$ROOT"

ENV_VARS="MINIGOLF_SCORES_PATH=/tmp/minigolf_scores.json"
if [[ -n "${ACCOUNT_SESSION_SECRET:-}" ]]; then
  ENV_VARS="${ENV_VARS},ACCOUNT_SESSION_SECRET=${ACCOUNT_SESSION_SECRET}"
else
  echo "ACCOUNT_SESSION_SECRET is unset. Phone tokens will 401 until it is set on ${SERVICE}." >&2
fi
if [[ -n "${EXPLORE_TICKET_SECRET:-}" ]]; then
  ENV_VARS="${ENV_VARS},EXPLORE_TICKET_SECRET=${EXPLORE_TICKET_SECRET}"
fi

echo "Deploying $SERVICE in $REGION (min 0 / max 1)"
gcloud run deploy "$SERVICE" \
  --project "$PROJECT" \
  --image "$IMAGE" \
  --region "$REGION" \
  --platform managed \
  --min-instances 0 \
  --max-instances 1 \
  --concurrency 80 \
  --cpu 1 \
  --memory "$MEMORY" \
  --timeout 3600 \
  --session-affinity \
  --allow-unauthenticated \
  --port 8080 \
  --cpu-throttling \
  --set-env-vars "$ENV_VARS"

ORIGIN="$(gcloud run services describe "$SERVICE" --project "$PROJECT" --region "$REGION" --format='value(status.url)')"
echo
echo "Test board origin: $ORIGIN"
echo "Health: $ORIGIN/explore/health"
echo "POST $ORIGIN/minigolf/score"
echo "GET  $ORIGIN/minigolf/top?limit=10"
echo "Set SUNSHINE_MINIGOLF_URL or user://config.cfg sunshine/minigolf_test_url to that origin on test builds only."
