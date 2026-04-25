<#
.SYNOPSIS
  Stage-1 local maintenance: audit, governor, snapshot guard, publication health guard.

.DESCRIPTION
  Runs tools/maintenance/run_run_output_audit_local.ps1, then
  tools/maintenance/run_governor_minimal.ps1 for the same date token, then
  tools/maintenance/guard_run_snapshot_coverage.ps1 (detection-only; no -Date), then
  tools/maintenance/guard_maintenance_publication_health.ps1 (detection-only; uses -Date).
  Stops before the next step if a step fails. Writes a daily log under
  reports/maintenance/logs/.

  Manual (from repo root):
    powershell -ExecutionPolicy Bypass -File tools/maintenance/run_daily_maintenance_local.ps1

  Optional scheduled task (run once if you want automation):
    powershell -ExecutionPolicy Bypass -File tools/maintenance/install_daily_maintenance_task.ps1
#>
[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format "yyyy_MM_dd")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$powershellExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path -LiteralPath $powershellExe)) {
    $powershellExe = "powershell.exe"
}
$logDir = Join-Path $repoRoot "reports\maintenance\logs"
$logPath = Join-Path $logDir ("daily_maintenance_{0}.log" -f $Date)
$auditScript = Join-Path $PSScriptRoot "run_run_output_audit_local.ps1"
$governorScript = Join-Path $PSScriptRoot "run_governor_minimal.ps1"
$guardScript = Join-Path $PSScriptRoot "guard_run_snapshot_coverage.ps1"
$publicationHealthScript = Join-Path $PSScriptRoot "guard_maintenance_publication_health.ps1"
$agentCsv = Join-Path $repoRoot ("reports\maintenance\agent_outputs\{0}\run_output_audit_findings.csv" -f $Date)
$latestCsv = Join-Path $repoRoot "tables\maintenance_findings_latest.csv"
$summaryMd = Join-Path $repoRoot "reports\maintenance\governor_summary_latest.md"
$snapshotCoverageCsv = Join-Path $repoRoot "tables\run_snapshot_coverage_latest.csv"
$snapshotCoverageMd = Join-Path $repoRoot "reports\maintenance\run_snapshot_coverage_latest.md"
$publicationHealthCsv = Join-Path $repoRoot "tables\maintenance_publication_health_latest.csv"
$publicationHealthMd = Join-Path $repoRoot "reports\maintenance\maintenance_health_latest.md"

if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-DailyLog {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] {1}" -f $stamp, $Message
    Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
    Write-Output $Message
}

