$ErrorActionPreference = 'Stop'

function Invoke-KeycloakAdminAPI {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not $script:KeycloakToken) {
        $tokenResponse = docker compose exec keycloak /bin/sh -c "curl -s -d 'client_id=admin-cli' -d 'username=admin' -d 'password=admin' -d 'grant_type=password' http://localhost:8080/realms/master/protocol/openid-connect/token" 2>&1
        if ($LASTEXITCODE -ne 0 -or -not $tokenResponse) {
            throw "Failed to retrieve Keycloak admin token: $tokenResponse"
        }

        $tokenJson = $tokenResponse | ConvertFrom-Json
        if (-not $tokenJson.access_token) {
            throw "Keycloak admin token response missing access_token: $tokenResponse"
        }

        $script:KeycloakToken = $tokenJson.access_token.Trim()
    }

    $apiResponse = docker compose exec keycloak /bin/sh -c "curl -s -o - -w '%{http_code}' -H 'Authorization: Bearer $($script:KeycloakToken)' http://localhost:8080$Path" 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $apiResponse) {
        throw "Failed to query Keycloak admin API at $Path: $apiResponse"
    }

    $trimmedResponse = $apiResponse.Trim()
    if ($trimmedResponse.Length -lt 3) {
        throw "Unexpected response length for $Path: $apiResponse"
    }

    $statusCodeText = $trimmedResponse.Substring($trimmedResponse.Length - 3)
    $body = $trimmedResponse.Substring(0, $trimmedResponse.Length - 3)
    $statusCode = 0
    if (-not [int]::TryParse($statusCodeText, [ref]$statusCode)) {
        throw "Failed to parse status code from response for $Path: $apiResponse"
    }

    return [PSCustomObject]@{
        StatusCode = $statusCode
        Body       = $body
    }
}

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

    It "d-vpn realm exists in Keycloak" {
        $realmResponse = Invoke-KeycloakAdminAPI -Path '/admin/realms/d-vpn'
        $realmResponse.StatusCode | Should -Be 200

        $realm = $realmResponse.Body | ConvertFrom-Json
        $realm.realm | Should -Be 'd-vpn'
    }

    It "headscale OIDC client exists in d-vpn realm" {
        $clientsResponse = Invoke-KeycloakAdminAPI -Path '/admin/realms/d-vpn/clients'
        $clientsResponse.StatusCode | Should -Be 200

        $clients = $clientsResponse.Body | ConvertFrom-Json
        $headscaleClient = $clients | Where-Object { $_.clientId -eq 'headscale' }
        $headscaleClient | Should -Not -BeNullOrEmpty
        $headscaleClient.redirectUris | Should -Contain 'http://localhost:8080/oidc/callback'
        $headscaleClient.redirectUris | Should -Contain 'http://headscale:8080/oidc/callback'
    }

    It "testuser exists in d-vpn realm" {
        $usersResponse = Invoke-KeycloakAdminAPI -Path '/admin/realms/d-vpn/users?username=testuser'
        $usersResponse.StatusCode | Should -Be 200

        $users = $usersResponse.Body | ConvertFrom-Json
        $testUser = $users | Where-Object { $_.username -eq 'testuser' }
        $testUser | Should -Not -BeNullOrEmpty
    }
}
