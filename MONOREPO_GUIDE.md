# Leanpoint Monorepo Guide

Welcome to the new leanpoint monorepo! This guide will help you get started with both the backend and the frontend.

## 🎯 What's New

Leanpoint is now a monorepo with:

- **Zig Backend** (`src/`) - Fast, lightweight checkpoint sync provider
- **React Frontend** (`web/`) - Modern web UI inspired by checkpointz
- **Unified Build System** - Single `Makefile` to build everything

## 📁 Project Structure

```
leanpoint/
├── src/                  # Zig backend source
│   ├── main.zig         # Entry point
│   ├── server.zig       # HTTP server + static file serving
│   ├── state.zig        # Application state with upstream tracking
│   ├── upstreams.zig    # Upstream manager
│   └── ...
├── web/                  # React frontend
│   ├── src/
│   │   ├── components/  # React components
│   │   ├── api/         # API client
│   │   ├── types/       # TypeScript types
│   │   └── App.tsx      # Main app
│   ├── package.json
│   └── README.md
├── web-dist/            # Built frontend (generated)
├── Makefile             # Build system
└── README.md            # Main documentation
```

## 🚀 Quick Start

### 1. Build Everything

```bash
make build
```

This builds both the Zig backend and the React frontend.

### 2. Run the Backend with UI

```bash
# Make sure you have an upstreams config
cp upstreams.example.json upstreams.json
# Edit upstreams.json as needed

# Run with static frontend
./zig-out/bin/leanpoint --upstreams-config upstreams.json --static-dir web-dist
```

### 3. Access the Web UI

Open your browser to:

```
http://localhost:5555
```

You should see the leanpoint dashboard with:
- Real-time checkpoint status
- Upstream nodes health monitoring
- Consensus tracking

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
cd web && npm run dev
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
| `GET /status` | Current checkpoint status (JSON) | Frontend, Monitoring |
| `GET /api/upstreams` | Upstream nodes data (JSON) | Frontend |
| `GET /metrics` | Prometheus metrics | Monitoring |
| `GET /healthz` | Health check | Load balancers |
| `GET /` | Web UI (if `--static-dir` set) | Browsers |

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

### Docker

The Dockerfile already supports the monorepo structure:

```bash
# Build image
docker build -t leanpoint:latest .

# Run with static UI
docker run -p 5555:5555 \
  -v $(pwd)/upstreams.json:/app/upstreams.json \
  leanpoint:latest \
  --upstreams-config /app/upstreams.json --static-dir /app/web-dist
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

## 🎯 Next Steps

1. **Customize the UI** - Make it your own!
2. **Add more metrics** - Extend the backend API
3. **Create dashboards** - Use the data for Grafana
4. **Contribute** - PRs welcome!

## 🔗 Related Documentation

- Main README: `README.md`
- Frontend README: `web/README.md`
- Checkpointz (inspiration): https://github.com/ethpandaops/checkpointz

## 💡 Tips

- Use `make dev` for fast frontend iteration
- Keep the backend running while developing
- Use browser DevTools to debug API calls
- Check `/metrics` endpoint for detailed stats

---

**Happy monitoring! ⚡**
