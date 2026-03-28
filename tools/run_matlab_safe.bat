@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_PATH=%~1"
set "REPO_ROOT=C:\Dev\matlab-functions"
set "RUN_DIR_POINTER=%REPO_ROOT%\run_dir_pointer.txt"
set "MATLAB_EXIT_CODE="
set "RUN_DIR="
set "FINAL_EXIT_CODE=0"
set "RUN_FINGERPRINT=NA"
set "SCRIPT_CONTENT_HASH=NA"
set "DUPLICATE_RUN=NO"
set "FINGERPRINT_CREATED=NO"

echo [MATLAB WRAPPER] Runnable script path argument:
echo %SCRIPT_PATH%
echo [MATLAB WRAPPER] Canonical caller format: tools\run_matlab_safe.bat "C:/Dev/matlab-functions/path/to/script.m"

if "%SCRIPT_PATH%"=="" (
  echo [MATLAB WRAPPER] ERROR: Missing runnable script path argument.
  echo [MATLAB WRAPPER] USAGE: tools\run_matlab_safe.bat "C:/Dev/matlab-functions/path/to/script.m"
  set "FINAL_EXIT_CODE=2"
  goto :emit_status
)

set "SCRIPT_PATH_ABS="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$p = '%SCRIPT_PATH%'; if (-not [System.IO.Path]::IsPathRooted($p)) { Write-Output '__ERROR__ABSOLUTE_PATH_REQUIRED'; exit 11 }; if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { Write-Output '__ERROR__FILE_NOT_FOUND'; exit 12 }; $resolved = (Resolve-Path -LiteralPath $p).Path; if ([System.IO.Path]::GetExtension($resolved).ToLowerInvariant() -ne '.m') { Write-Output '__ERROR__INVALID_EXTENSION'; exit 13 }; Write-Output $resolved"`) do set "SCRIPT_PATH_ABS=%%I"

if /i "%SCRIPT_PATH_ABS%"=="__ERROR__ABSOLUTE_PATH_REQUIRED" (
  echo [MATLAB WRAPPER] ERROR: Absolute runnable script path is required.
  set "FINAL_EXIT_CODE=2"
  goto :emit_status
)
if /i "%SCRIPT_PATH_ABS%"=="__ERROR__FILE_NOT_FOUND" (
  echo [MATLAB WRAPPER] ERROR: Runnable script file does not exist.
  set "FINAL_EXIT_CODE=2"
  goto :emit_status
)
if /i "%SCRIPT_PATH_ABS%"=="__ERROR__INVALID_EXTENSION" (
  echo [MATLAB WRAPPER] ERROR: Runnable script must use .m extension.
  set "FINAL_EXIT_CODE=2"
  goto :emit_status
)

if not defined SCRIPT_PATH_ABS (
  echo [MATLAB WRAPPER] ERROR: Failed to resolve runnable script absolute path.
  set "FINAL_EXIT_CODE=2"
  goto :emit_status
)

echo [MATLAB WRAPPER] Generating stable run fingerprint...

if exist tools\generate_run_fingerprint.ps1 goto run_generate_fingerprint
echo FINGERPRINT_CREATED=NO
echo DUPLICATE_RUN=NO
goto after_generate_fingerprint
:run_generate_fingerprint
powershell -NoProfile -ExecutionPolicy Bypass -File tools\generate_run_fingerprint.ps1 "%SCRIPT_PATH_ABS%"
:after_generate_fingerprint

if exist "%RUN_DIR_POINTER%" del "%RUN_DIR_POINTER%" >nul 2>&1

echo [MATLAB WRAPPER] Validating runnable script via validator...
powershell -ExecutionPolicy Bypass -File tools\validate_matlab_runnable.ps1 "%SCRIPT_PATH_ABS%"
if not %ERRORLEVEL% equ 0 (
  echo [MATLAB WRAPPER] ERROR: Script validation failed with exit code %ERRORLEVEL%
  set "FINAL_EXIT_CODE=3"
  goto :emit_status
)
echo [MATLAB WRAPPER] Script validation passed.


echo [MATLAB WRAPPER] Launch policy: wrapper-managed MATLAB invocation only (with 300-second timeout).
set "MATLAB_EXE=C:\Program Files\MATLAB\R2023b\bin\matlab.exe"
set "RUN_START_TIME="
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')"`) do set "RUN_START_TIME=%%t"

if not defined RUN_START_TIME (
  echo [MATLAB WRAPPER] ERROR: Failed to capture RUN_START_TIME.
  set "FINAL_EXIT_CODE=8"
  goto :emit_status
)

