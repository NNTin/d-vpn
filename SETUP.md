# Headscale UI Setup

Follow these steps to let the Headscale UI talk to your Headscale instance without 401 errors.

1) Make sure the stack is running: `docker compose up -d`
2) Create an API key from the Headscale container (the debug line about `HEADSCALE_CLI_ADDRESS` is normal):
   `docker exec headscale headscale apikeys create --expiration 720h`
Copy the returned token (example: `InSTKih.gJpg4OPPYMOuI6NloJN-K3ILC8o6wgke`).
3) Open the UI at `http://localhost:8081`
4) In the UI settings, set:
   - Headscale URL: `http://localhost:8080` (from your host). If configuring from another container on the same Docker network, use `http://headscale:8080`.
   - API key: paste the token from step 2.
5) Reload the page and retry; the UI stores `headscaleURL` and `headscaleAPIKey` in your browser’s localStorage. If you still see 401s, verify the URL is reachable and the key is valid/unexpired.

# Headscale CLI Bootstrap (no UI)

1) Ensure the stack is running: `docker compose up -d`
2) Create the initial admin user in Headscale (message about `HEADSCALE_CLI_ADDRESS` is normal):
   `docker exec headscale headscale users create admin`
3) Confirm the user exists and note the ID (should be `1`):
   `docker exec headscale headscale users list`
4) Generate a reusable preauth key for the admin user (ID 1) with a 30-day expiry:
   `docker exec headscale headscale preauthkeys create --user 1 --reusable --expiration 720h`
   The generated key (current run): `9d320d6e6fa361f08586ec81d931d3b430f6bb7899a74739`
5) Use that preauth key to connect a client (example with Tailscale client on the host):
   `tailscale up --login-server http://localhost:8080 --authkey 9d320d6e6fa361f08586ec81d931d3b430f6bb7899a74739`
   From another container on the same Docker network, point `--login-server` to `http://headscale:8080` instead of localhost.

# WireGuard Home Node & Peer Distribution (no Tailscale client)

The sequence diagram uses Headscale to distribute WireGuard keys and the HomePi endpoint to authenticated users. We do not rely on the Tailscale client in this flow.

Planned steps (aligning with TODO):
1) Prepare the WireGuard home node (Raspberry Pi or the `wireguard` container) as the endpoint Headscale will advertise.
2) Define how Headscale (via API / dashboard) hands out WireGuard peer configs (keys + HomePi endpoint) to authenticated users.
3) Verify a test peer can connect to the home node using the distributed WireGuard config.
