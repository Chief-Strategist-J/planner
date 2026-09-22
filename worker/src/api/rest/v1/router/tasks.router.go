package router

import (
	"net/http"

	"planner/src/api/rest/v1/handlers"
	"planner/src/shared/middleware"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: TASK REST ROUTER
===============================================
1. Multiplexer & Routing Registry:
   - Registers standard REST resource endpoints on the native Go 1.22+ http.ServeMux.
   - Extracts path parameters ({projectId}, {taskId}) via r.PathValue().
2. Middleware Decoration:
   - Wraps all routes in ContextMetadataMiddleware (traceparent, request-id, correlation-id).
   - Injects IdempotencyMiddleware for mutating endpoints.
   - Wraps entire multiplexer with PanicRecoveryMiddleware.
3. Path Registration:
   - POST  /api/v1/projects/{projectId}/tasks
   - GET   /api/v1/projects/{projectId}/tasks
   - GET   /api/v1/projects/{projectId}/tasks/{taskId}
   - PATCH /api/v1/projects/{projectId}/tasks/{taskId}/status
   - POST  /api/v1/scheduler/trigger
*/

type TasksRouter struct {
	handler          *handlers.TasksRestHandler
	idempotencyStore *middleware.IdempotencyStore
	apiVersion       string
}

func NewTasksRouter(handler *handlers.TasksRestHandler, idempotencyStore *middleware.IdempotencyStore, apiVersion string) *TasksRouter {
	return &TasksRouter{
		handler:          handler,
		idempotencyStore: idempotencyStore,
		apiVersion:       apiVersion,
	}
}

func (tr *TasksRouter) SetupRoutes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("POST /api/v1/projects/{projectId}/tasks", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		tr.handler.UpsertTask(w, r, projectId)
	})

	mux.HandleFunc("GET /api/v1/projects/{projectId}/tasks", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		tr.handler.ListTasks(w, r, projectId)
	})

	mux.HandleFunc("GET /api/v1/projects/{projectId}/tasks/{taskId}", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		taskId := r.PathValue("taskId")
		tr.handler.GetTaskById(w, r, projectId, taskId)
	})

	mux.HandleFunc("PATCH /api/v1/projects/{projectId}/tasks/{taskId}/status", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		taskId := r.PathValue("taskId")
		tr.handler.UpdateTaskStatus(w, r, projectId, taskId)
	})

	mux.HandleFunc("POST /api/v1/scheduler/trigger", func(w http.ResponseWriter, r *http.Request) {
		tr.handler.TriggerSchedulerSweep(w, r)
	})

	var rootHandler http.Handler = mux
	rootHandler = middleware.IdempotencyMiddleware(tr.idempotencyStore)(rootHandler)
	rootHandler = middleware.ContextMetadataMiddleware(tr.apiVersion)(rootHandler)
	rootHandler = middleware.PanicRecoveryMiddleware()(rootHandler)

	return rootHandler
}
