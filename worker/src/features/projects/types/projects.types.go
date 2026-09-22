package types

/*
TOP-LEVEL ALGORITHM BLUEPRINT: PROJECT DOMAIN TYPES & ENUMS
===========================================================
1. Domain Enum Validation:
   - Enforces valid project lifecycle states: ACTIVE, ON_HOLD, COMPLETED, ARCHIVED.
   - Rejects unmapped or speculative state transitions.
2. Serialization Mapping:
   - Provides dual tag bindings for JSON (REST transport) and YAML (database storage).
   - Enforces strict camelCase JSON wire serialization conforming to Section 13.4.
3. Storage Container Schema:
   - Project represents the structured YAML document stored in `projects/{projectId}/project.yaml`.
*/

type ProjectStatus string

const (
	ProjectStatusActive    ProjectStatus = "ACTIVE"
	ProjectStatusOnHold    ProjectStatus = "ON_HOLD"
	ProjectStatusCompleted ProjectStatus = "COMPLETED"
	ProjectStatusArchived  ProjectStatus = "ARCHIVED"
)

func (s ProjectStatus) IsValid() bool {
	switch s {
	case ProjectStatusActive, ProjectStatusOnHold, ProjectStatusCompleted, ProjectStatusArchived:
		return true
	default:
		return false
	}
}

type Project struct {
	ProjectId   string        `json:"projectId" yaml:"projectId"`
	Name        string        `json:"name" yaml:"name"`
	Description string        `json:"description" yaml:"description"`
	OwnerEmail  string        `json:"ownerEmail,omitempty" yaml:"ownerEmail,omitempty"`
	Status      ProjectStatus `json:"status" yaml:"status"`
	CreatedAt   string        `json:"createdAt" yaml:"createdAt"`
	UpdatedAt   string        `json:"updatedAt" yaml:"updatedAt"`
}

type UpsertProjectInput struct {
	ProjectId   string        `json:"projectId"`
	Name        string        `json:"name"`
	Description string        `json:"description"`
	OwnerEmail  string        `json:"ownerEmail"`
	Status      ProjectStatus `json:"status"`
}

type UpdateProjectInput struct {
	Name        string         `json:"name,omitempty"`
	Description string         `json:"description,omitempty"`
	OwnerEmail  string         `json:"ownerEmail,omitempty"`
	Status      *ProjectStatus `json:"status,omitempty"`
}
