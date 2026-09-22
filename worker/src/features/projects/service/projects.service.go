package service

import (
	"context"
	"regexp"
	"strings"

	"planner/src/features/projects/repository"
	"planner/src/features/projects/types"
	"planner/src/shared/errors"
	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: PROJECT DOMAIN SERVICE
=====================================================
1. Domain Input Validation:
   - Validates projectId format matching `^[a-zA-Z0-9-_]+$` to prevent directory traversal attacks.
   - Enforces presence of mandatory fields (projectId, name).
   - Validates project status against allowed enum values.
2. Mutation Dispatch:
   - Sanitizes text inputs (trimming whitespaces).
   - Coordinates Upsert, Update, and Delete operations via ProjectRepositoryPort.
3. Query Coordination:
   - Queries single project or collection from repository, validating optional status filter.
*/

var validProjectIdRegex = regexp.MustCompile(`^[a-zA-Z0-9-_]+$`)

type ProjectsService struct {
	repo repository.ProjectRepositoryPort
}

func NewProjectsService(repo repository.ProjectRepositoryPort) *ProjectsService {
	return &ProjectsService{
		repo: repo,
	}
}

func (s *ProjectsService) UpsertProject(ctx context.Context, input types.UpsertProjectInput) (*types.Project, error) {
	var details []response.ErrorDetail

	input.ProjectId = strings.TrimSpace(input.ProjectId)
	if input.ProjectId == "" {
		details = append(details, response.ErrorDetail{
			Field: "projectId",
			Issue: "must not be empty",
		})
	} else if !validProjectIdRegex.MatchString(input.ProjectId) {
		details = append(details, response.ErrorDetail{
			Field: "projectId",
			Issue: "must contain only alphanumeric characters, dashes, and underscores",
		})
	}

	input.Name = strings.TrimSpace(input.Name)
	if input.Name == "" {
		details = append(details, response.ErrorDetail{
			Field: "name",
			Issue: "must not be empty",
		})
	}

	if input.Status != "" && !input.Status.IsValid() {
		details = append(details, response.ErrorDetail{
			Field: "status",
			Issue: "must be one of ACTIVE, ON_HOLD, COMPLETED, ARCHIVED",
		})
	}

	if len(details) > 0 {
		return nil, errors.NewValidationError("Project validation failed", details)
	}

	return s.repo.UpsertProject(ctx, input)
}

func (s *ProjectsService) GetProjectById(ctx context.Context, projectId string) (*types.Project, error) {
	projectId = strings.TrimSpace(projectId)
	if projectId == "" {
		return nil, errors.NewBadRequestError("projectId must not be empty")
	}

	return s.repo.GetProjectById(ctx, projectId)
}

func (s *ProjectsService) ListProjects(ctx context.Context, statusStr string) ([]types.Project, error) {
	var statusFilter *types.ProjectStatus
	if statusStr != "" {
		parsed := types.ProjectStatus(strings.ToUpper(strings.TrimSpace(statusStr)))
		if !parsed.IsValid() {
			return nil, errors.NewValidationError("Invalid status filter", []response.ErrorDetail{
				{Field: "status", Issue: "must be one of ACTIVE, ON_HOLD, COMPLETED, ARCHIVED"},
			})
		}
		statusFilter = &parsed
	}

	return s.repo.ListProjects(ctx, statusFilter)
}

func (s *ProjectsService) UpdateProject(ctx context.Context, projectId string, input types.UpdateProjectInput) (*types.Project, error) {
	projectId = strings.TrimSpace(projectId)
	if projectId == "" {
		return nil, errors.NewBadRequestError("projectId must not be empty")
	}

	if input.Status != nil && !input.Status.IsValid() {
		return nil, errors.NewValidationError("Invalid status", []response.ErrorDetail{
			{Field: "status", Issue: "must be one of ACTIVE, ON_HOLD, COMPLETED, ARCHIVED"},
		})
	}

	return s.repo.UpdateProject(ctx, projectId, input)
}

func (s *ProjectsService) DeleteProject(ctx context.Context, projectId string) error {
	projectId = strings.TrimSpace(projectId)
	if projectId == "" {
		return errors.NewBadRequestError("projectId must not be empty")
	}

	return s.repo.DeleteProject(ctx, projectId)
}
