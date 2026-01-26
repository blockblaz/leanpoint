# Leanpoint - Checkpoint Sync Provider

[![CI](https://github.com/blockblaz/leanpoint/workflows/CI/badge.svg)](https://github.com/blockblaz/leanpoint/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A lightweight, fast Zig service that monitors finality across multiple Lean Ethereum lean nodes with consensus validation and a modern web UI. Inspired by [checkpointz](https://github.com/ethpandaops/checkpointz).

## 🎯 What is Leanpoint?

Leanpoint is a monorepo containing:

- **Zig Backend** (`src/`) - Fast, lightweight checkpoint sync provider (8MB binary)
- **React Frontend** (`web/`) - Modern web UI for real-time monitoring
- **Unified Build System** - Single `Makefile` to build everything

It polls multiple lean nodes, requires 50%+ consensus before serving finality data, and provides:
- Real-time checkpoint status monitoring
- Per-upstream health tracking
- Prometheus metrics integration
- Web dashboard for visualization

## 📁 Project Structure

```
leanpoint/
├── src/                  # Zig backend source
│   ├── main.zig         # Entry point
│   ├── server.zig       # HTTP server + API + static file serving
│   ├── state.zig        # Application state with upstream tracking
│   ├── upstreams.zig    # Upstream manager with consensus
│   ├── lean_api.zig     # Lean Ethereum API client
│   ├── metrics.zig      # Prometheus metrics
│   └── config.zig       # Configuration loader
├── web/                  # React frontend
│   ├── src/
│   │   ├── components/  # StatusCard, UpstreamsTable
│   │   ├── api/         # API client functions
│   │   ├── types/       # TypeScript interfaces
│   │   └── App.tsx      # Main app
│   ├── package.json
│   └── README.md
├── web-dist/            # Built frontend (generated)
├── Makefile             # Unified build system
├── Dockerfile           # Docker image with UI
└── README.md            # This file
```

## 🚀 Quick Start

### Build Everything

```bash
make build
```

This builds both the Zig backend and the React frontend.

### Run with Web UI

```bash
# Create configuration
cp upstreams.example.json upstreams.json
# Edit upstreams.json with your lean node endpoints

# Run with web interface
./zig-out/bin/leanpoint --upstreams-config upstreams.json --static-dir web-dist
```

### Access the Dashboard

Open your browser to:

```
http://localhost:5555
```

You'll see:
- Real-time checkpoint status (finalized/justified slots)
- Upstreams table with health status
- Consensus information
- Historical checkpoint tracking

## 🛠️ Development Workflow

### Backend Development

```bash
# Build only backend
make build-backend

# Run backend
./zig-out/bin/leanpoint --upstreams-config upstreams.json
```

### Frontend Development

```bash
# Start frontend dev server with hot reload
make dev
# or
cd web && npm run dev
```

The dev server runs on `http://localhost:5173` and proxies API requests to `http://localhost:5555`.

**Important**: Keep the backend running while developing the frontend!

```bash
# Terminal 1: Backend
./zig-out/bin/leanpoint --upstreams-config upstreams.json

# Terminal 2: Frontend dev server
make dev
```

### Production Build

```bash
# Build everything for production
make build

# Run with static frontend
./zig-out/bin/leanpoint --upstreams-config upstreams.json --static-dir web-dist
```

## 📡 API Endpoints

The backend exposes these endpoints:

| Endpoint | Description | Used By |
|----------|-------------|---------|
| `GET /` | Web UI (if `--static-dir` set) | Browsers |
| `GET /status` | Current checkpoint status (JSON) | Frontend, Monitoring |
| `GET /api/upstreams` | Upstream nodes data (JSON) | Frontend |
| `GET /metrics` | Prometheus metrics | Monitoring |
| `GET /healthz` | Health check | Load balancers |

### GET /status

Returns current finality checkpoint:

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

### GET /api/upstreams

Returns detailed upstream status:

```json
{
  "upstreams": [
    {
      "name": "zeam_0",
      "url": "http://127.0.0.1:8081",
      "path": "/v0/health",
      "healthy": true,
      "last_success_ms": 1705852800000,
      "error_count": 0,
      "last_error": null,
      "last_justified_slot": 12345,
      "last_finalized_slot": 12344
    }
  ],
  "consensus": {
    "total_upstreams": 4,
    "responding_upstreams": 4,
    "has_consensus": true
  }
}
```

## 🧪 Testing with Local Devnet

### 1. Start Local Lean Devnet

```bash
cd /path/to/lean-quickstart
./spin-node.sh --node all
```

### 2. Generate Upstreams Config

```bash
cd /path/to/leanpoint
python3 convert-validator-config.py \
  ../lean-quickstart/local-devnet/genesis/validator-config.yaml \
  upstreams-local.json
```

### 3. Run Leanpoint with UI

```bash
./zig-out/bin/leanpoint --upstreams-config upstreams-local.json --static-dir web-dist
```

### 4. Monitor in Browser

Open `http://localhost:5555` and watch the dashboard update in real-time!

## 🎨 Customizing the UI

### Change Colors/Theme

Edit `web/src/styles/App.css`:

```css
:root {
  --primary-color: #6366f1;      /* Change primary color */
  --secondary-color: #8b5cf6;    /* Change secondary color */
  --bg-color: #0f172a;           /* Change background */
  /* ... more variables ... */
}
```

### Modify Components

- **Status Cards**: `web/src/components/StatusCard.tsx`
- **Upstreams Table**: `web/src/components/UpstreamsTable.tsx`
- **Main Layout**: `web/src/App.tsx`

After making changes:

```bash
# Rebuild frontend
make build-web

# Or use hot reload during development
make dev
```

## 🔧 Makefile Commands

| Command | Description |
|---------|-------------|
| `make build` | Build backend + frontend |
| `make build-backend` | Build only Zig backend |
| `make build-web` | Build only frontend |
| `make install-web` | Install frontend dependencies |
| `make dev` | Start frontend dev server |
| `make run` | Run backend with UI |
| `make clean` | Clean all build artifacts |
| `make clean-web` | Clean only frontend artifacts |
| `make help` | Show all commands |

## Configuration

### CLI Options

```bash
leanpoint [options]

Options:
  --bind <addr>             Bind address (default 0.0.0.0)
  --port <port>             Bind port (default 5555)
  --upstreams-config <file> JSON config file with multiple upstreams
  --poll-ms <ms>            Poll interval in milliseconds (default 10000)
  --timeout-ms <ms>         Request timeout in milliseconds (default 5000)
  --stale-ms <ms>           Stale threshold in milliseconds (default 30000)
  --static-dir <dir>        Static frontend directory (e.g., web-dist)
  --help                    Show this help
```

### Upstreams Configuration

**Example `upstreams.json`:**

```json
{
  "upstreams": [
    {
      "name": "zeam_0",
      "url": "http://127.0.0.1:8081",
      "path": "/v0/health"
    },
    {
      "name": "ream_0",
      "url": "http://127.0.0.1:8082",
      "path": "/v0/health"
    },
    {
      "name": "qlean_0",
      "url": "http://127.0.0.1:8083",
      "path": "/v0/health"
    }
  ]
}
```

### Generate from lean-quickstart

Use the helper script to convert `validator-config.yaml`:

```bash
python3 convert-validator-config.py \
  /path/to/validator-config.yaml \
  upstreams.json
```

## 🐛 Troubleshooting

### Backend won't start

```bash
# Check if port 5555 is already in use
lsof -i :5555

# Try a different port
./zig-out/bin/leanpoint --upstreams-config upstreams.json --port 5556 --static-dir web-dist
```

### Frontend shows "Loading..." forever

1. Check backend is running: `curl http://localhost:5555/status`
2. Check browser console for errors
3. Verify API proxy in `web/vite.config.ts`

### Build fails

```bash
# Clean and rebuild
make clean
make build
```

### UI not updating in dev mode

1. Check both backend and frontend dev server are running
2. Hard refresh browser (Cmd+Shift+R or Ctrl+Shift+R)
3. Check browser console for errors

## 📦 Deployment

### Docker (Recommended)

The Docker image includes the complete web UI:

```bash
# Build image (includes web UI)
docker build -t leanpoint:latest .

# Run with web UI
docker run -p 5555:5555 \
  -v $(pwd)/upstreams.json:/etc/leanpoint/upstreams.json \
  leanpoint:latest

# The image automatically serves the web UI from /usr/share/leanpoint/web
# Access at http://localhost:5555
```

### Static Binary + Frontend

```bash
# Build everything
make build

# Deploy these files:
# - zig-out/bin/leanpoint (backend binary)
# - web-dist/ (frontend static files)
# - upstreams.json (your config)

# Run on server
./leanpoint --upstreams-config upstreams.json --static-dir web-dist
```

## Features

- ✅ **Multi-upstream support** with 50%+ consensus requirement
- ✅ **Parallel polling** of all lean nodes for low latency
- ✅ **Per-upstream health tracking** with error counts and timestamps
- ✅ **Modern web UI** with real-time updates
- ✅ **Prometheus metrics** for comprehensive monitoring
- ✅ **Health check endpoint** for load balancers
- ✅ **Lightweight binary** (~8MB backend + 155KB frontend)
- ✅ **Easy integration** with lean-quickstart devnets

## Consensus Algorithm

Leanpoint requires **50%+ of upstreams to agree** before serving finality data.

### How It Works

1. **Poll Phase**: All upstreams are polled concurrently
2. **Collection Phase**: Justified/finalized slot pairs are collected
3. **Counting Phase**: Each unique slot pair is counted
4. **Consensus Phase**: Only pairs with >50% votes are accepted
5. **Serving Phase**: Consensus data is exposed via API and UI

### Consensus Examples

| Scenario | Agreement | Result |
|----------|-----------|--------|
| 3 upstreams, all agree | 3/3 = 100% | ✅ Serve data |
| 3 upstreams, 2 agree | 2/3 = 67% | ✅ Serve data |
| 4 upstreams, 2 agree | 2/4 = 50% | ❌ No consensus |
| 5 upstreams, 3 agree | 3/5 = 60% | ✅ Serve data |

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

### Available Metrics

```
leanpoint_justified_slot          # Latest justified slot
leanpoint_finalized_slot          # Latest finalized slot
leanpoint_last_success_timestamp_ms  # Last successful consensus
leanpoint_last_updated_timestamp_ms  # Last update attempt
leanpoint_last_latency_ms         # Poll latency
leanpoint_error_total             # Total errors
```

## 🔗 Related Documentation

- **Frontend Development**: See `web/README.md` for frontend-specific docs
- **Checkpointz (inspiration)**: https://github.com/ethpandaops/checkpointz
- **Lean Quickstart**: Integration with devnets

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Make your changes with clear commit messages
4. Build and test: `make build`
5. Submit a pull request

### CI/CD

GitHub Actions CI automatically:
- Builds both backend and frontend
- Runs tests
- Checks code formatting
- Builds Docker image

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Inspired by [checkpointz](https://github.com/ethpandaops/checkpointz) by ethPandaOps
- Built for the Lean Ethereum ecosystem
- Written in [Zig](https://ziglang.org/)

---

**Built with ⚡ by the Lean Ethereum community**
