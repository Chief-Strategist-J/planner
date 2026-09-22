#!/usr/bin/env bash
# ==============================================================================
# TOP-LEVEL ALGORITHM BLUEPRINT: GCP INFRASTRUCTURE SETUP & PROVISIONING
# ==============================================================================
# 1. Configuration Resolution:
#    - Evaluates and assigns project variables, region, zone, billing account,
#      service account, and artifact registry repository names with environment fallbacks.
# 2. Project Lifecycle:
#    - Checks if GCP project exists; provisions project if missing.
#    - Associates project with designated billing account.
# 3. Environment Defaults:
#    - Configures active gcloud CLI context for project, region, and compute zone.
# 4. Service Enablement:
#    - Enables Cloud Run, Artifact Registry, Cloud Build, IAM, Secret Manager,
#      Logging, Monitoring, and Compute Engine APIs.
# 5. Container Registry Provisioning:
#    - Verifies or creates Docker repository in Artifact Registry.
# 6. Service Account & Least-Privilege IAM Configuration:
#    - Provisions execution service account with logging, monitoring, and secret access.
#    - Authorizes Cloud Build service account with artifact registry write access.
# ==============================================================================
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-planner-app-66733}"
PROJECT_NAME="${PROJECT_NAME:-Planner App}"
BILLING_ACCOUNT_ID="${BILLING_ACCOUNT_ID:-01794D-EED2AE-135FE4}"
REGION="${REGION:-asia-south1}"
ZONE="${ZONE:-asia-south1-a}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME:-planner-runner}"
ARTIFACT_REPO_NAME="${ARTIFACT_REPO_NAME:-planner-repo}"

echo "=========================================================="
echo "Initializing GCP Project & Infrastructure Setup"
echo "Project ID:           ${PROJECT_ID}"
echo "Region:               ${REGION} (Closest to Bengaluru)"
echo "Billing Account:      ${BILLING_ACCOUNT_ID}"
echo "=========================================================="

if gcloud projects describe "${PROJECT_ID}" >/dev/null 2>&1; then
  echo "[INFO] Project ${PROJECT_ID} already exists."
else
  echo "[INFO] Creating project ${PROJECT_ID}..."
  gcloud projects create "${PROJECT_ID}" --name="${PROJECT_NAME}"
fi

echo "[INFO] Linking billing account ${BILLING_ACCOUNT_ID}..."
gcloud billing projects link "${PROJECT_ID}" --billing-account="${BILLING_ACCOUNT_ID}"

echo "[INFO] Configuring gcloud CLI defaults..."
gcloud config set project "${PROJECT_ID}"
gcloud config set run/region "${REGION}"
gcloud config set compute/region "${REGION}"
gcloud config set compute/zone "${ZONE}"

echo "[INFO] Enabling required Cloud APIs..."
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  iam.googleapis.com \
  secretmanager.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  compute.googleapis.com

if gcloud artifacts repositories describe "${ARTIFACT_REPO_NAME}" --location="${REGION}" >/dev/null 2>&1; then
  echo "[INFO] Artifact Registry ${ARTIFACT_REPO_NAME} already exists."
else
  echo "[INFO] Creating Artifact Registry repository ${ARTIFACT_REPO_NAME}..."
  gcloud artifacts repositories create "${ARTIFACT_REPO_NAME}" \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Docker repository for Planner app"
fi

SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "${SA_EMAIL}" >/dev/null 2>&1; then
  echo "[INFO] Service account ${SA_EMAIL} already exists."
else
  echo "[INFO] Creating service account ${SERVICE_ACCOUNT_NAME}..."
  gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
    --display-name="Planner Cloud Run Runner"
  sleep 3
fi

echo "[INFO] Applying IAM policies to ${SA_EMAIL}..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/logging.logWriter" --condition=None

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/monitoring.metricWriter" --condition=None

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor" --condition=None

# 7. Persistent Cloud Storage Bucket (Free-Tier Safe: 5GB monthly free)
BUCKET_NAME="${BUCKET_NAME:-${PROJECT_ID}-data}"
if gcloud storage buckets describe "gs://${BUCKET_NAME}" >/dev/null 2>&1; then
  echo "[INFO] Cloud Storage bucket gs://${BUCKET_NAME} already exists."
else
  echo "[INFO] Creating Cloud Storage bucket gs://${BUCKET_NAME}..."
  gcloud storage buckets create "gs://${BUCKET_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --uniform-bucket-level-access
fi

echo "[INFO] Granting storage objectAdmin to ${SA_EMAIL}..."
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"

PROJECT_NUM=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${PROJECT_NUM}@cloudbuild.gserviceaccount.com" \
  --role="roles/artifactregistry.writer" --condition=None || true

echo "=========================================================="
echo "GCP Setup Completed Successfully!"
echo "Artifact Repository: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO_NAME}"
echo "Storage Bucket:      gs://${BUCKET_NAME}"
echo "Service Account:     ${SA_EMAIL}"
echo "=========================================================="
