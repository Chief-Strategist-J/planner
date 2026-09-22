package middleware

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"planner/src/shared/errors"
	"planner/src/shared/response"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: HTTP TRANSPORT MIDDLEWARE CHAIN
==============================================================
1. Tracing & Metadata Extraction:
   - Evaluates incoming HTTP transport headers (traceparent, x-request-id, x-correlation-id, x-api-version).
   - Generates compliant unique identifiers for any omitted header values.
   - Injects canonical tracing and correlation headers into the outgoing HTTP response stream.
   - Stores request timing, identifiers, and version in the Go request context.
2. Cryptographic Idempotency Verification:
   - Intercepts mutating HTTP verbs (POST, PUT, PATCH, DELETE) when `x-idempotency-key` is supplied.
   - Reads the full request payload and computes a SHA-256 digest: SHA256(method + ":" + path + ":" + body).
   - Queries the thread-safe idempotency registry:
     a. Match found with identical hash: Emits cached status code, headers, and body with `x-cache-hit: true`.
     b. Match found with differing hash: Terminates execution immediately with HTTP 409 IDEMPOTENCY_KEY_REUSE.
     c. Cache miss: Executes the downstream handler, captures the emitted response, and stores it in the registry.
3. Panic Recovery Guard:
   - Catches unhandled panics, logs the failure, and returns a standardized 500 INTERNAL_SERVER_ERROR response.
*/

type contextKey string

const (
	ContextKeyRequestId     contextKey = "requestId"
	ContextKeyCorrelationId contextKey = "correlationId"
	ContextKeyCausationId   contextKey = "causationId"
	ContextKeyStartTime     contextKey = "startTime"
	ContextKeyApiVersion    contextKey = "apiVersion"
)

type IdempotencyRecord struct {
	RequestHash string
	StatusCode  int
	Body        []byte
	Headers     http.Header
}

type IdempotencyStore struct {
	mu      sync.RWMutex
	records map[string]IdempotencyRecord
}

func NewIdempotencyStore() *IdempotencyStore {
	return &IdempotencyStore{
		records: make(map[string]IdempotencyRecord),
	}
}

func generateRandomHex(byteCount int) string {
	b := make([]byte, byteCount)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func ContextMetadataMiddleware(apiVersion string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			startTime := time.Now()

			reqId := r.Header.Get("x-request-id")
			if reqId == "" {
				reqId = fmt.Sprintf("req-%d-%s", time.Now().UnixMilli(), generateRandomHex(4))
			}

			corrId := r.Header.Get("x-correlation-id")
			if corrId == "" {
				corrId = fmt.Sprintf("corr-%d-%s", time.Now().UnixMilli(), generateRandomHex(4))
			}

			causationId := r.Header.Get("x-causation-id")

			traceParent := r.Header.Get("traceparent")
			if traceParent == "" {
				traceParent = fmt.Sprintf("00-%s-%s-01", generateRandomHex(16), generateRandomHex(8))
			}

			w.Header().Set("traceparent", traceParent)
			w.Header().Set("x-request-id", reqId)
			w.Header().Set("x-correlation-id", corrId)
			w.Header().Set("x-api-version", apiVersion)
			w.Header().Set("Content-Type", "application/json")

			ctx := context.WithValue(r.Context(), ContextKeyRequestId, reqId)
			ctx = context.WithValue(ctx, ContextKeyCorrelationId, corrId)
			ctx = context.WithValue(ctx, ContextKeyCausationId, causationId)
			ctx = context.WithValue(ctx, ContextKeyStartTime, startTime)
			ctx = context.WithValue(ctx, ContextKeyApiVersion, apiVersion)

			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

type bufferedResponseWriter struct {
	http.ResponseWriter
	statusCode int
	body       bytes.Buffer
}

func (b *bufferedResponseWriter) WriteHeader(statusCode int) {
	b.statusCode = statusCode
	b.ResponseWriter.WriteHeader(statusCode)
}

func (b *bufferedResponseWriter) Write(p []byte) (int, error) {
	b.body.Write(p)
	return b.ResponseWriter.Write(p)
}

func IdempotencyMiddleware(store *IdempotencyStore) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method != http.MethodPost && r.Method != http.MethodPut && r.Method != http.MethodPatch && r.Method != http.MethodDelete {
				next.ServeHTTP(w, r)
				return
			}

			idempotencyKey := r.Header.Get("x-idempotency-key")
			if idempotencyKey == "" {
				next.ServeHTTP(w, r)
				return
			}

			bodyBytes, err := io.ReadAll(r.Body)
			if err != nil {
				http.Error(w, `{"error":"unable to read request body"}`, http.StatusBadRequest)
				return
			}
			r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))

			hasher := sha256.New()
			hasher.Write([]byte(r.Method))
			hasher.Write([]byte(":"))
			hasher.Write([]byte(r.URL.Path))
			hasher.Write([]byte(":"))
			hasher.Write(bodyBytes)
			currentHash := hex.EncodeToString(hasher.Sum(nil))

			store.mu.RLock()
			existing, exists := store.records[idempotencyKey]
			store.mu.RUnlock()

			if exists {
				if existing.RequestHash != currentHash {
					reqId, _ := r.Context().Value(ContextKeyRequestId).(string)
					corrId, _ := r.Context().Value(ContextKeyCorrelationId).(string)
					apiVersion, _ := r.Context().Value(ContextKeyApiVersion).(string)
					startTime, _ := r.Context().Value(ContextKeyStartTime).(time.Time)

					meta := response.BuildMeta(reqId, corrId, "", startTime, apiVersion)
					errResp := response.NewErrorResponse(
						http.StatusConflict,
						errors.CodeIdempotencyKeyReuse,
						"Idempotency key collision detected with conflicting request payload hash",
						false,
						nil,
						meta,
					)
					w.WriteHeader(http.StatusConflict)
					_ = json.NewEncoder(w).Encode(errResp)
					return
				}

				for k, v := range existing.Headers {
					for _, headerVal := range v {
						w.Header().Add(k, headerVal)
					}
				}
				w.Header().Set("x-cache-hit", "true")
				w.WriteHeader(existing.StatusCode)
				_, _ = w.Write(existing.Body)
				return
			}

			bufferedWriter := &bufferedResponseWriter{
				ResponseWriter: w,
				statusCode:     http.StatusOK,
			}

			next.ServeHTTP(bufferedWriter, r)

			if bufferedWriter.statusCode < 400 {
				store.mu.Lock()
				store.records[idempotencyKey] = IdempotencyRecord{
					RequestHash: currentHash,
					StatusCode:  bufferedWriter.statusCode,
					Body:        bufferedWriter.body.Bytes(),
					Headers:     bufferedWriter.Header().Clone(),
				}
				store.mu.Unlock()
			}
		})
	}
}

func PanicRecoveryMiddleware() func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					reqId, _ := r.Context().Value(ContextKeyRequestId).(string)
					corrId, _ := r.Context().Value(ContextKeyCorrelationId).(string)
					apiVersion, _ := r.Context().Value(ContextKeyApiVersion).(string)
					startTime, _ := r.Context().Value(ContextKeyStartTime).(time.Time)

					meta := response.BuildMeta(reqId, corrId, "", startTime, apiVersion)
					errResp := response.NewErrorResponse(
						http.StatusInternalServerError,
						errors.CodeInternalServerError,
						fmt.Sprintf("Internal system panic recovered: %v", rec),
						true,
						nil,
						meta,
					)
					w.WriteHeader(http.StatusInternalServerError)
					_ = json.NewEncoder(w).Encode(errResp)
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}
