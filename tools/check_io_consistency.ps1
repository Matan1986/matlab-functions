[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptFilePath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptFilePath)) {
        $scriptFilePath = $MyInvocation.MyCommand.Path
    }
    if ([string]::IsNullOrWhiteSpace($scriptFilePath)) {
        throw 'Cannot infer RepoRoot automatically. Provide -RepoRoot explicitly.'
    }

    $scriptFilePath = (Resolve-Path -LiteralPath $scriptFilePath).Path
    $probeDir = Split-Path -Parent $scriptFilePath
    while (-not [string]::IsNullOrWhiteSpace($probeDir)) {
        $hasRepoRules = Test-Path -LiteralPath (Join-Path $probeDir 'docs\repo_execution_rules.md')
        $hasReadme = Test-Path -LiteralPath (Join-Path $probeDir 'README.md')
        if ($hasRepoRules -or $hasReadme) {
            $RepoRoot = $probeDir
            break
        }

        $parent = Split-Path -Parent $probeDir
        if ($parent -eq $probeDir) {
            break
        }
        $probeDir = $parent
    }

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Get-Location).Path
    }
}

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function ConvertTo-UtcDateTime {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    $s = [string]$Value
    if ([string]::IsNullOrWhiteSpace($s)) {
        return $null
    }

    $dt = $null
    if ([datetime]::TryParse($s, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$dt)) {
        return $dt.ToUniversalTime()
    }

    if ([datetime]::TryParse($s, [ref]$dt)) {
        return $dt.ToUniversalTime()
    }

    return $null
}

function Get-RunIdFromPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $m = [regex]::Match($Path, 'run_\d{4}_\d{2}_\d{2}_\d{6}_[^\\/]+', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        return $m.Value
    }

    return $null
}

