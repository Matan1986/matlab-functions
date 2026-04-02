@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_PATH=%~1"
set "REPO_ROOT=C:\Dev\matlab-functions"
set "RUN_DIR_POINTER=%REPO_ROOT%\run_dir_pointer.txt"
set "FALLBACK_RUNS_ROOT=%REPO_ROOT%\results\relaxation_canonical\runs"
set "SOFT_GATE_STATUS_CSV=%REPO_ROOT%\tables\wrapper_soft_gate_status.csv"
set "SOFT_GATE_REPORT_MD=%REPO_ROOT%\reports\wrapper_soft_gate.md"
set "MATLAB_EXIT_CODE="
set "RUN_DIR="
set "FINAL_EXIT_CODE=0"
set "STATUS_REPORTED=UNKNOWN"
set "PRECHECK_RESULT="
set "PRECHECK_FAIL_REASONS="
set "MATLAB_TIMEOUT_SECONDS=%MATLAB_TIMEOUT_SECONDS%"
if not defined MATLAB_TIMEOUT_SECONDS set "MATLAB_TIMEOUT_SECONDS=0"

echo [MATLAB WRAPPER] Runnable script path argument:
echo %SCRIPT_PATH%
echo [MATLAB WRAPPER] Canonical caller format: tools\run_matlab_safe.bat "C:/Dev/matlab-functions/path/to/script.m"

if "%SCRIPT_PATH%"=="" (
  echo [MATLAB WRAPPER] ERROR: Missing runnable script path argument.
  echo [MATLAB WRAPPER] USAGE: tools\run_matlab_safe.bat "C:/Dev/matlab-functions/path/to/script.m"
  set "FINAL_EXIT_CODE=2"
  goto :finalize
)

set "SCRIPT_PATH_ABS="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$p = '%SCRIPT_PATH%'; if (-not [System.IO.Path]::IsPathRooted($p)) { Write-Output '__ERROR__ABSOLUTE_PATH_REQUIRED'; exit 11 }; if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { Write-Output '__ERROR__FILE_NOT_FOUND'; exit 12 }; $resolved = (Resolve-Path -LiteralPath $p).Path; if ([System.IO.Path]::GetExtension($resolved).ToLowerInvariant() -ne '.m') { Write-Output '__ERROR__INVALID_EXTENSION'; exit 13 }; Write-Output $resolved"`) do set "SCRIPT_PATH_ABS=%%I"

if /i "%SCRIPT_PATH_ABS%"=="__ERROR__ABSOLUTE_PATH_REQUIRED" (
  echo [MATLAB WRAPPER] ERROR: Absolute runnable script path is required.
  set "FINAL_EXIT_CODE=2"
  goto :finalize
)
if /i "%SCRIPT_PATH_ABS%"=="__ERROR__FILE_NOT_FOUND" (
  echo [MATLAB WRAPPER] ERROR: Runnable script file does not exist.
  set "FINAL_EXIT_CODE=2"
  goto :finalize
)
if /i "%SCRIPT_PATH_ABS%"=="__ERROR__INVALID_EXTENSION" (
  echo [MATLAB WRAPPER] ERROR: Runnable script must use .m extension.
  set "FINAL_EXIT_CODE=2"
  goto :finalize
)

if not defined SCRIPT_PATH_ABS (
  echo [MATLAB WRAPPER] ERROR: Failed to resolve runnable script absolute path.
  set "FINAL_EXIT_CODE=2"
  goto :finalize
)

echo [MATLAB WRAPPER] Generating stable run fingerprint...

if exist tools\generate_run_fingerprint.ps1 (
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\generate_run_fingerprint.ps1 "%SCRIPT_PATH_ABS%"
)

if exist "%RUN_DIR_POINTER%" del "%RUN_DIR_POINTER%" >nul 2>&1

