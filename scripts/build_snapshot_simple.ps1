# TODO (IMPORTANT - DO NOT BREAK EXISTING LOGIC)
# Make experiment bundles dynamic:
# Instead of hardcoded experiments (switching/aging/relaxation),
# scan results/ and create snapshot_<experiment>.zip for each folder.
#
# Requirements:
# - Do NOT remove existing logic
# - Do NOT change bundle structure
# - If dynamic scan fails, fallback to current behavior
# - Keep cross/code/core bundles unchanged

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = 'C:\Dev\matlab-functions'
$outDir = 'L:\My Drive\For agents\snapshot\auto\snapshot_simple'
$tempRoot = 'C:\temp'

if (-not (Test-Path -LiteralPath $repoRoot)) {
    throw "Repository root not found: $repoRoot"
}

if (-not (Test-Path -LiteralPath $tempRoot)) {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$runId = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$stageDir = Join-Path $tempRoot ("snapshot_simple_stage_" + $runId)
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

function Get-RelativePathNormalized {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $root = (Resolve-Path -LiteralPath $RootPath).Path.TrimEnd('\')
    $file = (Resolve-Path -LiteralPath $FilePath).Path

    if (-not $file.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "File is not under root. root=$root file=$file"
    }

    # Keep the full first path component (for example "runs", "analysis", "LEGACY_NOTE.md").
    return $file.Substring($root.Length).TrimStart('\') -replace '\\', '/'
}

function New-ZipFromMappings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationZip,
        [Parameter(Mandatory = $true)]
        [array]$Mappings
    )

    if (Test-Path -LiteralPath $DestinationZip) {
        Remove-Item -LiteralPath $DestinationZip -Force
    }

    $zip = [System.IO.Compression.ZipFile]::Open($DestinationZip, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($map in $Mappings) {
            $source = [string]$map.Source
            $destPrefix = [string]$map.DestPrefix

            if (-not (Test-Path -LiteralPath $source)) {
                throw "Mapping source not found: $source"
            }

            if ((Get-Item -LiteralPath $source).PSIsContainer) {
                $files = Get-ChildItem -LiteralPath $source -Recurse -File -Force
                foreach ($file in $files) {
                    $relative = Get-RelativePathNormalized -RootPath $source -FilePath $file.FullName
                    $entryName = if ([string]::IsNullOrWhiteSpace($destPrefix)) {
                        $relative
                    } else {
                        ($destPrefix.TrimEnd('/') + '/' + $relative)
                    }

                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                        $zip,
                        $file.FullName,
                        $entryName,
                        [System.IO.Compression.CompressionLevel]::Optimal
                    ) | Out-Null
                }
            }
            else {
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $zip,
                    $source,
                    $destPrefix.TrimStart('/'),
                    [System.IO.Compression.CompressionLevel]::Optimal
                ) | Out-Null
            }
        }
    }
    finally {
        if ($null -ne $zip) {
            $zip.Dispose()
        }
    }

    if (-not (Test-Path -LiteralPath $DestinationZip)) {
        throw "ZIP was not created: $DestinationZip"
    }

    if ((Get-Item -LiteralPath $DestinationZip).Length -le 0) {
        throw "ZIP is empty: $DestinationZip"
    }
}

function Move-Atomic {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath) {
        Remove-Item -LiteralPath $DestinationPath -Force
    }
    Move-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
}

function Build-Bundle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [Parameter(Mandatory = $true)]
        [array]$Mappings
    )

    $tmpZip = Join-Path $stageDir ($FileName + '.tmp')
    New-ZipFromMappings -DestinationZip $tmpZip -Mappings $Mappings
    Move-Atomic -SourcePath $tmpZip -DestinationPath (Join-Path $outDir $FileName)
    Write-Output ("Built: " + $FileName)
}

function Add-FileMappingWithPolicy {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList]$Mappings,
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,
        [Parameter(Mandatory = $true)]
        [string]$DestPrefix,
        [Parameter(Mandatory = $true)]
        [bool]$Essential
    )

    $fullPath = Join-Path $RepoRoot $RelativePath
    if (Test-Path -LiteralPath $fullPath) {
        [void]$Mappings.Add(@{
            Source = $fullPath
            DestPrefix = $DestPrefix
        })
        return
    }

    if ($Essential) {
        throw ("Essential snapshot_control file missing: " + $RelativePath)
    }

    Write-Warning ("Optional snapshot_control file missing: " + $RelativePath)
}

