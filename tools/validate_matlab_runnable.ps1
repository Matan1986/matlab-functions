[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ScriptPath
)

$ErrorActionPreference = "Stop"
$script:ValidatorPrefix = "[MATLAB RUNNABLE VALIDATOR]"
$script:Failures = New-Object System.Collections.Generic.List[string]

$ValidStates = @(
    "transitional",
    "canonical",
    "legacy_allowed",
    "legacy_blocked"
)

function AddFailure {
    param(
        [string]$Code,
        [string]$Message
    )
    $script:Failures.Add("${Code}: $Message")
}

function FailValidation {
    param([System.Collections.Generic.List[string]]$Failures)
    Write-Output "$script:ValidatorPrefix RESULT = FAIL"
    foreach ($failure in $Failures) {
        Write-Output "$script:ValidatorPrefix REASON = $failure"
    }
    exit 1
}

function Get-RepoRoot {
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Read-RepoValidatorState {
    param([string]$RepoRoot)

    $path = Join-Path $RepoRoot "docs\repo_state.md"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return "canonical"
    }
    try {
        $lines = Get-Content -LiteralPath $path -Encoding UTF8
    }
    catch {
        return "canonical"
    }
    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t.Length -eq 0 -or $t.StartsWith("#")) {
            continue
        }
        if ($t -match '^\s*VALIDATOR_STATE\s*=\s*(\S+)') {
            $cand = $Matches[1].Trim().ToLowerInvariant()
            if ($script:ValidStates -contains $cand) {
                return $cand
            }
        }
        $lower = $t.ToLowerInvariant()
        foreach ($vs in $script:ValidStates) {
            if ($lower -eq $vs -or $lower -eq "`"$vs`"" -or $lower -eq "'$vs'") {
                return $vs
            }
        }
    }
    return "canonical"
}

function EmitStructuredVerdictLine {
    param(
        [string]$Key,
        [ValidateSet("PASS", "WARN", "FAIL")]
        [string]$Status
    )
    Write-Output "${Key}=${Status}"
}

if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
    AddFailure -Code "INPUT_EMPTY" -Message "No runnable script path was provided."
    FailValidation -Failures $script:Failures
}

$repoRoot = Get-RepoRoot
$repoRootWithSeparator = $repoRoot
if (-not $repoRootWithSeparator.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
    $repoRootWithSeparator += [System.IO.Path]::DirectorySeparatorChar
}

$validatorState = Read-RepoValidatorState -RepoRoot $repoRoot

$fileExists = $false
try {
    $fileExists = Test-Path -LiteralPath $ScriptPath -PathType Leaf
}
catch {
    $fileExists = $false
}

$isAbsolutePath = [System.IO.Path]::IsPathRooted($ScriptPath)

$resolvedScriptPath = $null
$resolvedForDisplay = $ScriptPath
if ($fileExists) {
    try {
        $resolvedScriptPath = (Resolve-Path -LiteralPath $ScriptPath).ProviderPath
        $resolvedForDisplay = $resolvedScriptPath
    }
    catch {
        AddFailure -Code "PATH_RESOLUTION_FAILED" -Message "Unable to resolve runnable script path '$ScriptPath'."
    }
}

$repoCheckPath = $null
if ($resolvedScriptPath) {
    $repoCheckPath = [System.IO.Path]::GetFullPath($resolvedScriptPath)
}
else {
    try {
        $repoCheckPath = [System.IO.Path]::GetFullPath($ScriptPath)
    }
    catch {
        $repoCheckPath = $null
    }
}

$isUnderRepoRoot = $false
if ($repoCheckPath) {
    $isUnderRepoRoot =
        $repoCheckPath.StartsWith($repoRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase) -or
        $repoCheckPath.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

$hasMExtension = $false
$extensionTarget = if ($resolvedScriptPath) { $resolvedScriptPath } else { $ScriptPath }
if (-not [string]::IsNullOrWhiteSpace($extensionTarget)) {
    $hasMExtension = ([System.IO.Path]::GetExtension($extensionTarget).ToLowerInvariant() -eq ".m")
}

$rawBytes = $null
$fileText = $null
$allLines = @()
$canInspectContent = $false
if ($fileExists -and $resolvedScriptPath) {
    try {
        $rawBytes = [System.IO.File]::ReadAllBytes($resolvedScriptPath)
        $fileText = [System.IO.File]::ReadAllText($resolvedScriptPath, [System.Text.Encoding]::UTF8)
        $allLines = [System.IO.File]::ReadAllLines($resolvedScriptPath, [System.Text.Encoding]::UTF8)
        $canInspectContent = $true
    }
    catch {
        AddFailure -Code "FILE_READ_FAILED" -Message "Unable to read runnable script '$resolvedScriptPath'. $_"
    }
}

$nonAsciiCount = -1
$isAsciiOnly = $false
if ($canInspectContent) {
    $nonAsciiCount = ($rawBytes | Where-Object { $_ -gt 127 }).Count
    $isAsciiOnly = ($nonAsciiCount -eq 0)
}

$hasBom = $false
if ($canInspectContent -and $rawBytes.Length -ge 3) {
    if ($rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF) {
        $hasBom = $true
    }
}
if ($canInspectContent -and -not $hasBom -and $rawBytes.Length -ge 2) {
    if (
        ($rawBytes[0] -eq 0xFF -and $rawBytes[1] -eq 0xFE) -or
        ($rawBytes[0] -eq 0xFE -and $rawBytes[1] -eq 0xFF)
    ) {
        $hasBom = $true
    }
}

$zeroWidthRegex = [regex]'[\u200B-\u200D\u2060\uFEFF]'
$zeroWidthMatch = if ($canInspectContent) { $zeroWidthRegex.Match($fileText) } else { $null }
$hasZeroWidthChars = $zeroWidthMatch -and $zeroWidthMatch.Success
$asciiSafe = $canInspectContent -and $isAsciiOnly -and (-not $hasBom) -and (-not $hasZeroWidthChars)

$firstExecutableLineNumber = -1
$firstExecutableLine = $null
if ($canInspectContent) {
    for ($i = 0; $i -lt $allLines.Count; $i++) {
        $line = $allLines[$i]
        if ($line -match '^\s*$') { continue }
        if ($line -match '^\s*%') { continue }
        $firstExecutableLineNumber = $i + 1
        $firstExecutableLine = $line.Trim()
        break
    }
}

$hasRequiredHeader = ($firstExecutableLine -eq "clear; clc;")

$forbiddenFunctionLines = New-Object System.Collections.Generic.List[int]
if ($canInspectContent) {
    for ($i = 0; $i -lt $allLines.Count; $i++) {
        if ($allLines[$i] -match '^\s*function\b') {
            $forbiddenFunctionLines.Add($i + 1)
        }
    }
}
$hasNoFunctions = ($forbiddenFunctionLines.Count -eq 0)

$hasCreateRunContext = $false
if ($canInspectContent) {
    $hasCreateRunContext = $fileText -match '(?i)\bcreateRunContext\s*\('
}

$legacyGlobalOutput = $false
if ($canInspectContent) {
    if ($fileText -match 'tables/') { $legacyGlobalOutput = $true }
    if ($fileText -match 'reports/') { $legacyGlobalOutput = $true }
    if ($fileText -match 'figures/') { $legacyGlobalOutput = $true }
}

$directMatlabInvocation = $false
if ($canInspectContent) {
    if ($fileText -match '(?i)\bmatlab(\.exe)?\b[^\r\n]*\-batch\b') { $directMatlabInvocation = $true }
    if ($fileText -match '(?i)\bmatlab(\.exe)?\b[^\r\n]*\-r\b') { $directMatlabInvocation = $true }
}

# --- CANONICAL RULE: NO INTERACTIVE FUNCTIONS ---
$forbiddenInteractiveFunctions = @()
if ($canInspectContent) {
    # Check for input() function (user input)
    if ($fileText -match '(?i)\binput\s*\(') {
        $forbiddenInteractiveFunctions += "input("
    }
    # Check for uiwait (UI blocking)
    if ($fileText -match '(?i)\buiwait\b') {
        $forbiddenInteractiveFunctions += "uiwait"
    }
    # Check for questdlg (dialog box)
    if ($fileText -match '(?i)\bquestdlg\b') {
        $forbiddenInteractiveFunctions += "questdlg"
    }
}
$hasNoInteractive = ($forbiddenInteractiveFunctions.Count -eq 0)

# --- CANONICAL RULE: NO DEBUG/RETRY PATTERNS ---
$forbiddenDebugPatterns = @()
if ($canInspectContent) {
    # Check for debug breakpoints
    if ($fileText -match '(?i)\bdbstop\b|\bdbclear\b|\bdbquit\b|\bkeyboard\b') {
        $forbiddenDebugPatterns += "debug breakpoint"
    }
    # Check for warning suppression
    if ($fileText -match '(?i)\bwarning\s*\(\s*[''"]off[''"]') {
        $forbiddenDebugPatterns += "warning suppression"
    }
}
$hasNoDebugPatterns = ($forbiddenDebugPatterns.Count -eq 0)

# --- CANONICAL RULE: NO SILENT CATCH (try/catch MUST rethrow) ---
$hasSilentCatch = $false
if ($canInspectContent) {
    # Check if script has catch blocks without rethrow (silent failures)
    if ($fileText -match '(?i)\bcatch\b') {
        # If catch exists, must also have rethrow to be valid
        if (-not ($fileText -match '(?i)\brethrow\b')) {
            $hasSilentCatch = $true
        }
    }
}
$hasNoSilentCatch = (-not $hasSilentCatch)

# --- CANONICAL RULE: NO FALLBACK LOGIC ---
$hasFallbackLogic = $false
if ($canInspectContent) {
    # Check for if-exist patterns that skip errors
    if ($fileText -match '(?i)(if\s+exist|if\s+isfile|if\s+isfolder).*skip\b') {
        $hasFallbackLogic = $true
    }
    # Check for catch-continue-return patterns
    if ($fileText -match '(?i)catch.*return\b') {
        $hasFallbackLogic = $true
    }
    # Check for fallback assignments or defaults
    if ($fileText -match '(?i)(result\s*=|output\s*=).*\[\]|(result\s*=|output\s*=).*empty') {
        $hasFallbackLogic = $true
    }
}
$hasNoFallback = (-not $hasFallbackLogic)

# --- CANONICAL RULE: REQUIRED OUTPUT ARTIFACTS ---
$writsExecutionStatus = $false
$writesOutputTable = $false
if ($canInspectContent) {
    # Check if script writes execution_status.csv
    if ($fileText -match '(?i)execution_status' -or $fileText -match '(?i)writetable.*status\b' -or $fileText -match '(?i)writecsv.*execution') {
        $writsExecutionStatus = $true
    }
    # Check if script writes result/output tables (via writetable, writematrix, or table assignments to CSV)
    if ($fileText -match '(?i)writetable\b.*\.csv' -or $fileText -match '(?i)writematrix\b' -or $fileText -match '(?i)\.csv' -or $fileText -match '(?i)writetable\b') {
        $writesOutputTable = $true
    }
}
$hasRequiredOutputs = ($writsExecutionStatus -and $writesOutputTable)

# --- DRIFT CHECK: OUTPUT FILE CONSISTENCY ---
$writesMarkdownOutput = $false
$hasNoExtraFileTypes = $true
if ($canInspectContent) {
    # Check if script writes markdown output files
    if ($fileText -match '(?i)\.md\b' -or $fileText -match '(?i)writetable.*\.md' -or $fileText -match '(?i)report') {
        $writesMarkdownOutput = $true
    }
    # Check for extra unexpected file type patterns (beyond CSV, MD, and allowed metadata)
    # Allowed: .csv, .md, .mat, .json (metadata)
    # Forbidden extra types in output context: .txt (unless metadata), .log, .dat, .bin, etc.
    if ($canInspectContent) {
        # Check for unexpected file outputs that suggest drift (extra file types)
        if ($fileText -match '(?i)fopen\b.*[''"].*\.(txt|dat|bin|log)[''"]' -or 
            $fileText -match '(?i)writefile\b' -or 
            $fileText -match '(?i)saveas\b.*fig\b') {
            $hasNoExtraFileTypes = $false
        }
    }
}
$checkDriftPass = ($writsExecutionStatus -and $writesOutputTable -and $writesMarkdownOutput -and $hasNoExtraFileTypes)

# --- Derive CHECK_* statuses per state ---
$checkAscii = "FAIL"
if (-not $canInspectContent) {
    $checkAscii = "FAIL"
}
elseif ($asciiSafe) {
    $checkAscii = "PASS"
}

$checkHeader = "FAIL"
if ($canInspectContent -and $hasRequiredHeader) {
    $checkHeader = "PASS"
}
elseif (-not $canInspectContent) {
    $checkHeader = "FAIL"
}

$checkFunction = "FAIL"
if ($canInspectContent -and $hasNoFunctions) {
    $checkFunction = "PASS"
}
elseif (-not $canInspectContent) {
    $checkFunction = "FAIL"
}

$checkRunContext = "FAIL"
if ($canInspectContent) {
    if ($hasCreateRunContext) {
        $checkRunContext = "PASS"
    }
    else {
        if ($validatorState -eq "transitional") {
            $checkRunContext = "WARN"
        }
        elseif ($validatorState -eq "legacy_allowed") {
            $checkRunContext = "WARN"
        }
        else {
            $checkRunContext = "FAIL"
        }
    }
}

$checkDrift = if ($checkDriftPass) { "PASS" } else { "FAIL" }

Write-Output "VALIDATOR_STATE=$validatorState"
EmitStructuredVerdictLine -Key "CHECK_ASCII" -Status $checkAscii
EmitStructuredVerdictLine -Key "CHECK_HEADER" -Status $checkHeader
EmitStructuredVerdictLine -Key "CHECK_FUNCTION" -Status $checkFunction
EmitStructuredVerdictLine -Key "CHECK_RUN_CONTEXT" -Status $checkRunContext
EmitStructuredVerdictLine -Key "CHECK_DRIFT" -Status $checkDrift

# --- CANONICAL RULE VERDICTS ---
$checkInteractive = if ($hasNoInteractive) { "PASS" } else { "FAIL" }
$checkDebugPatterns = if ($hasNoDebugPatterns) { "PASS" } else { "FAIL" }
$checkSilentCatch = if ($hasNoSilentCatch) { "PASS" } else { "FAIL" }
$checkFallback = if ($hasNoFallback) { "PASS" } else { "FAIL" }
$checkOutputs = if ($hasRequiredOutputs) { "PASS" } else { "FAIL" }

if ($validatorState -eq "canonical") {
    EmitStructuredVerdictLine -Key "CHECK_NO_INTERACTIVE" -Status $checkInteractive
    EmitStructuredVerdictLine -Key "CHECK_NO_DEBUG" -Status $checkDebugPatterns
    EmitStructuredVerdictLine -Key "CHECK_NO_SILENT_CATCH" -Status $checkSilentCatch
    EmitStructuredVerdictLine -Key "CHECK_NO_FALLBACK" -Status $checkFallback
    EmitStructuredVerdictLine -Key "CHECK_REQUIRED_OUTPUTS" -Status $checkOutputs
    EmitStructuredVerdictLine -Key "CHECK_DRIFT" -Status $checkDrift
}

# --- Preconditions (always block) ---
if (-not $fileExists) {
    AddFailure -Code "FILE_NOT_FOUND" -Message "Runnable script not found at path '$ScriptPath'."
}
if (-not $isAbsolutePath) {
    AddFailure -Code "PATH_NOT_ABSOLUTE" -Message "Runnable script path must be absolute. Received '$ScriptPath'."
}
if (-not $isUnderRepoRoot) {
    $pathForMessage = if ($repoCheckPath) { $repoCheckPath } else { $resolvedForDisplay }
    AddFailure -Code "PATH_OUTSIDE_REPO_ROOT" -Message "Runnable script must be under repo root '$repoRoot'. Resolved path '$pathForMessage'."
}
if (-not $hasMExtension) {
    AddFailure -Code "INVALID_EXTENSION" -Message "Runnable script must use .m extension. Resolved path '$extensionTarget'."
}
if (-not $canInspectContent -and $fileExists -and $resolvedScriptPath) {
    AddFailure -Code "CONTENT_UNREADABLE" -Message "Cannot read script content for validation."
}

$safetyFail = ($checkAscii -eq "FAIL") -or ($checkHeader -eq "FAIL") -or ($checkFunction -eq "FAIL")

$canonicalFail = $false
if ($validatorState -eq "canonical") {
    $canonicalFail = $safetyFail
    if ($checkRunContext -eq "FAIL") { $canonicalFail = $true }
    if ($directMatlabInvocation) { $canonicalFail = $true }
    # CANONICAL ENFORCEMENT: Strict ruleset
    if ($checkInteractive -eq "FAIL") { $canonicalFail = $true }
    if ($checkDebugPatterns -eq "FAIL") { $canonicalFail = $true }
    if ($checkSilentCatch -eq "FAIL") { $canonicalFail = $true }
    if ($checkFallback -eq "FAIL") { $canonicalFail = $true }
    if ($checkOutputs -eq "FAIL") { $canonicalFail = $true }
    if ($checkDrift -eq "FAIL") { $canonicalFail = $true }
}

$legacyAllowedFail = $safetyFail

$legacyBlockedFail = $false
if ($validatorState -eq "legacy_blocked") {
    $legacyBlockedFail = $safetyFail
    if ($legacyGlobalOutput) { $legacyBlockedFail = $true }
    if ($directMatlabInvocation) { $legacyBlockedFail = $true }
    if (-not $hasCreateRunContext) { $legacyBlockedFail = $true }
}

$block = $false
switch ($validatorState) {
    "transitional" {
        if ($safetyFail) { $block = $true }
        if ($script:Failures.Count -gt 0) { $block = $true }
    }
    "canonical" {
        if ($canonicalFail) { $block = $true }
        if ($script:Failures.Count -gt 0) { $block = $true }
    }
    "legacy_allowed" {
        if ($legacyAllowedFail) { $block = $true }
        if ($script:Failures.Count -gt 0) { $block = $true }
    }
    "legacy_blocked" {
        if ($legacyBlockedFail) { $block = $true }
        if ($script:Failures.Count -gt 0) { $block = $true }
    }
    default {
        if ($safetyFail) { $block = $true }
        if ($script:Failures.Count -gt 0) { $block = $true }
    }
}

# Add detailed failures when blocking (state-specific)
if ($validatorState -eq "canonical" -and $block -and $script:Failures.Count -eq 0) {
    if ($checkAscii -eq "FAIL") { AddFailure -Code "CHECK_ASCII" -Message "ASCII/BOM/zero-width safety violation." }
    if ($checkHeader -eq "FAIL") { AddFailure -Code "CHECK_HEADER" -Message "First executable line must be exactly 'clear; clc;'." }
    if ($checkFunction -eq "FAIL") { AddFailure -Code "CHECK_FUNCTION" -Message "Runnable script must be a pure script (no function definitions)." }
    if ($checkRunContext -eq "FAIL") { AddFailure -Code "CHECK_RUN_CONTEXT" -Message "Script must call createRunContext." }
    if ($directMatlabInvocation) { AddFailure -Code "WRAPPER_REQUIRED" -Message "Direct MATLAB invocation is forbidden; use tools/run_matlab_safe.bat." }
    # CANONICAL ENFORCEMENT: Strict ruleset
    if ($checkInteractive -eq "FAIL") { AddFailure -Code "NO_INTERACTIVE" -Message "Script contains forbidden interactive functions: $($forbiddenInteractiveFunctions -join ', '). Forbid: input(, uiwait, questdlg." }
    if ($checkDebugPatterns -eq "FAIL") { AddFailure -Code "NO_DEBUG" -Message "Script contains debug/retry patterns: $($forbiddenDebugPatterns -join ', '). Forbid: dbstop, keyboard, warning suppression." }
    if ($checkSilentCatch -eq "FAIL") { AddFailure -Code "NO_SILENT_CATCH" -Message "catch block without rethrow is forbidden (silent failure not allowed). Use: catch ME; rethrow(ME); end" }
    if ($checkFallback -eq "FAIL") { AddFailure -Code "NO_FALLBACK" -Message "Script contains fallback logic or error suppression. Must FAIL HARD, no retry or fallback." }
    if ($checkOutputs -eq "FAIL") { AddFailure -Code "REQUIRED_OUTPUTS" -Message "Script must write execution_status.csv and at least one CSV result table. Use writetable() or writematrix()." }
    if ($checkDrift -eq "FAIL") { AddFailure -Code "CHECK_DRIFT" -Message "ERROR: output mismatch between expected and actual files. Script must write execution_status.csv, at least one CSV, and at least one MD file with no extra unexpected file types." }
}

if ($validatorState -eq "legacy_blocked" -and $block -and $script:Failures.Count -eq 0) {
    if ($checkAscii -eq "FAIL") { AddFailure -Code "CHECK_ASCII" -Message "ASCII/BOM/zero-width safety violation." }
    if ($checkHeader -eq "FAIL") { AddFailure -Code "CHECK_HEADER" -Message "First executable line must be exactly 'clear; clc;'." }
    if ($checkFunction -eq "FAIL") { AddFailure -Code "CHECK_FUNCTION" -Message "Runnable script must be a pure script (no function definitions)." }
    if ($legacyGlobalOutput) { AddFailure -Code "LEGACY_PATH" -Message "Legacy global output path literals detected." }
    if ($directMatlabInvocation) { AddFailure -Code "NON_WRAPPER" -Message "Non-wrapper MATLAB execution forbidden." }
    if (-not $hasCreateRunContext) { AddFailure -Code "RUN_CONTEXT" -Message "createRunContext required." }
}

if ($validatorState -eq "transitional" -and $block) {
    if ($checkAscii -eq "FAIL" -and $script:Failures.Count -eq 0) {
        AddFailure -Code "CHECK_ASCII" -Message "ASCII/BOM/zero-width safety violation."
    }
    if ($checkHeader -eq "FAIL" -and $script:Failures.Count -eq 0) {
        AddFailure -Code "CHECK_HEADER" -Message "First executable line must be exactly 'clear; clc;'."
    }
    if ($checkFunction -eq "FAIL" -and $script:Failures.Count -eq 0) {
        AddFailure -Code "CHECK_FUNCTION" -Message "Runnable script must be a pure script (no function definitions)."
    }
}

# Transitional: optional WARN lines (do not fail)
if ($validatorState -eq "transitional") {
    if ($checkRunContext -eq "WARN") {
        Write-Output "$script:ValidatorPrefix WARN CHECK_RUN_CONTEXT missing createRunContext"
    }
    if ($legacyGlobalOutput) {
        Write-Output "$script:ValidatorPrefix WARN LEGACY_OUTPUT_PATH tables/ or reports/ or figures/ in script text"
    }
}

if ($validatorState -eq "legacy_allowed") {
    if ($checkRunContext -eq "WARN") {
        Write-Output "$script:ValidatorPrefix WARN CHECK_RUN_CONTEXT missing createRunContext"
    }
    if ($legacyGlobalOutput) { Write-Output "$script:ValidatorPrefix WARN LEGACY_OUTPUT_PATH" }
    if ($directMatlabInvocation) { Write-Output "$script:ValidatorPrefix WARN DIRECT_MATLAB_INVOCATION" }
}

if (-not $block -and $script:Failures.Count -eq 0) {
    Write-Output "$script:ValidatorPrefix RESULT = PASS"
    Write-Output "$script:ValidatorPrefix OK: $resolvedForDisplay"
    exit 0
}

if ($script:Failures.Count -eq 0 -and $block) {
    AddFailure -Code "STATE_VALIDATION" -Message "Validator state '$validatorState' requirements not met."
}

FailValidation -Failures $script:Failures
