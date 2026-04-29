param(
    [string]$ScriptPath = ""
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $ScriptPath -or $ScriptPath.Trim().Length -eq 0) {
    $ScriptPath = Join-Path $repoRoot 'Switching/analysis/run_switching_corrected_old_builder_readiness_check.m'
}

$scriptAbs = (Resolve-Path $ScriptPath).Path
$runner = Join-Path $repoRoot 'tools/run_matlab_safe.bat'

if (-not (Test-Path $runner)) {
    throw "Missing MATLAB runner: $runner"
}
if (-not (Test-Path $scriptAbs)) {
    throw "Missing readiness script: $scriptAbs"
}

Write-Output "Running readiness check script: $scriptAbs"
& $runner $scriptAbs
if ($LASTEXITCODE -ne 0) {
    throw "MATLAB readiness script failed with exit code $LASTEXITCODE"
}

Write-Output "Readiness check completed."