function Get-ExperimentFolders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    # Preserve current behavior as a safety fallback if dynamic discovery fails.
    $fallbackFolders = @('switching', 'relaxation', 'aging')
    $resultsRoot = Join-Path $RepoRoot 'results'

    try {
        if (-not (Test-Path -LiteralPath $resultsRoot)) {
            throw "Results root not found: $resultsRoot"
        }

        $experiments = Get-ChildItem -LiteralPath $resultsRoot -Directory -ErrorAction Stop |
            Where-Object { $_.Name -ne 'cross_experiment' } |
            Sort-Object -Property Name

        if ($null -eq $experiments -or $experiments.Count -eq 0) {
            throw "No experiment folders discovered under: $resultsRoot"
        }

        $valid = @()
        foreach ($exp in $experiments) {
            if (Test-Path -LiteralPath $exp.FullName) {
                $valid += $exp
            }
        }

        if ($valid.Count -eq 0) {
            throw "No valid experiment folders discovered under: $resultsRoot"
        }

        Write-Host ("Dynamic experiment bundles: " + (($valid | ForEach-Object { $_.Name }) -join ', '))
        return $valid
    }
    catch {
        Write-Warning ("Dynamic experiment discovery failed. Falling back to fixed list (switching, relaxation, aging). Error: " + $_.Exception.Message)
        return $fallbackFolders
    }
}

