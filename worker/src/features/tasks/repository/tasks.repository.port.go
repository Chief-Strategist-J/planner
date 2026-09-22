package repository

import (
	"context"

	"planner/src/features/tasks/types"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: TASK REPOSITORY PORT INTERFACE
=============================================================
1. Hexagonal Isolation:
   - Encapsulates persistence operations behind an abstract port contract.
   - Decouples domain services from specific physical storage engines (YAML file, SQL, KV).
2. Method Specification:
   - UpsertTask: Idempotently creates or modifies a task in the specified project.
   - GetTaskById: Retrieves a single task by its unique identifier within a project.
   - ListTasksByProject: Returns tasks for a project, optionally filtered by status.
   - ListAllPendingTasks: Scans across all projects to aggregate pending items for scheduled sweeps.
*/

type TaskRepositoryPort interface {
	UpsertTask(ctx context.Context, projectId string, input types.UpsertTaskInput) (*types.Task, error)
	GetTaskById(ctx context.Context, projectId string, taskId string) (*types.Task, error)
	ListTasksByProject(ctx context.Context, projectId string, statusFilter *types.TaskStatus) ([]types.Task, error)
	ListAllPendingTasks(ctx context.Context) (map[string][]types.Task, error)
}
