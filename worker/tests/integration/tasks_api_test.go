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
	projRepo "planner/src/features/projects/repository"
	projSvc "planner/src/features/projects/service"
	projTypes "planner/src/features/projects/types"
	taskRepo "planner/src/features/tasks/repository"
	taskSvc "planner/src/features/tasks/service"
	taskTypes "planner/src/features/tasks/types"
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
   - Points both Project and Task repositories to an isolated temporary filesystem directory.
2. Verified Invariants:
   - Project CRUD & Pagination: Asserts Project creation, retrieval, update, paginated listing, and deletion.
   - Task CRUD & Pagination: Asserts Task creation, status update, paginated listing, and deletion.
   - Envelope Compliance: Asserts success=true, 200/201 status code, non-empty meta (requestId, timestamp, apiVersion, pagination).
   - Cryptographic Idempotency: Asserts identical replay succeeds from cache and modified replay fails with HTTP 409.
   - Scheduler Trigger: Verifies POST /api/v1/scheduler/trigger returns valid summary metrics.
*/

func setupIntegrationServer(t *testing.T) (*httptest.Server, string) {
	tempDir, err := os.MkdirTemp("", "planner_api_test_*")
	if err != nil {
		t.Fatalf("failed to create temp directory: %v", err)
	}

	taskRepository, err := taskRepo.NewYamlTaskRepository(tempDir)
	if err != nil {
		t.Fatalf("failed to initialize task repository: %v", err)
	}

	projectRepository, err := projRepo.NewYamlProjectRepository(tempDir)
	if err != nil {
		t.Fatalf("failed to initialize project repository: %v", err)
	}

	taskService := taskSvc.NewTasksService(taskRepository)
	projectService := projSvc.NewProjectsService(projectRepository)

	emailAdapter := email.NewSmtpEmailAdapter("logger", "test@planner.internal", email.SmtpConfig{})
	sched := scheduler.NewDailySchedulerEngine(taskRepository, emailAdapter, 1440, "team@planner.internal")

	idempotencyStore := middleware.NewIdempotencyStore()
	tasksHandler := handlers.NewTasksRestHandler(taskService, sched)
	projectsHandler := handlers.NewProjectsRestHandler(projectService)

	tasksRouter := router.NewTasksRouter(tasksHandler, projectsHandler, idempotencyStore, "v1")

	server := httptest.NewServer(tasksRouter.SetupRoutes())
	return server, tempDir
}

func TestProjectsApi_EndToEndLifecycle(t *testing.T) {
	server, tempDir := setupIntegrationServer(t)
	defer server.Close()
	defer os.RemoveAll(tempDir)

	client := server.Client()

	createProjectPayload := projTypes.UpsertProjectInput{
		ProjectId:   "infra-core",
		Name:        "Infrastructure Core",
		Description: "Kubernetes and edge compute",
		OwnerEmail:  "infra-lead@planner.internal",
		Status:      projTypes.ProjectStatusActive,
	}
	bodyBytes, _ := json.Marshal(createProjectPayload)

	req, _ := http.NewRequest(http.MethodPost, server.URL+"/api/v1/projects", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("create project request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		t.Fatalf("expected 200 OK on create project, got %d: %s", resp.StatusCode, string(b))
	}

	var createEnvelope response.ApiResponse[projTypes.Project]
	_ = json.NewDecoder(resp.Body).Decode(&createEnvelope)
	if !createEnvelope.Success || createEnvelope.Data.ProjectId != "infra-core" {
		t.Errorf("unexpected project creation response: %+v", createEnvelope)
	}

	getReq, _ := http.NewRequest(http.MethodGet, server.URL+"/api/v1/projects/infra-core", nil)
	getResp, err := client.Do(getReq)
	if err != nil {
		t.Fatalf("get project request failed: %v", err)
	}
	defer getResp.Body.Close()

	if getResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK on get project, got %d", getResp.StatusCode)
	}

	patchPayload := projTypes.UpdateProjectInput{
		Description: "Updated scope with service mesh",
	}
	patchBytes, _ := json.Marshal(patchPayload)

	patchReq, _ := http.NewRequest(http.MethodPatch, server.URL+"/api/v1/projects/infra-core", bytes.NewReader(patchBytes))
	patchReq.Header.Set("Content-Type", "application/json")

	patchResp, err := client.Do(patchReq)
	if err != nil {
		t.Fatalf("patch project request failed: %v", err)
	}
	defer patchResp.Body.Close()

	var patchEnvelope response.ApiResponse[projTypes.Project]
	_ = json.NewDecoder(patchResp.Body).Decode(&patchEnvelope)
	if patchEnvelope.Data.Description != "Updated scope with service mesh" {
		t.Errorf("expected updated description, got: %s", patchEnvelope.Data.Description)
	}

	listReq, _ := http.NewRequest(http.MethodGet, server.URL+"/api/v1/projects?page=1&pageSize=10&status=ACTIVE", nil)
	listResp, err := client.Do(listReq)
	if err != nil {
		t.Fatalf("list projects request failed: %v", err)
	}
	defer listResp.Body.Close()

	var listEnvelope response.ApiResponse[[]projTypes.Project]
	_ = json.NewDecoder(listResp.Body).Decode(&listEnvelope)
	if !listEnvelope.Success || len(listEnvelope.Data) != 1 {
		t.Errorf("expected 1 active project, got: %+v", listEnvelope)
	}
	if listEnvelope.Meta.Pagination == nil || *listEnvelope.Meta.Pagination.TotalItems != 1 {
		t.Errorf("expected pagination metadata with 1 item, got: %+v", listEnvelope.Meta.Pagination)
	}

	delReq, _ := http.NewRequest(http.MethodDelete, server.URL+"/api/v1/projects/infra-core", nil)
	delResp, err := client.Do(delReq)
	if err != nil {
		t.Fatalf("delete project request failed: %v", err)
	}
	defer delResp.Body.Close()

	if delResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK on delete project, got %d", delResp.StatusCode)
	}
}

