#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# generate-ci-service-account-key.sh
# Grants Cloud Run deployment permissions & generates a key for GitHub Actions
# ==============================================================================

PROJECT_ID="${PROJECT_ID:-planner-app-66733}"
SERVICE_ACCOUNT_NAME="github-actions-deployer"
SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="./gcp-sa-key.json"

echo "=========================================================="
echo "Creating GitHub Actions CI/CD Deployer Service Account"
echo "Project ID: ${PROJECT_ID}"
echo "=========================================================="

# 1. Create dedicated CI Service Account
if gcloud iam service-accounts describe "${SA_EMAIL}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "[INFO] Service account ${SA_EMAIL} already exists."
else
  echo "[INFO] Creating service account ${SERVICE_ACCOUNT_NAME}..."
  gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
    --project="${PROJECT_ID}" \
    --display-name="GitHub Actions Cloud Run Deployer"
  sleep 3
fi

# 2. Grant Required Roles
echo "[INFO] Granting required Cloud Run & IAM roles..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.admin" --condition=None

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser" --condition=None

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.reader" --condition=None

# 3. Generate Key File
echo "[INFO] Generating JSON key..."
gcloud iam service-accounts keys create "${KEY_FILE}" \
  --iam-account="${SA_EMAIL}" \
  --project="${PROJECT_ID}"

echo "=========================================================="
echo "Key generated successfully at: ${KEY_FILE}"
echo ""
echo "Next Step:"
echo "1. Go to your GitHub Repo -> Settings -> Secrets and variables -> Actions"
echo "2. Create a new secret named: GCP_SA_KEY"
echo "3. Paste the contents of ${KEY_FILE} into the secret value."
echo "4. Remove ${KEY_FILE} once copied: rm ${KEY_FILE}"
echo "=========================================================="