function Invoke-MaintenanceStep {
    param(
        [string]$StepName,
        [string]$ScriptPath,
        [string]$DateArg,
        [switch]$OmitDateArgument
    )
    Write-DailyLog ("--- {0} ---" -f $StepName)
    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()
    try {
        $argList = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $ScriptPath
        )
        if (-not $OmitDateArgument) {
            $argList += @("-Date", $DateArg)
        }
        $proc = Start-Process -FilePath $powershellExe -Wait -PassThru -NoNewWindow `
            -ArgumentList $argList `
            -RedirectStandardOutput $tmpOut `
            -RedirectStandardError $tmpErr

        if (Test-Path -LiteralPath $tmpOut) {
            Get-Content -LiteralPath $tmpOut -ErrorAction SilentlyContinue | ForEach-Object {
                Write-DailyLog ("  {0}" -f $_)
            }
        }
        if (Test-Path -LiteralPath $tmpErr) {
            $errText = Get-Content -LiteralPath $tmpErr -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($errText)) {
                Write-DailyLog ("  [stderr] {0}" -f $errText.TrimEnd())
            }
        }

        $code = $proc.ExitCode
        if ($code -ne 0) {
            Write-DailyLog ("{0} FAILED (exit {1})" -f $StepName, $code)
            return $false
        }
        Write-DailyLog ("{0} OK (exit 0)" -f $StepName)
        return $true
    }
    finally {
        Remove-Item -LiteralPath $tmpOut -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmpErr -ErrorAction SilentlyContinue
    }
}

$script:LogPath = $logPath
$startUtc = Get-Date -Format "o"
Write-DailyLog "=== Daily maintenance start (Date=$Date) at $startUtc ==="
Write-DailyLog ("Repo root: {0}" -f $repoRoot)
Write-DailyLog ("Log file: {0}" -f $logPath)

if (-not (Test-Path -LiteralPath $auditScript)) {
    Write-DailyLog "FATAL: audit script not found."
    exit 1
}
if (-not (Test-Path -LiteralPath $governorScript)) {
    Write-DailyLog "FATAL: governor script not found."
    exit 1
}
if (-not (Test-Path -LiteralPath $guardScript)) {
    Write-DailyLog "FATAL: guard_run_snapshot_coverage script not found."
    exit 1
}
if (-not (Test-Path -LiteralPath $publicationHealthScript)) {
    Write-DailyLog "FATAL: guard_maintenance_publication_health script not found."
    exit 1
}

$auditOk = Invoke-MaintenanceStep -StepName "run_run_output_audit_local" -ScriptPath $auditScript -DateArg $Date
if (-not $auditOk) {
    Write-DailyLog "FINAL_VERDICT=FAIL (audit step)"
    Write-Output "Step run_run_output_audit_local: FAILED (Governor not run)."
    exit 1
}
Write-Output "Step run_run_output_audit_local: OK"

$govOk = Invoke-MaintenanceStep -StepName "run_governor_minimal" -ScriptPath $governorScript -DateArg $Date
if (-not $govOk) {
    Write-DailyLog "FINAL_VERDICT=FAIL (governor step)"
    Write-Output "Step run_governor_minimal: FAILED."
    exit 1
}
Write-Output "Step run_governor_minimal: OK"

$guardOk = Invoke-MaintenanceStep -StepName "guard_run_snapshot_coverage" -ScriptPath $guardScript -OmitDateArgument
if (-not $guardOk) {
    Write-DailyLog "FINAL_VERDICT=FAIL (guard_run_snapshot_coverage)"
    Write-Output "Step guard_run_snapshot_coverage: FAILED."
    exit 1
}
Write-Output "Step guard_run_snapshot_coverage: OK"

$pubOk = Invoke-MaintenanceStep -StepName "guard_maintenance_publication_health" -ScriptPath $publicationHealthScript -DateArg $Date
if (-not $pubOk) {
    Write-DailyLog "FINAL_VERDICT=FAIL (guard_maintenance_publication_health)"
    Write-Output "Step guard_maintenance_publication_health: FAILED."
    exit 1
}
Write-Output "Step guard_maintenance_publication_health: OK"

Write-DailyLog ("Agent CSV (expected): {0}" -f $agentCsv)
Write-DailyLog ("Governor latest CSV: {0}" -f $latestCsv)
Write-DailyLog ("Governor summary MD: {0}" -f $summaryMd)
Write-DailyLog ("Snapshot coverage CSV: {0}" -f $snapshotCoverageCsv)
Write-DailyLog ("Snapshot coverage report: {0}" -f $snapshotCoverageMd)
Write-DailyLog ("Publication health CSV: {0}" -f $publicationHealthCsv)
Write-DailyLog ("Publication health report: {0}" -f $publicationHealthMd)
Write-DailyLog "FINAL_VERDICT=OK"
Write-Output ""
Write-Output "Daily maintenance completed OK."
Write-Output ("  Log: {0}" -f $logPath)
Write-Output ("  Agent CSV: {0}" -f $agentCsv)
Write-Output ("  Latest findings: {0}" -f $latestCsv)
Write-Output ("  Summary: {0}" -f $summaryMd)
Write-Output ("  Snapshot coverage CSV: {0}" -f $snapshotCoverageCsv)
Write-Output ("  Snapshot coverage report: {0}" -f $snapshotCoverageMd)
Write-Output ("  Publication health CSV: {0}" -f $publicationHealthCsv)
Write-Output ("  Publication health report: {0}" -f $publicationHealthMd)
exit 0
