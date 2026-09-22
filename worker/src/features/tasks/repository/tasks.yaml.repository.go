package repository

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"gopkg.in/yaml.v3"

	"planner/src/features/tasks/types"
	"planner/src/shared/errors"
	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: YAML STORAGE REPOSITORY
======================================================
1. Storage Topology & Organization:
   - Root base directory is configured via configuration (default: `./projects`).
   - Each project is isolated in `./projects/{projectId}/tasks.yaml`.
2. Concurrency Control & Thread Safety:
   - In-memory per-project mutex registry synchronizes concurrent operations on identical project files.
   - Global mutex coordinates project lock map modifications.
3. Atomic Persistence Sequence:
   - Encodes updated task structure into YAML format.
   - Writes serialized bytes into an ephemeral sibling file (`tasks.yaml.tmp`).
   - Flushes buffers and performs POSIX atomic rename to replace the authoritative `tasks.yaml`.
   - Guarantees zero partial file corruption during unexpected termination.
4. Upsert Execution Flow:
   - Reads existing YAML file or constructs empty project document if missing.
   - Searches task collection for matching taskId:
     a. Match Found: Updates title, description, assigned email, due date, status, and sets updatedAt.
     b. Match Missing: Appends new task record with default PENDING status, createdAt, and updatedAt.
   - Persists state atomically and returns the resulting Task pointer.
5. All Pending Query Flow:
   - Traverses all directory entries in `./projects`.
   - Locates and deserializes all existing `tasks.yaml` files.
   - Filters task records strictly matching StatusPending into a project-grouped map.
*/

type YamlTaskRepository struct {
	baseDir      string
	projectLocks map[string]*sync.RWMutex
	globalMu     sync.Mutex
}

func NewYamlTaskRepository(baseDir string) (*YamlTaskRepository, error) {
	if err := os.MkdirAll(baseDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create base projects directory: %w", err)
	}
	return &YamlTaskRepository{
		baseDir:      baseDir,
		projectLocks: make(map[string]*sync.RWMutex),
	}, nil
}

func (r *YamlTaskRepository) getProjectLock(projectId string) *sync.RWMutex {
	r.globalMu.Lock()
	defer r.globalMu.Unlock()

	lock, exists := r.projectLocks[projectId]
	if !exists {
		lock = &sync.RWMutex{}
		r.projectLocks[projectId] = lock
	}
	return lock
}

func (r *YamlTaskRepository) getProjectFilePath(projectId string) string {
	return filepath.Join(r.baseDir, projectId, "tasks.yaml")
}

func (r *YamlTaskRepository) readProjectFileUnsafe(projectId string) (*types.ProjectTasksFile, error) {
	filePath := r.getProjectFilePath(projectId)
	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return &types.ProjectTasksFile{
				ProjectId:   projectId,
				LastUpdated: response.FormatIsoTimestamp(time.Now()),
				Tasks:       []types.Task{},
			}, nil
		}
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to read tasks file: %v", err))
	}

	var file types.ProjectTasksFile
	if err := yaml.Unmarshal(data, &file); err != nil {
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to parse yaml in %s: %v", filePath, err))
	}

	if file.Tasks == nil {
		file.Tasks = []types.Task{}
	}
	file.ProjectId = projectId
	return &file, nil
}

func (r *YamlTaskRepository) writeProjectFileUnsafe(projectId string, file *types.ProjectTasksFile) error {
	projectDir := filepath.Join(r.baseDir, projectId)
	if err := os.MkdirAll(projectDir, 0755); err != nil {
		return errors.NewInternalServerError(fmt.Sprintf("failed to create project directory: %v", err))
	}

	file.LastUpdated = response.FormatIsoTimestamp(time.Now())

	data, err := yaml.Marshal(file)
	if err != nil {
		return errors.NewInternalServerError(fmt.Sprintf("failed to serialize yaml: %v", err))
	}

	finalPath := r.getProjectFilePath(projectId)
	tmpPath := finalPath + ".tmp"

	if err := os.WriteFile(tmpPath, data, 0644); err != nil {
		return errors.NewInternalServerError(fmt.Sprintf("failed to write temporary file: %v", err))
	}

	if err := os.Rename(tmpPath, finalPath); err != nil {
		_ = os.Remove(tmpPath)
		return errors.NewInternalServerError(fmt.Sprintf("failed to atomically replace tasks file: %v", err))
	}

	return nil
}

