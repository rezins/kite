# Stage 1: Build Frontend
FROM node:20-alpine AS frontend-builder
WORKDIR /app/ui
COPY ui/package.json ui/pnpm-lock.yaml ./
RUN npm install -g pnpm && \
    pnpm install --frozen-lockfile
COPY ui/ ./
RUN pnpm run build

# Stage 2: Build Backend
FROM golang:1.24.9-alpine3.22 AS backend-builder
WORKDIR /app
COPY go.mod ./
COPY go.sum ./
RUN go mod download
COPY . .
COPY --from=frontend-builder /app/static ./static
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o kite .

# Stage 3: Final Ubuntu Image with doctl
FROM ubuntu:24.04
USER root
# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    curl && \
    rm -rf /var/lib/apt/lists/*

# Install doctl
RUN wget -q https://github.com/digitalocean/doctl/releases/download/v1.115.0/doctl-1.115.0-linux-amd64.tar.gz && \
    tar xf doctl-1.115.0-linux-amd64.tar.gz && \
    mv doctl /usr/local/bin/ && \
    chmod +x /usr/local/bin/doctl && \
    rm doctl-1.115.0-linux-amd64.tar.gz && \
    doctl version

# Set working directory
WORKDIR /app

# Copy binary from backend builder
COPY --from=backend-builder /app/kite .

# Expose port
EXPOSE 8080

# Run the application
CMD ["./kite"]