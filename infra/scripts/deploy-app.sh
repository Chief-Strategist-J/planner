#!/usr/bin/env bash
# ==============================================================================
# TOP-LEVEL ALGORITHM BLUEPRINT: CLOUD RUN CONTAINER DEPLOYMENT
# ==============================================================================
# 1. Environment & Target Resolution:
#    - Resolves GCP Project ID, region, Cloud Run service name, artifact repo,
#      image tag, fully-qualified image URI, and execution service account.
#    - Resolves script directory and relative path to worker context directory.
# 2. Container Build & Image Dispatch:
#    - Submits container build context to Cloud Build.
#    - Tags and pushes immutable Docker container image to Google Artifact Registry.
# 3. Serverless Service Deployment (Free-Tier Safe):
#    - Deploys container image to Google Cloud Run.
#    - Configures scale-to-zero (min-instances=0) and max-instances=1 to avoid cost spikes.
#    - Enforces 512Mi memory limit, 1 vCPU, concurrency 80, and active CPU throttling.
#    - Sets allow-unauthenticated to permit HTTP ingress.
# 4. Service Discovery & Verification:
#    - Queries deployed service endpoint URL and displays health check command.
# ==============================================================================
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-planner-app-66733}"
REGION="${REGION:-asia-south1}"
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

echo "[INFO] Submitting build to Cloud Build..."
cd "${WORKER_DIR}"
gcloud builds submit --project="${PROJECT_ID}" --tag="${IMAGE_URI}" .

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
