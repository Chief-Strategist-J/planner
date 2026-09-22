output "service_url" {
  description = "The publicly accessible URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.planner_service.uri
}

output "artifact_registry_repository" {
  description = "The Docker Artifact Registry repository URI"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo_name}"
}

output "service_account_email" {
  description = "The Service Account email used by Cloud Run"
  value       = google_service_account.cloud_run_sa.email
}
