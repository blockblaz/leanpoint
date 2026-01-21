# Multi-stage build for leanpoint

# Stage 1: Build stage
FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
    curl \
    xz \
    bash

# Install Zig
ARG ZIG_VERSION=0.13.0
RUN curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" | tar -xJ -C /usr/local && \
    ln -s "/usr/local/zig-linux-x86_64-${ZIG_VERSION}/zig" /usr/local/bin/zig

# Set working directory
WORKDIR /build

# Copy source files
COPY build.zig build.zig.zon ./
COPY src/ ./src/

# Build the project
RUN zig build -Doptimize=ReleaseSafe

# Stage 2: Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    libgcc \
    libstdc++

# Create non-root user
RUN addgroup -g 1000 leanpoint && \
    adduser -D -u 1000 -G leanpoint leanpoint

# Create directories
RUN mkdir -p /etc/leanpoint /var/lib/leanpoint && \
    chown -R leanpoint:leanpoint /etc/leanpoint /var/lib/leanpoint

# Copy binary from builder
COPY --from=builder /build/zig-out/bin/leanpoint /usr/local/bin/leanpoint

# Copy example config
COPY upstreams.example.json /etc/leanpoint/upstreams.example.json

# Switch to non-root user
USER leanpoint

# Expose port
EXPOSE 5555

# Set working directory
WORKDIR /var/lib/leanpoint

# Default command
CMD ["leanpoint", "--help"]
