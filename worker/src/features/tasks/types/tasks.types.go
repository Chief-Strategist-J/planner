package types

/*
TOP-LEVEL ALGORITHM BLUEPRINT: TASK DOMAIN TYPES & ENUMS
=========================================================
1. Domain Enum Validation:
   - Enforces valid task lifecycle states: PENDING, IN_PROGRESS, COMPLETED, CANCELLED.
   - Enforces valid task priority ratings: LOW, MEDIUM, HIGH, CRITICAL.
   - Rejects unmapped or speculative state transitions.
2. Serialization Mapping:
   - Provides dual tag bindings for JSON (REST transport) and YAML (database storage).
   - Enforces strict camelCase JSON wire serialization conforming to Section 13.4.
3. Storage Container Schema:
   - ProjectTasksFile represents the top-level structured YAML document in `projects/{projectId}/tasks.yaml`.
*/

type TaskStatus string

const (
	StatusPending    TaskStatus = "PENDING"
	StatusInProgress TaskStatus = "IN_PROGRESS"
	StatusCompleted  TaskStatus = "COMPLETED"
	StatusCancelled  TaskStatus = "CANCELLED"
)

func (s TaskStatus) IsValid() bool {
	switch s {
	case StatusPending, StatusInProgress, StatusCompleted, StatusCancelled:
		return true
	default:
		return false
	}
}

type TaskPriority string

const (
	PriorityLow      TaskPriority = "LOW"
	PriorityMedium   TaskPriority = "MEDIUM"
	PriorityHigh     TaskPriority = "HIGH"
	PriorityCritical TaskPriority = "CRITICAL"
)

func (p TaskPriority) IsValid() bool {
	switch p {
	case PriorityLow, PriorityMedium, PriorityHigh, PriorityCritical:
		return true
	default:
		return false
	}
}

type Task struct {
	TaskId          string       `json:"taskId" yaml:"taskId" firestore:"taskId"`
	ProjectId       string       `json:"projectId" yaml:"projectId" firestore:"projectId"`
	Title           string       `json:"title" yaml:"title" firestore:"title"`
	Description     string       `json:"description" yaml:"description" firestore:"description"`
	Status          TaskStatus   `json:"status" yaml:"status" firestore:"status"`
	Priority        TaskPriority `json:"priority,omitempty" yaml:"priority,omitempty" firestore:"priority,omitempty"`
	AssignedToEmail string       `json:"assignedToEmail,omitempty" yaml:"assignedToEmail,omitempty" firestore:"assignedToEmail,omitempty"`
	DueDate         string       `json:"dueDate,omitempty" yaml:"dueDate,omitempty" firestore:"dueDate,omitempty"`
	CreatedAt       string       `json:"createdAt" yaml:"createdAt" firestore:"createdAt"`
	UpdatedAt       string       `json:"updatedAt" yaml:"updatedAt" firestore:"updatedAt"`
}

type ProjectTasksFile struct {
	ProjectId   string `json:"projectId" yaml:"projectId"`
	LastUpdated string `json:"lastUpdated" yaml:"lastUpdated"`
	Tasks       []Task `json:"tasks" yaml:"tasks"`
}

type UpsertTaskInput struct {
	TaskId          string       `json:"taskId"`
	Title           string       `json:"title"`
	Description     string       `json:"description"`
	Status          TaskStatus   `json:"status"`
	Priority        TaskPriority `json:"priority"`
	AssignedToEmail string       `json:"assignedToEmail"`
	DueDate         string       `json:"dueDate"`
}

type UpdateTaskStatusInput struct {
	Status TaskStatus `json:"status"`
}

type SchedulerSweepResult struct {
	ScannedProjects   int `json:"scannedProjects"`
	PendingTasksFound int `json:"pendingTasksFound"`
	EmailsDispatched  int `json:"emailsDispatched"`
}
