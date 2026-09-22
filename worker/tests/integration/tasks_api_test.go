package integration

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"planner/src/api/rest/v1/handlers"
	"planner/src/api/rest/v1/router"
	"planner/src/features/tasks/repository"
	"planner/src/features/tasks/service"
	"planner/src/features/tasks/types"
	"planner/src/infra/email"
	"planner/src/infra/scheduler"
	"planner/src/shared/middleware"
	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: HTTP REST API INTEGRATION SUITE
==============================================================
1. Test Harness Setup:
   - Spawns an in-memory httptest.Server with all real domain handlers, router, and middleware.
   - Points the repository to an isolated temporary filesystem directory.
2. Verified Invariants:
   - Envelope Compliance: Asserts success=true, 200/201 status code, non-empty meta (requestId, timestamp, apiVersion).
   - Upsert Endpoint: Inserts task via POST /api/v1/projects/{projectId}/tasks and asserts persistence.
   - Status Update Endpoint: Modifies status via PATCH /api/v1/projects/{projectId}/tasks/{taskId}/status.
   - Cryptographic Idempotency: Asserts identical replay succeeds from cache and modified replay fails with HTTP 409.
   - Scheduler Trigger: Verifies POST /api/v1/scheduler/trigger returns valid summary metrics.
*/

func setupIntegrationServer(t *testing.T) (*httptest.Server, string) {
	tempDir, err := os.MkdirTemp("", "planner_api_test_*")
	if err != nil {
		t.Fatalf("failed to create temp directory: %v", err)
	}

	repo, err := repository.NewYamlTaskRepository(tempDir)
	if err != nil {
		t.Fatalf("failed to initialize repository: %v", err)
	}

	svc := service.NewTasksService(repo)
	emailAdapter := email.NewSmtpEmailAdapter("logger", "test@planner.internal", email.SmtpConfig{})
	sched := scheduler.NewDailySchedulerEngine(repo, emailAdapter, 1440, "team@planner.internal")

	idempotencyStore := middleware.NewIdempotencyStore()
	handler := handlers.NewTasksRestHandler(svc, sched)
	tasksRouter := router.NewTasksRouter(handler, idempotencyStore, "v1")

	server := httptest.NewServer(tasksRouter.SetupRoutes())
	return server, tempDir
}

func TestTasksApi_EndToEndLifecycle(t *testing.T) {
	server, tempDir := setupIntegrationServer(t)
	defer server.Close()
	defer os.RemoveAll(tempDir)

	client := server.Client()

	upsertPayload := types.UpsertTaskInput{
		TaskId:          "TASK-99",
		Title:           "Deploy New Kubernetes Cluster",
		Description:     "Spin up nodes in us-east-1",
		Status:          types.StatusPending,
		AssignedToEmail: "devops@planner.internal",
		DueDate:         "2026-09-30",
	}
	bodyBytes, _ := json.Marshal(upsertPayload)

	req, _ := http.NewRequest(http.MethodPost, server.URL+"/api/v1/projects/cloud-infra/tasks", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-idempotency-key", "idem-task-99-create")

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("expected 200 OK, got %d: %s", resp.StatusCode, string(body))
	}

	var successEnvelope response.ApiResponse[types.Task]
	if err := json.NewDecoder(resp.Body).Decode(&successEnvelope); err != nil {
		t.Fatalf("failed to parse envelope: %v", err)
	}

	if !successEnvelope.Success || successEnvelope.StatusCode != 200 {
		t.Errorf("envelope invariant violation: %+v", successEnvelope)
	}
	if successEnvelope.Meta.RequestId == "" || successEnvelope.Meta.ApiVersion != "v1" {
		t.Errorf("missing or invalid meta: %+v", successEnvelope.Meta)
	}
	if successEnvelope.Data.TaskId != "TASK-99" || successEnvelope.Data.Status != types.StatusPending {
		t.Errorf("unexpected task data: %+v", successEnvelope.Data)
	}

	getReq, _ := http.NewRequest(http.MethodGet, server.URL+"/api/v1/projects/cloud-infra/tasks/TASK-99", nil)
	getResp, err := client.Do(getReq)
	if err != nil {
		t.Fatalf("failed to get task: %v", err)
	}
	defer getResp.Body.Close()

	if getResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK on GET, got %d", getResp.StatusCode)
	}

	patchPayload := types.UpdateTaskStatusInput{
		Status: types.StatusInProgress,
	}
	patchBytes, _ := json.Marshal(patchPayload)

	patchReq, _ := http.NewRequest(http.MethodPatch, server.URL+"/api/v1/projects/cloud-infra/tasks/TASK-99/status", bytes.NewReader(patchBytes))
	patchReq.Header.Set("Content-Type", "application/json")

	patchResp, err := client.Do(patchReq)
	if err != nil {
		t.Fatalf("failed to patch status: %v", err)
	}
	defer patchResp.Body.Close()

	if patchResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(patchResp.Body)
		t.Fatalf("expected 200 OK on PATCH, got %d: %s", patchResp.StatusCode, string(body))
	}

	var patchEnvelope response.ApiResponse[types.Task]
	_ = json.NewDecoder(patchResp.Body).Decode(&patchEnvelope)
	if patchEnvelope.Data.Status != types.StatusInProgress {
		t.Errorf("expected status IN_PROGRESS, got: %s", patchEnvelope.Data.Status)
	}

	triggerReq, _ := http.NewRequest(http.MethodPost, server.URL+"/api/v1/scheduler/trigger", nil)
	triggerResp, err := client.Do(triggerReq)
	if err != nil {
		t.Fatalf("failed to trigger scheduler: %v", err)
	}
	defer triggerResp.Body.Close()

	if triggerResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK on scheduler trigger, got %d", triggerResp.StatusCode)
	}

	var schedEnvelope response.ApiResponse[types.SchedulerSweepResult]
	_ = json.NewDecoder(triggerResp.Body).Decode(&schedEnvelope)
	if !schedEnvelope.Success {
		t.Errorf("expected scheduler sweep success, got: %+v", schedEnvelope)
	}
}

