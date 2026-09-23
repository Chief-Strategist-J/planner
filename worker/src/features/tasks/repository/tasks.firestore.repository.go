package repository

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"planner/src/features/tasks/types"
	"planner/src/shared/errors"
	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: FIRESTORE TASK REPOSITORY ADAPTER
================================================================
1. Hexagonal Port Compliance:
   - Implements TaskRepositoryPort for Google Cloud Firestore.
   - Provides 100% contract equivalence with YamlTaskRepository.
2. Hierarchical Subcollections:
   - Path: `projects/{projectId}/tasks/{taskId}`
   - Allows clean project-scoped access and security isolation.
3. Collection Group Indexing:
   - `ListAllPendingTasks` utilizes Firestore `CollectionGroup("tasks")` where status == "PENDING".
   - Enables O(N_pending) fast global scheduler sweeps without reading unrelated records.
4. Error Normalization:
   - Returns errors.NewNotFoundError when tasks do not exist.
   - Preserves exact error messages matching the YAML repository specification.
*/

type FirestoreTaskRepository struct {
	client *firestore.Client
}

func NewFirestoreTaskRepository(client *firestore.Client) *FirestoreTaskRepository {
	return &FirestoreTaskRepository{
		client: client,
	}
}

func (r *FirestoreTaskRepository) getTaskRef(projectId, taskId string) *firestore.DocumentRef {
	return r.client.Collection("projects").Doc(projectId).Collection("tasks").Doc(taskId)
}

func (r *FirestoreTaskRepository) UpsertTask(ctx context.Context, projectId string, input types.UpsertTaskInput) (*types.Task, error) {
	taskRef := r.getTaskRef(projectId, input.TaskId)
	nowStr := response.FormatIsoTimestamp(time.Now())

	docSnap, err := taskRef.Get(ctx)
	if err != nil && status.Code(err) != codes.NotFound {
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to check task document in firestore: %v", err))
	}

	if err == nil && docSnap.Exists() {
		var existing types.Task
		if err := docSnap.DataTo(&existing); err != nil {
			return nil, errors.NewInternalServerError(fmt.Sprintf("failed to parse existing task document: %v", err))
		}

		existing.TaskId = input.TaskId
		existing.ProjectId = projectId
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

		if _, err := taskRef.Set(ctx, existing); err != nil {
			return nil, errors.NewInternalServerError(fmt.Sprintf("failed to update task in firestore: %v", err))
		}

		return &existing, nil
	}

	taskStatus := input.Status
	if taskStatus == "" {
		taskStatus = types.StatusPending
	}

	taskPriority := input.Priority
	if taskPriority == "" {
		taskPriority = types.PriorityMedium
	}

	newTask := types.Task{
		TaskId:          input.TaskId,
		ProjectId:       projectId,
		Title:           input.Title,
		Description:     input.Description,
		Status:          taskStatus,
		Priority:        taskPriority,
		AssignedToEmail: input.AssignedToEmail,
		DueDate:         input.DueDate,
		CreatedAt:       nowStr,
		UpdatedAt:       nowStr,
	}

	if _, err := taskRef.Set(ctx, newTask); err != nil {
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to create task in firestore: %v", err))
	}

	return &newTask, nil
}

func (r *FirestoreTaskRepository) GetTaskById(ctx context.Context, projectId string, taskId string) (*types.Task, error) {
	taskRef := r.getTaskRef(projectId, taskId)
	docSnap, err := taskRef.Get(ctx)
	if err != nil {
		if status.Code(err) == codes.NotFound {
			return nil, errors.NewNotFoundError(fmt.Sprintf("task '%s' not found in project '%s'", taskId, projectId))
		}
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to get task '%s' from firestore: %v", taskId, err))
	}

	var task types.Task
	if err := docSnap.DataTo(&task); err != nil {
		return nil, errors.NewInternalServerError(fmt.Sprintf("failed to parse task document: %v", err))
	}

	task.TaskId = taskId
	task.ProjectId = projectId
	return &task, nil
}

func (r *FirestoreTaskRepository) ListTasksByProject(ctx context.Context, projectId string, statusFilter *types.TaskStatus) ([]types.Task, error) {
	var query firestore.Query = r.client.Collection("projects").Doc(projectId).Collection("tasks").Query

	if statusFilter != nil {
		query = query.Where("status", "==", string(*statusFilter))
	}

	iter := query.Documents(ctx)
	defer iter.Stop()

	tasks := make([]types.Task, 0)
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, errors.NewInternalServerError(fmt.Sprintf("failed to iterate tasks in firestore: %v", err))
		}

		var t types.Task
		if err := doc.DataTo(&t); err != nil {
			continue
		}
		t.TaskId = doc.Ref.ID
		t.ProjectId = projectId
		tasks = append(tasks, t)
	}

	return tasks, nil
}

func (r *FirestoreTaskRepository) ListAllPendingTasks(ctx context.Context) (map[string][]types.Task, error) {
	q := r.client.CollectionGroup("tasks").Where("status", "==", string(types.StatusPending))
	iter := q.Documents(ctx)
	defer iter.Stop()

	pendingMap := make(map[string][]types.Task)
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, errors.NewInternalServerError(fmt.Sprintf("failed to scan pending tasks in firestore: %v", err))
		}

		var t types.Task
		if err := doc.DataTo(&t); err != nil {
			continue
		}
		t.TaskId = doc.Ref.ID
		if t.ProjectId == "" && doc.Ref.Parent != nil && doc.Ref.Parent.Parent != nil {
			t.ProjectId = doc.Ref.Parent.Parent.ID
		}

		if t.ProjectId != "" {
			pendingMap[t.ProjectId] = append(pendingMap[t.ProjectId], t)
		}
	}

	return pendingMap, nil
}

func (r *FirestoreTaskRepository) DeleteTask(ctx context.Context, projectId string, taskId string) error {
	taskRef := r.getTaskRef(projectId, taskId)
	docSnap, err := taskRef.Get(ctx)
	if err != nil {
		if status.Code(err) == codes.NotFound {
			return errors.NewNotFoundError(fmt.Sprintf("task '%s' not found in project '%s'", taskId, projectId))
		}
		return errors.NewInternalServerError(fmt.Sprintf("failed to get task before deletion: %v", err))
	}

	if !docSnap.Exists() {
		return errors.NewNotFoundError(fmt.Sprintf("task '%s' not found in project '%s'", taskId, projectId))
	}

	if _, err := taskRef.Delete(ctx); err != nil {
		return errors.NewInternalServerError(fmt.Sprintf("failed to delete task '%s' from firestore: %v", taskId, err))
	}

	return nil
}
