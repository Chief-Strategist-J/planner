package service

import (
	"context"
	"strings"

	"planner/src/features/tasks/repository"
	"planner/src/features/tasks/types"
	"planner/src/shared/errors"
	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: TASK DOMAIN SERVICE
===================================================
1. Domain Input Validation:
   - Enforces required semantic fields (projectId, taskId, title).
   - Validates that provided task status values conform to the standard enum taxonomy.
   - Emits structured field-level validation errors upon violations.
2. Upsert Coordination:
   - Sanitizes string inputs by trimming leading and trailing whitespaces.
   - Delegates mutation to the underlying TaskRepositoryPort.
3. Status Transition Workflow:
   - Verifies target task existence within the project scope.
   - Validates the requested status transition.
   - Mutates the task status and timestamps via idempotent repository upsert.
4. Query Dispatching:
   - Routes single-entity and collection queries directly through the repository port.
*/

type TasksService struct {
	repo repository.TaskRepositoryPort
}

func NewTasksService(repo repository.TaskRepositoryPort) *TasksService {
	return &TasksService{
		repo: repo,
	}
}

func (s *TasksService) UpsertTask(ctx context.Context, projectId string, input types.UpsertTaskInput) (*types.Task, error) {
	var details []response.ErrorDetail

	projectId = strings.TrimSpace(projectId)
	if projectId == "" {
		details = append(details, response.ErrorDetail{
			Field: "projectId",
			Issue: "must not be empty",
		})
	}

	input.TaskId = strings.TrimSpace(input.TaskId)
	if input.TaskId == "" {
		details = append(details, response.ErrorDetail{
			Field: "taskId",
			Issue: "must not be empty",
		})
	}

	input.Title = strings.TrimSpace(input.Title)
	if input.Title == "" {
		details = append(details, response.ErrorDetail{
			Field: "title",
			Issue: "must not be empty",
		})
	}

	if input.Status != "" && !input.Status.IsValid() {
		details = append(details, response.ErrorDetail{
			Field: "status",
			Issue: "must be one of PENDING, IN_PROGRESS, COMPLETED, CANCELLED",
		})
	}

	if input.Priority != "" && !input.Priority.IsValid() {
		details = append(details, response.ErrorDetail{
			Field: "priority",
			Issue: "must be one of LOW, MEDIUM, HIGH, CRITICAL",
		})
	}

	if len(details) > 0 {
		return nil, errors.NewValidationError("Task validation failed", details)
	}

	return s.repo.UpsertTask(ctx, projectId, input)
}

func (s *TasksService) GetTaskById(ctx context.Context, projectId string, taskId string) (*types.Task, error) {
	projectId = strings.TrimSpace(projectId)
	taskId = strings.TrimSpace(taskId)

	if projectId == "" || taskId == "" {
		return nil, errors.NewBadRequestError("projectId and taskId are mandatory")
	}

	return s.repo.GetTaskById(ctx, projectId, taskId)
}

func (s *TasksService) ListTasksByProject(ctx context.Context, projectId string, statusStr string) ([]types.Task, error) {
	projectId = strings.TrimSpace(projectId)
	if projectId == "" {
		return nil, errors.NewBadRequestError("projectId is mandatory")
	}

	var statusFilter *types.TaskStatus
	if statusStr != "" {
		parsed := types.TaskStatus(strings.ToUpper(strings.TrimSpace(statusStr)))
		if !parsed.IsValid() {
			return nil, errors.NewValidationError("Invalid status filter", []response.ErrorDetail{
				{Field: "status", Issue: "must be one of PENDING, IN_PROGRESS, COMPLETED, CANCELLED"},
			})
		}
		statusFilter = &parsed
	}

	return s.repo.ListTasksByProject(ctx, projectId, statusFilter)
}

func (s *TasksService) UpdateTaskStatus(ctx context.Context, projectId string, taskId string, input types.UpdateTaskStatusInput) (*types.Task, error) {
	if !input.Status.IsValid() {
		return nil, errors.NewValidationError("Invalid status parameter", []response.ErrorDetail{
			{Field: "status", Issue: "must be one of PENDING, IN_PROGRESS, COMPLETED, CANCELLED"},
		})
	}

	existing, err := s.repo.GetTaskById(ctx, projectId, taskId)
	if err != nil {
		return nil, err
	}

	upsertInput := types.UpsertTaskInput{
		TaskId:          existing.TaskId,
		Title:           existing.Title,
		Description:     existing.Description,
		Status:          input.Status,
		Priority:        existing.Priority,
		AssignedToEmail: existing.AssignedToEmail,
		DueDate:         existing.DueDate,
	}

	return s.repo.UpsertTask(ctx, projectId, upsertInput)
}

func (s *TasksService) DeleteTask(ctx context.Context, projectId string, taskId string) error {
	projectId = strings.TrimSpace(projectId)
	taskId = strings.TrimSpace(taskId)
	if projectId == "" || taskId == "" {
		return errors.NewBadRequestError("projectId and taskId are mandatory")
	}

	return s.repo.DeleteTask(ctx, projectId, taskId)
}

