```pwsh
PS /home/nntin/git/d-vpn> Install-Module -Name PowerShellGet -Force -SkipPublisherCheck
PS /home/nntin/git/d-vpn> Install-Module -Name Pester -Force -AllowClobber
PS /home/nntin/git/d-vpn> Get-Module -Name Pester -ListAvailable

PS /home/nntin/git/d-vpn> pwsh ./tests/WireGuardStartup.Tests.ps1                      

Starting discovery in 1 files.
Discovery found 1 tests in 189ms.
Running tests.
[+] /home/nntin/git/d-vpn/tests/WireGuardStartup.Tests.ps1 615ms (214ms|238ms)
Tests completed in 630ms
Tests Passed: 1, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0
```

## Sync service test setup

Requirements: Docker Compose v2, Pester, and a Headscale API key.

1) Create `.env` in repo root with `HEADSCALE_API_KEY` (generate with `docker exec headscale headscale apikeys create -e 999d`).
2) Start the stack so `sync-service` is running: `docker compose up -d --build headscale wireguard sync-service`.
3) Run tests: `pwsh ./tests/SyncService.Tests.ps1`.

The sync service tests check the container is running, `/health` returns `{"status":"healthy"}`, and `/peers` responds with JSON. A populated peer list is optional; an empty array passes.
