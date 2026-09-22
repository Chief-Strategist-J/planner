package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"planner/src/features/tasks/service"
	"planner/src/features/tasks/types"
	"planner/src/infra/scheduler"
	"planner/src/shared/errors"
	"planner/src/shared/middleware"
	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: TASKS REST TRANSPORT HANDLER
===========================================================
1. Ingress Validation & Context Extraction:
   - Extracts tracing metadata (requestId, correlationId, causationId, startTime, apiVersion) from context.
   - Enforces closed, bounded JSON deserialization on request bodies.
2. Standardized Envelope Serialization:
   - Encapsulates domain outcomes inside the mandatory ApiResponse[T] envelope (success: true, statusCode, data, meta).
   - Returns paginated collection envelope with meta.pagination for ListTasks.
   - Maps errors directly to ApiErrorResponse (success: false, statusCode, error: {code, message, retryable}, meta).
3. Handled Endpoints:
   - UpsertTask: POST /api/v1/projects/{projectId}/tasks
   - ListTasks:  GET /api/v1/projects/{projectId}/tasks?page=1&pageSize=10&status=PENDING
   - GetTaskById: GET /api/v1/projects/{projectId}/tasks/{taskId}
   - UpdateTaskStatus: PATCH /api/v1/projects/{projectId}/tasks/{taskId}/status
   - DeleteTask: DELETE /api/v1/projects/{projectId}/tasks/{taskId}
   - TriggerSchedulerSweep: POST /api/v1/scheduler/trigger
*/

type TasksRestHandler struct {
	service   *service.TasksService
	scheduler *scheduler.DailySchedulerEngine
}

func NewTasksRestHandler(service *service.TasksService, scheduler *scheduler.DailySchedulerEngine) *TasksRestHandler {
	return &TasksRestHandler{
		service:   service,
		scheduler: scheduler,
	}
}

func (h *TasksRestHandler) extractMeta(r *http.Request) response.Meta {
	reqId, _ := r.Context().Value(middleware.ContextKeyRequestId).(string)
	corrId, _ := r.Context().Value(middleware.ContextKeyCorrelationId).(string)
	causationId, _ := r.Context().Value(middleware.ContextKeyCausationId).(string)
	apiVersion, _ := r.Context().Value(middleware.ContextKeyApiVersion).(string)
	startTime, _ := r.Context().Value(middleware.ContextKeyStartTime).(time.Time)

	return response.BuildMeta(reqId, corrId, causationId, startTime, apiVersion)
}

func (h *TasksRestHandler) writeError(w http.ResponseWriter, r *http.Request, err error) {
	meta := h.extractMeta(r)
	var statusCode = http.StatusInternalServerError
	var code = errors.CodeInternalServerError
	var message = "An internal error occurred"
	var retryable = true
	var details []response.ErrorDetail

	if appErr, ok := err.(*errors.AppError); ok {
		statusCode = appErr.StatusCode
		code = appErr.Code
		message = appErr.Message
		retryable = appErr.Retryable
		details = appErr.Details
	} else if err != nil {
		message = err.Error()
	}

	w.WriteHeader(statusCode)
	errResp := response.NewErrorResponse(statusCode, code, message, retryable, details, meta)
	_ = json.NewEncoder(w).Encode(errResp)
}

func (h *TasksRestHandler) writeSuccess(w http.ResponseWriter, r *http.Request, statusCode int, data any) {
	meta := h.extractMeta(r)
	w.WriteHeader(statusCode)
	resp := response.NewSuccessResponse(statusCode, data, meta)
	_ = json.NewEncoder(w).Encode(resp)
}

func (h *TasksRestHandler) writePaginatedSuccess(w http.ResponseWriter, r *http.Request, statusCode int, data any, pagination response.PaginationMeta) {
	meta := h.extractMeta(r)
	w.WriteHeader(statusCode)
	resp := response.NewPaginatedSuccessResponse(statusCode, data, meta, pagination)
	_ = json.NewEncoder(w).Encode(resp)
}

func (h *TasksRestHandler) UpsertTask(w http.ResponseWriter, r *http.Request, projectId string) {
	var input types.UpsertTaskInput
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		h.writeError(w, r, errors.NewValidationError("Malformed or invalid JSON payload", []response.ErrorDetail{
			{Field: "body", Issue: err.Error()},
		}))
		return
	}

	task, err := h.service.UpsertTask(r.Context(), projectId, input)
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	h.writeSuccess(w, r, http.StatusOK, task)
}

func (h *TasksRestHandler) ListTasks(w http.ResponseWriter, r *http.Request, projectId string) {
	statusFilter := r.URL.Query().Get("status")
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	pageSize, _ := strconv.Atoi(r.URL.Query().Get("pageSize"))
	if pageSize < 1 {
		pageSize = 10
	}

	tasks, err := h.service.ListTasksByProject(r.Context(), projectId, statusFilter)
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	sliced, pagination := response.PaginateSlice(tasks, page, pageSize)
	h.writePaginatedSuccess(w, r, http.StatusOK, sliced, pagination)
}

func (h *TasksRestHandler) GetTaskById(w http.ResponseWriter, r *http.Request, projectId string, taskId string) {
	task, err := h.service.GetTaskById(r.Context(), projectId, taskId)
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	h.writeSuccess(w, r, http.StatusOK, task)
}

func (h *TasksRestHandler) UpdateTaskStatus(w http.ResponseWriter, r *http.Request, projectId string, taskId string) {
	var input types.UpdateTaskStatusInput
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		h.writeError(w, r, errors.NewValidationError("Malformed or invalid JSON payload", []response.ErrorDetail{
			{Field: "body", Issue: err.Error()},
		}))
		return
	}

	task, err := h.service.UpdateTaskStatus(r.Context(), projectId, taskId, input)
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	h.writeSuccess(w, r, http.StatusOK, task)
}

func (h *TasksRestHandler) DeleteTask(w http.ResponseWriter, r *http.Request, projectId string, taskId string) {
	err := h.service.DeleteTask(r.Context(), projectId, taskId)
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	h.writeSuccess(w, r, http.StatusOK, map[string]string{
		"projectId": projectId,
		"taskId":    taskId,
		"deleted":   "true",
	})
}

func (h *TasksRestHandler) TriggerSchedulerSweep(w http.ResponseWriter, r *http.Request) {
	result, err := h.scheduler.TriggerSweep(r.Context())
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	h.writeSuccess(w, r, http.StatusOK, result)
}
