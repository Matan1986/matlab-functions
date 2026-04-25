<#
.SYNOPSIS
  Registers a daily Windows Scheduled Task for Stage-1 local maintenance.

.DESCRIPTION
  Creates or updates task "MatlabFunctionsDailyMaintenance" to run daily at 04:00
  as the current user, without storing a password (interactive session context).

  Requires: run_daily_maintenance_local.ps1 in the same folder.

  Manual:
    powershell -ExecutionPolicy Bypass -File tools/maintenance/install_daily_maintenance_task.ps1

  Run daily pipeline once (no task install):
    powershell -ExecutionPolicy Bypass -File tools/maintenance/run_daily_maintenance_local.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dailyScript = Join-Path $PSScriptRoot "run_daily_maintenance_local.ps1"
if (-not (Test-Path -LiteralPath $dailyScript)) {
    Write-Error "Missing run_daily_maintenance_local.ps1 next to this installer."
    exit 1
}

$taskName = "MatlabFunctionsDailyMaintenance"
$pwsh = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$dailyScript`""

$action = New-ScheduledTaskAction -Execute $pwsh -Argument $arguments
$trigger = New-ScheduledTaskTrigger -Daily -At "04:00"
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

$userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited

$description = "matlab-functions Stage-1 maintenance: run output audit + minimal governor."

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description $description `
    -Force | Out-Null

Write-Output "Scheduled task registered (or updated)."
Write-Output ("  Task name: {0}" -f $taskName)
Write-Output ("  Execute: {0}" -f $pwsh)
Write-Output ("  Arguments: {0}" -f $arguments)
Write-Output ("  Trigger: Daily at 04:00 (user: {0})" -f $userId)
exit 0
