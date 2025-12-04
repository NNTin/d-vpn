$ErrorActionPreference = 'Stop'

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
}
