# 📱 Scheduler App — Flutter Mobile Client

A modern, responsive cross-platform Flutter mobile client for the **Planner & Task Scheduler** system.

---

## ✨ Features

* **Real-Time Task Tracking:** View and manage tasks categorized by project.
* **Filter by Status:** Filter tasks by `PENDING`, `IN_PROGRESS`, and `COMPLETED`.
* **Cloud Run Connected:** Communicates with the live serverless backend hosted on Google Cloud Run (`https://planner-service-715525810343.asia-south1.run.app`).
* **On-Demand Reminders Sweep:** Trigger automated email reminder sweeps directly from the app.
* **Offline-Ready Design:** Structured architecture following clean code separation (Data, Domain, Presentation).

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart         # Theme & palette tokens
│   │   └── app_endpoints.dart      # REST API endpoints
│   └── network/
│       └── api_client.dart         # HTTP client & interceptors
├── data/
│   ├── models/                     # DTOs & JSON serialization
│   └── repositories/               # Remote API implementations
├── domain/
│   ├── entities/                   # Pure business entities
│   └── repositories/               # Repository interfaces/ports
├── presentation/
│   ├── screens/                    # UI screens (Projects, Tasks, Dashboard)
│   └── widgets/                    # Reusable components
└── main.dart                       # Application entry point
```

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK `^3.19.0`
* Dart SDK `^3.3.0`
* Android Studio or Xcode (for physical device / emulator deployment)

### Setup & Execution
1. Fetch dependencies:
   ```bash
   flutter pub get
   ```
2. Run on connected device or simulator:
   ```bash
   flutter run
   ```
3. Build release APK:
   ```bash
   flutter build apk --release
   ```