function Get-RunIdTimestamp {
    param(
        [AllowNull()]
        [string]$RunId
    )

    if ([string]::IsNullOrWhiteSpace($RunId)) {
        return $null
    }

    $m = [regex]::Match($RunId, '^run_(\d{4})_(\d{2})_(\d{2})_(\d{6})_')
    if (-not $m.Success) {
        return $null
    }

    $stamp = '{0}-{1}-{2} {3}:{4}:{5}' -f `
        $m.Groups[1].Value,
        $m.Groups[2].Value,
        $m.Groups[3].Value,
        $m.Groups[4].Value.Substring(0, 2),
        $m.Groups[4].Value.Substring(2, 2),
        $m.Groups[4].Value.Substring(4, 2)

    $dt = $null
    if ([datetime]::TryParseExact($stamp, 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeLocal, [ref]$dt)) {
        return $dt.ToUniversalTime()
    }

    return $null
}

function Add-OutputCandidate {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[string]]$Collector,
        [AllowNull()]
        [object]$Candidate,
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    if ($null -eq $Candidate) {
        return
    }

    if ($Candidate -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Candidate)) {
            return
        }

        $text = $Candidate.Trim()
        if ($text -match '^(https?|s3)://') {
            return
        }

        $abs = Resolve-AbsolutePath -Path $text -BasePath $BasePath
        if (-not $Collector.Contains($abs)) {
            [void]$Collector.Add($abs)
        }
        return
    }

    if ($Candidate -is [System.Collections.IEnumerable] -and -not ($Candidate -is [string])) {
        foreach ($entry in $Candidate) {
            Add-OutputCandidate -Collector $Collector -Candidate $entry -BasePath $BasePath
        }
        return
    }

    if ($Candidate.PSObject -and $Candidate.PSObject.Properties) {
        $pathLikeKeys = @('path', 'file', 'filepath', 'output', 'output_path', 'relative_path', 'absolute_path')
        foreach ($key in $pathLikeKeys) {
            if ($Candidate.PSObject.Properties.Name -contains $key) {
                Add-OutputCandidate -Collector $Collector -Candidate $Candidate.$key -BasePath $BasePath
            }
        }
    }
}

function Get-ManifestExecutionStart {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Manifest
    )

    if ($Manifest.PSObject.Properties.Name -contains 'execution_start') {
        return (ConvertTo-UtcDateTime -Value $Manifest.execution_start)
    }

    return $null
}

function Get-ManifestOutputFiles {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Manifest,
        [Parameter(Mandatory = $true)]
        [string]$ManifestDirectory,
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath
    )

    $collector = New-Object 'System.Collections.Generic.List[string]'

    $topKeys = @('output_files', 'outputs', 'output_paths', 'expected_outputs', 'files_written', 'artifacts')
    foreach ($key in $topKeys) {
        if ($Manifest.PSObject.Properties.Name -contains $key) {
            Add-OutputCandidate -Collector $collector -Candidate $Manifest.$key -BasePath $RepoRootPath
        }
    }

    if ($Manifest.PSObject.Properties.Name -contains 'run') {
        $runObj = $Manifest.run
        if ($null -ne $runObj -and $runObj.PSObject) {
            foreach ($key in $topKeys) {
                if ($runObj.PSObject.Properties.Name -contains $key) {
                    Add-OutputCandidate -Collector $collector -Candidate $runObj.$key -BasePath $RepoRootPath
                }
            }
        }
    }

    if ($Manifest.PSObject.Properties.Name -contains 'io') {
        $ioObj = $Manifest.io
        if ($null -ne $ioObj -and $ioObj.PSObject) {
            foreach ($key in $topKeys) {
                if ($ioObj.PSObject.Properties.Name -contains $key) {
                    Add-OutputCandidate -Collector $collector -Candidate $ioObj.$key -BasePath $RepoRootPath
                }
            }
        }
    }

    if ($collector.Count -eq 0) {
        $hintKeys = @('report_path', 'report', 'status_path', 'status_file', 'csv_path', 'output_file')
        foreach ($key in $hintKeys) {
            if ($Manifest.PSObject.Properties.Name -contains $key) {
                Add-OutputCandidate -Collector $collector -Candidate $Manifest.$key -BasePath $ManifestDirectory
            }
        }
    }

    return $collector.ToArray()
}

function Get-RepoRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    $baseUri = [uri](([System.IO.Path]::GetFullPath($BasePath)).TrimEnd('\\') + '\\')
    $targetUri = [uri][System.IO.Path]::GetFullPath($TargetPath)
    return [uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\\')
}

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifest file not found: $ManifestPath"
}

$repoRootFull = [System.IO.Path]::GetFullPath($RepoRoot)
$manifestFull = [System.IO.Path]::GetFullPath($ManifestPath)
$manifestDir = Split-Path -Parent $manifestFull

$manifestRaw = Get-Content -LiteralPath $manifestFull -Raw
if ([string]::IsNullOrWhiteSpace($manifestRaw)) {
    throw "Manifest file is empty: $manifestFull"
}

$manifest = $manifestRaw | ConvertFrom-Json

$runId = $null
if ($manifest.PSObject.Properties.Name -contains 'run_id') {
    $runId = [string]$manifest.run_id
}
elseif ($manifest.PSObject.Properties.Name -contains 'run' -and $manifest.run -and $manifest.run.PSObject.Properties.Name -contains 'run_id') {
    $runId = [string]$manifest.run.run_id
}

$executionStartUtc = Get-ManifestExecutionStart -Manifest $manifest
$hasExecutionStartFromManifest = ($null -ne $executionStartUtc)
$outputFiles = @(Get-ManifestOutputFiles -Manifest $manifest -ManifestDirectory $manifestDir -RepoRootPath $repoRootFull)

$existingCount = 0
$staleCount = 0
$reusedFromPreviousRunCount = 0
$duplicatePathCount = 0

$missingFiles = New-Object 'System.Collections.Generic.List[string]'
$staleFiles = New-Object 'System.Collections.Generic.List[string]'
$reusedFiles = New-Object 'System.Collections.Generic.List[string]'
$duplicateFiles = New-Object 'System.Collections.Generic.List[string]'

$seenPaths = @{}
$runIdSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

foreach ($file in $outputFiles) {
    $normalized = [System.IO.Path]::GetFullPath($file)

    if ($seenPaths.ContainsKey($normalized)) {
        $duplicatePathCount += 1
        if (-not $duplicateFiles.Contains($normalized)) {
            [void]$duplicateFiles.Add($normalized)
        }
    }
    else {
        $seenPaths[$normalized] = $true
    }

    $pathRunId = Get-RunIdFromPath -Path $normalized
    if (-not [string]::IsNullOrWhiteSpace($pathRunId)) {
        [void]$runIdSet.Add($pathRunId)
    }

    if (-not (Test-Path -LiteralPath $normalized -PathType Leaf)) {
        [void]$missingFiles.Add($normalized)
        continue
    }

    $existingCount += 1

    $lastWriteUtc = (Get-Item -LiteralPath $normalized).LastWriteTimeUtc
    if ($null -ne $executionStartUtc -and $lastWriteUtc -lt $executionStartUtc) {
        $staleCount += 1
        [void]$staleFiles.Add($normalized)
    }

    if ($null -ne $executionStartUtc) {
        $runTime = Get-RunIdTimestamp -RunId $pathRunId
        if ($null -ne $runTime -and $runTime -lt $executionStartUtc) {
            $reusedFromPreviousRunCount += 1
            [void]$reusedFiles.Add($normalized)
        }
    }
}

if ($runIdSet.Count -gt 1) {
    $duplicatePathCount += $runIdSet.Count - 1
}

$outputsExist = ($outputFiles.Count -gt 0 -and $missingFiles.Count -eq 0)
$noStaleOutputs = ($staleCount -eq 0 -and $reusedFromPreviousRunCount -eq 0)
$noDuplicates = ($duplicatePathCount -eq 0)
$consistentRun = ($outputsExist -and $noStaleOutputs -and $noDuplicates -and $hasExecutionStartFromManifest)

$verdictOutputsExist = if ($outputsExist) { 'YES' } else { 'NO' }
$verdictNoStale = if ($noStaleOutputs) { 'YES' } else { 'NO' }
$verdictNoDuplicates = if ($noDuplicates) { 'YES' } else { 'NO' }
$verdictConsistent = if ($consistentRun) { 'YES' } else { 'NO' }

$reportDir = Join-Path $repoRootFull 'reports'
if (-not (Test-Path -LiteralPath $reportDir -PathType Container)) {
    New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
}

$reportStamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$reportPath = Join-Path $reportDir ("io_consistency_{0}.md" -f $reportStamp)
$reportPathForOutput = (Join-Path 'reports' ([System.IO.Path]::GetFileName($reportPath))).Replace('\', '/')

$detail = New-Object 'System.Collections.Generic.List[string]'
$detail.Add('# IO Consistency Report') | Out-Null
$detail.Add('') | Out-Null
$detail.Add("- generated_at_utc: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))") | Out-Null
$detail.Add("- manifest: $(Get-RepoRelativePath -BasePath $repoRootFull -TargetPath $manifestFull)") | Out-Null
$detail.Add("- outputs_declared: $($outputFiles.Count)") | Out-Null
$detail.Add("- outputs_found: $existingCount") | Out-Null
$detail.Add("- execution_start_utc: $(if ($executionStartUtc) { $executionStartUtc.ToString('yyyy-MM-ddTHH:mm:ssZ') } else { 'UNKNOWN' })") | Out-Null
$detail.Add('') | Out-Null
$detail.Add('## Verdicts') | Out-Null
$detail.Add('') | Out-Null
$detail.Add("OUTPUTS_EXIST=$verdictOutputsExist") | Out-Null
$detail.Add("NO_STALE_OUTPUTS=$verdictNoStale") | Out-Null
$detail.Add("NO_DUPLICATES=$verdictNoDuplicates") | Out-Null
$detail.Add("CONSISTENT_RUN=$verdictConsistent") | Out-Null
$detail.Add('execution_start_source=manifest') | Out-Null
$detail.Add('manifest_used_as_truth=YES') | Out-Null
$detail.Add('USES_MANIFEST_AS_SOURCE=YES') | Out-Null
$detail.Add('NO_INDEPENDENT_TRUTH=YES') | Out-Null
$detail.Add('') | Out-Null

if ($missingFiles.Count -gt 0) {
    $detail.Add('## Missing Outputs') | Out-Null
    $detail.Add('') | Out-Null
    foreach ($item in $missingFiles) {
        $detail.Add("- $(Get-RepoRelativePath -BasePath $repoRootFull -TargetPath $item)") | Out-Null
    }
    $detail.Add('') | Out-Null
}

if ($staleFiles.Count -gt 0) {
    $detail.Add('## Stale Outputs') | Out-Null
    $detail.Add('') | Out-Null
    foreach ($item in $staleFiles) {
        $detail.Add("- $(Get-RepoRelativePath -BasePath $repoRootFull -TargetPath $item)") | Out-Null
    }
    $detail.Add('') | Out-Null
}

if ($reusedFiles.Count -gt 0) {
    $detail.Add('## Reused Previous-Run Outputs') | Out-Null
    $detail.Add('') | Out-Null
    foreach ($item in $reusedFiles) {
        $detail.Add("- $(Get-RepoRelativePath -BasePath $repoRootFull -TargetPath $item)") | Out-Null
    }
    $detail.Add('') | Out-Null
}

if ($duplicateFiles.Count -gt 0) {
    $detail.Add('## Duplicate Output Paths') | Out-Null
    $detail.Add('') | Out-Null
    foreach ($item in $duplicateFiles) {
        $detail.Add("- $(Get-RepoRelativePath -BasePath $repoRootFull -TargetPath $item)") | Out-Null
    }
    $detail.Add('') | Out-Null
}

Set-Content -LiteralPath $reportPath -Value ($detail -join "`r`n") -Encoding ASCII

Write-Output ("OUTPUTS_EXIST={0}" -f $verdictOutputsExist)
Write-Output ("NO_STALE_OUTPUTS={0}" -f $verdictNoStale)
Write-Output ("NO_DUPLICATES={0}" -f $verdictNoDuplicates)
Write-Output ("CONSISTENT_RUN={0}" -f $verdictConsistent)
Write-Output ('execution_start_source=manifest')
Write-Output ('manifest_used_as_truth=YES')
Write-Output ('USES_MANIFEST_AS_SOURCE=YES')
Write-Output ('NO_INDEPENDENT_TRUTH=YES')
Write-Output ("REPORT_PATH={0}" -f $reportPathForOutput)