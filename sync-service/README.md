# Sync Service (Headscale → WireGuard)

Python-based bridge that polls Headscale for registered nodes, provisions WireGuard peers, and exposes an API to fetch peer configs.

## Architecture
- Polls Headscale REST API every `POLL_INTERVAL` seconds (default 30s) using a bearer API key.
- Generates WireGuard peer keys, allocates IPs sequentially from `10.13.13.2`, and appends peers to `/config/wg_confs/wg0.conf`.
- Reloads WireGuard via `wg syncconf` inside the WireGuard container (docker socket is mounted for exec).
- Persists processed nodes/IP allocations in `/config/sync-service-state.json` so restarts are idempotent.
- Serves peer configs via Flask on port `5000`.

## Setup
1. Generate Headscale API key:
   ```
   docker exec headscale headscale apikeys create -e 999d
   ```
2. Copy `.env.example` to `.env` (either in repo root for Compose or inside `sync-service/` for local runs) and set `HEADSCALE_API_KEY`.
3. Build & run via Docker Compose (from repo root):
   ```
   docker compose up -d --build sync-service
   ```
   Or run locally:
   ```
   pip install -r requirements.txt
   python app.py
   ```

## API Endpoints
- `GET /health` — health check.
- `GET /peer/<node_id>/config` — returns WireGuard peer config for the given Headscale node (404 if unknown).
- `GET /peers` — lists processed nodes and allocated IPs.

## How It Works
1. Poll Headscale for nodes.
2. For any new node:
   - Generate WireGuard keys.
   - Allocate the next IP from `10.13.13.0/24` starting at `10.13.13.2`.
   - Append `[Peer]` to `wg0.conf`.
   - Reload WireGuard with `wg syncconf`.
   - Persist node → IP mapping.
3. Peer config is rendered from `wg-config/templates/peer.conf` with injected keys and endpoints.

## State Management
- State file: `/config/sync-service-state.json`
- Structure:
  ```json
  {
    "processed_nodes": { "node_123": "10.13.13.2" },
    "last_ip": "10.13.13.2"
  }
  ```
- Safe writes via atomic rename; created automatically if missing.

## Troubleshooting
- Invalid API key: `401`/`403` from Headscale — regenerate and update env.
- WireGuard reload failure: check docker socket mount and container name; confirm `wg0.conf` is valid.
- IP exhaustion: ensure `WIREGUARD_SUBNET` has capacity or reclaim unused nodes.
- Template errors: verify `wg-config/templates/peer.conf` exists and contains expected placeholders.

## Future Improvements
- Webhooks instead of polling.
- Peer deletion/rotation workflows.
- Metrics/observability for sync status.
- Smarter IP pool management and conflict detection.