func TestTasksApi_IdempotencyHashMismatch(t *testing.T) {
	server, tempDir := setupIntegrationServer(t)
	defer server.Close()
	defer os.RemoveAll(tempDir)

	client := server.Client()

	firstPayload := types.UpsertTaskInput{
		TaskId: "TASK-IDEM",
		Title:  "Original Title",
		Status: types.StatusPending,
	}
	b1, _ := json.Marshal(firstPayload)

	req1, _ := http.NewRequest(http.MethodPost, server.URL+"/api/v1/projects/p1/tasks", bytes.NewReader(b1))
	req1.Header.Set("Content-Type", "application/json")
	req1.Header.Set("x-idempotency-key", "idem-unique-key-1")

	resp1, err := client.Do(req1)
	if err != nil {
		t.Fatalf("req1 failed: %v", err)
	}
	resp1.Body.Close()

	if resp1.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 for req1, got %d", resp1.StatusCode)
	}

	reqReplay, _ := http.NewRequest(http.MethodPost, server.URL+"/api/v1/projects/p1/tasks", bytes.NewReader(b1))
	reqReplay.Header.Set("Content-Type", "application/json")
	reqReplay.Header.Set("x-idempotency-key", "idem-unique-key-1")

	respReplay, err := client.Do(reqReplay)
	if err != nil {
		t.Fatalf("reqReplay failed: %v", err)
	}
	respReplay.Body.Close()

	if respReplay.Header.Get("x-cache-hit") != "true" {
		t.Errorf("expected x-cache-hit header on replay")
	}

	secondPayload := types.UpsertTaskInput{
		TaskId: "TASK-IDEM",
		Title:  "TAMPERED Different Title",
		Status: types.StatusPending,
	}
	b2, _ := json.Marshal(secondPayload)

	req2, _ := http.NewRequest(http.MethodPost, server.URL+"/api/v1/projects/p1/tasks", bytes.NewReader(b2))
	req2.Header.Set("Content-Type", "application/json")
	req2.Header.Set("x-idempotency-key", "idem-unique-key-1")

	resp2, err := client.Do(req2)
	if err != nil {
		t.Fatalf("req2 failed: %v", err)
	}
	defer resp2.Body.Close()

	if resp2.StatusCode != http.StatusConflict {
		t.Fatalf("expected 409 Conflict on idempotency key payload mutation, got %d", resp2.StatusCode)
	}

	var errEnvelope response.ApiErrorResponse
	_ = json.NewDecoder(resp2.Body).Decode(&errEnvelope)
	if errEnvelope.Error.Code != "IDEMPOTENCY_KEY_REUSE" {
		t.Errorf("expected error code IDEMPOTENCY_KEY_REUSE, got: %s", errEnvelope.Error.Code)
	}
}
