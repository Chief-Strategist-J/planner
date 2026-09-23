# ==============================================================================
# SEPARATE LLM MICROSERVICE: GOOGLE GEMMA 2 2B (SERVERLESS CLOUD RUN)
# ==============================================================================

resource "google_cloud_run_v2_service" "gemma_service" {
  depends_on = [
    google_project_service.enabled_apis,
    google_service_account.cloud_run_sa,
    google_artifact_registry_repository.docker_repo
  ]

  name                = "gemma-service"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.cloud_run_sa.email
    timeout         = "300s"

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo_name}/gemma-service:v11"

      resources {
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
        cpu_idle = true
      }

      ports {
        container_port = 8080
      }

      env {
        name  = "NUM_THREADS"
        value = "2"
      }
    }
  }
}

# Allow Public Invocations for Gemma LLM API
resource "google_cloud_run_service_iam_member" "gemma_public_access" {
  location = google_cloud_run_v2_service.gemma_service.location
  project  = var.project_id
  service  = google_cloud_run_v2_service.gemma_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ==============================================================================
# GCP BILLING BUDGET ALERT ($1.00 FREE-TIER PROTECTION)
# ==============================================================================
resource "google_billing_budget" "planner_budget" {
  billing_account = "01794D-EED2AE-135FE4"
  display_name    = "Planner & Gemma Free Tier Budget Alert"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "1"
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }
}