echo [MATLAB WRAPPER] Running soft precheck before validator...
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$scriptPath='%SCRIPT_PATH_ABS%'; $repoRoot='%REPO_ROOT%'; $tablesDir=Join-Path $repoRoot 'tables'; $reportsDir=Join-Path $repoRoot 'reports'; New-Item -ItemType Directory -Path $tablesDir -Force | Out-Null; New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null; $reasons=@(); if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { $reasons += 'script file unreadable'; $text='' } else { try { $text = Get-Content -LiteralPath $scriptPath -Raw -ErrorAction Stop } catch { $text = ''; $reasons += 'script file unreadable' } }; if (-not [string]::IsNullOrWhiteSpace($text)) { if ($text -match '(?is)\bcatch\b' -and -not ($text -match '(?is)\brethrow\b')) { $reasons += 'catch without rethrow' }; if (-not ($text -match '(?i)execution_status\.csv' -or $text -match '(?i)execution_status')) { $reasons += 'missing execution_status.csv' }; if (-not (($text -match '(?i)\bwritetable\b') -and ($text -match '(?i)\.csv\b'))) { $reasons += 'no CSV writetable' }; if (-not ($text -match '(?i)\.md\b')) { $reasons += 'no .md output' }; if (-not ($text -match '(?i)\bcreateRunContext\b')) { $reasons += 'missing createRunContext' } }; $result = if ($reasons.Count -eq 0) { 'PASS' } else { 'FAIL' }; $reasonText = if ($reasons.Count -eq 0) { '' } else { ($reasons -join '; ') }; [pscustomobject]@{ timestamp=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); script_path=$scriptPath; precheck_result=$result; fail_reasons=$reasonText } | Export-Csv -NoTypeInformation -Encoding ASCII -LiteralPath '%SOFT_GATE_STATUS_CSV%'; $md = @('# Wrapper Soft Gate', '', ('- SCRIPT_PATH: ' + $scriptPath), ('- PRECHECK_RESULT: ' + $result), ('- FAIL_REASONS: ' + $reasonText)); Set-Content -LiteralPath '%SOFT_GATE_REPORT_MD%' -Value $md -Encoding ASCII; Write-Output ('__PRECHECK_RESULT__=' + $result); Write-Output ('__PRECHECK_REASONS__=' + $reasonText)"`) do (
  for /f "tokens=1,* delims==" %%A in ("%%I") do (
    if /i "%%A"=="__PRECHECK_RESULT__" set "PRECHECK_RESULT=%%B"
    if /i "%%A"=="__PRECHECK_REASONS__" set "PRECHECK_FAIL_REASONS=%%B"
  )
)

if not defined PRECHECK_RESULT (
  set "PRECHECK_RESULT=FAIL"
  if not defined PRECHECK_FAIL_REASONS set "PRECHECK_FAIL_REASONS=precheck internal error"
)

if /i "!PRECHECK_RESULT!"=="FAIL" (
  echo PRECHECK_FAILED
  echo FAIL_REASONS=!PRECHECK_FAIL_REASONS!
  set "FINAL_EXIT_CODE=4"
  goto :finalize
)

echo [MATLAB WRAPPER] Soft precheck passed.

echo [MATLAB WRAPPER] Validating runnable script via validator...
powershell -ExecutionPolicy Bypass -File tools\validate_matlab_runnable.ps1 "%SCRIPT_PATH_ABS%"
if not %ERRORLEVEL% equ 0 (
  echo [MATLAB WRAPPER] ERROR: Script validation failed with exit code %ERRORLEVEL%
  set "FINAL_EXIT_CODE=3"
  goto :finalize
)
echo [MATLAB WRAPPER] Script validation passed.


if "!MATLAB_TIMEOUT_SECONDS!"=="0" (
  echo [MATLAB WRAPPER] Launch policy: wrapper-managed MATLAB invocation only (no timeout).
) else (
  echo [MATLAB WRAPPER] Launch policy: wrapper-managed MATLAB invocation only (timeout !MATLAB_TIMEOUT_SECONDS! seconds).
)
set "MATLAB_EXE=C:\Program Files\MATLAB\R2023b\bin\matlab.exe"
set "RUN_START_TIME="
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')"`) do set "RUN_START_TIME=%%t"

if not defined RUN_START_TIME (
  echo [MATLAB WRAPPER] ERROR: Failed to capture RUN_START_TIME.
  set "FINAL_EXIT_CODE=8"
  goto :finalize
)

echo [MATLAB WRAPPER] Running script: %SCRIPT_PATH_ABS%

powershell -NoProfile -ExecutionPolicy Bypass -Command "$matlabExe='%MATLAB_EXE%'; $matlabScript='%SCRIPT_PATH_ABS%'; $repoRoot='%REPO_ROOT%'; $timeoutSeconds=[int]%MATLAB_TIMEOUT_SECONDS%; if (-not (Test-Path -LiteralPath $matlabExe)) { $matlabExe='matlab.exe' }; try { $scriptDir = (Split-Path -Parent $matlabScript -ErrorAction Stop); $scriptName = (Split-Path -Leaf $matlabScript -ErrorAction Stop); $batchCmd = 'cd(''' + $scriptDir + '''); run(''' + $scriptName + '''); exit;'; $args=@('-batch', $batchCmd); $p=Start-Process -FilePath $matlabExe -ArgumentList $args -WorkingDirectory $repoRoot -PassThru; if ($timeoutSeconds -le 0) { $p.WaitForExit() | Out-Null; exit $p.ExitCode } elseif ($p.WaitForExit($timeoutSeconds * 1000)) { exit $p.ExitCode } else { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; exit 124 } } catch { exit 1 }"

