package unit

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"planner/src/features/projects/repository"
	"planner/src/features/projects/types"
	"planner/src/shared/errors"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: YAML PROJECT REPOSITORY UNIT TEST SUITE
======================================================================
1. Fixture Setup:
   - Creates an isolated ephemeral temporary directory.
   - Cleans up directory post-test execution.
2. Tested Invariants:
   - Create vs Update (Upsert) Semantics for project.yaml.
   - Metadata persistence (name, description, ownerEmail, status, timestamps).
   - Filtered listing and directory scanning.
   - Project deletion removing directory tree.
*/

func setupProjectRepo(t *testing.T) (*repository.YamlProjectRepository, string) {
	tempDir, err := os.MkdirTemp("", "planner_proj_test_*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	repo, err := repository.NewYamlProjectRepository(tempDir)
	if err != nil {
		t.Fatalf("failed to initialize repo: %v", err)
	}

	return repo, tempDir
}

func TestYamlProjectRepository_Upsert_CreateAndUpdate(t *testing.T) {
	repo, tempDir := setupProjectRepo(t)
	defer os.RemoveAll(tempDir)

	ctx := context.Background()
	projectId := "alpha-app"

	created, err := repo.UpsertProject(ctx, types.UpsertProjectInput{
		ProjectId:   projectId,
		Name:        "Alpha Application",
		Description: "Cloud Native Modernization",
		OwnerEmail:  "lead@company.internal",
		Status:      types.ProjectStatusActive,
	})
	if err != nil {
		t.Fatalf("unexpected error creating project: %v", err)
	}

	if created.ProjectId != projectId || created.Name != "Alpha Application" {
		t.Errorf("unexpected project fields: %+v", created)
	}

	yamlPath := filepath.Join(tempDir, projectId, "project.yaml")
	if _, err := os.Stat(yamlPath); os.IsNotExist(err) {
		t.Fatalf("expected project.yaml to exist at %s", yamlPath)
	}

	origCreatedAt := created.CreatedAt

	updated, err := repo.UpsertProject(ctx, types.UpsertProjectInput{
		ProjectId:   projectId,
		Name:        "Alpha Application - V2",
		Description: "Refined Scope",
		OwnerEmail:  "principal@company.internal",
		Status:      types.ProjectStatusOnHold,
	})
	if err != nil {
		t.Fatalf("unexpected error updating project: %v", err)
	}

	if updated.Name != "Alpha Application - V2" || updated.Status != types.ProjectStatusOnHold {
		t.Errorf("unexpected updated fields: %+v", updated)
	}
	if updated.CreatedAt != origCreatedAt {
		t.Errorf("expected createdAt to be preserved, got %s vs %s", updated.CreatedAt, origCreatedAt)
	}

	fetched, err := repo.GetProjectById(ctx, projectId)
	if err != nil {
		t.Fatalf("failed to fetch project: %v", err)
	}
	if fetched.Name != updated.Name || fetched.OwnerEmail != updated.OwnerEmail {
		t.Errorf("persisted project mismatch: %+v", fetched)
	}
}

func TestYamlProjectRepository_ListAndFilter(t *testing.T) {
	repo, tempDir := setupProjectRepo(t)
	defer os.RemoveAll(tempDir)

	ctx := context.Background()
	_, _ = repo.UpsertProject(ctx, types.UpsertProjectInput{
		ProjectId: "p1",
		Name:      "Project 1",
		Status:    types.ProjectStatusActive,
	})
	_, _ = repo.UpsertProject(ctx, types.UpsertProjectInput{
		ProjectId: "p2",
		Name:      "Project 2",
		Status:    types.ProjectStatusCompleted,
	})

	all, err := repo.ListProjects(ctx, nil)
	if err != nil {
		t.Fatalf("failed to list all projects: %v", err)
	}
	if len(all) != 2 {
		t.Errorf("expected 2 projects, got %d", len(all))
	}

	activeStatus := types.ProjectStatusActive
	activeList, err := repo.ListProjects(ctx, &activeStatus)
	if err != nil {
		t.Fatalf("failed to list active projects: %v", err)
	}
	if len(activeList) != 1 || activeList[0].ProjectId != "p1" {
		t.Errorf("expected 1 active project (p1), got: %+v", activeList)
	}
}

func TestYamlProjectRepository_DeleteProject(t *testing.T) {
	repo, tempDir := setupProjectRepo(t)
	defer os.RemoveAll(tempDir)

	ctx := context.Background()
	projectId := "to-delete"

	_, _ = repo.UpsertProject(ctx, types.UpsertProjectInput{
		ProjectId: projectId,
		Name:      "Ephemeral Project",
		Status:    types.ProjectStatusActive,
	})

	err := repo.DeleteProject(ctx, projectId)
	if err != nil {
		t.Fatalf("failed to delete project: %v", err)
	}

	_, err = repo.GetProjectById(ctx, projectId)
	if err == nil {
		t.Fatalf("expected NotFound error after delete, got nil")
	}

	appErr, ok := err.(*errors.AppError)
	if !ok || appErr.Code != errors.CodeResourceNotFound {
		t.Errorf("expected CodeResourceNotFound, got: %v", err)
	}
}
