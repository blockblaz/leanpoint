.PHONY: all build build-backend build-web install-web clean clean-web run dev help

all: build

help:
	@echo "Leanpoint Monorepo Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make build          - Build both backend and frontend"
	@echo "  make build-backend  - Build only the Zig backend"
	@echo "  make build-web      - Build only the frontend"
	@echo "  make install-web    - Install frontend dependencies"
	@echo "  make dev            - Run frontend dev server (hot reload)"
	@echo "  make run            - Run the backend"
	@echo "  make clean          - Clean all build artifacts"
	@echo "  make clean-web      - Clean only frontend artifacts"
	@echo ""

# Install frontend dependencies
install-web:
	@echo "📦 Installing frontend dependencies..."
	cd web && npm install

# Build frontend (production)
build-web: install-web
	@echo "🎨 Building frontend..."
	cd web && npm run build
	@echo "✅ Frontend built successfully to ./web-dist/"

# Build backend
build-backend:
	@echo "⚡ Building Zig backend..."
	zig build
	@echo "✅ Backend built successfully to ./zig-out/bin/leanpoint"

# Build everything
build: build-backend build-web
	@echo "✅ All components built successfully!"

# Run frontend dev server
dev:
	@echo "🚀 Starting frontend dev server..."
	cd web && npm run dev

# Run backend
run:
	@echo "🚀 Running leanpoint..."
	./zig-out/bin/leanpoint --upstreams-config upstreams.json --static-dir web-dist

# Clean frontend artifacts
clean-web:
	@echo "🧹 Cleaning frontend artifacts..."
	rm -rf web/node_modules web-dist

# Clean all artifacts
clean: clean-web
	@echo "🧹 Cleaning backend artifacts..."
	rm -rf zig-out zig-cache
	@echo "✅ All artifacts cleaned!"
