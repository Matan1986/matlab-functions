# Pre-execution guard for tools/run_matlab_safe.bat (infrastructure only).
# Role: SOLE runtime gate on the wrapper path before MATLAB starts (existence + .m leaf file).
# tools/validate_matlab_runnable.ps1 does NOT duplicate these checks; it is governance/audit only.
# Exits: 0 = script path OK for MATLAB launch; 2 = PRE_EXECUTION_INVALID_SCRIPT (MATLAB must not run).
param(
    [Parameter(Mandatory = $false)]
    [string] $ScriptPath
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$logPath = Join-Path $repoRoot "tables\pre_execution_failure_log.csv"

function Write-PreExecLog {
    param(
        [string] $FailureClass,
        [string] $PathForLog,
        [string] $Note
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $p = $PathForLog.Replace('"', '""')
    $n = $Note.Replace('"', '""')
    $line = "`"$ts`",`"$FailureClass`",`"$p`",NO,NO,NO,`"$n`""
    if (-not (Test-Path -LiteralPath $logPath)) {
        $header = "timestamp,failure_class,script_path,matlab_launched,script_entered,run_dir_created,notes"
        Set-Content -LiteralPath $logPath -Value $header -Encoding ascii
    }
    Add-Content -LiteralPath $logPath -Value $line -Encoding ascii
}

if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
    Write-PreExecLog -FailureClass "PRE_EXECUTION_INVALID_SCRIPT" -PathForLog "" -Note "empty_or_missing_script_argument"
    [Console]::Error.WriteLine("PRE_EXECUTION_INVALID_SCRIPT: empty script path")
    exit 2
}

try {
    $full = [System.IO.Path]::GetFullPath($ScriptPath)
}
catch {
    Write-PreExecLog -FailureClass "PRE_EXECUTION_INVALID_SCRIPT" -PathForLog $ScriptPath -Note "path_resolution_failed"
    [Console]::Error.WriteLine("PRE_EXECUTION_INVALID_SCRIPT: path resolution failed")
    exit 2
}

if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    Write-PreExecLog -FailureClass "PRE_EXECUTION_INVALID_SCRIPT" -PathForLog $full -Note "file_not_found"
    [Console]::Error.WriteLine("PRE_EXECUTION_INVALID_SCRIPT: file not found: $full")
    exit 2
}

if (-not $full.EndsWith(".m", [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-PreExecLog -FailureClass "PRE_EXECUTION_INVALID_SCRIPT" -PathForLog $full -Note "not_m_file_extension"
    [Console]::Error.WriteLine("PRE_EXECUTION_INVALID_SCRIPT: not a .m file: $full")
    exit 2
}

exit 0
