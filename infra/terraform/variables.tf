variable "project_id" {
  description = "The GCP Project ID"
  type        = string
  default     = "planner-app-66733"
}

variable "region" {
  description = "GCP Region closest to Bengaluru (Mumbai: asia-south1)"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "asia-south1-a"
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "planner-service"
}

variable "artifact_repo_name" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "planner-repo"
}

variable "service_account_name" {
  description = "Service Account name for Cloud Run"
  type        = string
  default     = "planner-runner"
}

variable "container_image" {
  description = "Container image URI for Cloud Run deployment"
  type        = string
  default     = "asia-south1-docker.pkg.dev/planner-app-66733/planner-repo/planner-worker:v1"
}

variable "min_instances" {
  description = "Minimum instances (0 for scale-to-zero Free Tier)"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum instances to prevent billing spikes"
  type        = number
  default     = 1
}

variable "cpu_limit" {
  description = "CPU allocation"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit"
  type        = string
  default     = "512Mi"
}
