package repository

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"gopkg.in/yaml.v3"

	"planner/src/features/projects/types"
	"planner/src/shared/errors"
	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: YAML PROJECT REPOSITORY
======================================================
1. Storage Organization:
   - Manages `./projects/{projectId}/project.yaml` per project.
   - Enforces thread safety via synchronized per-project mutex registry.
2. Atomic Persistence:
   - Serializes Project structure to YAML format.
   - Writes to `project.yaml.tmp` before performing POSIX atomic rename.
   - Guarantees zero corruption on interrupted writes.
3. Upsert Logic:
   - Checks if `project.yaml` exists in `projects/{projectId}/`.
   - If present: updates metadata, keeps original createdAt, updates updatedAt.
   - If missing: creates directory, initializes record with default ACTIVE status, sets createdAt and updatedAt.
4. Scan & List:
   - Traverses entries in base directory, parsing all valid `project.yaml` documents.
   - Automatically supports status filtering.
5. Deletion:
   - Removes the project folder and its contents recursively.
*/

type YamlProjectRepository struct {
	baseDir      string
	projectLocks map[string]*sync.RWMutex
	globalMu     sync.Mutex
}

func NewYamlProjectRepository(baseDir string) (*YamlProjectRepository, error) {
	if err := os.MkdirAll(baseDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create base projects directory: %w", err)
	}
	return &YamlProjectRepository{
		baseDir:      baseDir,
		projectLocks: make(map[string]*sync.RWMutex),
	}, nil
}

func (r *YamlProjectRepository) getProjectLock(projectId string) *sync.RWMutex {
	r.globalMu.Lock()
	defer r.globalMu.Unlock()

	lock, exists := r.projectLocks[projectId]
	if !exists {
		lock = &sync.RWMutex{}
		r.projectLocks[projectId] = lock
	}
	return lock
}

func (r *YamlProjectRepository) getProjectFilePath(projectId string) string {
	return filepath.Join(r.baseDir, projectId, "project.yaml")
}

func (r *YamlProjectRepository) readProjectFileUnsafe(projectId string) (*types.Project, error) {
	filePath := r.getProjectFilePath(projectId)
	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, errors.NewNotFoundError(fmt.Sprintf("project '%s' not found", projectId))
		}
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to read project file: %v", err))
	}

	var proj types.Project
	if err := yaml.Unmarshal(data, &proj); err != nil {
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to parse yaml in %s: %v", filePath, err))
	}

	proj.ProjectId = projectId
	return &proj, nil
}

func (r *YamlProjectRepository) writeProjectFileUnsafe(projectId string, proj *types.Project) error {
	projectDir := filepath.Join(r.baseDir, projectId)
	if err := os.MkdirAll(projectDir, 0755); err != nil {
		return errors.NewInternalServerError(fmt.Sprintf("failed to create project directory: %v", err))
	}

	proj.UpdatedAt = response.FormatIsoTimestamp(time.Now())

	data, err := yaml.Marshal(proj)
	if err != nil {
		return errors.NewInternalServerError(fmt.Sprintf("failed to serialize project yaml: %v", err))
	}

	finalPath := r.getProjectFilePath(projectId)
	tmpPath := finalPath + ".tmp"

	if err := os.WriteFile(tmpPath, data, 0644); err != nil {
		return errors.NewInternalServerError(fmt.Sprintf("failed to write temporary project file: %v", err))
	}

	if err := os.Rename(tmpPath, finalPath); err != nil {
		_ = os.Remove(tmpPath)
		return errors.NewInternalServerError(fmt.Sprintf("failed to atomically replace project file: %v", err))
	}

	return nil
}

func (r *YamlProjectRepository) UpsertProject(ctx context.Context, input types.UpsertProjectInput) (*types.Project, error) {
	lock := r.getProjectLock(input.ProjectId)
	lock.Lock()
	defer lock.Unlock()

	nowStr := response.FormatIsoTimestamp(time.Now())
	status := input.Status
	if status == "" {
		status = types.ProjectStatusActive
	}

	existing, err := r.readProjectFileUnsafe(input.ProjectId)
	if err == nil && existing != nil {
		existing.Name = input.Name
		existing.Description = input.Description
		if input.OwnerEmail != "" {
			existing.OwnerEmail = input.OwnerEmail
		}
		if input.Status != "" {
			existing.Status = input.Status
		}
		existing.UpdatedAt = nowStr

		if err := r.writeProjectFileUnsafe(input.ProjectId, existing); err != nil {
			return nil, err
		}
		return existing, nil
	}

	newProj := types.Project{
		ProjectId:   input.ProjectId,
		Name:        input.Name,
		Description: input.Description,
		OwnerEmail:  input.OwnerEmail,
		Status:      status,
		CreatedAt:   nowStr,
		UpdatedAt:   nowStr,
	}

	if err := r.writeProjectFileUnsafe(input.ProjectId, &newProj); err != nil {
		return nil, err
	}

	return &newProj, nil
}

func (r *YamlProjectRepository) GetProjectById(ctx context.Context, projectId string) (*types.Project, error) {
	lock := r.getProjectLock(projectId)
	lock.RLock()
	defer lock.RUnlock()

	return r.readProjectFileUnsafe(projectId)
}

func (r *YamlProjectRepository) ListProjects(ctx context.Context, statusFilter *types.ProjectStatus) ([]types.Project, error) {
	r.globalMu.Lock()
	entries, err := os.ReadDir(r.baseDir)
	r.globalMu.Unlock()

	if err != nil {
		if os.IsNotExist(err) {
			return []types.Project{}, nil
		}
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to read projects directory: %v", err))
	}

	projects := make([]types.Project, 0)

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		projectId := entry.Name()
		lock := r.getProjectLock(projectId)
		lock.RLock()
		proj, err := r.readProjectFileUnsafe(projectId)
		lock.RUnlock()

		if err != nil || proj == nil {
			continue
		}

		if statusFilter != nil && proj.Status != *statusFilter {
			continue
		}

		projects = append(projects, *proj)
	}

	return projects, nil
}

func (r *YamlProjectRepository) UpdateProject(ctx context.Context, projectId string, input types.UpdateProjectInput) (*types.Project, error) {
	lock := r.getProjectLock(projectId)
	lock.Lock()
	defer lock.Unlock()

	existing, err := r.readProjectFileUnsafe(projectId)
	if err != nil {
		return nil, err
	}

	if input.Name != "" {
		existing.Name = input.Name
	}
	if input.Description != "" {
		existing.Description = input.Description
	}
	if input.OwnerEmail != "" {
		existing.OwnerEmail = input.OwnerEmail
	}
	if input.Status != nil && input.Status.IsValid() {
		existing.Status = *input.Status
	}

	existing.UpdatedAt = response.FormatIsoTimestamp(time.Now())

	if err := r.writeProjectFileUnsafe(projectId, existing); err != nil {
		return nil, err
	}

	return existing, nil
}

func (r *YamlProjectRepository) DeleteProject(ctx context.Context, projectId string) error {
	lock := r.getProjectLock(projectId)
	lock.Lock()
	defer lock.Unlock()

	projectDir := filepath.Join(r.baseDir, projectId)
	if _, err := os.Stat(projectDir); os.IsNotExist(err) {
		return errors.NewNotFoundError(fmt.Sprintf("project '%s' does not exist", projectId))
	}

	if err := os.RemoveAll(projectDir); err != nil {
		return errors.NewInternalServerError(fmt.Sprintf("failed to delete project directory: %v", err))
	}

	return nil
}