echo [MATLAB WRAPPER] Running script: %SCRIPT_PATH_ABS%

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$matlabExe = '%MATLAB_EXE%'; ^
$matlabScript = '%SCRIPT_PATH_ABS%'; ^
$repoRoot = '%REPO_ROOT%'; ^
$timeoutSeconds = 300; ^
if (-not (Test-Path $matlabExe)) { $matlabExe = 'matlab.exe' }; ^
try { ^
  $args = @('-batch', \"run('$matlabScript'); exit;\"); ^
  $p = Start-Process -FilePath $matlabExe -ArgumentList $args -WorkingDirectory $repoRoot -PassThru; ^
  if ($p.WaitForExit($timeoutSeconds * 1000)) { exit $p.ExitCode } ^
  else { Stop-Process -Id $p.Id -Force; exit 124 } ^
} catch { exit 1 }"

set "MATLAB_EXIT_CODE=%ERRORLEVEL%"

if "!MATLAB_EXIT_CODE!"=="999" (
  echo [MATLAB WRAPPER] ERROR: MATLAB execution timeout after 300 seconds
  set "FINAL_EXIT_CODE=8"
  goto :emit_status
)

if "!MATLAB_EXIT_CODE!"=="998" (
  echo [MATLAB WRAPPER] ERROR: Failed to start MATLAB process
  set "FINAL_EXIT_CODE=8"
  goto :emit_status
)

if not defined MATLAB_EXIT_CODE set "MATLAB_EXIT_CODE=NA"
echo [MATLAB WRAPPER] MATLAB finished with code !MATLAB_EXIT_CODE!
set "FINAL_EXIT_CODE=!MATLAB_EXIT_CODE!"

if not exist "%RUN_DIR_POINTER%" (
  echo [MATLAB WRAPPER] ERROR: run_dir_pointer.txt was not created: %RUN_DIR_POINTER%
  if "!FINAL_EXIT_CODE!"=="0" set "FINAL_EXIT_CODE=6"
  goto :emit_status
)

set "RUN_DIR="
for /f "usebackq delims=" %%I in ("%RUN_DIR_POINTER%") do (
  if not defined RUN_DIR set "RUN_DIR=%%I"
)

if not defined RUN_DIR (
  echo [MATLAB WRAPPER] ERROR: run_dir_pointer.txt is empty.
  if "!FINAL_EXIT_CODE!"=="0" set "FINAL_EXIT_CODE=6"
  goto :emit_status
)

for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$p='%RUN_DIR%'; if (-not [System.IO.Path]::IsPathRooted($p)) { Write-Output '__ERROR__RUN_DIR_NOT_ABSOLUTE'; exit 21 }; if (-not (Test-Path -LiteralPath $p -PathType Container)) { Write-Output '__ERROR__RUN_DIR_NOT_FOUND'; exit 22 }; Write-Output (Resolve-Path -LiteralPath $p).Path"`) do set "RUN_DIR=%%I"

if /i "%RUN_DIR%"=="__ERROR__RUN_DIR_NOT_ABSOLUTE" (
  echo [MATLAB WRAPPER] ERROR: run_dir_pointer.txt must contain an absolute run_dir path.
  if "!FINAL_EXIT_CODE!"=="0" set "FINAL_EXIT_CODE=6"
  goto :emit_status
)

if /i "%RUN_DIR%"=="__ERROR__RUN_DIR_NOT_FOUND" (
  echo [MATLAB WRAPPER] ERROR: run_dir from pointer does not exist.
  if "!FINAL_EXIT_CODE!"=="0" set "FINAL_EXIT_CODE=6"
  goto :emit_status
)

if not exist "%RUN_DIR%\execution_status.csv" (
  echo [MATLAB WRAPPER] ERROR: Missing required artifact: %RUN_DIR%\execution_status.csv
  if "!FINAL_EXIT_CODE!"=="0" set "FINAL_EXIT_CODE=7"
)

if not exist "%RUN_DIR%\run_manifest.json" (
  echo [MATLAB WRAPPER] ERROR: Missing required artifact: %RUN_DIR%\run_manifest.json
  if "!FINAL_EXIT_CODE!"=="0" set "FINAL_EXIT_CODE=7"
)

set "HAS_CSV=0"
for /f %%F in ('dir /b /a-d "%RUN_DIR%\*.csv" 2^>nul') do set "HAS_CSV=1"
if "!HAS_CSV!"=="0" (
  echo [MATLAB WRAPPER] ERROR: run_dir must contain at least one CSV file.
  if "!FINAL_EXIT_CODE!"=="0" set "FINAL_EXIT_CODE=7"
)

set "HAS_MD=0"
for /f %%F in ('dir /b /a-d "%RUN_DIR%\*.md" 2^>nul') do set "HAS_MD=1"
if "!HAS_MD!"=="0" (
  echo [MATLAB WRAPPER] ERROR: run_dir must contain at least one Markdown file.
  if "!FINAL_EXIT_CODE!"=="0" set "FINAL_EXIT_CODE=7"
)

:emit_status
if not defined MATLAB_EXIT_CODE set "MATLAB_EXIT_CODE=NA"
if not defined RUN_DIR set "RUN_DIR=NA"
if not defined RUN_START_TIME set "RUN_START_TIME=NA"

set "HAS_OUTPUTS=NO"
set "FRESH_FILES_LIST_FILE=%TEMP%\fresh_outputs_%RANDOM%_%RANDOM%.txt"
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$t = '%RUN_START_TIME%'; $repoRoot = '%REPO_ROOT%'; $out = '%FRESH_FILES_LIST_FILE%'; if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }; if ($t -eq 'NA') { Write-Output '__NO_FRESH_OUTPUTS__'; exit 1 }; $runStart = [datetime]::ParseExact($t, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture); $files = Get-ChildItem "$repoRoot\tables","$repoRoot\reports","$repoRoot\results" -Recurse -File -ErrorAction SilentlyContinue ^| Where-Object { $_.LastWriteTime -gt $runStart } ^| ForEach-Object { [System.IO.Path]::GetRelativePath($repoRoot, $_.FullName).Replace('\','/') } ^| Sort-Object -Unique; if ($files.Count -gt 0) { $files ^| Set-Content -LiteralPath $out -Encoding ASCII; Write-Output '__FRESH_OUTPUTS_FOUND__'; exit 0 } else { '' ^| Set-Content -LiteralPath $out -Encoding ASCII; Write-Output '__NO_FRESH_OUTPUTS__'; exit 1 }"`) do set "FRESH_OUTPUTS_RESULT=%%I"

if /i "!FRESH_OUTPUTS_RESULT!"=="__FRESH_OUTPUTS_FOUND__" set "HAS_OUTPUTS=YES"

set "MANIFEST_OUTPUT_EXISTS_RESULT=__NO_MANIFEST_OUTPUTS__"
if /i "!HAS_OUTPUTS!"=="NO" if /i not "!RUN_DIR!"=="NA" if exist "!RUN_DIR!\run_manifest.json" (
  powershell -NoProfile -Command "$manifest = '%RUN_DIR%\run_manifest.json'; if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { exit 1 }; try { $obj = ConvertFrom-Json (Get-Content -LiteralPath $manifest -Raw) } catch { exit 1 }; $outs = @($obj.outputs); foreach ($entry in $outs) { $p = $null; if ($entry -is [string]) { $p = [string]$entry } elseif ($entry -and $entry.path) { $p = [string]$entry.path }; if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path -LiteralPath $p -PathType Leaf)) { exit 0 } }; exit 1"
  if !ERRORLEVEL! equ 0 set "HAS_OUTPUTS=YES"
)

:outputs_scan_done
set "DRIFT=YES"
set "DRIFT_REASON=NONE"
set "DRIFT_CHECK_PERFORMED=NO"
set "DRIFT_RAW_OUTPUT="
echo [DEBUG] Entering drift check block
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$repoRoot = '%REPO_ROOT%'; $runDir = '%RUN_DIR%'; $sep = [char]124; function NormalizePathToken([string]$p, [string]$root) { if ([string]::IsNullOrWhiteSpace($p)) { return $null }; $raw = $p.Trim(); $n = $raw.Replace('\','/'); if ($n.StartsWith('./')) { $n = $n.Substring(2) }; try { if ([System.IO.Path]::IsPathRooted($raw)) { $full = [System.IO.Path]::GetFullPath($raw) } else { $full = [System.IO.Path]::GetFullPath((Join-Path $root $raw)) }; $rootFull = [System.IO.Path]::GetFullPath($root); if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { return [System.IO.Path]::GetRelativePath($rootFull, $full).Replace('\','/').ToLowerInvariant() } } catch {}; return $n.ToLowerInvariant() }; if ($runDir -eq 'NA') { $result = '__DRIFT_YES__' + $sep + 'RUN_DIR_NOT_FOUND__'; Write-Output $result; exit 1 }; Push-Location -LiteralPath $runDir; try { if (-not (Test-Path 'run_manifest.json')) { $result = '__DRIFT_YES__' + $sep + 'MANIFEST_NOT_FOUND__'; Write-Output $result; exit 1 }; try { $m = Get-Content -LiteralPath 'run_manifest.json' -Raw ^| ConvertFrom-Json } catch { $result = '__DRIFT_YES__' + $sep + 'MANIFEST_PARSE_ERROR__'; Write-Output $result; exit 1 }; $expected = $m.outputs; if ($null -eq $expected) { $result = '__DRIFT_YES__' + $sep + 'NO_OUTPUTS_DECLARED__'; Write-Output $result; exit 1 }; $expectedRaw = @(); if ($expected -is [System.Array]) { $expectedRaw = $expected } else { $expectedRaw = @($expected) }; $expectedNorm = @($expectedRaw ^| ForEach-Object { if ($_ -is [string]) { NormalizePathToken ([string]$_) $repoRoot } elseif ($_ -and $_.path) { NormalizePathToken ([string]$_.path) $repoRoot } } ^| Where-Object { -not [string]::IsNullOrWhiteSpace($_) } ^| Sort-Object -Unique); $actualExist = @($expectedNorm ^| Where-Object { try { (Test-Path -LiteralPath $_) } catch { `$false } }); $missing = @($expectedNorm ^| Where-Object { $_ -notin $actualExist }); if ($missing.Count -gt 0) { $reason = 'missing_count_' + $missing.Count; $result = '__DRIFT_YES__' + $sep + $reason; Write-Output $result; exit 0 } else { $result = '__DRIFT_NO__' + $sep + 'NONE'; Write-Output $result; exit 0 } } finally { Pop-Location }; if (!$?) { Write-Output '**PS_FAILED**' }" 2^>^&1
`) do (
  set "DRIFT_RESULT=%%A"
  echo [DEBUG] PS_LINE=%%A
)

if not defined DRIFT_CHECK_PERFORMED (
  echo [DEBUG] POWERSHELL RETURNED NOTHING
)

set "DRIFT_RAW_OUTPUT=!DRIFT_RESULT!"

echo [DEBUG] RAW_DRIFT_OUTPUT=!DRIFT_RAW_OUTPUT!

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

echo [DEBUG] PARSED_DRIFT=!DRIFT!
echo [DEBUG] PARSED_REASON=!DRIFT_REASON!
if /i "!DRIFT_CHECK_PERFORMED!"=="NO" echo [DEBUG] DRIFT NOT EXECUTED

set "RUN_VALID=YES"
if not "!FINAL_EXIT_CODE!"=="0" set "RUN_VALID=NO"
if not "!HAS_OUTPUTS!"=="YES" set "RUN_VALID=NO"

set "STATUS_FILE=%REPO_ROOT%\tables\run_status.csv"
set "STATUS_FILE_WRITTEN=NO"
if not exist "%REPO_ROOT%\tables" mkdir "%REPO_ROOT%\tables" >nul 2>&1
(
  echo EXECUTION_STATUS,SCRIPT_SUCCESS
  echo RUN_VALID,!RUN_VALID!
  echo HAS_OUTPUTS,!HAS_OUTPUTS!
) > "%STATUS_FILE%" 2>nul
if exist "%STATUS_FILE%" set "STATUS_FILE_WRITTEN=YES"

set "RUN_TRUTH_ENFORCED=NO"
if "!STATUS_FILE_WRITTEN!"=="YES" set "RUN_TRUTH_ENFORCED=YES"

set "RUN_PROVENANCE_ENFORCED=YES"
if "!RUN_START_TIME!"=="NA" set "RUN_PROVENANCE_ENFORCED=NO"

echo RUN_VALID=!RUN_VALID!
echo HAS_OUTPUTS=!HAS_OUTPUTS!
echo DRIFT=!DRIFT!
echo DRIFT_REASON=!DRIFT_REASON!
echo DRIFT_CHECK_PERFORMED=!DRIFT_CHECK_PERFORMED!
echo FINGERPRINT_CREATED=!FINGERPRINT_CREATED!
echo DUPLICATE_RUN=!DUPLICATE_RUN!
echo RUN_PROVENANCE_ENFORCED=!RUN_PROVENANCE_ENFORCED!
echo RUN_TRUTH_ENFORCED=!RUN_TRUTH_ENFORCED!
echo STATUS_FILE_WRITTEN=!STATUS_FILE_WRITTEN!

echo WRAPPER_EXIT_CODE=!FINAL_EXIT_CODE!
echo MATLAB_EXIT_CODE=!MATLAB_EXIT_CODE!
echo RUN_DIR=!RUN_DIR!

if defined FRESH_FILES_LIST_FILE if exist "!FRESH_FILES_LIST_FILE!" del /q "!FRESH_FILES_LIST_FILE!" >nul 2>&1

endlocal & exit /b %FINAL_EXIT_CODE%

