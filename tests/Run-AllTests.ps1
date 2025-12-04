<#
.SYNOPSIS
Runs the complete test suite including integration coverage.

.DESCRIPTION
CI-focused wrapper that always executes both the individual service tests and
the end-to-end integration test. Delegates to Run-IndividualTests.ps1 for the
actual Pester execution and reporting while enforcing fail-fast behavior.

.EXAMPLE
pwsh ./tests/Run-AllTests.ps1
#>

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -Name Pester -ListAvailable)) {
    Write-Error "Pester module not found. Install with: Install-Module -Name Pester -Force -AllowClobber"
    exit 1
}

$composeVersion = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker Compose is required but not available: $composeVersion"
    exit 1
}

Write-Host "Running complete test suite (individual + integration tests)"

$runner = Join-Path $PSScriptRoot 'Run-IndividualTests.ps1'
if (-not (Test-Path $runner)) {
    Write-Error "Test runner not found at $runner"
    exit 1
}

& $runner -IncludeIntegration
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    exit $exitCode
}

exit 0
