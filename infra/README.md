# Infrastructure & Deployment Guide

This directory contains the automation scripts (Shell & Terraform) to provision Google Cloud Platform infrastructure and deploy the Planner Service to **Google Cloud Run** within **GCP Free Tier** limits, using the lowest-latency region for Bengaluru (`asia-south1` - Mumbai).

---

## Architecture Overview

* **Cloud Run:** Serverless container execution with auto-scaling to zero (`min-instances = 0`, `max-instances = 1`).
* **Artifact Registry:** Private Docker repository in `asia-south1`.
* **IAM Security:** Dedicated least-privilege service account (`planner-runner`) with Cloud Logging, Monitoring, and Secret Manager permissions.
* **Cost Optimization:** CPU throttling enabled (`cpu_idle = true`), allowing full free-tier eligibility (up to 2 million requests/month).

---

## Directory Structure

```
infra/
├── README.md
├── scripts/
│   ├── 01-setup-gcp.sh          # Provisions GCP APIs, IAM, and Artifact Registry
│   ├── 02-deploy-cloudrun.sh    # Builds container via Cloud Build & deploys to Cloud Run
│   └── destroy.sh               # Teardown script for service and container repo
└── terraform/
    ├── main.tf                  # Infrastructure resources (APIs, IAM, Artifact Registry, Cloud Run)
    ├── variables.tf             # Input variables with sensible defaults
    ├── outputs.tf               # Exported URIs (Service URL, Artifact Registry, SA Email)
    └── terraform.tfvars.example # Example variable values
```

---

## Option 1: Shell Scripts Deployment (Fastest)

### Step 1: Initialize GCP Project & IAM
```bash
./infra/scripts/01-setup-gcp.sh
```

### Step 2: Build & Deploy Container to Cloud Run
```bash
./infra/scripts/02-deploy-cloudrun.sh
```

### Clean Up Resources (Optional)
```bash
./infra/scripts/destroy.sh
```

---

## Option 2: Terraform Infrastructure-as-Code

### Prerequisites
Make sure `terraform` is installed on your system.

### 1. Initialize & Configure
```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
```

### 2. Plan & Apply
```bash
terraform plan
terraform apply
```

### 3. Destroy Infrastructure
```bash
terraform destroy
```

---

## Verifying Deployment

```bash
# Health Check Endpoint
curl https://planner-service-715525810343.asia-south1.run.app/health

# List Projects API
curl https://planner-service-715525810343.asia-south1.run.app/api/v1/projects
```
