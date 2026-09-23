#!/usr/bin/env bash
# ==============================================================================
# SEPARATE DEPLOYMENT SCRIPT: GEMMA 2B LLM MICROSERVICE
# ==============================================================================
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-planner-app-66733}"
REGION="${REGION:-asia-south1}"
SERVICE_NAME="gemma-service"
ARTIFACT_REPO_NAME="${ARTIFACT_REPO_NAME:-planner-repo}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO_NAME}/${SERVICE_NAME}:${IMAGE_TAG}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-planner-runner@${PROJECT_ID}.iam.gserviceaccount.com}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEMMA_DIR="$(cd "${SCRIPT_DIR}/../../gemma-service" && pwd)"

echo "=========================================================="
echo "Building & Deploying Gemma 2B LLM Microservice"
echo "Project ID:      ${PROJECT_ID}"
echo "Region:          ${REGION}"
echo "Service Name:    ${SERVICE_NAME}"
echo "Image URI:       ${IMAGE_URI}"
echo "=========================================================="

echo "[INFO] Authenticating Docker to Google Artifact Registry..."
TOKEN=$(gcloud auth application-default print-access-token)
echo "${TOKEN}" | docker login -u oauth2accesstoken --password-stdin "https://${REGION}-docker.pkg.dev"

echo "[INFO] Building Docker container image locally..."
docker build -t "${IMAGE_URI}" "${GEMMA_DIR}"

echo "[INFO] Pushing image to Google Artifact Registry..."
docker push "${IMAGE_URI}"

echo "[INFO] Deploying ${SERVICE_NAME} to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
  --project="${PROJECT_ID}" \
  --image="${IMAGE_URI}" \
  --region="${REGION}" \
  --service-account="${SERVICE_ACCOUNT}" \
  --cpu=2 \
  --memory=4Gi \
  --min-instances=0 \
  --max-instances=1 \
  --concurrency=80 \
  --cpu-throttling \
  --allow-unauthenticated

SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" --project="${PROJECT_ID}" --region="${REGION}" --format="value(status.url)")

echo "=========================================================="
echo "Gemma 2B Service Deployed Successfully!"
echo "Endpoint URL: ${SERVICE_URL}"
echo "Health Check: curl ${SERVICE_URL}/health"
echo "Chat API:     curl -X POST ${SERVICE_URL}/v1/chat/completions"
echo "=========================================================="
