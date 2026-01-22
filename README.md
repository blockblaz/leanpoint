# LeanEthereum Checkpoint Status Service

[![CI](https://github.com/blockblaz/leanpoint/workflows/CI/badge.svg)](https://github.com/blockblaz/leanpoint/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A lightweight, fast Zig service that monitors finality across multiple Lean Ethereum lean nodes with consensus validation. Inspired by [checkpointz](https://github.com/ethpandaops/checkpointz), leanpoint provides reliable checkpoint sync monitoring for the Lean Ethereum ecosystem.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [API Endpoints](#api-endpoints)
- [Configuration](#configuration)
- [Integration with lean-quickstart](#integration-with-lean-quickstart)
- [Supported Beacon API Formats](#supported-beacon-api-formats)
- [Consensus Algorithm](#consensus-algorithm)
- [Monitoring with Prometheus](#monitoring-with-prometheus)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)
- [Architecture Comparison](#architecture-comparison)
- [Contributing](#contributing)

## Overview

Leanpoint polls multiple lean nodes, requires 50%+ consensus before serving finality data, and exposes a simple HTTP API with Prometheus metrics. It's designed for:

- **Devnet Monitoring**: Track finality across local test networks
- **Production Deployments**: Provide reliable checkpoint sync data
- **Multi-Client Testing**: Monitor zeam, ream, qlean, lantern, lighthouse, grandine, and more
- **Consensus Validation**: Ensure finality agreement across diverse implementations

## Features

- ✅ **Multi-upstream support** with 50%+ consensus requirement (like checkpointz)
- ✅ **Parallel polling** of all lean nodes for low latency
- ✅ **Per-upstream health tracking** with error counts and timestamps
- ✅ **Prometheus metrics** for comprehensive monitoring
- ✅ **Health check endpoint** for load balancers and orchestration
- ✅ **Lightweight binary** (~8MB) with minimal resource usage
- ✅ **Easy integration** with lean-quickstart devnets
- ✅ **Standard Beacon API** format support

## Quick Start

### 1. Build

```bash
zig build
```

### 2. Create Configuration

Using the helper script with lean-quickstart:
```bash
python3 convert-validator-config.py \
  ../lean-quickstart/local-devnet/genesis/validator-config.yaml \
  upstreams.json
```

Or create manually:
```bash
cp upstreams.example.json upstreams.json
# Edit as needed
```

### 3. Run

```bash
./zig-out/bin/leanpoint --upstreams-config upstreams.json
```

### 4. Check Status

```bash
curl http://localhost:5555/status
curl http://localhost:5555/metrics
curl http://localhost:5555/healthz
```

## API Endpoints

### GET /status

Returns current finality checkpoint with metadata:

```json
{
  "justified_slot": 12345,
  "finalized_slot": 12344,
  "last_updated_ms": 1705852800000,
  "last_success_ms": 1705852800000,
  "stale": false,
  "error_count": 0,
  "last_error": null
}
```

**Fields:**
- `justified_slot`: Latest justified slot number (consensus from upstreams)
- `finalized_slot`: Latest finalized slot number (consensus from upstreams)
- `last_updated_ms`: Timestamp of last update attempt (milliseconds since epoch)
- `last_success_ms`: Timestamp of last successful consensus (milliseconds since epoch)
- `stale`: Boolean indicating if data is stale (exceeds threshold)
- `error_count`: Total number of errors encountered
- `last_error`: Most recent error message (null if no errors)

**HTTP Status:**
- `200 OK`: Data available (may be stale if `stale: true`)
- `500 Internal Server Error`: Server error

### GET /metrics

Returns Prometheus metrics:

```
# HELP leanpoint_justified_slot Latest justified slot.
# TYPE leanpoint_justified_slot gauge
leanpoint_justified_slot 12345
# HELP leanpoint_finalized_slot Latest finalized slot.
# TYPE leanpoint_finalized_slot gauge
leanpoint_finalized_slot 12344
# HELP leanpoint_last_success_timestamp_ms Last successful poll time (ms since epoch).
# TYPE leanpoint_last_success_timestamp_ms gauge
leanpoint_last_success_timestamp_ms 1705852800000
# HELP leanpoint_last_updated_timestamp_ms Last update time (ms since epoch).
# TYPE leanpoint_last_updated_timestamp_ms gauge
leanpoint_last_updated_timestamp_ms 1705852800000
# HELP leanpoint_last_latency_ms Last poll latency in milliseconds.
# TYPE leanpoint_last_latency_ms gauge
leanpoint_last_latency_ms 45
# HELP leanpoint_error_total Total poll errors.
# TYPE leanpoint_error_total counter
leanpoint_error_total 0
```

**Metrics:**
- `leanpoint_justified_slot`: Latest justified slot (gauge)
- `leanpoint_finalized_slot`: Latest finalized slot (gauge)
- `leanpoint_last_success_timestamp_ms`: Last successful consensus time (gauge)
- `leanpoint_last_updated_timestamp_ms`: Last update attempt time (gauge)
- `leanpoint_last_latency_ms`: Poll latency in milliseconds (gauge)
- `leanpoint_error_total`: Total errors (counter)

### GET /healthz

Health check for load balancers:

- Returns `200 OK` when data is fresh
- Returns `503 Service Unavailable` when stale

**Health Criteria:**
- Data must not be stale (within `--stale-ms` threshold)
- At least one successful poll must have occurred

### Static Files (Optional)

If `--static-dir` is set, other paths serve files from that directory.

## Configuration

### Defaults

| Option | Default | Description |
|--------|---------|-------------|
| Bind address | `0.0.0.0` | HTTP server bind address |
| Port | `5555` | HTTP server port |
| Lean URL | `http://127.0.0.1:5052` | Single upstream URL (legacy) |
| Lean path | `/status` | Beacon API endpoint path |
| Poll interval | `10000` ms | Time between upstream polls |
| Request timeout | `5000` ms | HTTP request timeout |
| Stale threshold | `30000` ms | Data freshness threshold |

### Single Upstream Mode (Legacy)

For monitoring a single lean node:

```bash
leanpoint \
  --bind 0.0.0.0 \
  --port 5555 \
  --lean-url http://127.0.0.1:5052 \
  --lean-path /status \
  --poll-ms 10000 \
  --timeout-ms 5000 \
  --stale-ms 30000 \
  --static-dir ./web
```

### Multi-Upstream Mode (Recommended)

Monitor multiple lean nodes with consensus validation:

```bash
leanpoint \
  --upstreams-config ./upstreams.json \
  --poll-ms 10000 \
  --timeout-ms 5000 \
  --stale-ms 30000
```

**How it works:**
1. Polls all upstreams in parallel every 10 seconds
2. Collects justified/finalized slot pairs from each
3. Only serves data when **50%+ of upstreams agree**
4. Tracks per-upstream health (errors, latency, last success)

**Example `upstreams.json`:**

```json
{
  "upstreams": [
    {
      "name": "zeam_0",
      "url": "http://localhost:5052",
      "path": "/status"
    },
    {
      "name": "ream_0",
      "url": "http://localhost:5053",
      "path": "/status"
    },
    {
      "name": "qlean_0",
      "url": "http://localhost:5054",
      "path": "/status"
    },
    {
      "name": "lighthouse_0",
      "url": "http://localhost:5055",
      "path": "/eth/v1/beacon/states/finalized/finality_checkpoints"
    }
  ]
}
```

### Environment Variables

All CLI options can be set via environment variables:

```bash
LEANPOINT_BIND_ADDR=0.0.0.0
LEANPOINT_BIND_PORT=5555
LEANPOINT_LEAN_URL=http://127.0.0.1:5052
LEANPOINT_LEAN_PATH=/status
LEANPOINT_POLL_MS=10000
LEANPOINT_TIMEOUT_MS=5000
LEANPOINT_STALE_MS=30000
LEANPOINT_STATIC_DIR=/path/to/static
LEANPOINT_UPSTREAMS_CONFIG=/path/to/upstreams.json
```

### CLI Options

```
Usage:
  leanpoint [options]

Options:
  --bind <addr>             Bind address (default 0.0.0.0)
  --port <port>             Bind port (default 5555)
  --lean-url <url>          LeanEthereum base URL (legacy single upstream)
  --lean-path <path>        LeanEthereum path (default /status)
  --upstreams-config <file> JSON config file with multiple upstreams
  --poll-ms <ms>            Poll interval in milliseconds
  --timeout-ms <ms>         Request timeout in milliseconds
  --stale-ms <ms>           Stale threshold in milliseconds
  --static-dir <dir>        Optional static frontend directory
  --help                    Show this help
```

## Integration with lean-quickstart

Perfect integration with [lean-quickstart](https://github.com/your-org/lean-quickstart) devnets:

### Step-by-Step Guide

#### 1. Start your devnet

```bash
cd /path/to/lean-quickstart
NETWORK_DIR=local-devnet ./spin-node.sh --node all --generateGenesis
```

#### 2. Generate upstreams config

```bash
cd /path/to/leanpoint
python3 convert-validator-config.py \
  ../lean-quickstart/local-devnet/genesis/validator-config.yaml \
  upstreams.json
```

This automatically creates configuration for all nodes in your devnet:

```json
{
  "upstreams": [
    {
      "name": "zeam_0",
      "url": "http://127.0.0.1:5052",
      "path": "/status"
    },
    {
      "name": "ream_0",
      "url": "http://127.0.0.1:5053",
      "path": "/status"
    },
    {
      "name": "qlean_0",
      "url": "http://127.0.0.1:5054",
      "path": "/status"
    }
  ]
}
```

#### 3. Monitor finality

```bash
./zig-out/bin/leanpoint --upstreams-config upstreams.json
```

#### 4. Watch consensus

```bash
# Terminal 1: Follow leanpoint output
./zig-out/bin/leanpoint --upstreams-config upstreams.json

# Terminal 2: Poll status
watch -n 2 'curl -s http://localhost:5555/status | jq'

# Terminal 3: Monitor metrics
curl -s http://localhost:5555/metrics | grep leanpoint_
```

### Convert Validator Config Script

The `convert-validator-config.py` helper script automatically:
- Reads validator-config.yaml from lean-quickstart
- Extracts validator names and network information
- Generates appropriate HTTP endpoints for each validator
- Creates upstreams.json in the correct format

**Usage:**

```bash
# With default paths
python3 convert-validator-config.py

# With custom paths
python3 convert-validator-config.py \
  /path/to/validator-config.yaml \
  /path/to/output.json

# Adjust base port if needed (default: 5052)
# Edit the script to change base_port parameter
```

## Supported Beacon API Formats

Leanpoint automatically handles multiple API response formats:

### Format 1: Lean Ethereum Custom

Used by zeam, ream, qlean, and other Lean Ethereum clients.

**Endpoint:** `/status`

**Response:**
```json
{
  "justified_slot": 123,
  "finalized_slot": 120
}
```

**Configuration:**
```json
{
  "name": "zeam_0",
  "url": "http://localhost:5052",
  "path": "/status"
}
```

### Format 2: Standard Beacon API

Used by lighthouse, grandine, lodestar, teku, nimbus, prysm.

**Endpoint:** `/eth/v1/beacon/states/finalized/finality_checkpoints`

**Response:**
```json
{
  "data": {
    "justified": {"slot": "123"},
    "finalized": {"slot": "120"}
  }
}
```

**Configuration:**
```json
{
  "name": "lighthouse_0",
  "url": "http://localhost:5052",
  "path": "/eth/v1/beacon/states/finalized/finality_checkpoints"
}
```

### Format 3: Nested Data Object

Alternative format with nested structure.

**Response:**
```json
{
  "data": {
    "justified_slot": 123,
    "finalized_slot": 120
  }
}
```

## Consensus Algorithm

Leanpoint requires **50%+ of upstreams to agree** before serving finality data.

### How It Works

1. **Poll Phase**: All upstreams are polled concurrently
2. **Collection Phase**: Justified/finalized slot pairs are collected from each successful response
3. **Counting Phase**: Each unique slot pair is counted
4. **Consensus Phase**: Only pairs with >50% votes are accepted
5. **Serving Phase**: Consensus data is served to clients

### Consensus Examples

| Scenario | Agreement | Result | Example |
|----------|-----------|--------|---------|
| 3 upstreams, all agree | 3/3 = 100% | ✅ Serve data | All at (100, 99) |
| 3 upstreams, 2 agree | 2/3 = 67% | ✅ Serve data | Two at (100, 99), one at (101, 100) |
| 4 upstreams, 2 agree | 2/4 = 50% | ❌ No consensus | Two at (100, 99), two at (101, 100) |
| 5 upstreams, 3 agree | 3/5 = 60% | ✅ Serve data | Three at (100, 99), rest differ |
| 3 upstreams, all differ | 1/3 = 33% | ❌ No consensus | All on different slots |

### Why Consensus Matters

- **Byzantine Fault Tolerance**: Single node failures don't affect service
- **Fork Detection**: Disagreement indicates nodes may be on different forks
- **Data Integrity**: Only serve finality data that multiple implementations agree on
- **Network Health**: Consensus failures indicate potential network issues

## Monitoring with Prometheus

### Prometheus Configuration

Add to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'leanpoint'
    scrape_interval: 10s
    static_configs:
      - targets: ['localhost:5555']
    metrics_path: '/metrics'
```

### Useful Queries

**Current finalized slot:**
```promql
leanpoint_finalized_slot
```

**Finality progress (slots per minute):**
```promql
rate(leanpoint_finalized_slot[5m]) * 60
```

**Error rate:**
```promql
rate(leanpoint_error_total[5m])
```

**Time since last successful consensus (seconds):**
```promql
(time() * 1000 - leanpoint_last_success_timestamp_ms) / 1000
```

**Data staleness alert (>60 seconds):**
```promql
(time() * 1000 - leanpoint_last_success_timestamp_ms) > 60000
```

**Poll latency:**
```promql
leanpoint_last_latency_ms
```

### Grafana Dashboard

Create a dashboard with panels for:
1. **Finalized Slot Timeline**: Line graph of `leanpoint_finalized_slot`
2. **Finality Progress**: Gauge showing `rate(leanpoint_finalized_slot[5m]) * 60`
3. **Error Count**: Counter of `leanpoint_error_total`
4. **Staleness Indicator**: Alert when data exceeds threshold
5. **Poll Latency**: Line graph of `leanpoint_last_latency_ms`

## Troubleshooting

### No Consensus Reached

**Symptom:**
```json
{
  "last_error": "no consensus reached among upstreams"
}
```

**Causes:**
- Nodes are not synced or on different forks
- Network connectivity issues
- Insufficient number of upstreams responding
- Nodes returning different data formats

**Solutions:**

```bash
# Check individual node status
curl http://localhost:5052/status
curl http://localhost:5053/status
curl http://localhost:5054/status

# Verify nodes are synced
# Check node logs for sync status

# Test network connectivity
for port in 5052 5053 5054; do
  curl -v http://localhost:$port/status
done

# Verify response formats match expected
curl -s http://localhost:5052/status | jq
```

### Connection Refused

**Symptom:**
```json
{
  "last_error": "poll error: ConnectionRefused"
}
```

**Solutions:**

```bash
# Verify correct ports in upstreams.json
cat upstreams.json | jq '.upstreams[].url'

# Check nodes are running
ps aux | grep -E "zeam|ream|qlean"

# Verify lean API is exposed
curl -v http://localhost:5052/status

# Check node startup logs for API endpoint
```

### Stale Data

**Symptom:**
- `/healthz` returns `503 Service Unavailable`
- `/status` shows `"stale": true`

**Solutions:**

```bash
# Increase stale threshold
leanpoint --upstreams-config upstreams.json --stale-ms 60000

# Decrease poll interval
leanpoint --upstreams-config upstreams.json --poll-ms 5000

# Check if nodes are actually progressing
watch -n 1 'curl -s http://localhost:5052/status'

# Verify nodes are not stuck
curl http://localhost:5052/status
sleep 15
curl http://localhost:5052/status
# Slots should increase
```

### Timeout Errors

**Symptom:**
```json
{
  "last_error": "poll error: Timeout"
}
```

**Solutions:**

```bash
# Increase request timeout
leanpoint --upstreams-config upstreams.json --timeout-ms 10000

# Check network latency
time curl http://localhost:5052/status

# Verify node is responsive
curl -w "@curl-format.txt" http://localhost:5052/status
```

### Wrong Beacon API Format

**Symptom:**
```json
{
  "last_error": "poll error: UnexpectedResponse"
}
```

**Solutions:**

```bash
# Check actual response format
curl -s http://localhost:5052/status | jq

# For Lean clients, use /status
# For Standard Beacon API, use /eth/v1/beacon/states/finalized/finality_checkpoints

# Update path in upstreams.json accordingly
```

## Advanced Usage

### Docker Deployment

**Build the image:**
```bash
docker build -t leanpoint:latest .
```

**Run the container:**
```bash
# Create configuration first
cp upstreams.example.json upstreams.json
# Edit upstreams.json with your lean node endpoints

# Run container
docker run -d \
  --name leanpoint \
  --restart unless-stopped \
  -p 5555:5555 \
  -v $(pwd)/upstreams.json:/etc/leanpoint/upstreams.json:ro \
  leanpoint:latest \
  leanpoint --upstreams-config /etc/leanpoint/upstreams.json
```

**Monitor:**
```bash
# View logs
docker logs -f leanpoint

# Check status
curl http://localhost:5555/status
curl http://localhost:5555/metrics
```

**Stop and cleanup:**
```bash
docker stop leanpoint
docker rm leanpoint
```

**Multi-architecture builds:**
```bash
# Build for specific platform
docker build --platform linux/amd64 -t leanpoint:amd64 .
docker build --platform linux/arm64 -t leanpoint:arm64 .

# Or use buildx for multi-arch
docker buildx build --platform linux/amd64,linux/arm64 -t leanpoint:latest .
```

### Systemd Service

**`/etc/systemd/system/leanpoint.service`:**
```ini
[Unit]
Description=Leanpoint Checkpoint Status Service
After=network.target

[Service]
Type=simple
User=leanpoint
WorkingDirectory=/opt/leanpoint
ExecStart=/opt/leanpoint/leanpoint --upstreams-config /opt/leanpoint/upstreams.json
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Setup:**
```bash
# Install
sudo cp zig-out/bin/leanpoint /opt/leanpoint/
sudo cp upstreams.json /opt/leanpoint/
sudo cp leanpoint.service /etc/systemd/system/

# Create user
sudo useradd -r -s /bin/false leanpoint
sudo chown -R leanpoint:leanpoint /opt/leanpoint

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable leanpoint
sudo systemctl start leanpoint

# Check status
sudo systemctl status leanpoint
sudo journalctl -u leanpoint -f
```

### Kubernetes Deployment

**`deployment.yaml`:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: leanpoint-config
data:
  upstreams.json: |
    {
      "upstreams": [
        {"name": "zeam_0", "url": "http://zeam-0:5052", "path": "/status"},
        {"name": "ream_0", "url": "http://ream-0:5053", "path": "/status"}
      ]
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: leanpoint
spec:
  replicas: 1
  selector:
    matchLabels:
      app: leanpoint
  template:
    metadata:
      labels:
        app: leanpoint
    spec:
      containers:
      - name: leanpoint
        image: leanpoint:latest
        ports:
        - containerPort: 5555
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/leanpoint
        livenessProbe:
          httpGet:
            path: /healthz
            port: 5555
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /healthz
            port: 5555
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: config
        configMap:
          name: leanpoint-config
---
apiVersion: v1
kind: Service
metadata:
  name: leanpoint
spec:
  selector:
    app: leanpoint
  ports:
  - port: 5555
    targetPort: 5555
    name: http
```

### Reverse Proxy with nginx

**With SSL and CORS:**
```nginx
server {
    listen 443 ssl http2;
    server_name checkpoint.example.com;
    
    ssl_certificate /etc/letsencrypt/live/checkpoint.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/checkpoint.example.com/privkey.pem;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=leanpoint:10m rate=10r/s;
    
    location / {
        limit_req zone=leanpoint burst=20;
        proxy_pass http://localhost:5555;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS headers
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type";
    }
}
```

### Monitoring Stack with Docker Compose

**`docker-compose.yml`:**
```yaml
version: '3.8'

services:
  leanpoint:
    image: leanpoint:latest
    ports:
      - "5555:5555"
    volumes:
      - ./upstreams.json:/etc/leanpoint/upstreams.json
    restart: always

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    restart: always

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    restart: always

volumes:
  prometheus_data:
  grafana_data:
```

## Architecture Comparison

### Leanpoint vs Checkpointz

| Feature | Leanpoint | Checkpointz |
|---------|-----------|-------------|
| **Language** | Zig | Go |
| **Binary Size** | ~8MB | ~50MB |
| **Config Format** | JSON | YAML |
| **Consensus** | 50%+ | 50%+ |
| **Finality Status** | ✅ | ✅ |
| **Block Serving** | ❌ (future) | ✅ |
| **State Serving** | ❌ (future) | ✅ |
| **Historical Epochs** | ❌ (future) | ✅ |
| **Caching** | Minimal | Extensive |
| **Web UI** | Optional | Built-in |
| **Target** | Lean Ethereum | Standard Ethereum |
| **Resource Usage** | Very Low | Low |
| **Startup Time** | Instant | Fast |

### Design Philosophy

**Leanpoint:**
- Minimalist approach focused on finality monitoring
- Optimized for Lean Ethereum ecosystem
- Single binary with no external dependencies
- Configuration via simple JSON
- Ideal for devnets and lightweight deployments

**Checkpointz:**
- Full-featured checkpoint sync provider
- Serves complete blocks and states
- Integrated web UI with client guides
- Sophisticated caching strategies
- Production-ready for public endpoints

### When to Use Leanpoint

- ✅ Monitoring Lean Ethereum devnets
- ✅ Lightweight production finality monitoring
- ✅ Multi-client consensus validation
- ✅ Low-resource environments
- ✅ Simple deployment requirements

### When to Use Checkpointz

- ✅ Full checkpoint sync provider
- ✅ Serving beacon chain blocks and states
- ✅ Public-facing checkpoint endpoints
- ✅ Standard Ethereum networks
- ✅ Need for integrated web UI

## File Structure

```
leanpoint/
├── src/
│   ├── main.zig              # Entry point with single/multi mode
│   ├── config.zig            # Configuration loader
│   ├── upstreams.zig         # Upstream manager with consensus
│   ├── upstreams_config.zig  # JSON config parser
│   ├── lean_api.zig          # Beacon API client
│   ├── metrics.zig           # Prometheus metrics
│   ├── server.zig            # HTTP server
│   └── state.zig             # Application state
├── zig-out/
│   └── bin/
│       └── leanpoint         # Compiled binary
├── upstreams.example.json    # Example configuration
├── convert-validator-config.py # Helper script
├── build.zig                 # Build configuration
├── build.zig.zon             # Package manifest
├── .gitignore                # Git ignore rules
└── README.md                 # This file
```

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Make your changes with clear commit messages
4. Add tests if applicable
5. Ensure code compiles: `zig build`
6. Run tests: `zig build test`
7. Format code: `zig fmt src/`
8. Submit a pull request

### CI/CD

The repository includes GitHub Actions CI that automatically:
- Builds the project
- Runs tests
- Checks code formatting
- Builds Docker image

All pull requests must pass CI checks before merging.

### Development Setup

```bash
# Clone repository
git clone https://github.com/your-org/leanpoint.git
cd leanpoint

# Build
zig build

# Run tests
zig build test

# Format code
zig fmt src/

# Run locally
./zig-out/bin/leanpoint --help
```

### Reporting Issues

When reporting issues, please include:
- Leanpoint version: `./zig-out/bin/leanpoint --help`
- Zig version: `zig version`
- Operating system and architecture
- Configuration (upstreams.json)
- Error messages or unexpected behavior
- Steps to reproduce

## License

[Specify your license here]

## Support

- **Issues**: [GitHub Issues](https://github.com/your-org/leanpoint/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/leanpoint/discussions)
- **Documentation**: This README

## Acknowledgments

- Inspired by [checkpointz](https://github.com/ethpandaops/checkpointz) by ethPandaOps
- Built for the Lean Ethereum ecosystem
- Written in [Zig](https://ziglang.org/)

---

**Built with ⚡ by the Lean Ethereum community**
