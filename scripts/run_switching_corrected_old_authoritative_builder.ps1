param(
    [string]$ScriptPath = ""
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $ScriptPath -or $ScriptPath.Trim().Length -eq 0) {
    $ScriptPath = Join-Path $repoRoot 'Switching/analysis/run_switching_corrected_old_authoritative_builder.m'
}

$scriptAbs = (Resolve-Path $ScriptPath).Path
$runner = Join-Path $repoRoot 'tools/run_matlab_safe.bat'

if (-not (Test-Path $runner)) {
    throw "Missing MATLAB runner: $runner"
}
if (-not (Test-Path $scriptAbs)) {
    throw "Missing builder script: $scriptAbs"
}

Write-Output "Running corrected-old authoritative builder script: $scriptAbs"
& $runner $scriptAbs
if ($LASTEXITCODE -ne 0) {
    throw "MATLAB authoritative builder script failed with exit code $LASTEXITCODE"
}

Write-Output "Corrected-old authoritative builder run completed."

