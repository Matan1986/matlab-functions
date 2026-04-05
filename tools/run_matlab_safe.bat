@echo off
rem Canonical MATLAB launch: matlab -batch "run('<ABSOLUTE_PATH_TO_SCRIPT.m>');"
rem (Forward slashes in SCRIPT_PATH_MATLAB; see MATLAB_COMMAND below.)
setlocal EnableExtensions

set "SCRIPT_ARG=%~1"
set "SCRIPT_PATH_RESOLVED="

if not defined SCRIPT_ARG (
  set "SCRIPT_ARG="
)

for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$p = [string]$env:SCRIPT_ARG; if ([string]::IsNullOrWhiteSpace($p)) { Write-Output ([System.IO.Path]::GetFullPath('.')) } elseif ([System.IO.Path]::IsPathRooted($p)) { Write-Output ([System.IO.Path]::GetFullPath($p)) } else { Write-Output ([System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $p))) }"`) do set "SCRIPT_PATH_RESOLVED=%%I"

if exist "%SCRIPT_PATH_RESOLVED%" (
  set "SCRIPT_EXISTS=YES"
) else (
  set "SCRIPT_EXISTS=NO"
)

set "SCRIPT_PATH_MATLAB=%SCRIPT_PATH_RESOLVED:\=/%"

set "MATLAB_COMMAND=run('%SCRIPT_PATH_MATLAB%')"

rem Pre-execution guard: do not launch MATLAB if script path is invalid (see tools/pre_execution_guard.ps1).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pre_execution_guard.ps1" "%SCRIPT_PATH_RESOLVED%"
if errorlevel 2 (
  echo PRE_EXECUTION_GUARD=FAIL
  echo FAILURE_CLASS=PRE_EXECUTION_INVALID_SCRIPT
  echo MATLAB_LAUNCHED=NO
  exit /b 2
)
echo PRE_EXECUTION_GUARD=OK

echo SCRIPT_PATH_RESOLVED=%SCRIPT_PATH_RESOLVED%
echo SCRIPT_EXISTS=%SCRIPT_EXISTS%
echo MATLAB_COMMAND_FULL=matlab -batch "%MATLAB_COMMAND%"
echo MATLAB_WHERE_START
where matlab
echo MATLAB_WHERE_END
echo BEFORE_MATLAB_CALL

matlab -batch "%MATLAB_COMMAND%"
set "MATLAB_EXIT_CODE=%ERRORLEVEL%"
echo AFTER_MATLAB_CALL

endlocal & exit /b %MATLAB_EXIT_CODE%