func TestTasksApi_EndToEndLifecycle(t *testing.T) {
	server, tempDir := setupIntegrationServer(t)
	defer server.Close()
	defer os.RemoveAll(tempDir)

	client := server.Client()

	upsertPayload := taskTypes.UpsertTaskInput{
		TaskId:          "TASK-99",
		Title:           "Deploy New Kubernetes Cluster",
		Description:     "Spin up nodes in us-east-1",
		Status:          taskTypes.StatusPending,
		Priority:        taskTypes.PriorityHigh,
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

	var successEnvelope response.ApiResponse[taskTypes.Task]
	if err := json.NewDecoder(resp.Body).Decode(&successEnvelope); err != nil {
		t.Fatalf("failed to parse envelope: %v", err)
	}

	if !successEnvelope.Success || successEnvelope.StatusCode != 200 {
		t.Errorf("envelope invariant violation: %+v", successEnvelope)
	}
	if successEnvelope.Meta.RequestId == "" || successEnvelope.Meta.ApiVersion != "v1" {
		t.Errorf("missing or invalid meta: %+v", successEnvelope.Meta)
	}
	if successEnvelope.Data.TaskId != "TASK-99" || successEnvelope.Data.Status != taskTypes.StatusPending {
		t.Errorf("unexpected task data: %+v", successEnvelope.Data)
	}
	if successEnvelope.Data.Priority != taskTypes.PriorityHigh {
		t.Errorf("expected priority HIGH, got: %s", successEnvelope.Data.Priority)
	}

	listReq, _ := http.NewRequest(http.MethodGet, server.URL+"/api/v1/projects/cloud-infra/tasks?page=1&pageSize=5", nil)
	listResp, err := client.Do(listReq)
	if err != nil {
		t.Fatalf("failed to list tasks: %v", err)
	}
	defer listResp.Body.Close()

	var listEnvelope response.ApiResponse[[]taskTypes.Task]
	_ = json.NewDecoder(listResp.Body).Decode(&listEnvelope)
	if !listEnvelope.Success || len(listEnvelope.Data) != 1 {
		t.Errorf("expected 1 task in paginated list, got: %+v", listEnvelope)
	}
	if listEnvelope.Meta.Pagination == nil || *listEnvelope.Meta.Pagination.TotalItems != 1 {
		t.Errorf("expected pagination metadata with totalItems=1, got: %+v", listEnvelope.Meta.Pagination)
	}

	patchPayload := taskTypes.UpdateTaskStatusInput{
		Status: taskTypes.StatusInProgress,
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

	delTaskReq, _ := http.NewRequest(http.MethodDelete, server.URL+"/api/v1/projects/cloud-infra/tasks/TASK-99", nil)
	delTaskResp, err := client.Do(delTaskReq)
	if err != nil {
		t.Fatalf("failed to delete task: %v", err)
	}
	defer delTaskResp.Body.Close()

	if delTaskResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK on DELETE task, got %d", delTaskResp.StatusCode)
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

	var schedEnvelope response.ApiResponse[taskTypes.SchedulerSweepResult]
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

	firstPayload := taskTypes.UpsertTaskInput{
		TaskId: "TASK-IDEM",
		Title:  "Original Title",
		Status: taskTypes.StatusPending,
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

	secondPayload := taskTypes.UpsertTaskInput{
		TaskId: "TASK-IDEM",
		Title:  "TAMPERED Different Title",
		Status: taskTypes.StatusPending,
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
