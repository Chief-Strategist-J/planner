terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# 1. Enable Required Google Cloud APIs
locals {
  services = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "compute.googleapis.com"
  ]
}

resource "google_project_service" "enabled_apis" {
  for_each                   = toset(local.services)
  project                    = var.project_id
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false
}

# 2. Artifact Registry Docker Repository
resource "google_artifact_registry_repository" "docker_repo" {
  depends_on    = [google_project_service.enabled_apis]
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_repo_name
  description   = "Docker repository for Planner App"
  format        = "DOCKER"
}

# 3. Dedicated Service Account for Cloud Run
resource "google_service_account" "cloud_run_sa" {
  depends_on   = [google_project_service.enabled_apis]
  project      = var.project_id
  account_id   = var.service_account_name
  display_name = "Planner Cloud Run Runner"
}

# 4. IAM Role Bindings for Service Account (Least Privilege)
resource "google_project_iam_member" "sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "sa_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "sa_secretmanager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# 5. Persistent Google Cloud Storage Bucket (5GB Monthly Free Tier)
resource "google_storage_bucket" "data_bucket" {
  depends_on                  = [google_project_service.enabled_apis]
  name                        = var.gcs_bucket_name
  location                    = var.region
  project                     = var.project_id
  force_destroy               = false
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "sa_storage_admin" {
  bucket = google_storage_bucket.data_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# 6. Cloud Run v2 Service (Free Tier Enforced with Persistent GCS Volume)
resource "google_cloud_run_v2_service" "planner_service" {
  depends_on = [
    google_project_service.enabled_apis,
    google_service_account.cloud_run_sa,
    google_artifact_registry_repository.docker_repo,
    google_storage_bucket.data_bucket,
    google_storage_bucket_iam_member.sa_storage_admin
  ]

  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloud_run_sa.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.container_image

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        # cpu_idle = true enables CPU throttling for Free Tier eligibility
        cpu_idle = true
      }

      ports {
        container_port = 8080
      }

      env {
        name  = "PROJECTS_DIR"
        value = "/app/projects"
      }
      env {
        name  = "CONFIG_PATH"
        value = "/app/config/default.yaml"
      }

      volume_mounts {
        name       = "planner-data"
        mount_path = "/app/projects"
      }
    }

    volumes {
      name = "planner-data"
      gcs {
        bucket    = google_storage_bucket.data_bucket.name
        read_only = false
      }
    }
  }
}

# 7. Allow Public (Unauthenticated) Invocations for the Web Service
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.planner_service.location
  project  = var.project_id
  service  = google_cloud_run_v2_service.planner_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