func (r *YamlTaskRepository) UpsertTask(ctx context.Context, projectId string, input types.UpsertTaskInput) (*types.Task, error) {
	lock := r.getProjectLock(projectId)
	lock.Lock()
	defer lock.Unlock()

	file, err := r.readProjectFileUnsafe(projectId)
	if err != nil {
		return nil, err
	}

	nowStr := response.FormatIsoTimestamp(time.Now())
	status := input.Status
	if status == "" {
		status = types.StatusPending
	}

	var targetIndex = -1
	for i, t := range file.Tasks {
		if t.TaskId == input.TaskId {
			targetIndex = i
			break
		}
	}

	if targetIndex >= 0 {
		existing := &file.Tasks[targetIndex]
		existing.Title = input.Title
		existing.Description = input.Description
		if input.Status != "" {
			existing.Status = input.Status
		}
		if input.Priority != "" {
			existing.Priority = input.Priority
		}
		if input.AssignedToEmail != "" {
			existing.AssignedToEmail = input.AssignedToEmail
		}
		if input.DueDate != "" {
			existing.DueDate = input.DueDate
		}
		existing.UpdatedAt = nowStr

		if err := r.writeProjectFileUnsafe(projectId, file); err != nil {
			return nil, err
		}
		return existing, nil
	}

	priority := input.Priority
	if priority == "" {
		priority = types.PriorityMedium
	}

	newTask := types.Task{
		TaskId:          input.TaskId,
		ProjectId:       projectId,
		Title:           input.Title,
		Description:     input.Description,
		Status:          status,
		Priority:        priority,
		AssignedToEmail: input.AssignedToEmail,
		DueDate:         input.DueDate,
		CreatedAt:       nowStr,
		UpdatedAt:       nowStr,
	}

	file.Tasks = append(file.Tasks, newTask)

	if err := r.writeProjectFileUnsafe(projectId, file); err != nil {
		return nil, err
	}

	return &newTask, nil
}

func (r *YamlTaskRepository) GetTaskById(ctx context.Context, projectId string, taskId string) (*types.Task, error) {
	lock := r.getProjectLock(projectId)
	lock.RLock()
	defer lock.RUnlock()

	file, err := r.readProjectFileUnsafe(projectId)
	if err != nil {
		return nil, err
	}

	for _, t := range file.Tasks {
		if t.TaskId == taskId {
			result := t
			return &result, nil
		}
	}

	return nil, errors.NewNotFoundError(fmt.Sprintf("task '%s' not found in project '%s'", taskId, projectId))
}

func (r *YamlTaskRepository) ListTasksByProject(ctx context.Context, projectId string, statusFilter *types.TaskStatus) ([]types.Task, error) {
	lock := r.getProjectLock(projectId)
	lock.RLock()
	defer lock.RUnlock()

	file, err := r.readProjectFileUnsafe(projectId)
	if err != nil {
		return nil, err
	}

	if statusFilter == nil {
		return file.Tasks, nil
	}

	filtered := make([]types.Task, 0)
	for _, t := range file.Tasks {
		if t.Status == *statusFilter {
			filtered = append(filtered, t)
		}
	}

	return filtered, nil
}

func (r *YamlTaskRepository) ListAllPendingTasks(ctx context.Context) (map[string][]types.Task, error) {
	r.globalMu.Lock()
	entries, err := os.ReadDir(r.baseDir)
	r.globalMu.Unlock()

	if err != nil {
		if os.IsNotExist(err) {
			return make(map[string][]types.Task), nil
		}
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to scan projects directory: %v", err))
	}

	pendingMap := make(map[string][]types.Task)

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		projectId := entry.Name()
		lock := r.getProjectLock(projectId)
		lock.RLock()

		file, err := r.readProjectFileUnsafe(projectId)
		lock.RUnlock()

		if err != nil {
			continue
		}

		var pendingList []types.Task
		for _, t := range file.Tasks {
			if t.Status == types.StatusPending {
				pendingList = append(pendingList, t)
			}
		}

		if len(pendingList) > 0 {
			pendingMap[projectId] = pendingList
		}
	}

	return pendingMap, nil
}

func (r *YamlTaskRepository) DeleteTask(ctx context.Context, projectId string, taskId string) error {
	lock := r.getProjectLock(projectId)
	lock.Lock()
	defer lock.Unlock()

	file, err := r.readProjectFileUnsafe(projectId)
	if err != nil {
		return err
	}

	targetIndex := -1
	for i, t := range file.Tasks {
		if t.TaskId == taskId {
			targetIndex = i
			break
		}
	}

	if targetIndex < 0 {
		return errors.NewNotFoundError(fmt.Sprintf("task '%s' not found in project '%s'", taskId, projectId))
	}

	file.Tasks = append(file.Tasks[:targetIndex], file.Tasks[targetIndex+1:]...)

	return r.writeProjectFileUnsafe(projectId, file)
}

