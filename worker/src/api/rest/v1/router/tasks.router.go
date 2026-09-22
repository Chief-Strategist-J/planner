package router

import (
	"net/http"

	"planner/src/api/rest/v1/handlers"
	"planner/src/shared/middleware"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: PLANNER REST ROUTER
==================================================
1. Multiplexer & Routing Registry:
   - Registers standard REST resource endpoints on the native Go 1.22+ http.ServeMux.
   - Extracts path parameters ({projectId}, {taskId}) via r.PathValue().
2. Middleware Decoration:
   - Wraps all routes in ContextMetadataMiddleware (traceparent, request-id, correlation-id).
   - Injects IdempotencyMiddleware for mutating endpoints.
   - Wraps entire multiplexer with PanicRecoveryMiddleware.
3. Path Registration:
   - Projects:
     - POST   /api/v1/projects
     - GET    /api/v1/projects
     - GET    /api/v1/projects/{projectId}
     - PATCH  /api/v1/projects/{projectId}
     - DELETE /api/v1/projects/{projectId}
   - Tasks:
     - POST   /api/v1/projects/{projectId}/tasks
     - GET    /api/v1/projects/{projectId}/tasks
     - GET    /api/v1/projects/{projectId}/tasks/{taskId}
     - PATCH  /api/v1/projects/{projectId}/tasks/{taskId}/status
     - DELETE /api/v1/projects/{projectId}/tasks/{taskId}
   - Scheduler:
     - POST   /api/v1/scheduler/trigger
*/

type TasksRouter struct {
	tasksHandler     *handlers.TasksRestHandler
	projectsHandler  *handlers.ProjectsRestHandler
	idempotencyStore *middleware.IdempotencyStore
	apiVersion       string
}

func NewTasksRouter(
	tasksHandler *handlers.TasksRestHandler,
	projectsHandler *handlers.ProjectsRestHandler,
	idempotencyStore *middleware.IdempotencyStore,
	apiVersion string,
) *TasksRouter {
	return &TasksRouter{
		tasksHandler:     tasksHandler,
		projectsHandler:  projectsHandler,
		idempotencyStore: idempotencyStore,
		apiVersion:       apiVersion,
	}
}

func (tr *TasksRouter) SetupRoutes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("POST /api/v1/projects", func(w http.ResponseWriter, r *http.Request) {
		tr.projectsHandler.UpsertProject(w, r)
	})

	mux.HandleFunc("GET /api/v1/projects", func(w http.ResponseWriter, r *http.Request) {
		tr.projectsHandler.ListProjects(w, r)
	})

	mux.HandleFunc("GET /api/v1/projects/{projectId}", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		tr.projectsHandler.GetProjectById(w, r, projectId)
	})

	mux.HandleFunc("PATCH /api/v1/projects/{projectId}", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		tr.projectsHandler.UpdateProject(w, r, projectId)
	})

	mux.HandleFunc("DELETE /api/v1/projects/{projectId}", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		tr.projectsHandler.DeleteProject(w, r, projectId)
	})

	mux.HandleFunc("POST /api/v1/projects/{projectId}/tasks", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		tr.tasksHandler.UpsertTask(w, r, projectId)
	})

	mux.HandleFunc("GET /api/v1/projects/{projectId}/tasks", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		tr.tasksHandler.ListTasks(w, r, projectId)
	})

	mux.HandleFunc("GET /api/v1/projects/{projectId}/tasks/{taskId}", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		taskId := r.PathValue("taskId")
		tr.tasksHandler.GetTaskById(w, r, projectId, taskId)
	})

	mux.HandleFunc("PATCH /api/v1/projects/{projectId}/tasks/{taskId}/status", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		taskId := r.PathValue("taskId")
		tr.tasksHandler.UpdateTaskStatus(w, r, projectId, taskId)
	})

	mux.HandleFunc("DELETE /api/v1/projects/{projectId}/tasks/{taskId}", func(w http.ResponseWriter, r *http.Request) {
		projectId := r.PathValue("projectId")
		taskId := r.PathValue("taskId")
		tr.tasksHandler.DeleteTask(w, r, projectId, taskId)
	})

	mux.HandleFunc("POST /api/v1/scheduler/trigger", func(w http.ResponseWriter, r *http.Request) {
		tr.tasksHandler.TriggerSchedulerSweep(w, r)
	})

	var rootHandler http.Handler = mux
	rootHandler = middleware.IdempotencyMiddleware(tr.idempotencyStore)(rootHandler)
	rootHandler = middleware.ContextMetadataMiddleware(tr.apiVersion)(rootHandler)
	rootHandler = middleware.PanicRecoveryMiddleware()(rootHandler)

	return rootHandler
}
