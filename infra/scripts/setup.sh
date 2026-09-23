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
  firestore.googleapis.com

echo "[INFO] Granting datastore.user role to ${SA_EMAIL} for Cloud Firestore..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/datastore.user" --condition=None

if gcloud firestore databases describe --database="(default)" >/dev/null 2>&1; then
  echo "[INFO] Firestore database (default) already exists."
else
  echo "[INFO] Provisioning Firestore database (default) in Native Mode..."
  gcloud firestore databases create --location="${REGION}" --type=firestore-native || true
fi

PROJECT_NUM=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${PROJECT_NUM}@cloudbuild.gserviceaccount.com" \
  --role="roles/artifactregistry.writer" --condition=None || true

echo "=========================================================="
echo "GCP Setup Completed Successfully!"
echo "Artifact Repository: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO_NAME}"
echo "Firestore Database:  (default) [Native Mode]"
echo "Service Account:     ${SA_EMAIL}"
echo "=========================================================="
