package errors

import (
	"fmt"
	"net/http"

	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: CANONICAL ERROR TAXONOMY
========================================================
1. Error Standardization:
   - Provides immutable machine-readable canonical error string identifiers.
   - Strictly conforms to Section 0.2 and 13.3 of the API specification.
2. AppError Model:
   - Enriches standard Go errors with HTTP status codes, machine-readable error codes,
     retryability indicators, and optional field-level validation breakdowns.
3. Factory Functions:
   - Encapsulates common application failure classifications:
     NotFound, Validation, IdempotencyKeyReuse, Conflict, InternalServer.
*/

const (
	CodeResourceNotFound      = "RESOURCE_NOT_FOUND"
	CodeValidationFailed      = "VALIDATION_FAILED"
	CodeIdempotencyKeyReuse   = "IDEMPOTENCY_KEY_REUSE"
	CodeConflict              = "CONFLICT"
	CodeInternalServerError   = "INTERNAL_SERVER_ERROR"
	CodeBadRequest            = "BAD_REQUEST"
	CodePayloadTooLarge       = "PAYLOAD_TOO_LARGE"
	CodeUnsupportedMediaType  = "UNSUPPORTED_MEDIA_TYPE"
	CodeUnsupportedApiVersion = "UNSUPPORTED_API_VERSION"
)

type AppError struct {
	StatusCode int
	Code       string
	Message    string
	Retryable  bool
	Details    []response.ErrorDetail
}

func (e *AppError) Error() string {
	return fmt.Sprintf("[%s] %s (HTTP %d)", e.Code, e.Message, e.StatusCode)
}

func NewNotFoundError(message string) *AppError {
	return &AppError{
		StatusCode: http.StatusNotFound,
		Code:       CodeResourceNotFound,
		Message:    message,
		Retryable:  false,
	}
}

func NewValidationError(message string, details []response.ErrorDetail) *AppError {
	return &AppError{
		StatusCode: http.StatusBadRequest,
		Code:       CodeValidationFailed,
		Message:    message,
		Retryable:  false,
		Details:    details,
	}
}

func NewIdempotencyKeyReuseError(message string) *AppError {
	return &AppError{
		StatusCode: http.StatusConflict,
		Code:       CodeIdempotencyKeyReuse,
		Message:    message,
		Retryable:  false,
	}
}

func NewInternalServerError(message string) *AppError {
	return &AppError{
		StatusCode: http.StatusInternalServerError,
		Code:       CodeInternalServerError,
		Message:    message,
		Retryable:  true,
	}
}

func NewBadRequestError(message string) *AppError {
	return &AppError{
		StatusCode: http.StatusBadRequest,
		Code:       CodeBadRequest,
		Message:    message,
		Retryable:  false,
	}
}
