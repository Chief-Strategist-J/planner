package response

import (
	"math"
	"time"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: RESPONSE ENVELOPE GENERATION
============================================================
1. Standard Invariant Compliance:
   - Formulates strict RFC-compliant envelopes for all HTTP transport outcomes.
   - Strictly enforces the existence of `success`, `statusCode`, `data`/`error`, and `meta`.
   - Rejects the simultaneous existence of `data` and `error`.
2. Timestamp Standardization:
   - Generates millisecond-precision UTC RFC3339 timestamps terminating with literal 'Z'.
   - Complies with Section 13.1 of the API Request & Response Specification.
3. Pagination Compliance (Section 13.2):
   - Generates PaginationMeta containing page, pageSize, totalItems, totalPages,
     hasNextPage, hasPreviousPage, nextCursor.
   - Provides PaginateSlice utility to deterministically slice in-memory collections.
4. Response Assembly:
   - NewSuccessResponse: Instantiates an ApiResponse[T] with success=true and the supplied payload.
   - NewPaginatedSuccessResponse: Instantiates an ApiResponse[T] including meta.pagination.
   - NewErrorResponse: Instantiates an ApiErrorResponse with success=false and standardized error taxonomy.
*/

type PaginationMeta struct {
	Page            *int    `json:"page"`
	PageSize        int     `json:"pageSize"`
	TotalItems      *int    `json:"totalItems"`
	TotalPages      *int    `json:"totalPages"`
	HasNextPage     bool    `json:"hasNextPage"`
	HasPreviousPage bool    `json:"hasPreviousPage"`
	NextCursor      *string `json:"nextCursor"`
}

type Meta struct {
	RequestId       string          `json:"requestId"`
	CorrelationId   string          `json:"correlationId"`
	CausationId     string          `json:"causationId,omitempty"`
	Timestamp       string          `json:"timestamp"`
	ExecutionTimeMs int64           `json:"executionTimeMs"`
	ApiVersion      string          `json:"apiVersion"`
	Pagination      *PaginationMeta `json:"pagination,omitempty"`
}

type ErrorDetail struct {
	Field string `json:"field"`
	Issue string `json:"issue"`
}

type ErrorInfo struct {
	Code      string        `json:"code"`
	Message   string        `json:"message"`
	Retryable bool          `json:"retryable"`
	Details   []ErrorDetail `json:"details,omitempty"`
}

type ApiResponse[T any] struct {
	Success    bool `json:"success"`
	StatusCode int  `json:"statusCode"`
	Data       T    `json:"data"`
	Meta       Meta `json:"meta"`
}

type ApiErrorResponse struct {
	Success    bool      `json:"success"`
	StatusCode int       `json:"statusCode"`
	Error      ErrorInfo `json:"error"`
	Meta       Meta      `json:"meta"`
}

func FormatIsoTimestamp(t time.Time) string {
	return t.UTC().Format("2006-01-02T15:04:05.000Z")
}

func BuildMeta(requestId string, correlationId string, causationId string, startTime time.Time, apiVersion string) Meta {
	elapsed := time.Since(startTime).Milliseconds()
	if elapsed < 0 {
		elapsed = 0
	}
	return Meta{
		RequestId:       requestId,
		CorrelationId:   correlationId,
		CausationId:     causationId,
		Timestamp:       FormatIsoTimestamp(time.Now()),
		ExecutionTimeMs: elapsed,
		ApiVersion:      apiVersion,
	}
}

func NewSuccessResponse[T any](statusCode int, data T, meta Meta) ApiResponse[T] {
	return ApiResponse[T]{
		Success:    true,
		StatusCode: statusCode,
		Data:       data,
		Meta:       meta,
	}
}

func NewPaginatedSuccessResponse[T any](statusCode int, data T, meta Meta, pagination PaginationMeta) ApiResponse[T] {
	meta.Pagination = &pagination
	return ApiResponse[T]{
		Success:    true,
		StatusCode: statusCode,
		Data:       data,
		Meta:       meta,
	}
}

func NewErrorResponse(statusCode int, code string, message string, retryable bool, details []ErrorDetail, meta Meta) ApiErrorResponse {
	return ApiErrorResponse{
		Success:    false,
		StatusCode: statusCode,
		Error: ErrorInfo{
			Code:      code,
			Message:   message,
			Retryable: retryable,
			Details:   details,
		},
		Meta: meta,
	}
}

func PaginateSlice[T any](items []T, page int, pageSize int) ([]T, PaginationMeta) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 10
	}
	if pageSize > 100 {
		pageSize = 100
	}

	totalItems := len(items)
	totalPages := int(math.Ceil(float64(totalItems) / float64(pageSize)))
	if totalPages == 0 && totalItems == 0 {
		totalPages = 0
	}

	startIndex := (page - 1) * pageSize
	if startIndex > totalItems {
		startIndex = totalItems
	}

	endIndex := startIndex + pageSize
	if endIndex > totalItems {
		endIndex = totalItems
	}

	sliced := items[startIndex:endIndex]
	if sliced == nil {
		sliced = []T{}
	}

	hasNextPage := page < totalPages
	hasPreviousPage := page > 1 && totalPages > 0

	pagination := PaginationMeta{
		Page:            &page,
		PageSize:        pageSize,
		TotalItems:      &totalItems,
		TotalPages:      &totalPages,
		HasNextPage:     hasNextPage,
		HasPreviousPage: hasPreviousPage,
		NextCursor:      nil,
	}

	return sliced, pagination
}
