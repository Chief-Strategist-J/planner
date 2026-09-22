#!/usr/bin/env bash
# ==============================================================================
# TOP-LEVEL ALGORITHM BLUEPRINT: INFRASTRUCTURE TEARDOWN & CLEANUP
# ==============================================================================
# 1. Environment & Target Resolution:
#    - Resolves target Project ID, region, Cloud Run service name, and artifact repository.
# 2. Destructive Action Confirmation:
#    - Prompts user for interactive confirmation before proceeding with deletion.
# 3. Resource De-provisioning:
#    - Deletes Cloud Run service instance.
#    - Deletes Artifact Registry Docker repository and all stored container images.
# ==============================================================================
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-planner-app-66733}"
REGION="${REGION:-asia-south1}"
SERVICE_NAME="${SERVICE_NAME:-planner-service}"
ARTIFACT_REPO_NAME="${ARTIFACT_REPO_NAME:-planner-repo}"

read -p "Are you sure you want to delete ${SERVICE_NAME} and ${ARTIFACT_REPO_NAME} in ${PROJECT_ID}? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "[INFO] Deleting Cloud Run service ${SERVICE_NAME}..."
  gcloud run services delete "${SERVICE_NAME}" --project="${PROJECT_ID}" --region="${REGION}" --quiet || true

  echo "[INFO] Deleting Artifact Registry repository ${ARTIFACT_REPO_NAME}..."
  gcloud artifacts repositories delete "${ARTIFACT_REPO_NAME}" --project="${PROJECT_ID}" --location="${REGION}" --quiet || true

  echo "[INFO] Cleanup completed."
else
  echo "[INFO] Aborted."
fi
