# Test Suite

## Overview
This Pester-based suite verifies automated bootstrap and configuration of the d-vpn stack. It validates Keycloak realm/client/user imports, WireGuard tunnel activation, and sync service readiness using both log inspection and runtime checks executed via `docker compose exec`.

## CI/CD Integration
All tests run automatically via GitHub Actions on every push and pull request. The CI workflow (`.github/workflows/ci.yml`) performs a clean environment setup, generates required secrets, starts the Docker Compose stack, and executes the complete test suite. On test failures, Docker Compose logs are automatically collected and published as workflow artifacts for debugging. Check the [GitHub Actions](https://github.com/nntin/d-vpn/actions) page for current build status and test results.

## Prerequisites
- PowerShell 7+ available in your PATH.
- Pester module installed: `Install-Module -Name Pester -Force -AllowClobber`.
- CI environment: GitHub Actions runners have all prerequisites pre-installed (PowerShell 7+, Pester, Docker Compose).
- Docker Compose v2 installed and accessible as `docker compose`.
- Stack running locally: `docker compose up -d` (start headscale, keycloak, wireguard, sync-service).
- `.env` file with `HEADSCALE_API_KEY` set for sync service tests (generate via `docker exec headscale headscale apikeys create -e 999d` as noted in `SETUP.md`).

## Usage
### Running all tests
- `pwsh ./tests/Run-AllTests.ps1`
- This runs both individual service tests and the integration test (same as CI).
- For individual tests only (without integration): `pwsh ./tests/Run-IndividualTests.ps1`

### Running individual tests
- Keycloak: `pwsh ./tests/KeycloakStartup.Tests.ps1`
- WireGuard: `pwsh ./tests/WireGuardStartup.Tests.ps1`
- Sync service: `pwsh ./tests/SyncService.Tests.ps1`

### Running integration test
- `pwsh ./tests/Invoke-IntegrationTest.ps1`
- Performs a clean start (`docker compose down -v`), restarts all services, and validates the full flow; expect ~2-5 minutes runtime.
- Removes all volumes and restarts services as part of setup—ensure no important local state is needed before running.

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
| Integration | E2E Flow | Headscale user creation; preauth key generation; node registration; sync service detection (30s poll); WireGuard peer creation; peer config retrieval; config format validation |
| Integration | Network | Peer IP allocated in 10.13.13.0/24 subnet; peer config contains correct server endpoint (10.13.13.1:51820); AllowedIPs matches subnet |

## Future Enhancements
- [ ] Keycloak: Verify OIDC token generation for testuser
- [ ] Keycloak: Verify client secret matches Headscale config
- [ ] WireGuard: Verify firewall rules (iptables/nftables)
- [ ] WireGuard: Verify DNS resolution via CoreDNS
- [ ] Sync Service: Verify WireGuard peer creation after Headscale node registration
- [ ] Sync Service: Verify state file updates on sync cycles
- [ ] Headscale: Verify OIDC configuration is loaded
- [ ] Headscale: Verify API key authentication
- [x] Integration: End-to-end node registration and peer provisioning (CLI-based)
- [ ] Integration: End-to-end OIDC login flow with browser automation
- [ ] Integration: Actual VPN connectivity test (ping through tunnel)
- [ ] Integration: Multi-node peer-to-peer connectivity test

## Integration Test
Validates the complete hybrid architecture flow from Headscale node registration through WireGuard peer provisioning and config delivery.

- Setup: clean start via `docker compose down -v`, `docker compose up -d`, and health checks for headscale, keycloak, wireguard, and sync-service.
- Execution: create integration user/node, generate preauth key, wait for sync service polling to provision the peer, verify WireGuard state, and retrieve peer config from the sync API.
- Cleanup: `docker compose down` after assertions complete; temporary resources (`integration-test-user`, `integration-test-node`) are created and removed with the stack.
- Expected duration: 2-5 minutes depending on startup and sync polling intervals.

## Troubleshooting
- Pester module not found → run `Install-Module -Name Pester -Force -AllowClobber`.
- Services not running → start with `docker compose up -d`.
- `HEADSCALE_API_KEY` missing → generate and add to `.env` per `SETUP.md`.
- Tests failing → inspect service logs with `docker compose logs <service>` and re-run the affected test file.
- Integration test timeout waiting for services → increase health check timeout or check service logs.
- Sync service not detecting node → verify `HEADSCALE_API_KEY` is set, check sync service logs for polling errors, and ensure a 30s poll interval has elapsed.
- WireGuard peer not created → check sync service logs for key generation errors, verify docker socket mount, and validate `wg0.conf` syntax.
- Peer config validation fails → inspect config output, check template rendering in `wireguard_manager.py`, and verify all key files exist.
