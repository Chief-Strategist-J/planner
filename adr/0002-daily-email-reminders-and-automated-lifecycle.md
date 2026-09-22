# ADR 0002: Daily Email Reminders & Automated Working-Hours Lifecycle

* **Status:** Accepted
* **Date:** 2026-09-22
* **Deciders:** Engineering & DevOps Team
* **Project:** Planner App (`planner-app-66733`)
* **Timezone Standard:** Indian Standard Time (IST / UTC + 5:30)

---

## 1. Context and Problem Statement

The team required:
1. **Automated Daily Email Reminders:** A daily morning notification summarizing all `PENDING` tasks across projects, sent to respective task assignees.
2. **Optimal Morning Timing:** Scheduled specifically for **10:00 AM IST** every day.
3. **Zero Off-Hours Activity:** Automatic shutdown/removal of cloud services outside working hours (after 06:00 PM IST and weekends) with automated reactivation at 09:00 AM IST.
4. **CI/CD Integration:** Centralized management via GitHub Actions utilizing secure, ephemeral credentials (`GCP_SA_KEY`).

---

## 2. Decision & Architecture

We established a dual-pipeline automation strategy in GitHub Actions aligned with Indian Standard Time:

```
Timeline (IST / Bengaluru):
---------------------------------------------------------------------------------------------------------
09:00 AM IST (Mon–Fri)   ---> 🚀 [.github/workflows/cloud-run-schedule.yml]
                               Deploys & starts Cloud Run service in asia-south1.
                               Service is online for daily requests.

10:00 AM IST (Daily)     ---> 📧 [.github/workflows/daily-reminder.yml]
                               1. Triggers live Cloud Run scheduler endpoint (/api/v1/scheduler/trigger).
                               2. Runs Go sweep engine (server/main.go --sweep-only).
                               3. Aggregates pending tasks by assignee email.
                               4. Dispatches email digest via SMTP / logs summary table to GitHub Actions.

06:00 PM IST (Mon–Fri)   ---> 🛑 [.github/workflows/cloud-run-schedule.yml]
                               Deletes Cloud Run service revision.
                               Zero services running overnight and on weekends ($0.00 cost).
---------------------------------------------------------------------------------------------------------
```

---

## 3. How the Email Reminder Works

### Step-by-Step Execution:
1. **Project Scan:** The Go Daily Scheduler Engine (`worker/src/infra/scheduler/daily.scheduler.go`) iterates across all projects in storage (`/app/projects` or `./projects`).
2. **Pending Task Filtering:** Identifies all tasks where `status == "PENDING"`.
3. **Recipient Grouping:**
   * If `assignedToEmail` is specified, assigns the task to that user's digest.
   * If unassigned, groups under the configured fallback email (`team@planner.internal` / project owner).
4. **Email Dispatch:**
   * Uses `SmtpEmailAdapter` with environment variables (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`).
   * When secrets are provided, dispatches authenticated SMTP emails.
   * When in local/test mode without SMTP secrets, outputs formatted notification logs.
5. **Job Summary Output:** Formats a structured Markdown table directly inside the GitHub Actions execution log (`$GITHUB_STEP_SUMMARY`) displaying:
   * Project ID & Name
   * Task Title & Description
   * Priority (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`)
   * Due Date & Assignee Email

---

## 4. Schedule & Cron Conversion Table

Because GitHub Actions schedules operate in UTC, the expressions are translated as follows:

| Schedule Purpose | Local Time (IST) | GitHub Actions UTC Schedule | Cron Expression | Days Active |
|---|---|---|---|---|
| **Daily Task Email Reminder** | **10:00 AM IST** | **04:30 UTC** *(10:00 − 5:30)* | `30 4 * * *` | Everyday |
| **Morning Service Startup** | **09:00 AM IST** | **03:30 UTC** *(09:00 − 5:30)* | `30 3 * * 1-5` | Mon – Fri |
| **Evening Service Shutdown** | **06:00 PM IST** | **12:30 UTC** *(18:00 − 5:30)* | `30 12 * * 1-5` | Mon – Fri |

---

## 5. Security & Authentication

* **GitHub Secret `GCP_SA_KEY`:** Contains the JSON key for `github-actions-deployer@planner-app-66733.iam.gserviceaccount.com`.
* **Least-Privilege Roles:**
  * `roles/run.admin` (Manage Cloud Run deployments and deletions)
  * `roles/iam.serviceAccountUser` (Impersonate `planner-runner` service account)
  * `roles/artifactregistry.reader` (Pull container images)
* **Zero Disk Artifacts:** Key files are excluded in `.gitignore` (`*-key.json`) and removed from local storage.

---

## 6. Verification and Status

* **Workflow Test Run:** Executed with GitHub Actions run ID `35712721544`.
* **Result:** Deployed and verified in **42 seconds** (`Status: Success`).
* **Endpoint Confirmation:** `https://planner-service-715525810343.asia-south1.run.app/health` returned HTTP 200 OK.
