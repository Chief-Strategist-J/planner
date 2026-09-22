# Stage 1: Build binary
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Install git and ca-certificates
RUN apk add --no-cache git ca-certificates

# Copy dependency specifications
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Compile optimized static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/bin/planner-server ./server/main.go

# Stage 2: Minimal runtime container
FROM alpine:3.20

WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata

# Create projects storage directory
RUN mkdir -p /app/projects /app/config

# Copy compiled binary and configuration
COPY --from=builder /app/bin/planner-server /app/planner-server
COPY config/default.yaml /app/config/default.yaml

# Set environment defaults for Cloud Run
ENV PORT=8080
ENV PROJECTS_DIR=/app/projects
ENV CONFIG_PATH=/app/config/default.yaml

EXPOSE 8080

ENTRYPOINT ["/app/planner-server"]
