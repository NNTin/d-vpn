$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Runs all service startup tests in sequence with summary reporting.

.DESCRIPTION
Executes the Keycloak, WireGuard, and sync service Pester test files. The script
verifies prerequisites (Pester module, Docker Compose, running services) before
running each test file. All tests run even if one fails, and a summary table is
printed at the end. Exit code is 0 when all tests pass; otherwise 1.

.EXAMPLE
pwsh ./tests/Run-IndividualTests.ps1
#>

$testFiles = @(
    'KeycloakStartup.Tests.ps1',
    'WireGuardStartup.Tests.ps1',
    'SyncService.Tests.ps1'
)

if (-not (Get-Module -Name Pester -ListAvailable)) {
    Write-Error "Pester module not found. Install with: Install-Module -Name Pester -Force -AllowClobber"
    exit 1
}

$composeVersion = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker Compose is required but not available: $composeVersion"
    exit 1
}

$composePsOutput = docker compose ps --format json 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Unable to determine service status with 'docker compose ps --format json': $composePsOutput"
} else {
    try {
        $services = ($composePsOutput -join "`n") | ConvertFrom-Json
        $notRunning = $services | Where-Object { $_.State -notmatch 'running' }
        if ($notRunning) {
            $names = ($notRunning | ForEach-Object { $_.Name }) -join ', '
            Write-Warning "Some services are not running: $names. Tests may fail."
        }
    } catch {
        Write-Warning "Failed to parse compose status output: $composePsOutput"
    }
}

$results = @()
$totalPassed = 0
$totalFailed = 0
$totalSkipped = 0

foreach ($testFile in $testFiles) {
    Write-Host ""
    Write-Host "Running $testFile..."
    $result = $null
    try {
        $result = Invoke-Pester -Path "./tests/$testFile" -Output Detailed -PassThru
    } catch {
        Write-Error "Test run failed for $testFile: $_"
    }

    $passed = $result.PassedCount
    $failed = $result.FailedCount
    $skipped = $result.SkippedCount

    if ($null -eq $passed) { $passed = 0 }
    if ($null -eq $failed) { $failed = 0 }
    if ($null -eq $skipped) { $skipped = 0 }

    $totalPassed += $passed
    $totalFailed += $failed
    $totalSkipped += $skipped

    $results += [PSCustomObject]@{
        TestFile = $testFile
        Passed   = $passed
        Failed   = $failed
        Skipped  = $skipped
    }
}

Write-Host "`nSummary:"
$results | Format-Table -AutoSize
Write-Host ""
Write-Host ("Totals: Passed {0}, Failed {1}, Skipped {2}" -f $totalPassed, $totalFailed, $totalSkipped)

if ($totalFailed -gt 0) {
    exit 1
}

exit 0
