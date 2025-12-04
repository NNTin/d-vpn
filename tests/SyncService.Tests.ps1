$ErrorActionPreference = 'Stop'

function Invoke-SyncServiceExec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $result = docker compose exec sync-service /bin/sh -c "$Command" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to execute command in sync-service container: $result"
    }

    return $result -join "`n"
}

function Get-SyncServiceContainerId {
    $id = docker compose ps -q sync-service 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read sync-service status: $id"
    }
    return $id.Trim()
}

function Invoke-SyncServiceHealth {
    return Invoke-RestMethod -Uri "http://localhost:5000/health" -Method Get -TimeoutSec 5 -ErrorAction Stop
}

function Invoke-SyncServicePeers {
    return Invoke-RestMethod -Uri "http://localhost:5000/peers" -Method Get -TimeoutSec 5 -ErrorAction Stop
}

Describe "Sync Service" {
    BeforeAll {
        $script:containerId = Get-SyncServiceContainerId
    }

    It "container is running" {
        $script:containerId | Should -Not -BeNullOrEmpty
    }

    It "health endpoint reports healthy" {
        $health = Invoke-SyncServiceHealth
        $health.status | Should -Be "healthy"
    }

    It "peers endpoint responds with JSON" {
        $peers = Invoke-SyncServicePeers
        $peers | Should -Not -Be $null
        ($peers | Measure-Object).Count | Should -BeGreaterThanOrEqual 0
    }

    It "state file exists" {
        $stateExists = Invoke-SyncServiceExec -Command "test -f /config/sync-service-state.json && echo exists"
        $stateExists.Trim() | Should -Be 'exists'
    }

    It "state file is valid JSON" {
        $stateFile = Invoke-SyncServiceExec -Command "cat /config/sync-service-state.json"
        $stateJson = $stateFile | ConvertFrom-Json
        $stateJson.nodes | Should -Not -Be $null
        $stateJson.last_sync_time | Should -Not -Be $null
    }

    It "environment variables are set" {
        $envOutput = Invoke-SyncServiceExec -Command "env"
        $envMap = @{}
        foreach ($line in $envOutput -split "`n") {
            if ($line -match '^(?<key>[^=]+)=(?<value>.*)$') {
                $envMap[$Matches['key']] = $Matches['value']
            }
        }

        $requiredVars = @('HEADSCALE_URL', 'HEADSCALE_API_KEY', 'WIREGUARD_CONTAINER_NAME', 'WIREGUARD_SUBNET', 'API_PORT')
        foreach ($var in $requiredVars) {
            $envMap[$var] | Should -Not -BeNullOrEmpty
        }
    }

    It "can reach Headscale API" {
        $healthResponse = Invoke-SyncServiceExec -Command "curl -fsS http://headscale:8080/health"
        $healthResponse | Should -Not -BeNullOrEmpty
    }
}
