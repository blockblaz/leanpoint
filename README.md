# Leanpoint Checkpoint Status Service

Minimal Zig service that polls a LeanEthereum node for justified/finalized
slots and exposes a lightweight HTTP API plus Prometheus metrics. Optionally
serves a static frontend build (for example, the Checkpointz web UI).

## Endpoints

- `GET /status` returns JSON with `justified_slot`, `finalized_slot`,
  `last_updated_ms`, `last_success_ms`, `stale`, `error_count`, `last_error`
- `GET /metrics` returns Prometheus metrics
- `GET /healthz` returns `200` when data is fresh, `503` when stale

If `--static-dir` is set, other paths will be served from that directory.

## Configuration

Defaults:

- bind address `0.0.0.0`
- port `5555`
- LeanEthereum base URL `http://127.0.0.1:5052`
- LeanEthereum path `/status`
- poll interval `10_000` ms
- request timeout `5_000` ms
- stale threshold `30_000` ms

### CLI options

```
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

### Environment variables

```
LEANPOINT_BIND_ADDR
LEANPOINT_BIND_PORT
LEANPOINT_LEAN_URL
LEANPOINT_LEAN_PATH
LEANPOINT_POLL_MS
LEANPOINT_TIMEOUT_MS
LEANPOINT_STALE_MS
LEANPOINT_STATIC_DIR
```

## LeanEthereum response shape

The service expects one of these JSON shapes:

```
{"justified_slot":123,"finalized_slot":120}
```

or

```
{"data":{"justified":{"slot":"123"},"finalized":{"slot":120}}}
```

If your LeanEthereum endpoint differs, set `--lean-path` to the correct path
and ensure it returns `justified_slot` and `finalized_slot` or the nested
`data.justified.slot` and `data.finalized.slot` fields.