try {
    Write-Output 'Building snapshot_simple...'

    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'runs'))) {
        Write-Warning 'runs folder missing'
    }

    $analysisPath = Join-Path $repoRoot 'analysis'
    if (-not (Test-Path -LiteralPath $analysisPath)) {
        Write-Warning 'analysis folder missing'
    }

    $reportsList = @(
        'adversarial_observable_report.md',
        'dimensionless_constrained_basin_report.md',
        'functional_form_scan_report.md',
        'functional_form_test_report.md',
        'observable_search_report.md',
        'pareto_x_defense_report.md',
        'speak_vs_x_cross_experiment_report.md',
        'stability_basin_report.md',
        'subset_stability_report.md',
        'temperature_null_test_report.md'
    )

    $crossReportMappings = @()
    foreach ($reportFile in $reportsList) {
        $fullPath = Join-Path $repoRoot ("reports\" + $reportFile)
        if (Test-Path -LiteralPath $fullPath) {
            $crossReportMappings += @{
                Source = $fullPath
                DestPrefix = ("reports/" + $reportFile)
            }
        }
    }

    $controlMappings = [System.Collections.ArrayList]::new()
    $controlFiles = @(
        @{ RelativePath = 'docs\project_control_board.md'; DestPrefix = 'docs/project_control_board.md'; Essential = $true },
        @{ RelativePath = 'tables\project_workstream_status.csv'; DestPrefix = 'tables/project_workstream_status.csv'; Essential = $true },
        @{ RelativePath = 'docs\context_bundle.json'; DestPrefix = 'docs/context_bundle.json'; Essential = $true },
        @{ RelativePath = 'docs\context_bundle_full.json'; DestPrefix = 'docs/context_bundle_full.json'; Essential = $false },
        @{ RelativePath = 'docs\repo_state.json'; DestPrefix = 'docs/repo_state.json'; Essential = $true },
        @{ RelativePath = 'docs\system_master_plan.md'; DestPrefix = 'docs/system_master_plan.md'; Essential = $false },
        @{ RelativePath = 'docs\infrastructure_laws.md'; DestPrefix = 'docs/infrastructure_laws.md'; Essential = $false },
        @{ RelativePath = 'docs\AGENT_RULES.md'; DestPrefix = 'docs/AGENT_RULES.md'; Essential = $false },
        @{ RelativePath = 'docs\system_registry.json'; DestPrefix = 'docs/system_registry.json'; Essential = $false },
        @{ RelativePath = 'analysis\knowledge\run_registry.csv'; DestPrefix = 'analysis/knowledge/run_registry.csv'; Essential = $false },
        @{ RelativePath = 'tables\switching_canonical_identity.csv'; DestPrefix = 'tables/switching_canonical_identity.csv'; Essential = $false },
        @{ RelativePath = 'tables\module_canonical_status.csv'; DestPrefix = 'tables/module_canonical_status.csv'; Essential = $false }
    )

    foreach ($controlFile in $controlFiles) {
        Add-FileMappingWithPolicy `
            -Mappings $controlMappings `
            -RepoRoot $repoRoot `
            -RelativePath $controlFile.RelativePath `
            -DestPrefix $controlFile.DestPrefix `
            -Essential ([bool]$controlFile.Essential)
    }

    Build-Bundle -FileName 'snapshot_control.zip' -Mappings $controlMappings

    Build-Bundle -FileName 'snapshot_core.zip' -Mappings @(
        @{
            Source = (Join-Path $repoRoot 'docs\repo_state.json')
            DestPrefix = 'docs/repo_state.json'
        }
    )

    $resultsPath = Join-Path $repoRoot 'results'
    $experimentFolders = Get-ExperimentFolders -RepoRoot $repoRoot
    foreach ($exp in $experimentFolders) {
        $name = if ($exp -is [System.IO.DirectoryInfo]) { $exp.Name } else { [string]$exp }
        Write-Output ("Processing experiment: " + $name)
        Build-Bundle -FileName ("snapshot_" + $name + ".zip") -Mappings @(
            @{
                Source = (Join-Path $resultsPath $name)
                DestPrefix = ("results/" + $name)
            }
        )
    }

    $crossMappings = @(
        @{
            Source = (Join-Path $repoRoot 'results\cross_experiment')
            DestPrefix = 'results/cross_experiment'
        }
    ) + $crossReportMappings

    Build-Bundle -FileName 'snapshot_cross.zip' -Mappings $crossMappings

    $codeMappings = @(
        @{
            Source = (Join-Path $repoRoot 'Switching')
            DestPrefix = 'Switching'
        },
        @{
            Source = (Join-Path $repoRoot 'Relaxation ver3')
            DestPrefix = 'Relaxation'
        },
        @{
            Source = (Join-Path $repoRoot 'Aging')
            DestPrefix = 'Aging'
        }
    )

    if (Test-Path -LiteralPath $analysisPath) {
        $codeMappings += @{
            Source = $analysisPath
            DestPrefix = 'analysis'
        }
    }

    Build-Bundle -FileName 'snapshot_code.zip' -Mappings $codeMappings

    $contextBundlePath = Join-Path $repoRoot 'docs\context_bundle.json'
    Copy-Item -LiteralPath $contextBundlePath -Destination (Join-Path $outDir 'context_bundle.json') -Force

    $contextBundleFullPath = Join-Path $repoRoot 'docs\context_bundle_full.json'
    if (Test-Path -LiteralPath $contextBundleFullPath) {
        Copy-Item -LiteralPath $contextBundleFullPath -Destination (Join-Path $outDir 'context_bundle_full.json') -Force
    }

    $readmePath = Join-Path $outDir 'README.txt'
    @'
READ FIRST (external agent handoff)

1) Start with snapshot_control.zip.
2) Read docs/project_control_board.md and tables/project_workstream_status.csv first.
3) Context bundles are navigation/state artifacts, not evidence closure.
4) Scientific graph, claims, and query integration may be partial for canonical Switching.
5) Do not treat claims/snapshot/query outputs as canonical unless control board and workstream status explicitly say so.

snapshot_simple bundle guide

snapshot_core.zip
- Contains: docs/repo_state.json
- Use when: you need minimal project context and module/observable mapping.

snapshot_switching.zip
- Contains: results/switching/
- Use when: you need switching run outputs, run-local reports, tables, figures, and manifests.

snapshot_relaxation.zip
- Contains: results/relaxation/
- Use when: you need relaxation run outputs and run-local evidence.

snapshot_aging.zip
- Contains: results/aging/
- Use when: you need aging run outputs and run-local evidence.

snapshot_cross.zip
- Contains: results/cross_experiment/ plus cross/X/scaling/correlation reports in reports/
- Use when: you need cross-experiment evidence and global X/scaling/correlation synthesis.

snapshot_code.zip
- Contains: Switching/, Relaxation/ (sourced from Relaxation ver3 in this repo), Aging/, analysis/
- Use when: you need analysis and experiment code corresponding to run outputs.
'@ | Set-Content -LiteralPath $readmePath -Encoding UTF8

    Write-Output 'snapshot_simple build complete.'
}
finally {
    if (Test-Path -LiteralPath $stageDir) {
        Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
