# Keycloak Realm Bootstrap (PoW)

This directory contains the Keycloak realm configuration used for automatic import on startup. The setup supports the hybrid architecture (Headscale for discovery + WireGuard for tunnels) for proof-of-work/local development only.

## Realm Details
- Realm name: `d-vpn`
- Purpose: OIDC authentication for Headscale node registration

## OIDC Client
- Client ID: `headscale`
- Client Secret: `d-vpn-headscale-secret-change-in-production`
- Warning: Fixed secret for PoW. For production, generate a secure random secret and use `client_secret_path` in the Headscale config.
- Redirect URIs: `http://localhost:8080/oidc/callback`, `http://headscale:8080/oidc/callback`
- Protocol: OpenID Connect (authorization code flow)

## Test User
```
username: testuser
password: testpass
email: testuser@d-vpn.local
```
Purpose: Validate the OIDC authentication flow for Milestone 2.3+.

## How It Works
- `d-vpn-realm.json` is mounted to `/opt/keycloak/data/import` in the Keycloak container.
- The `--import-realm` flag in `docker-compose.yml` triggers automatic import on startup.
- Import is idempotent (skips if the realm already exists).
- To apply JSON changes, reset the Keycloak volume and restart:
  ```
  docker compose down -v && docker compose up -d
  ```

## Next Steps
- See Milestone 2.3 in `TODO.md` for Headscale OIDC configuration.
- Use the client secret above in `headscale/config/config.yaml`.
- Next phase wires Headscale to this Keycloak realm for authentication.

## Verification
- Open the admin console: `http://localhost:8180`
- Login with admin/admin
- Confirm realm `d-vpn` exists in the dropdown
- Clients → `headscale`: verify client settings
- Users → confirm `testuser` exists
