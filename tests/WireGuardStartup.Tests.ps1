$ErrorActionPreference = 'Stop'

function Invoke-WireGuardExec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $output = docker compose exec wireguard /bin/sh -c "$Command" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to execute command in wireguard container: $output"
    }

    return $output -join "`n"
}

function Get-WireGuardLogs {
    $logs = docker compose logs wireguard --no-color 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read wireguard logs: $logs"
    }

    if (-not $logs) {
        throw "No logs returned for wireguard service."
    }

    return $logs -join "`n"
}

Describe "WireGuard startup" {
    BeforeAll {
        $script:logs = Get-WireGuardLogs
    }

    It "emits expected initialization lines" {
        $script:logs | Should -Match 'Found WG conf /config/wg_confs/wg0\.conf, adding to list'
        $script:logs | Should -Match 'Activating tunnel /config/wg_confs/wg0\.conf'
        $script:logs | Should -Match 'All tunnels are now active'
    }

    It "wg0 interface is active" {
        $wgStatus = Invoke-WireGuardExec -Command "wg show wg0"
        $wgStatus | Should -Match 'interface: wg0'
        $wgStatus | Should -Match 'listening port: 51820'
    }

    It "server private key exists" {
        $result = Invoke-WireGuardExec -Command "test -f /config/server/privatekey && echo exists"
        $result.Trim() | Should -Be 'exists'
    }

    It "server public key exists" {
        $result = Invoke-WireGuardExec -Command "test -f /config/server/publickey && echo exists"
        $result.Trim() | Should -Be 'exists'
    }

    It "wg0.conf is populated" {
        $config = Invoke-WireGuardExec -Command "cat /config/wg_confs/wg0.conf"
        $config | Should -Match '\[Interface\]'
        $config | Should -Match 'Address = 10\.13\.13\.1/24'
        $config | Should -Match 'ListenPort = 51820'
        $config | Should -Match 'PrivateKey'
    }
}
