$ErrorActionPreference = 'Stop'

$integrationUser = 'integration-test-user'
$integrationNode = 'integration-test-node'

function Assert-Prerequisites {
    if (-not (Get-Module -Name Pester -ListAvailable)) {
        throw "Pester module not found. Install with: Install-Module -Name Pester -Force -AllowClobber"
    }

    $composeVersion = docker compose version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose is required but not available: $composeVersion"
    }
}

function Invoke-Compose {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $output = docker compose @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to $Description: $($output -join "`n")"
    }

    return $output -join "`n"
}

function Wait-ForCondition {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$Condition,
        [int]$TimeoutSeconds = 60,
        [int]$IntervalSeconds = 5,
        [string]$Description = "condition"
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = $null

    while ((Get-Date) -lt $deadline) {
        try {
            $result = & $Condition
            if ($result) {
                return $result
            }
        } catch {
            $lastError = $_
        }

        Start-Sleep -Seconds $IntervalSeconds
    }

    if ($lastError) {
        throw "Timeout waiting for $Description. Last error: $lastError"
    }

    throw "Timeout waiting for $Description after $TimeoutSeconds seconds."
}

function Wait-ForServiceHealth {
    param(
        [int]$TimeoutSeconds = 120,
        [int]$IntervalSeconds = 5,
        [string[]]$ServiceNames = @('keycloak', 'headscale', 'wireguard', 'sync-service')
    )

    $lastStates = @()

    $condition = {
        $psOutput = docker compose ps --format json 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Unable to read compose status: $($psOutput -join "`n")"
            return $false
        }

        try {
            $services = ($psOutput -join "`n") | ConvertFrom-Json
        } catch {
            Write-Warning "Failed to parse compose status JSON: $psOutput"
            return $false
        }

        $allHealthy = $true
        $lastStates = @()
        foreach ($name in $ServiceNames) {
            $service = $services | Where-Object { $_.Service -eq $name -or $_.Name -eq $name }
            if (-not $service) {
                $lastStates += "$name:not-found"
                $allHealthy = $false
                continue
            }

            $state = $service.State
            $lastStates += "$name:$state"
            if ($state -notmatch 'healthy') {
                $allHealthy = $false
            }
        }

        return $allHealthy
    }

    try {
        Wait-ForCondition -Condition $condition -TimeoutSeconds $TimeoutSeconds -IntervalSeconds $IntervalSeconds -Description "services to be healthy"
    } catch {
        throw "Timeout waiting for services to be healthy. Last states: $($lastStates -join ', ')"
    }
}

function Invoke-HeadscaleExec {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    $output = docker compose exec headscale headscale @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Headscale command failed: $($output -join "`n")"
    }

    return $output -join "`n"
}

function Invoke-WireGuardExec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $output = docker compose exec wireguard-server /bin/sh -c "$Command" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "WireGuard command failed: $($output -join "`n")"
    }

    return $output -join "`n"
}

function Get-SyncServicePeers {
    Invoke-RestMethod -Uri "http://localhost:5000/peers" -Method Get -TimeoutSec 5 -ErrorAction Stop
}

function Get-SyncServicePeerConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NodeId
    )

    Invoke-RestMethod -Uri "http://localhost:5000/peer/$NodeId/config" -Method Get -TimeoutSec 5 -ErrorAction Stop
}

