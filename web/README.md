# Leanpoint Web UI

Modern web interface for leanpoint, inspired by [checkpointz](https://github.com/ethpandaops/checkpointz).

## Features

- **Real-time Status Dashboard**: Live updates of finalized and justified slots
- **Upstreams Monitoring**: View health and status of all configured lean nodes
- **Consensus Tracking**: Visual display of consensus status across upstreams
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Dark Theme**: Eye-friendly dark UI

## Development

### Prerequisites

- Node.js 18+ and npm
- leanpoint backend running (see parent README)

### Quick Start

```bash
# Install dependencies
npm install

# Start dev server with hot reload
npm run dev

# Build for production
npm run build
```

The dev server runs on `http://localhost:5173` by default and proxies API requests to `http://localhost:5555`.

### Build for Production

```bash
npm run build
```

This creates an optimized production build in `../web-dist/` which can be served by the Zig backend using the `--static-dir web-dist` flag.

## Project Structure

```
web/
├── src/
│   ├── api/           # API client functions
│   ├── components/    # React components
│   ├── pages/         # Page components
│   ├── styles/        # CSS styles
│   ├── types/         # TypeScript type definitions
│   ├── App.tsx        # Main app component
│   └── main.tsx       # Entry point
├── index.html         # HTML template
├── package.json       # Dependencies
├── tsconfig.json      # TypeScript config
└── vite.config.ts     # Vite bundler config
```

## API Integration

The frontend consumes these API endpoints from the backend:

- `GET /status` - Current checkpoint status
- `GET /api/upstreams` - Upstreams health and consensus data
- `GET /healthz` - Service health check

## Customization

### Styling

Edit `src/styles/App.css` to customize colors, fonts, and layout. The design uses CSS custom properties (variables) for easy theme customization.

### Components

- `StatusCard.tsx` - Displays checkpoint status metrics
- `UpstreamsTable.tsx` - Shows upstream nodes table with health status

## License

Same as parent project (leanpoint)
