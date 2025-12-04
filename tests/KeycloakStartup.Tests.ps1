$ErrorActionPreference = 'Stop'

function Get-KeycloakLogs {
    $logs = docker compose logs keycloak --no-color 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read keycloak logs: $logs"
    }

    if (-not $logs) {
        throw "No logs returned for keycloak service."
    }

    return $logs -join "`n"
}

Describe "Keycloak startup" {
    BeforeAll {
        $script:logs = Get-KeycloakLogs
    }

    It "imports the d-vpn realm from mounted export" {
        $script:logs | Should -Match 'Importing from directory .*/data/import'
        $script:logs | Should -Match 'KC-SERVICES0030: Full model import requested'
        $script:logs | Should -Match 'Realm ''d-vpn'' imported'
        $script:logs | Should -Match 'KC-SERVICES0032: Import finished successfully'
    }

    It "starts Keycloak dev mode after import" {
        $script:logs | Should -Match 'Updating the configuration and installing your custom providers, if any\. Please wait\.'
        $script:logs | Should -Match 'Keycloak .* started'
        $script:logs | Should -Match 'Profile dev activated'
    }
}