set "MATLAB_EXIT_CODE=%ERRORLEVEL%"

if not defined MATLAB_EXIT_CODE set "MATLAB_EXIT_CODE=NA"
echo [MATLAB WRAPPER] MATLAB finished with code !MATLAB_EXIT_CODE!
if "!MATLAB_EXIT_CODE!"=="124" echo [MATLAB WRAPPER] WARN: MATLAB execution timeout after !MATLAB_TIMEOUT_SECONDS! seconds.
if "!MATLAB_EXIT_CODE!"=="1" echo [MATLAB WRAPPER] WARN: MATLAB exited with a nonzero code.

set "RUN_DIR="
if exist "%RUN_DIR_POINTER%" (
  for /f "usebackq delims=" %%I in ("%RUN_DIR_POINTER%") do (
    if not defined RUN_DIR if not "%%~I"=="" set "RUN_DIR=%%~I"
  )
)

if not defined RUN_DIR (
  echo [MATLAB WRAPPER] WARN: run_dir_pointer.txt missing or empty, using fallback run directory discovery.
  for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$root='%FALLBACK_RUNS_ROOT%'; if (Test-Path -LiteralPath $root -PathType Container) { $d = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if ($null -ne $d) { Write-Output $d.FullName } }"`) do (
    if not defined RUN_DIR set "RUN_DIR=%%I"
  )
)

if defined RUN_DIR (
  for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$p='%RUN_DIR%'; if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path '%REPO_ROOT%' $p }; if (Test-Path -LiteralPath $p -PathType Container) { Write-Output (Resolve-Path -LiteralPath $p).Path } else { Write-Output '__RUN_DIR_NOT_FOUND__' }"`) do set "RUN_DIR=%%I"
  if /i "!RUN_DIR!"=="__RUN_DIR_NOT_FOUND__" set "RUN_DIR="
)

if defined RUN_DIR (
  for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$statusFile = Join-Path '%RUN_DIR%' 'execution_status.csv'; if (-not (Test-Path -LiteralPath $statusFile -PathType Leaf)) { Write-Output 'UNKNOWN'; exit 0 }; try { $rows = Import-Csv -LiteralPath $statusFile; if ($null -eq $rows -or $rows.Count -eq 0) { Write-Output 'UNKNOWN'; exit 0 }; $raw = [string]$rows[0].EXECUTION_STATUS; if ([string]::IsNullOrWhiteSpace($raw)) { Write-Output 'UNKNOWN'; exit 0 }; $v = $raw.Trim().ToUpperInvariant(); if ($v -eq 'SUCCESS' -or $v -eq 'OK' -or $v -eq 'COMPLETED' -or $v -eq 'RUN_VALID') { Write-Output 'SUCCESS' } elseif ($v.Contains('FAIL') -or $v.Contains('ERROR')) { Write-Output 'FAILED' } else { Write-Output 'UNKNOWN' } } catch { Write-Output 'UNKNOWN' }"`) do set "STATUS_REPORTED=%%I"
) else (
  set "STATUS_REPORTED=UNKNOWN"
)

if not defined RUN_DIR echo [MATLAB WRAPPER] WARN: No run directory could be resolved from pointer or fallback.

if not "%MATLAB_EXIT_CODE%"=="0" if not defined RUN_DIR set "FINAL_EXIT_CODE=%MATLAB_EXIT_CODE%"

:finalize
if not defined MATLAB_EXIT_CODE set "MATLAB_EXIT_CODE=NA"
if not defined RUN_DIR set "RUN_DIR=NA"
if not defined STATUS_REPORTED set "STATUS_REPORTED=UNKNOWN"

echo STATUS=!STATUS_REPORTED!
echo WRAPPER_EXIT_CODE=!FINAL_EXIT_CODE!
echo MATLAB_EXIT_CODE=!MATLAB_EXIT_CODE!
echo RUN_DIR=!RUN_DIR!

endlocal & exit /b %FINAL_EXIT_CODE%