Describe "End-to-end integration test" {
    BeforeAll {
        $script:testStart = Get-Date
        Assert-Prerequisites

        Write-Host "Resetting stack (docker compose down -v)..."
        Invoke-Compose -Args @('down', '-v') -Description "stop and clean existing stack"

        Write-Host "Starting stack (docker compose up -d)..."
        Invoke-Compose -Args @('up', '-d') -Description "start stack"

        Write-Host "Waiting for services to become healthy..."
        Wait-ForServiceHealth -TimeoutSeconds 120 -IntervalSeconds 5
    }

    AfterAll {
        Write-Host "Stopping stack (docker compose down)..."
        try {
            Invoke-Compose -Args @('down') -Description "stop stack after integration test"
        } catch {
            Write-Warning "Cleanup failed: $_"
        }

        if ($script:testStart) {
            $duration = (Get-Date) - $script:testStart
            Write-Host ("Integration test duration: {0:c}" -f $duration)
        }
    }

    It "creates Headscale user for integration testing" {
        $output = Invoke-HeadscaleExec -Args @('users', 'create', $integrationUser)
        $output | Should -Match $integrationUser
    }

    It "generates a reusable preauth key" {
        $preauthJson = Invoke-HeadscaleExec -Args @(
            'preauthkeys', 'create',
            '--user', $integrationUser,
            '--reusable',
            '--expiration', '1h',
            '--format', 'json'
        )

        $preauth = $preauthJson | ConvertFrom-Json
        $script:preauthKey = $preauth.key
        $script:preauthKey | Should -Not -BeNullOrEmpty
    }

    It "registers a test node" {
        $registerOutput = Invoke-HeadscaleExec -Args @(
            'debug', 'create-node',
            '--user', $integrationUser,
            '--name', $integrationNode
        )

        $registerOutput | Should -Match $integrationNode
    }

    It "lists nodes and captures node id" {
        $nodesJson = Invoke-HeadscaleExec -Args @('nodes', 'list', '--output', 'json')
        $nodes = $nodesJson | ConvertFrom-Json
        $node = $nodes | Where-Object {
            $_.name -eq $integrationNode -or $_.hostname -eq $integrationNode -or $_.givenName -eq $integrationNode
        }

        $node | Should -Not -BeNullOrEmpty
        $script:nodeId = $node.id
        if (-not $script:nodeId) {
            $script:nodeId = $node.node_key
        }
        if (-not $script:nodeId) {
            $script:nodeId = $node.name
        }

        $script:nodeId = [string]$script:nodeId

        $script:nodeId | Should -Not -BeNullOrEmpty
    }

    It "detects the node via sync service peers endpoint" {
        $peerIp = Wait-ForCondition -TimeoutSeconds 60 -IntervalSeconds 5 -Description "sync service to process node" -Condition {
            $peers = Get-SyncServicePeers
            $match = $peers | Where-Object {
                $_.node_id -eq "$($script:nodeId)" -or $_.node_id -eq [string]$script:nodeId -or $_.node_id -eq $integrationNode
            }
            if ($match) {
                return $match.peer_ip
            }
            return $false
        }

        $script:peerIp = $peerIp
        $script:peerIp | Should -Not -BeNullOrEmpty
    }

    It "creates a WireGuard peer with matching public key" {
        $script:peerPublicKey = Wait-ForCondition -TimeoutSeconds 60 -IntervalSeconds 5 -Description "peer public key file to be created" -Condition {
            try {
                $key = Invoke-WireGuardExec -Command "cat /config/peers/$($script:nodeId)/publickey"
                if ($key -and $key.Trim().Length -gt 0) {
                    return $key.Trim()
                }
            } catch {
                return $false
            }

            return $false
        }

        $wgOutput = Invoke-WireGuardExec -Command "wg show wg0"
        $wgOutput | Should -Match [Regex]::Escape($script:peerPublicKey)
        if ($script:peerIp) {
            $wgOutput | Should -Match [Regex]::Escape($script:peerIp)
        }
    }

    It "retrieves peer configuration from sync service" {
        $configText = Get-SyncServicePeerConfig -NodeId $script:nodeId
        $script:peerConfig = $configText

        $configText | Should -Match '\[Interface\]'
        $configText | Should -Match '\[Peer\]'
        $configText | Should -Match 'Address\\s*=\\s*10\\.13\\.13\\.\\d+/32'
        $configText | Should -Match 'PrivateKey\\s*=\\s*.+'
        $configText | Should -Match 'PublicKey\\s*=\\s*.+'
        $configText | Should -Match 'Endpoint\\s*=\\s*10\\.13\\.13\\.1:51820'
        $configText | Should -Match 'AllowedIPs\\s*=\\s*10\\.13\\.13\\.0/24'
    }

    It "allocates peer IP within the expected subnet" {
        $script:peerIp | Should -Match '^10\\.13\\.13\\.\\d+$'
        $octet = [int]([regex]::Match($script:peerIp, '^10\\.13\\.13\\.(\\d+)$').Groups[1].Value)
        $octet | Should -BeGreaterThan 1
        $octet | Should -BeLessThan 255
        $script:peerIp | Should -Not -Be '10.13.13.1'
    }
}
