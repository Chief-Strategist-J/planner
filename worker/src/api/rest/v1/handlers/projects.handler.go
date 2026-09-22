package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"planner/src/features/projects/service"
	"planner/src/features/projects/types"
	"planner/src/shared/errors"
	"planner/src/shared/middleware"
	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: PROJECTS REST TRANSPORT HANDLER
==============================================================
1. Context & Metadata Extraction:
   - Extracts tracing metadata (requestId, correlationId, causationId, startTime, apiVersion) from request context.
   - Enforces closed JSON deserialization on request bodies.
2. Standardized Envelope Serialization:
   - Encapsulates domain responses in ApiResponse[T] (success: true, statusCode, data, meta).
   - Injects meta.pagination for collection endpoints (ListProjects).
   - Maps errors directly to ApiErrorResponse (success: false, statusCode, error: {code, message, retryable}, meta).
3. Handled Endpoints:
   - UpsertProject: POST /api/v1/projects
   - ListProjects:  GET /api/v1/projects?page=1&pageSize=10&status=ACTIVE
   - GetProjectById: GET /api/v1/projects/{projectId}
   - UpdateProject: PATCH /api/v1/projects/{projectId}
   - DeleteProject: DELETE /api/v1/projects/{projectId}
*/

type ProjectsRestHandler struct {
	service *service.ProjectsService
}

func NewProjectsRestHandler(service *service.ProjectsService) *ProjectsRestHandler {
	return &ProjectsRestHandler{
		service: service,
	}
}

func (h *ProjectsRestHandler) extractMeta(r *http.Request) response.Meta {
	reqId, _ := r.Context().Value(middleware.ContextKeyRequestId).(string)
	corrId, _ := r.Context().Value(middleware.ContextKeyCorrelationId).(string)
	causationId, _ := r.Context().Value(middleware.ContextKeyCausationId).(string)
	apiVersion, _ := r.Context().Value(middleware.ContextKeyApiVersion).(string)
	startTime, _ := r.Context().Value(middleware.ContextKeyStartTime).(time.Time)

	return response.BuildMeta(reqId, corrId, causationId, startTime, apiVersion)
}

func (h *ProjectsRestHandler) writeError(w http.ResponseWriter, r *http.Request, err error) {
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

func (h *ProjectsRestHandler) writeSuccess(w http.ResponseWriter, r *http.Request, statusCode int, data any) {
	meta := h.extractMeta(r)
	w.WriteHeader(statusCode)
	resp := response.NewSuccessResponse(statusCode, data, meta)
	_ = json.NewEncoder(w).Encode(resp)
}

func (h *ProjectsRestHandler) writePaginatedSuccess(w http.ResponseWriter, r *http.Request, statusCode int, data any, pagination response.PaginationMeta) {
	meta := h.extractMeta(r)
	w.WriteHeader(statusCode)
	resp := response.NewPaginatedSuccessResponse(statusCode, data, meta, pagination)
	_ = json.NewEncoder(w).Encode(resp)
}

func (h *ProjectsRestHandler) UpsertProject(w http.ResponseWriter, r *http.Request) {
	var input types.UpsertProjectInput
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		h.writeError(w, r, errors.NewValidationError("Malformed or invalid JSON payload", []response.ErrorDetail{
			{Field: "body", Issue: err.Error()},
		}))
		return
	}

	proj, err := h.service.UpsertProject(r.Context(), input)
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	h.writeSuccess(w, r, http.StatusOK, proj)
}

func (h *ProjectsRestHandler) GetProjectById(w http.ResponseWriter, r *http.Request, projectId string) {
	proj, err := h.service.GetProjectById(r.Context(), projectId)
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	h.writeSuccess(w, r, http.StatusOK, proj)
}

func (h *ProjectsRestHandler) ListProjects(w http.ResponseWriter, r *http.Request) {
	statusFilter := r.URL.Query().Get("status")
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	pageSize, _ := strconv.Atoi(r.URL.Query().Get("pageSize"))
	if pageSize < 1 {
		pageSize = 10
	}

	projects, err := h.service.ListProjects(r.Context(), statusFilter)
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	sliced, pagination := response.PaginateSlice(projects, page, pageSize)
	h.writePaginatedSuccess(w, r, http.StatusOK, sliced, pagination)
}

func (h *ProjectsRestHandler) UpdateProject(w http.ResponseWriter, r *http.Request, projectId string) {
	var input types.UpdateProjectInput
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		h.writeError(w, r, errors.NewValidationError("Malformed or invalid JSON payload", []response.ErrorDetail{
			{Field: "body", Issue: err.Error()},
		}))
		return
	}

	proj, err := h.service.UpdateProject(r.Context(), projectId, input)
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	h.writeSuccess(w, r, http.StatusOK, proj)
}

func (h *ProjectsRestHandler) DeleteProject(w http.ResponseWriter, r *http.Request, projectId string) {
	err := h.service.DeleteProject(r.Context(), projectId)
	if err != nil {
		h.writeError(w, r, err)
		return
	}

	h.writeSuccess(w, r, http.StatusOK, map[string]string{
		"projectId": projectId,
		"deleted":   "true",
	})
}
