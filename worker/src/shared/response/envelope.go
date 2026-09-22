package response

import (
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
3. Execution Time Calculation:
   - Computes elapsed execution duration in milliseconds from the request start context.
4. Response Assembly:
   - NewSuccessResponse: Instantiates an ApiResponse[T] with success=true and the supplied payload.
   - NewErrorResponse: Instantiates an ApiErrorResponse with success=false and standardized error taxonomy.
*/

type Meta struct {
	RequestId       string `json:"requestId"`
	CorrelationId   string `json:"correlationId"`
	CausationId     string `json:"causationId,omitempty"`
	Timestamp       string `json:"timestamp"`
	ExecutionTimeMs int64  `json:"executionTimeMs"`
	ApiVersion      string `json:"apiVersion"`
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
