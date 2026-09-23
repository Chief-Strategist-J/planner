package repository

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"planner/src/features/projects/types"
	"planner/src/shared/errors"
	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: FIRESTORE PROJECT REPOSITORY ADAPTER
===================================================================
1. Hexagonal Port Compliance:
   - Implements ProjectRepositoryPort for Google Cloud Firestore.
   - Provides 100% contract equivalence with YamlProjectRepository.
2. Collection Hierarchy:
   - Root collection: `projects`
   - Document ID: `projectId`
3. Idempotent Upsert & Partial Update:
   - UpsertProject checks for document presence, initializes timestamps on creation,
     and updates fields on modification.
   - UpdateProject checks for document existence, applies partial changes, and updates updatedAt.
4. Error Normalization:
   - Normalizes gRPC NotFound codes into application-level errors.NewNotFoundError.
   - Wraps database execution faults in errors.NewInternalServerError.
*/

type FirestoreProjectRepository struct {
	client     *firestore.Client
	collection *firestore.CollectionRef
}

func NewFirestoreProjectRepository(client *firestore.Client) *FirestoreProjectRepository {
	return &FirestoreProjectRepository{
		client:     client,
		collection: client.Collection("projects"),
	}
}

func (r *FirestoreProjectRepository) UpsertProject(ctx context.Context, input types.UpsertProjectInput) (*types.Project, error) {
	docRef := r.collection.Doc(input.ProjectId)
	nowStr := response.FormatIsoTimestamp(time.Now())

	docSnap, err := docRef.Get(ctx)
	if err != nil && status.Code(err) != codes.NotFound {
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to check project document in firestore: %v", err))
	}

	if err == nil && docSnap.Exists() {
		var existing types.Project
		if err := docSnap.DataTo(&existing); err != nil {
			return nil, errors.NewInternalServerError(fmt.Sprintf("failed to parse existing project document: %v", err))
		}

		existing.Name = input.Name
		existing.Description = input.Description
		if input.OwnerEmail != "" {
			existing.OwnerEmail = input.OwnerEmail
		}
		if input.Status != "" {
			existing.Status = input.Status
		}
		existing.UpdatedAt = nowStr

		if _, err := docRef.Set(ctx, existing); err != nil {
			return nil, errors.NewInternalServerError(fmt.Sprintf("failed to update project in firestore: %v", err))
		}
		return &existing, nil
	}

	projectStatus := input.Status
	if projectStatus == "" {
		projectStatus = types.ProjectStatusActive
	}

	newProj := types.Project{
		ProjectId:   input.ProjectId,
		Name:        input.Name,
		Description: input.Description,
		OwnerEmail:  input.OwnerEmail,
		Status:      projectStatus,
		CreatedAt:   nowStr,
		UpdatedAt:   nowStr,
	}

	if _, err := docRef.Set(ctx, newProj); err != nil {
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to create project in firestore: %v", err))
	}

	return &newProj, nil
}

func (r *FirestoreProjectRepository) GetProjectById(ctx context.Context, projectId string) (*types.Project, error) {
	docRef := r.collection.Doc(projectId)
	docSnap, err := docRef.Get(ctx)
	if err != nil {
		if status.Code(err) == codes.NotFound {
			return nil, errors.NewNotFoundError(fmt.Sprintf("project '%s' not found", projectId))
		}
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to get project '%s' from firestore: %v", projectId, err))
	}

	var proj types.Project
	if err := docSnap.DataTo(&proj); err != nil {
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to parse project document: %v", err))
	}

	proj.ProjectId = projectId
	return &proj, nil
}

func (r *FirestoreProjectRepository) ListProjects(ctx context.Context, statusFilter *types.ProjectStatus) ([]types.Project, error) {
	var query firestore.Query = r.collection.Query

	if statusFilter != nil {
		query = query.Where("status", "==", string(*statusFilter))
	}

	iter := query.Documents(ctx)
	defer iter.Stop()

	projects := make([]types.Project, 0)
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, errors.NewInternalServerError(fmt.Sprintf("failed to iterate projects in firestore: %v", err))
		}

		var proj types.Project
		if err := doc.DataTo(&proj); err != nil {
			continue
		}
		proj.ProjectId = doc.Ref.ID
		projects = append(projects, proj)
	}

	return projects, nil
}

func (r *FirestoreProjectRepository) UpdateProject(ctx context.Context, projectId string, input types.UpdateProjectInput) (*types.Project, error) {
	docRef := r.collection.Doc(projectId)
	docSnap, err := docRef.Get(ctx)
	if err != nil {
		if status.Code(err) == codes.NotFound {
			return nil, errors.NewNotFoundError(fmt.Sprintf("project '%s' not found", projectId))
		}
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to get project '%s' for update: %v", projectId, err))
	}

	var existing types.Project
	if err := docSnap.DataTo(&existing); err != nil {
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to parse project document: %v", err))
	}

	existing.ProjectId = projectId
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

	if _, err := docRef.Set(ctx, existing); err != nil {
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to update project '%s' in firestore: %v", projectId, err))
	}

	return &existing, nil
}

func (r *FirestoreProjectRepository) DeleteProject(ctx context.Context, projectId string) error {
	docRef := r.collection.Doc(projectId)
	docSnap, err := docRef.Get(ctx)
	if err != nil {
		if status.Code(err) == codes.NotFound {
			return errors.NewNotFoundError(fmt.Sprintf("project '%s' does not exist", projectId))
		}
		return errors.NewInternalServerError(fmt.Sprintf("failed to verify project before deletion: %v", err))
	}

	if !docSnap.Exists() {
		return errors.NewNotFoundError(fmt.Sprintf("project '%s' does not exist", projectId))
	}

	// Delete all subcollection tasks under this project
	tasksIter := docRef.Collection("tasks").Documents(ctx)
	defer tasksIter.Stop()
	for {
		taskDoc, err := tasksIter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return errors.NewInternalServerError(fmt.Sprintf("failed to iterate tasks during project deletion: %v", err))
		}
		if _, err := taskDoc.Ref.Delete(ctx); err != nil {
			return errors.NewInternalServerError(fmt.Sprintf("failed to delete task during project deletion: %v", err))
		}
	}

	// Delete project document
	if _, err := docRef.Delete(ctx); err != nil {
		return errors.NewInternalServerError(fmt.Sprintf("failed to delete project '%s' from firestore: %v", projectId, err))
	}

	return nil
}
