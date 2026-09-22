package repository

import (
	"context"

	"planner/src/features/projects/types"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: PROJECT REPOSITORY PORT INTERFACE
================================================================
1. Hexagonal Isolation:
   - Encapsulates project persistence operations behind an abstract port contract.
   - Decouples domain services from physical filesystem storage.
2. Method Specification:
   - UpsertProject: Creates or updates project metadata in `projects/{projectId}/project.yaml`.
   - GetProjectById: Retrieves a single project's metadata by its unique slug/identifier.
   - ListProjects: Returns all existing projects, optionally filtered by status.
   - UpdateProject: Applies partial patch to project metadata.
   - DeleteProject: Removes project directory or archives it.
*/

type ProjectRepositoryPort interface {
	UpsertProject(ctx context.Context, input types.UpsertProjectInput) (*types.Project, error)
	GetProjectById(ctx context.Context, projectId string) (*types.Project, error)
	ListProjects(ctx context.Context, statusFilter *types.ProjectStatus) ([]types.Project, error)
	UpdateProject(ctx context.Context, projectId string, input types.UpdateProjectInput) (*types.Project, error)
	DeleteProject(ctx context.Context, projectId string) error
}
