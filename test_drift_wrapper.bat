@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Test the DRIFT output logic without running MATLAB
REM Simulate a completed run with all outputs present

set "RUN_DIR=C:\Dev\matlab-functions\results\switching\runs\run_2026_03_28_125438_minimal_canonical"
set "REPO_ROOT=C:\Dev\matlab-functions"

echo [TEST] Simulating DRIFT check output...
echo.

set "DRIFT=UNKNOWN"
set "DRIFT_REASON=NONE"
set "DRIFT_CHECK_PERFORMED=NO"

REM Run the drift check PowerShell logic
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$repoRoot = '%REPO_ROOT%'; $runDir = '%RUN_DIR%'; function NormalizePathToken([string]$p, [string]$root) { if ([string]::IsNullOrWhiteSpace($p)) { return $null }; $raw = $p.Trim(); $n = $raw.Replace('\','/'); if ($n.StartsWith('./')) { $n = $n.Substring(2) }; try { if ([System.IO.Path]::IsPathRooted($raw)) { $full = [System.IO.Path]::GetFullPath($raw) } else { $full = [System.IO.Path]::GetFullPath((Join-Path $root $raw)) }; $rootFull = [System.IO.Path]::GetFullPath($root); if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { return [System.IO.Path]::GetRelativePath($rootFull, $full).Replace('\','/').ToLowerInvariant() } } catch {}; return $n.ToLowerInvariant() }; if ($runDir -eq 'NA') { Write-Output '__DRIFT_UNKNOWN__|RUN_DIR_NOT_FOUND__'; exit 1 }; Push-Location -LiteralPath $runDir; try { if (-not (Test-Path 'run_manifest.json')) { Write-Output '__DRIFT_UNKNOWN__|MANIFEST_NOT_FOUND__'; exit 1 }; try { $m = Get-Content -LiteralPath 'run_manifest.json' -Raw ^| ConvertFrom-Json } catch { Write-Output '__DRIFT_UNKNOWN__|MANIFEST_PARSE_ERROR__'; exit 1 }; $expected = $m.outputs; if ($null -eq $expected) { Write-Output '__DRIFT_UNKNOWN__|NO_OUTPUTS_DECLARED__'; exit 1 }; $expectedRaw = @(); if ($expected -is [System.Array]) { $expectedRaw = $expected } else { $expectedRaw = @($expected) }; $expectedNorm = @($expectedRaw ^| ForEach-Object { if ($_ -is [string]) { NormalizePathToken ([string]$_) $repoRoot } elseif ($_ -and $_.path) { NormalizePathToken ([string]$_.path) $repoRoot } } ^| Where-Object { -not [string]::IsNullOrWhiteSpace($_) } ^| Sort-Object -Unique); $actualExist = @($expectedNorm ^| Where-Object { try { (Test-Path -LiteralPath $_) } catch { `$false } }); $missing = @($expectedNorm ^| Where-Object { $_ -notin $actualExist }); if ($missing.Count -gt 0) { $reason = \"missing_count_$($missing.Count)\"; Write-Output \"__DRIFT_YES__|$reason\"; exit 0 } else { Write-Output '__DRIFT_NO__|NONE'; exit 0 } } finally { Pop-Location }"`) do set "DRIFT_RESULT=%%I"

echo [DRIFT_RESULT] %DRIFT_RESULT%

for /f "tokens=1,2 delims=|" %%A in ("%DRIFT_RESULT%") do (
  set "DRIFT_STATUS=%%A"
  set "DRIFT_MSG=%%B"
)

if /i "!DRIFT_STATUS!"=="__DRIFT_YES__" (
  set "DRIFT=YES"
  set "DRIFT_REASON=!DRIFT_MSG!"
  set "DRIFT_CHECK_PERFORMED=YES"
)
if /i "!DRIFT_STATUS!"=="__DRIFT_NO__" (
  set "DRIFT=NO"
  set "DRIFT_REASON=!DRIFT_MSG!"
  set "DRIFT_CHECK_PERFORMED=YES"
)

echo.
echo [OUTPUT] Final DRIFT values:
echo DRIFT=!DRIFT!
echo DRIFT_REASON=!DRIFT_REASON!
echo DRIFT_CHECK_PERFORMED=!DRIFT_CHECK_PERFORMED!

endlocal
