# ADR 0002: Daily Email Reminders, SMTP Configuration & Automated Working-Hours Lifecycle

* **Status:** Accepted
* **Date:** 2026-09-22
* **Deciders:** Engineering & DevOps Team
* **Project:** Planner App (`planner-app-66733`)
* **Timezone Standard:** Indian Standard Time (IST / UTC + 5:30)

---

## 1. Context and Problem Statement

The team required:
1. **Automated Daily Email Reminders:** A daily morning digest delivered to assignees summarizing all `PENDING` tasks across projects.
2. **Optimal Morning Timing:** Scheduled specifically for **10:00 AM IST** every day.
3. **Secure SMTP Email Delivery:** Standardized configuration using GitHub Repository Secrets for authenticated TLS email delivery.
4. **Data Persistence Guarantee:** Clear definition of how project and task data is preserved across service shutdowns and container restarts.
5. **Zero Off-Hours Activity:** Automatic shutdown of cloud services outside working hours (06:00 PM IST and weekends) with automated reactivation at 09:00 AM IST.

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
                               3. Scans Git-persisted project & task YAML files.
                               4. Aggregates pending tasks by assignee email.
                               5. Dispatches authenticated SMTP email digest to assignees.

06:00 PM IST (Mon–Fri)   ---> 🛑 [.github/workflows/cloud-run-schedule.yml]
                               Deletes Cloud Run service revision.
                               Zero services running overnight and on weekends ($0.00 cost).
---------------------------------------------------------------------------------------------------------
```

---

## 3. Storage Persistence & Git-Backed State Model

### Why Your Data is Not Deleted:
* **Git-Backed Persistence:** Project metadata (`project.yaml`) and task lists (`tasks.yaml`) stored under `worker/projects/` are committed and tracked in the **GitHub Git Repository**.
* **Stateless Cloud Run vs Persistent Git:** Even though Cloud Run container instances are ephemeral (they scale to 0 when idle and delete at 6:00 PM IST), the authoritative task data lives safely in **Git**.
* **Reminder Execution:** Every day at **10:00 AM IST**, GitHub Actions checks out the repository (`actions/checkout@v4`), loads the authoritative task records from Git, and evaluates pending tasks. Task data is **never lost or deleted**.

---

## 4. Email Notification System & SMTP Configuration

### 4.1 Secret Configuration Matrix
To enable email delivery without committing credentials into code, 4 secrets were configured in **GitHub Repository Settings > Secrets and variables > Actions**:

| Secret Name | Configuration Description | Configured Value / Example |
|---|---|---|
| **`SMTP_HOST`** | Outgoing SMTP mail server | `smtp.gmail.com` |
| **`SMTP_PORT`** | Encrypted TLS port | `587` |
| **`SMTP_USERNAME`** | Authenticated sender email | `jaydeep.v@blute.co.in` |
| **`SMTP_PASSWORD`** | Dedicated 16-character Google App Password | `xxxx xxxx xxxx xxxx` |

### 4.2 How the Email Password Was Generated:
1. Logged into Google Account > **Security** > **2-Step Verification**.
2. Generated a dedicated **App Password** named `Planner CI Reminder`.
3. Stored the resulting 16-character token securely in GitHub Secrets as `SMTP_PASSWORD`.

### 4.3 Dual-Mode Architecture:
The Go email adapter (`worker/src/infra/email/smtp.email.adapter.go`) dynamically evaluates available configuration:
* **`EMAIL_MODE=smtp` (Active):** When `SMTP_HOST` and credentials exist, builds standard RFC 5322 MIME email messages and dispatches them via authenticated TLS SMTP connection (`net/smtp.SendMail`).
* **`EMAIL_MODE=logger` (Fallback):** If SMTP secrets are omitted, falls back to structured console logging without breaking CI builds.

### 4.4 Email Message Digest Structure:
```text
To: <assignee@domain.com>
From: noreply@planner.internal
Subject: [Planner] Daily Pending Tasks Digest
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

Hello,

You have N pending task(s) awaiting completion:

1. [task-id] Task Title (Project: project-id | Due: YYYY-MM-DD)
   Details: Task description details...

Please review and update their statuses in the Planner API.
```

---

## 5. Schedule & Cron Conversion Table

| Schedule Purpose | Local Time (IST) | GitHub Actions UTC Schedule | Cron Expression | Days Active |
|---|---|---|---|---|
| **Daily Task Email Reminder** | **10:00 AM IST** | **04:30 UTC** *(10:00 − 5:30)* | `30 4 * * *` | Everyday |
| **Morning Service Startup** | **09:00 AM IST** | **03:30 UTC** *(09:00 − 5:30)* | `30 3 * * 1-5` | Mon – Fri |
| **Evening Service Shutdown** | **06:00 PM IST** | **12:30 UTC** *(18:00 − 5:30)* | `30 12 * * 1-5` | Mon – Fri |

---

## 6. Verification and Test Results

### 6.1 Cloud Run Lifecycle Pipeline (Run ID: `35712721544`)
* Authenticated using `GCP_SA_KEY` repository secret.
* Deployed container image to Cloud Run (`asia-south1`) in **42 seconds** with status `SUCCESS`.

### 6.2 Daily Email Reminder Pipeline (Run ID: `35713727023`)
* **Execution Mode:** `EMAIL_MODE=smtp`
* **Projects Scanned:** `1` (`cloud-initiative`)
* **Pending Tasks Found:** `1` (`task-email-verify`)
* **Recipient:** `jaydeep.v@blute.co.in`
* **Result:** `[SUCCESS] Sweep finished. Projects: 1 | Pending Tasks: 1 | Emails Dispatched: 1`
