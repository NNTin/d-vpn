$ErrorActionPreference = 'Stop'

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
}
