# ==============================================================================
# Declarative Imports (Terraform 1.5+)
# Automatically adopts existing GCP resources into Terraform state if present,
# preventing 409 Conflict errors during terraform apply.
# ==============================================================================

import {
  to = google_service_account.cloud_run_sa
  id = "projects/${var.project_id}/serviceAccounts/${var.service_account_name}@${var.project_id}.iam.gserviceaccount.com"
}

import {
  to = google_artifact_registry_repository.docker_repo
  id = "projects/${var.project_id}/locations/${var.region}/repositories/${var.artifact_repo_name}"
}

import {
  to = google_cloud_run_v2_service.planner_service
  id = "projects/${var.project_id}/locations/${var.region}/services/${var.service_name}"
}

import {
  to = google_storage_bucket.data_bucket
  id = var.gcs_bucket_name
}

