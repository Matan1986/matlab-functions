[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format "yyyy_MM_dd")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$resultsRoot = Join-Path $repoRoot "results"
$outputDir = Join-Path $repoRoot ("reports\maintenance\agent_outputs\{0}" -f $Date)
$outputCsv = Join-Path $outputDir "run_output_audit_findings.csv"

if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$findings = New-Object System.Collections.Generic.List[object]
$runDirs = @()

if (Test-Path -LiteralPath $resultsRoot) {
    $runDirs = Get-ChildItem -LiteralPath $resultsRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "run_*" -and
            $_.Parent -and
            $_.Parent.Name -eq "runs"
        }
}

if ($runDirs.Count -eq 0) {
    [void]$findings.Add([pscustomobject][ordered]@{
        finding_id = "NO_RUN_DIRS"
        module = "results"
        severity = "HIGH"
        description = "No run directories were found under results/**/runs/run_*"
    })
} else {
    foreach ($runDir in $runDirs) {
        $module = "unknown"
        if ($runDir.Parent -and $runDir.Parent.Parent) {
            $module = [string]$runDir.Parent.Parent.Name
        }

        $children = @(Get-ChildItem -LiteralPath $runDir.FullName -Force -ErrorAction SilentlyContinue)
        if ($children.Count -eq 0) {
            [void]$findings.Add([pscustomobject][ordered]@{
                finding_id = ("RUN_EMPTY_{0}" -f $runDir.Name)
                module = $module
                severity = "LOW"
                description = ("Run directory is empty: {0}" -f $runDir.FullName)
            })
        }

        $manifestPath = Join-Path $runDir.FullName "run_manifest.json"
        if (-not (Test-Path -LiteralPath $manifestPath)) {
            [void]$findings.Add([pscustomobject][ordered]@{
                finding_id = ("RUN_MISSING_MANIFEST_{0}" -f $runDir.Name)
                module = $module
                severity = "MEDIUM"
                description = ("Missing run_manifest.json: {0}" -f $runDir.FullName)
            })
        }
    }
}

if ($findings.Count -eq 0) {
    Set-Content -LiteralPath $outputCsv -Value "finding_id,module,severity,description" -Encoding UTF8
} else {
    $findings | Select-Object finding_id, module, severity, description |
        Export-Csv -LiteralPath $outputCsv -NoTypeInformation -Encoding UTF8
}

Write-Output ("Runs found: {0}" -f $runDirs.Count)
Write-Output ("Findings: {0}" -f $findings.Count)
Write-Output ("Output path: {0}" -f $outputCsv)
