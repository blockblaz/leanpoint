# Multi-stage build for leanpoint

# Stage 1: Build stage
FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
    curl \
    xz \
    bash

# Install Zig 0.14.1
ARG ZIG_VERSION=0.14.1
RUN curl -L -o /tmp/zig.tar.xz "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" && \
    tar -xJf /tmp/zig.tar.xz -C /usr/local && \
    ln -s "/usr/local/zig-x86_64-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig && \
    rm /tmp/zig.tar.xz

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
