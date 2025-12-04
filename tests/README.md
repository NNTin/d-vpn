# Test Suite

## Overview
This Pester-based suite verifies automated bootstrap and configuration of the d-vpn stack. It validates Keycloak realm/client/user imports, WireGuard tunnel activation, and sync service readiness using both log inspection and runtime checks executed via `docker compose exec`.

## Prerequisites
- PowerShell 7+ available in your PATH.
- Pester module installed: `Install-Module -Name Pester -Force -AllowClobber`.
- Docker Compose v2 installed and accessible as `docker compose`.
- Stack running locally: `docker compose up -d` (start headscale, keycloak, wireguard, sync-service).
- `.env` file with `HEADSCALE_API_KEY` set for sync service tests (generate via `docker exec headscale headscale apikeys create -e 999d` as noted in `SETUP.md`).

## Usage
### Running all tests
- `pwsh ./tests/Run-IndividualTests.ps1`
- The script checks prerequisites, runs each test file, prints per-file pass/fail/skip counts, and exits non-zero if any test fails.

### Running individual tests
- Keycloak: `pwsh ./tests/KeycloakStartup.Tests.ps1`
- WireGuard: `pwsh ./tests/WireGuardStartup.Tests.ps1`
- Sync service: `pwsh ./tests/SyncService.Tests.ps1`

### Interpreting results
- Pester output reports Passed/Failed/Skipped counts and durations. A non-zero exit code from the runner or individual files indicates at least one failure; investigate detailed test output to identify which checks failed.

## Verification Criteria
| Service   | Verification Type | Criteria |
|-----------|-------------------|----------|
| Keycloak  | Log inspection    | Realm import triggers and finishes; dev mode starts |
| Keycloak  | Config verification | `d-vpn` realm exists; `headscale` client present with expected redirect URIs; `testuser` user exists |
| WireGuard | Log inspection    | Tunnel config discovered and activation logged |
| WireGuard | Runtime state     | `wg0` interface active with port 51820; server keys present; `wg0.conf` populated with interface, address, listen port, private key |
| Sync Service | Container status | Container present and running |
| Sync Service | API health     | `/health` returns healthy; `/peers` responds with JSON |
| Sync Service | Internal state | State file exists and is valid JSON; critical env vars present; container can reach Headscale health endpoint |

## Future Enhancements
- [ ] Keycloak: Verify OIDC token generation for testuser
- [ ] Keycloak: Verify client secret matches Headscale config
- [ ] WireGuard: Verify firewall rules (iptables/nftables)
- [ ] WireGuard: Verify DNS resolution via CoreDNS
- [ ] Sync Service: Verify WireGuard peer creation after Headscale node registration
- [ ] Sync Service: Verify state file updates on sync cycles
- [ ] Headscale: Verify OIDC configuration is loaded
- [ ] Headscale: Verify API key authentication
- [ ] Integration: End-to-end OIDC login flow (deferred to integration test phase)

## Troubleshooting
- Pester module not found → run `Install-Module -Name Pester -Force -AllowClobber`.
- Services not running → start with `docker compose up -d`.
- `HEADSCALE_API_KEY` missing → generate and add to `.env` per `SETUP.md`.
- Tests failing → inspect service logs with `docker compose logs <service>` and re-run the affected test file.
