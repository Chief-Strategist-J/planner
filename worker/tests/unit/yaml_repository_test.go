package unit

import (
	"context"
	"os"
	"path/filepath"
	"sync"
	"testing"

	"planner/src/features/tasks/repository"
	"planner/src/features/tasks/types"
	"planner/src/shared/errors"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: YAML REPOSITORY UNIT TEST SUITE
=============================================================
1. Fixture Lifecycle:
   - Allocates an isolated ephemeral directory per test run.
   - Automatically cleans up the test folder upon completion.
2. Verified Invariants:
   - Create vs Update (Upsert) Semantics: Asserts creation on missing ID and in-place modification on existing ID.
   - Concurrency Safety: Launches concurrent goroutines upserting into the same project YAML file.
   - Query Accuracy: Asserts filtered task retrieval and multi-project pending task aggregation.
*/

func setupTestRepo(t *testing.T) (*repository.YamlTaskRepository, string) {
	tempDir, err := os.MkdirTemp("", "planner_test_*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	repo, err := repository.NewYamlTaskRepository(tempDir)
	if err != nil {
		t.Fatalf("failed to initialize repo: %v", err)
	}

	return repo, tempDir
}

func TestYamlTaskRepository_Upsert_CreateAndUpdate(t *testing.T) {
	repo, tempDir := setupTestRepo(t)
	defer os.RemoveAll(tempDir)

	ctx := context.Background()
	projectId := "proj-finance"
	taskId := "task-101"

	created, err := repo.UpsertTask(ctx, projectId, types.UpsertTaskInput{
		TaskId:          taskId,
		Title:           "Generate Annual Audit",
		Description:     "Collect financial records",
		Status:          types.StatusPending,
		AssignedToEmail: "auditor@corp.internal",
		DueDate:         "2026-10-01",
	})
	if err != nil {
		t.Fatalf("unexpected error creating task: %v", err)
	}

	if created.TaskId != taskId || created.Title != "Generate Annual Audit" {
		t.Errorf("unexpected created task fields: %+v", created)
	}
	if created.CreatedAt == "" || created.UpdatedAt == "" {
		t.Errorf("expected timestamps to be populated: %+v", created)
	}

	yamlPath := filepath.Join(tempDir, projectId, "tasks.yaml")
	if _, err := os.Stat(yamlPath); os.IsNotExist(err) {
		t.Fatalf("expected tasks.yaml to exist at %s", yamlPath)
	}

	origCreatedAt := created.CreatedAt

	updated, err := repo.UpsertTask(ctx, projectId, types.UpsertTaskInput{
		TaskId:          taskId,
		Title:           "Generate Annual Audit - Finalized",
		Description:     "Updated with review comments",
		Status:          types.StatusInProgress,
		AssignedToEmail: "senior-auditor@corp.internal",
		DueDate:         "2026-10-05",
	})
	if err != nil {
		t.Fatalf("unexpected error updating task: %v", err)
	}

	if updated.Title != "Generate Annual Audit - Finalized" {
		t.Errorf("expected updated title, got: %s", updated.Title)
	}
	if updated.Status != types.StatusInProgress {
		t.Errorf("expected updated status IN_PROGRESS, got: %s", updated.Status)
	}
	if updated.CreatedAt != origCreatedAt {
		t.Errorf("expected createdAt to be preserved, got %s vs orig %s", updated.CreatedAt, origCreatedAt)
	}

	fetched, err := repo.GetTaskById(ctx, projectId, taskId)
	if err != nil {
		t.Fatalf("failed to fetch task: %v", err)
	}
	if fetched.Title != updated.Title || fetched.Status != types.StatusInProgress {
		t.Errorf("persisted task does not match updated state: %+v", fetched)
	}
}

func TestYamlTaskRepository_GetTaskById_NotFound(t *testing.T) {
	repo, tempDir := setupTestRepo(t)
	defer os.RemoveAll(tempDir)

	ctx := context.Background()
	_, err := repo.GetTaskById(ctx, "non-existent", "missing-task")
	if err == nil {
		t.Fatalf("expected NotFound error, got nil")
	}

	appErr, ok := err.(*errors.AppError)
	if !ok || appErr.Code != errors.CodeResourceNotFound {
		t.Errorf("expected CodeResourceNotFound, got: %v", err)
	}
}

func TestYamlTaskRepository_ConcurrentUpserts(t *testing.T) {
	repo, tempDir := setupTestRepo(t)
	defer os.RemoveAll(tempDir)

	ctx := context.Background()
	projectId := "concurrent-proj"
	workerCount := 10
	var wg sync.WaitGroup

	for i := 0; i < workerCount; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			taskId := "task-concurrent"
			_, err := repo.UpsertTask(ctx, projectId, types.UpsertTaskInput{
				TaskId:      taskId,
				Title:       "Concurrent Title",
				Description: "Stress testing write race condition",
				Status:      types.StatusPending,
			})
			if err != nil {
				t.Errorf("worker %d failed upsert: %v", index, err)
			}
		}(i)
	}
	wg.Wait()

	tasks, err := repo.ListTasksByProject(ctx, projectId, nil)
	if err != nil {
		t.Fatalf("failed to list tasks after concurrent test: %v", err)
	}

	if len(tasks) != 1 {
		t.Fatalf("expected exactly 1 task after concurrent upserts with same taskId, got %d", len(tasks))
	}
}

func TestYamlTaskRepository_ListAllPendingTasks(t *testing.T) {
	repo, tempDir := setupTestRepo(t)
	defer os.RemoveAll(tempDir)

	ctx := context.Background()

	_, _ = repo.UpsertTask(ctx, "proj-1", types.UpsertTaskInput{
		TaskId: "t1",
		Title:  "Pending 1",
		Status: types.StatusPending,
	})
	_, _ = repo.UpsertTask(ctx, "proj-1", types.UpsertTaskInput{
		TaskId: "t2",
		Title:  "Completed 1",
		Status: types.StatusCompleted,
	})
	_, _ = repo.UpsertTask(ctx, "proj-2", types.UpsertTaskInput{
		TaskId: "t3",
		Title:  "Pending 2",
		Status: types.StatusPending,
	})

	pendingMap, err := repo.ListAllPendingTasks(ctx)
	if err != nil {
		t.Fatalf("failed to list pending tasks: %v", err)
	}

	if len(pendingMap) != 2 {
		t.Fatalf("expected 2 projects with pending tasks, got %d", len(pendingMap))
	}
	if len(pendingMap["proj-1"]) != 1 || pendingMap["proj-1"][0].TaskId != "t1" {
		t.Errorf("unexpected pending tasks for proj-1: %+v", pendingMap["proj-1"])
	}
	if len(pendingMap["proj-2"]) != 1 || pendingMap["proj-2"][0].TaskId != "t3" {
		t.Errorf("unexpected pending tasks for proj-2: %+v", pendingMap["proj-2"])
	}
}
