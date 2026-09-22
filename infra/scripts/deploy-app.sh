#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 02-deploy-cloudrun.sh - Build Docker Image & Deploy to Cloud Run (Free Tier Safe)
# ==============================================================================

PROJECT_ID="${PROJECT_ID:-planner-app-66733}"
REGION="${REGION:-asia-south1}" # Mumbai
SERVICE_NAME="${SERVICE_NAME:-planner-service}"
ARTIFACT_REPO_NAME="${ARTIFACT_REPO_NAME:-planner-repo}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO_NAME}/planner-worker:${IMAGE_TAG}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-planner-runner@${PROJECT_ID}.iam.gserviceaccount.com}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKER_DIR="$(cd "${SCRIPT_DIR}/../../worker" && pwd)"

echo "=========================================================="
echo "Building and Deploying to Cloud Run"
echo "Project ID:       ${PROJECT_ID}"
echo "Region:           ${REGION}"
echo "Service Name:     ${SERVICE_NAME}"
echo "Image URI:        ${IMAGE_URI}"
echo "Service Account:  ${SERVICE_ACCOUNT}"
echo "=========================================================="

# 1. Build and push container using Cloud Build
echo "[INFO] Submitting build to Cloud Build..."
cd "${WORKER_DIR}"
gcloud builds submit --project="${PROJECT_ID}" --tag="${IMAGE_URI}" .

# 2. Deploy to Cloud Run with Free Tier guardrails
# - min-instances: 0 (scale to zero when idle)
# - max-instances: 1 (caps instance growth to avoid surprises)
# - cpu-throttling: true (only consume compute while actively processing requests)
# - memory: 512Mi, cpu: 1
echo "[INFO] Deploying ${SERVICE_NAME} to Cloud Run in ${REGION}..."
gcloud run deploy "${SERVICE_NAME}" \
  --project="${PROJECT_ID}" \
  --image="${IMAGE_URI}" \
  --region="${REGION}" \
  --service-account="${SERVICE_ACCOUNT}" \
  --min-instances=0 \
  --max-instances=1 \
  --cpu=1 \
  --memory=512Mi \
  --concurrency=80 \
  --cpu-throttling \
  --allow-unauthenticated

SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" --project="${PROJECT_ID}" --region="${REGION}" --format="value(status.url)")

echo "=========================================================="
echo "Deployment Finished Successfully!"
echo "Service URL: ${SERVICE_URL}"
echo "Health Check: curl ${SERVICE_URL}/health"
echo "=========================================================="
