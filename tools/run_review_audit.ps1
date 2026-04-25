param(
    [string]$RepoRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-JsonObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return $raw | ConvertFrom-Json
}

function Get-RunIdParts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunId
    )

    $match = [regex]::Match($RunId, '^run_(\d{4})_(\d{2})_(\d{2})_(\d{6})_(.+)$')
    if (-not $match.Success) {
        return [pscustomobject]@{
            TimestampText = ''
            TimestampValue = $null
            Label = ''
        }
    }

    $stampText = '{0}-{1}-{2} {3}:{4}:{5}' -f `
        $match.Groups[1].Value, `
        $match.Groups[2].Value, `
        $match.Groups[3].Value, `
        $match.Groups[4].Value.Substring(0, 2), `
        $match.Groups[4].Value.Substring(2, 2), `
        $match.Groups[4].Value.Substring(4, 2)

    $stampValue = $null
    try {
        $stampValue = [datetime]::ParseExact($stampText, 'yyyy-MM-dd HH:mm:ss', $null)
    } catch {
        $stampValue = $null
    }

    return [pscustomobject]@{
        TimestampText = $stampText
        TimestampValue = $stampValue
        Label = $match.Groups[5].Value
    }
}

function Get-RelativePathString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    $baseUri = [uri](([System.IO.Path]::GetFullPath($BasePath)).TrimEnd('\') + '\')
    $targetUri = [uri][System.IO.Path]::GetFullPath($TargetPath)
    return [uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

function Split-CsvLike {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return ($Value -split '\s*,\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-MainScripts {
    param(
        [string]$RunDir,
        [string[]]$ReportFiles,
        [string]$LogPath,
        [string]$NotesPath,
        [object]$Manifest
    )

    $scripts = New-Object System.Collections.Generic.List[string]

    if (Test-Path -LiteralPath $NotesPath) {
        $noteLines = Get-Content -LiteralPath $NotesPath
        foreach ($line in $noteLines) {
            $match = [regex]::Match($line, 'Executed scripts:\s*(.+)$')
            if ($match.Success) {
                foreach ($script in (Split-CsvLike -Value $match.Groups[1].Value)) {
                    if ($script -and -not $scripts.Contains($script)) {
                        [void]$scripts.Add($script.Trim())
                    }
                }
            }
        }
    }

    if ($scripts.Count -eq 0) {
        foreach ($reportFile in $ReportFiles | Select-Object -First 3) {
            $text = Get-Content -LiteralPath $reportFile -Raw
            $matches = [regex]::Matches($text, '`([^`]+\.m)`')
            foreach ($item in $matches) {
                $script = $item.Groups[1].Value.Trim()
                if ($script -and -not $scripts.Contains($script)) {
                    [void]$scripts.Add($script)
                }
            }
        }
    }

    if ($scripts.Count -eq 0 -and $Manifest -and $Manifest.PSObject.Properties.Name -contains 'run_type') {
        $runType = [string]$Manifest.run_type
        if (-not [string]::IsNullOrWhiteSpace($runType)) {
            [void]$scripts.Add("unknown ($runType)")
        }
    }

    if ($scripts.Count -eq 0 -and (Test-Path -LiteralPath $LogPath)) {
        $logText = Get-Content -LiteralPath $LogPath -Raw
        $match = [regex]::Match($logText, 'Starting (.+?) run orchestration')
        if ($match.Success) {
            [void]$scripts.Add("unknown ($($match.Groups[1].Value.Trim()))")
        }
    }

    if ($scripts.Count -eq 0) {
        $runId = Split-Path -Path $RunDir -Leaf
        $parts = Get-RunIdParts -RunId $runId
        if (-not [string]::IsNullOrWhiteSpace($parts.Label)) {
            [void]$scripts.Add("unknown ($($parts.Label))")
        }
    }

    return $scripts.ToArray()
}

function Get-ObservableNamesFromReports {
    param(
        [string[]]$ReportFiles
    )

    $skipTokens = @(
        'experiment', 'sample', 'temperature', 'observable', 'value', 'units', 'role',
        'source_run', 'coordinates', 'observables'
    )
    $names = New-Object System.Collections.Generic.List[string]

    foreach ($reportFile in $ReportFiles | Select-Object -First 4) {
        $text = Get-Content -LiteralPath $reportFile -Raw
        $matches = [regex]::Matches($text, '`([A-Za-z][A-Za-z0-9_()]+)`')
        foreach ($item in $matches) {
            $token = $item.Groups[1].Value.Trim()
            if ($token -match '\.m$') {
                continue
            }
            if ($token -match '[\\/]' -or $token -match '\s') {
                continue
            }
            if ($skipTokens -contains $token.ToLowerInvariant()) {
                continue
            }
            if (-not $names.Contains($token)) {
                [void]$names.Add($token)
            }
        }
    }

    return $names.ToArray()
}

function Get-ObservableNames {
    param(
        [string[]]$TableFiles,
        [string[]]$ReportFiles
    )

    $names = New-Object System.Collections.Generic.List[string]

    foreach ($tableFile in $TableFiles) {
        if ([System.IO.Path]::GetExtension($tableFile).ToLowerInvariant() -notin @('.csv', '.tsv')) {
            continue
        }

        $headers = @()
        try {
            $firstLine = Get-Content -LiteralPath $tableFile -TotalCount 1
            if ([string]::IsNullOrWhiteSpace($firstLine)) {
                continue
            }
            $delimiter = if ($tableFile.ToLowerInvariant().EndsWith('.tsv')) { "`t" } else { ',' }
            $headers = $firstLine -split [regex]::Escape($delimiter)
        } catch {
            continue
        }

        $observableHeader = $headers | Where-Object { $_.Trim().ToLowerInvariant() -eq 'observable' } | Select-Object -First 1
        if (-not $observableHeader) {
            continue
        }

        try {
            $rows = Import-Csv -LiteralPath $tableFile -Delimiter $delimiter
            foreach ($row in $rows) {
                $value = [string]$row.observable
                if (-not [string]::IsNullOrWhiteSpace($value) -and -not $names.Contains($value)) {
                    [void]$names.Add($value.Trim())
                }
            }
        } catch {
            continue
        }
    }

    if ($names.Count -eq 0) {
        foreach ($name in (Get-ObservableNamesFromReports -ReportFiles $ReportFiles)) {
            if (-not $names.Contains($name)) {
                [void]$names.Add($name)
            }
        }
    }

    return $names.ToArray()
}

function Get-ClusterInfo {
    param(
        [string]$Experiment,
        [string]$Label
    )

    $experimentLower = ([string]$Experiment).ToLowerInvariant()
    $labelLower = ([string]$Label).ToLowerInvariant()

    if ($experimentLower -eq 'aging') {
        if ($labelLower -like '*geometry*') {
            return [pscustomobject]@{
                Key = 'aging_geometry'
                Name = 'aging geometry runs'
                Explanation = 'Aging runs focused on geometry or visualization outputs rather than final observable exports.'
            }
        }
        return [pscustomobject]@{
            Key = 'aging_analysis'
            Name = 'aging analysis runs'
            Explanation = 'Aging runs that export structured datasets, decomposition outputs, or aging-specific diagnostics for later review.'
        }
    }

    if ($experimentLower -eq 'relaxation') {
        return [pscustomobject]@{
            Key = 'relaxation_analysis'
            Name = 'relaxation analysis runs'
            Explanation = 'Relaxation runs covering coordinate extraction, smoothing, maps, and time or temperature dependent diagnostics.'
        }
    }

    if ($experimentLower -eq 'switching') {
        return [pscustomobject]@{
            Key = 'switching_analysis'
            Name = 'switching analysis runs'
            Explanation = 'Switching runs that audit alignment, compute switching observables, or stage switching-specific review outputs.'
        }
    }

    if ($experimentLower -in @('cross_experiment', 'cross_analysis')) {
        return [pscustomobject]@{
            Key = 'cross_experiment_analysis'
            Name = 'cross_experiment analysis runs'
            Explanation = 'Runs that aggregate observables across experiments or compare outputs across multiple pipelines.'
        }
    }

    return [pscustomobject]@{
        Key = 'infrastructure_tooling'
        Name = 'infrastructure or tooling runs'
        Explanation = 'Repository maintenance, cleanup, tests, and other support runs that help the pipeline but are not primary scientific analyses.'
    }
}
function Get-OutputInventory {
    param(
        [string]$RunDir
    )

    $metadataNames = @('run_manifest.json', 'run_review.json', 'run_notes.txt', 'log.txt', 'config_snapshot.m')
    $figureExtensions = @('.png', '.jpg', '.jpeg', '.svg', '.pdf', '.fig', '.eps', '.tif', '.tiff')
    $tableExtensions = @('.csv', '.tsv', '.xlsx', '.xls')
    $reportExtensions = @('.md', '.pdf', '.html', '.htm', '.txt', '.docx')

    $files = Get-ChildItem -LiteralPath $RunDir -Recurse -File
    $outputFiles = New-Object System.Collections.Generic.List[object]
    $figureFiles = New-Object System.Collections.Generic.List[string]
    $tableFiles = New-Object System.Collections.Generic.List[string]
    $reportFiles = New-Object System.Collections.Generic.List[string]
    $emptyTables = New-Object System.Collections.Generic.List[string]

    foreach ($file in $files) {
        if ($metadataNames -contains $file.Name) {
            continue
        }

        $relativePath = Get-RelativePathString -BasePath $RunDir -TargetPath $file.FullName
        $relativeLower = $relativePath.ToLowerInvariant()
        $extension = $file.Extension.ToLowerInvariant()
        $category = 'artifact'

        if ($relativeLower.StartsWith('reports\') -or (($reportExtensions -contains $extension) -and $file.BaseName.ToLowerInvariant().Contains('report'))) {
            $category = 'report'
            [void]$reportFiles.Add($file.FullName)
        } elseif ($relativeLower.StartsWith('figures\') -or ($figureExtensions -contains $extension)) {
            $category = 'figure'
            [void]$figureFiles.Add($file.FullName)
        } elseif ($relativeLower.StartsWith('tables\') -or $relativeLower.StartsWith('csv\') -or ($tableExtensions -contains $extension)) {
            $category = 'table'
            [void]$tableFiles.Add($file.FullName)
        } elseif ($relativeLower.StartsWith('archives\') -or $extension -eq '.zip') {
            $category = 'archive'
        }

        [void]$outputFiles.Add([pscustomobject]@{
            FullName = $file.FullName
            RelativePath = $relativePath
            Category = $category
            Length = [int64]$file.Length
        })

        if ($category -eq 'table' -and $extension -in @('.csv', '.tsv')) {
            try {
                $preview = Get-Content -LiteralPath $file.FullName -TotalCount 2 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                if ($preview.Count -le 1) {
                    [void]$emptyTables.Add($relativePath)
                }
            } catch {
                [void]$emptyTables.Add($relativePath)
            }
        }
    }

    $totalOutputBytes = 0
    if ($outputFiles.Count -gt 0) {
        $measured = @($outputFiles.ToArray()) | Measure-Object -Property Length -Sum
        if ($measured) {
            $totalOutputBytes = [int64]$measured[0].Sum
        }
    }

    return [pscustomobject]@{
        OutputFiles = $outputFiles.ToArray()
        FigureFiles = $figureFiles.ToArray()
        TableFiles = $tableFiles.ToArray()
        ReportFiles = $reportFiles.ToArray()
        EmptyTables = $emptyTables.ToArray()
        TotalOutputBytes = $totalOutputBytes
        TotalOutputFiles = $outputFiles.Count
        FigureCount = $figureFiles.Count
        TableCount = $tableFiles.Count
        ReportCount = $reportFiles.Count
    }
}

function Join-Values {
    param(
        [object[]]$Values,
        [string]$Separator = '; '
    )

    if (-not $Values) {
        return ''
    }

    return (($Values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join $Separator)
}

function Get-ClaimIndex {
    param(
        [string]$ClaimsDir
    )

    $index = @{}
    if (-not (Test-Path -LiteralPath $ClaimsDir)) {
        return $index
    }

    $claimFiles = Get-ChildItem -LiteralPath $ClaimsDir -File -Filter *.json -ErrorAction SilentlyContinue
    foreach ($claimFile in $claimFiles) {
        $claim = Get-JsonObject -Path $claimFile.FullName
        if (-not $claim) {
            continue
        }

        $claimId = if ($claim.PSObject.Properties.Name -contains 'claim_id') { [string]$claim.claim_id } else { $claimFile.BaseName }
        $sourceRuns = @()
        if ($claim.PSObject.Properties.Name -contains 'source_runs') {
            $sourceRuns = @($claim.source_runs)
        }

        foreach ($runId in $sourceRuns) {
            if (-not $index.ContainsKey($runId)) {
                $index[$runId] = New-Object System.Collections.Generic.List[string]
            }
            [void]$index[$runId].Add($claimId)
        }
    }

    return $index
}

function Add-Flag {
    param(
        [System.Collections.Generic.List[object]]$FlagList,
        [string]$RunId,
        [string]$Experiment,
        [string]$Label,
        [string]$Timestamp,
        [string]$Status,
        [int]$Severity,
        [string]$Reason,
        [string]$Attention
    )

    [void]$FlagList.Add([pscustomobject]@{
        run_id = $RunId
        experiment = $Experiment
        label = $Label
        timestamp = $Timestamp
        status = $Status
        severity = $Severity
        reason = $Reason
        attention = $Attention
    })
}

function Get-SeverityLabel {
    param(
        [int]$Severity
    )

    switch ($Severity) {
        3 { return 'high' }
        2 { return 'medium' }
        default { return 'low' }
    }
}

$repoRootPath = [System.IO.Path]::GetFullPath($RepoRoot)
$resultsRoot = Join-Path $repoRootPath 'results'
$claimsRoot = Join-Path $repoRootPath 'claims'

if (-not (Test-Path -LiteralPath $resultsRoot)) {
    throw "Results directory not found: $resultsRoot"
}

$claimIndex = Get-ClaimIndex -ClaimsDir $claimsRoot

$runDirectories = Get-ChildItem -LiteralPath $resultsRoot -Directory |
    Where-Object { $_.Name -ne 'review' } |
    ForEach-Object {
        $runsDir = Join-Path $_.FullName 'runs'
        if (Test-Path -LiteralPath $runsDir) {
            Get-ChildItem -LiteralPath $runsDir -Directory | Where-Object { $_.Name -like 'run_*' }
        }
    } |
    Sort-Object FullName

$runRecords = New-Object System.Collections.Generic.List[object]
$flagRows = New-Object System.Collections.Generic.List[object]
$clusterRows = New-Object System.Collections.Generic.List[object]

foreach ($runDir in $runDirectories) {
    $experiment = Split-Path -Path (Split-Path -Path $runDir.FullName -Parent) -Parent | Split-Path -Leaf
    $runId = $runDir.Name
    $runParts = Get-RunIdParts -RunId $runId

    $manifestPath = Join-Path $runDir.FullName 'run_manifest.json'
    $reviewPath = Join-Path $runDir.FullName 'run_review.json'
    $logPath = Join-Path $runDir.FullName 'log.txt'
    $notesPath = Join-Path $runDir.FullName 'run_notes.txt'

    $manifest = Get-JsonObject -Path $manifestPath
    $review = Get-JsonObject -Path $reviewPath
    $inventory = Get-OutputInventory -RunDir $runDir.FullName

    $label = if ($manifest -and $manifest.PSObject.Properties.Name -contains 'label' -and -not [string]::IsNullOrWhiteSpace([string]$manifest.label)) {
        [string]$manifest.label
    } else {
        $runParts.Label
    }

    $timestamp = if ($manifest -and $manifest.PSObject.Properties.Name -contains 'timestamp' -and -not [string]::IsNullOrWhiteSpace([string]$manifest.timestamp)) {
        [string]$manifest.timestamp
    } elseif ($runParts.TimestampText) {
        $runParts.TimestampText
    } else {
        ''
    }

    $status = 'missing'
    if ($review) {
        if ($review.PSObject.Properties.Name -contains 'review_status' -and -not [string]::IsNullOrWhiteSpace([string]$review.review_status)) {
            $status = [string]$review.review_status
        } elseif ($review.PSObject.Properties.Name -contains 'status' -and -not [string]::IsNullOrWhiteSpace([string]$review.status)) {
            $status = [string]$review.status
        }
    }

    $mainScripts = @(Get-MainScripts -RunDir $runDir.FullName -ReportFiles $inventory.ReportFiles -LogPath $logPath -NotesPath $notesPath -Manifest $manifest)
    $observables = @(Get-ObservableNames -TableFiles $inventory.TableFiles -ReportFiles $inventory.ReportFiles)
    $cluster = Get-ClusterInfo -Experiment $experiment -Label $label

    $metadataIssues = New-Object System.Collections.Generic.List[string]
    if (-not $manifest) {
        [void]$metadataIssues.Add('missing run_manifest.json')
    }
    if (-not $review) {
        [void]$metadataIssues.Add('missing run_review.json')
    }
    if ($manifest) {
        if ($manifest.PSObject.Properties.Name -contains 'run_id' -and [string]$manifest.run_id -ne $runId) {
            [void]$metadataIssues.Add('manifest run_id mismatch')
        }
        if ($manifest.PSObject.Properties.Name -contains 'experiment' -and [string]$manifest.experiment -ne $experiment) {
            [void]$metadataIssues.Add('manifest experiment mismatch')
        }
        if ($manifest.PSObject.Properties.Name -contains 'label' -and $runParts.Label -and [string]$manifest.label -ne $runParts.Label) {
            [void]$metadataIssues.Add('manifest label mismatch with run_id')
        }
    }

    $logText = if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath -Raw } else { '' }
    $notesLength = if (Test-Path -LiteralPath $notesPath) { (Get-Item -LiteralPath $notesPath).Length } else { 0 }
    $isPlaceholder = $false
    if ($manifest -and $manifest.PSObject.Properties.Name -contains 'run_type' -and [string]$manifest.run_type -eq 'metadata_recovery') {
        $isPlaceholder = $true
    }
    if ($logText -match 'Placeholder .* results cleanup') {
        $isPlaceholder = $true
    }

    $claimIds = @($(if ($claimIndex.ContainsKey($runId)) { $claimIndex[$runId].ToArray() } else { @() }))
    $hasClaims = $claimIds.Count -gt 0
    $reportPresent = $inventory.ReportCount -gt 0
    $observablesPresent = $observables.Count -gt 0

    $sampleOutputs = $inventory.OutputFiles |
        Where-Object { $_.Category -in @('report', 'figure', 'table') } |
        Select-Object -First 6 -ExpandProperty RelativePath

    $outputSignature = [string]::Join('|', @(
            [string]$reportPresent,
            [string]($inventory.FigureCount -gt 0),
            [string]($inventory.TableCount -gt 0),
            (Join-Values -Values ($observables | Sort-Object)),
            (Join-Values -Values ($mainScripts | Sort-Object))
        ))

    $runRecord = [pscustomobject]@{
        run_id = $runId
        experiment = $experiment
        label = $label
        timestamp = $timestamp
        status = $status
        main_script_used = Join-Values -Values $mainScripts
        report_present = $reportPresent
        observables_present = $observablesPresent
        observables_generated = Join-Values -Values $observables
        claims_reference = $hasClaims
        claim_ids = Join-Values -Values $claimIds
        key_outputs_present = "reports=$($inventory.ReportCount); figures=$($inventory.FigureCount); tables=$($inventory.TableCount); sample=$((Join-Values -Values $sampleOutputs -Separator ' | '))"
        table_count = $inventory.TableCount
        figure_count = $inventory.FigureCount
        report_count = $inventory.ReportCount
        output_file_count = $inventory.TotalOutputFiles
        output_size_bytes = [int64]($inventory.TotalOutputBytes | ForEach-Object { if ($_ -eq $null) { 0 } else { $_ } })
        empty_tables = Join-Values -Values $inventory.EmptyTables
        metadata_issues = Join-Values -Values $metadataIssues
        cluster_key = $cluster.Key
        cluster_name = $cluster.Name
        cluster_explanation = $cluster.Explanation
        dataset = if ($manifest -and $manifest.PSObject.Properties.Name -contains 'dataset') { [string]$manifest.dataset } else { '' }
        is_placeholder = $isPlaceholder
        notes_empty = ($notesLength -eq 0)
        log_has_run_complete = ($logText -match 'Run complete')
        output_signature = $outputSignature
    }

    [void]$runRecords.Add($runRecord)
    [void]$clusterRows.Add([pscustomobject]@{
        cluster_key = $cluster.Key
        cluster_name = $cluster.Name
        cluster_explanation = $cluster.Explanation
        run_id = $runId
        experiment = $experiment
        label = $label
        timestamp = $timestamp
        status = $status
    })
}
$records = $runRecords.ToArray()

$labelGroups = $records | Group-Object experiment, label | Where-Object { $_.Count -gt 1 }
foreach ($group in $labelGroups) {
    $sorted = $group.Group | Sort-Object timestamp, run_id
    $baseline = $sorted | Select-Object -First 1

    foreach ($record in $sorted) {
        $duplicateNote = "duplicate label within experiment ($($group.Count) runs share '$($record.label)')"
        Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 1 -Reason $duplicateNote -Attention 'Compare with sibling runs before approval.'

        if ($record.run_id -ne $baseline.run_id -and $record.output_signature -ne $baseline.output_signature) {
            Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 2 -Reason 'output signature differs from earlier run(s) with the same label' -Attention 'Check whether this rerun supersedes or contradicts prior outputs.'
        }
    }
}

$sizeMedians = @{}
foreach ($group in ($records | Group-Object experiment)) {
    $positive = @($group.Group | Where-Object { $_.output_size_bytes -gt 0 } | Select-Object -ExpandProperty output_size_bytes | Sort-Object)
    if ($positive.Count -eq 0) {
        $sizeMedians[$group.Name] = 0
    } elseif ($positive.Count % 2 -eq 1) {
        $sizeMedians[$group.Name] = [double]$positive[[int][math]::Floor($positive.Count / 2)]
    } else {
        $upper = [int]($positive.Count / 2)
        $lower = $upper - 1
        $sizeMedians[$group.Name] = ([double]$positive[$lower] + [double]$positive[$upper]) / 2.0
    }
}

foreach ($record in $records) {
    if (-not $record.report_present) {
        Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 3 -Reason 'report missing' -Attention 'Review via raw outputs only; consider requesting a narrative report before approval.'
    }

    if (-not $record.observables_present -and $record.cluster_key -in @('switching_analysis', 'relaxation_analysis', 'cross_experiment_analysis')) {
        Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 2 -Reason 'no observables detected in a run type that usually exports observables' -Attention 'Confirm whether the run intentionally produced only diagnostic outputs.'
    }

    if ($record.empty_tables) {
        Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 2 -Reason "empty table(s): $($record.empty_tables)" -Attention 'Open the table files and confirm whether the pipeline terminated before data export.'
    }

    if ($record.metadata_issues) {
        Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 2 -Reason "metadata inconsistency: $($record.metadata_issues)" -Attention 'Validate the manifest and review metadata before approval.'
    }

    if ($record.output_file_count -eq 0) {
        Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 3 -Reason 'no outputs beyond metadata files' -Attention 'Treat as failed or incomplete unless a cleanup note explains the absence.'
    }

    $medianSize = if ($sizeMedians.ContainsKey($record.experiment)) { [double]$sizeMedians[$record.experiment] } else { 0.0 }
    if ($record.output_file_count -gt 0 -and ($record.output_size_bytes -lt 10240 -or ($medianSize -gt 0 -and $record.output_size_bytes -lt ($medianSize * 0.05)))) {
        Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 1 -Reason 'unusually small output size relative to repository norms' -Attention 'Compare file counts and file contents with neighboring runs.'
    }

    if ($record.is_placeholder) {
        Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 2 -Reason 'placeholder or metadata recovery run' -Attention 'Do not treat placeholder artifacts as evidence of a fresh scientific result.'
    }

    if (-not $record.log_has_run_complete -and -not $record.is_placeholder -and $record.status -eq 'pending_review' -and ((-not $record.report_present) -or $record.notes_empty -or $record.output_file_count -lt 5)) {
        Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 2 -Reason 'log does not record a completed run' -Attention 'Inspect log.txt for an interrupted or partial analysis.'
    }

    if ($record.notes_empty -and -not $record.report_present -and $record.status -eq 'pending_review') {
        Add-Flag -FlagList $flagRows -RunId $record.run_id -Experiment $record.experiment -Label $record.label -Timestamp $record.timestamp -Status $record.status -Severity 2 -Reason 'run notes are empty and no report is present' -Attention 'Context is thin; approval will require manual reconstruction from files.'
    }
}

$flagged = $flagRows.ToArray() |
    Sort-Object @{ Expression = 'severity'; Descending = $true }, experiment, label, timestamp, run_id

$maintenanceDateToken = Get-Date -Format 'yyyy_MM_dd'
$maintenanceOutputDir = Join-Path $repoRootPath ("reports\maintenance\agent_outputs\{0}" -f $maintenanceDateToken)
if (-not (Test-Path -LiteralPath $maintenanceOutputDir)) {
    New-Item -ItemType Directory -Path $maintenanceOutputDir -Force | Out-Null
}
$maintenanceFindingsCsv = Join-Path $maintenanceOutputDir 'run_output_audit_findings.csv'

$governorRows = New-Object System.Collections.Generic.List[object]
foreach ($row in $flagged) {
    [void]$governorRows.Add([pscustomobject][ordered]@{
        finding_id = [string]$row.run_id
        module = [string]$row.experiment
        severity = ([string](Get-SeverityLabel -Severity ([int]$row.severity))).ToUpperInvariant()
        description = [string]$row.reason
    })
}

if ($governorRows.Count -eq 0) {
    @([pscustomobject][ordered]@{
        finding_id = ''
        module = ''
        severity = ''
        description = ''
    }) | Export-Csv -LiteralPath $maintenanceFindingsCsv -NoTypeInformation -Encoding UTF8
    (Import-Csv -LiteralPath $maintenanceFindingsCsv | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.finding_id) -or
            -not [string]::IsNullOrWhiteSpace([string]$_.module) -or
            -not [string]::IsNullOrWhiteSpace([string]$_.severity) -or
            -not [string]::IsNullOrWhiteSpace([string]$_.description)
        }) | Export-Csv -LiteralPath $maintenanceFindingsCsv -NoTypeInformation -Encoding UTF8
} else {
    $governorRows | Export-Csv -LiteralPath $maintenanceFindingsCsv -NoTypeInformation -Encoding UTF8
}

Write-Output "Governor CSV output: $maintenanceFindingsCsv"
Write-Output "Governor CSV rows written: $($governorRows.Count)"

$flagSummaryByRun = @{}
foreach ($row in $flagged) {
    if (-not $flagSummaryByRun.ContainsKey($row.run_id)) {
        $flagSummaryByRun[$row.run_id] = New-Object System.Collections.Generic.List[string]
    }
    [void]$flagSummaryByRun[$row.run_id].Add($row.reason)
}

$pendingRuns = $records | Where-Object { $_.status -eq 'pending_review' } | Sort-Object experiment, timestamp, run_id

$timestampToken = Get-Date -Format 'yyyy_MM_dd_HHmmss'
$auditRunId = "run_${timestampToken}_run_review_audit"
$auditRoot = Join-Path $resultsRoot 'review'
$auditRunsRoot = Join-Path $auditRoot 'runs'
$auditRunDir = Join-Path $auditRunsRoot $auditRunId

New-Item -ItemType Directory -Path $auditRunDir -Force | Out-Null

$runSummaryCsv = Join-Path $auditRunDir 'run_summary_table.csv'
$runClustersCsv = Join-Path $auditRunDir 'run_clusters.csv'
$flaggedCsv = Join-Path $auditRunDir 'flagged_runs.csv'
$pendingSummariesMd = Join-Path $auditRunDir 'pending_review_short_summaries.md'
$auditReportMd = Join-Path $auditRunDir 'run_review_audit_report.md'
$zipPath = Join-Path $auditRunDir 'run_review_audit_package.zip'
$manifestOut = Join-Path $auditRunDir 'run_manifest.json'
$logOut = Join-Path $auditRunDir 'log.txt'
$notesOut = Join-Path $auditRunDir 'run_notes.txt'

$summaryRows = $records |
    Sort-Object @{ Expression = { if ($_.status -eq 'pending_review') { 0 } else { 1 } } }, experiment, timestamp, run_id |
    Select-Object run_id, experiment, label, timestamp, main_script_used, report_present, observables_present, observables_generated, claims_reference, claim_ids, status, table_count, figure_count, report_count, output_file_count, output_size_bytes, key_outputs_present, empty_tables, metadata_issues, cluster_name

$summaryRows | Export-Csv -LiteralPath $runSummaryCsv -NoTypeInformation
$clusterRows.ToArray() | Sort-Object cluster_name, experiment, timestamp, run_id | Export-Csv -LiteralPath $runClustersCsv -NoTypeInformation
$flagged | Select-Object run_id, experiment, label, timestamp, status, severity, @{ Name = 'severity_label'; Expression = { Get-SeverityLabel -Severity $_.severity } }, reason, attention | Export-Csv -LiteralPath $flaggedCsv -NoTypeInformation

$summaryBuilder = New-Object System.Text.StringBuilder
[void]$summaryBuilder.AppendLine('# Pending Review Short Summaries')
[void]$summaryBuilder.AppendLine()
[void]$summaryBuilder.AppendLine("Pending runs scanned: $($pendingRuns.Count)")
[void]$summaryBuilder.AppendLine()

foreach ($run in $pendingRuns) {
    $flags = @($(if ($flagSummaryByRun.ContainsKey($run.run_id)) { $flagSummaryByRun[$run.run_id].ToArray() } else { @() }))
    $healthSentence = if ($flags.Count -gt 0) {
        "It needs attention because " + (($flags | Select-Object -Unique | Select-Object -First 3) -join '; ') + '.'
    } else {
        'It looks structurally healthy for human review because it has the expected narrative and output artifacts.'
    }

    $scriptsText = if ([string]::IsNullOrWhiteSpace($run.main_script_used)) { 'an unknown script path' } else { $run.main_script_used }
    $datasetText = if ([string]::IsNullOrWhiteSpace($run.dataset)) { $run.label } else { $run.dataset }
    $observablesText = if ($run.observables_present) { $run.observables_generated } else { 'no explicit observables detected' }
    $outputText = "$($run.report_count) report(s), $($run.figure_count) figure(s), and $($run.table_count) table(s)"

    [void]$summaryBuilder.AppendLine("## $($run.run_id)")
    [void]$summaryBuilder.AppendLine()
    [void]$summaryBuilder.AppendLine("This $($run.experiment) run appears to execute $scriptsText for `"$datasetText`".")
    [void]$summaryBuilder.AppendLine("The artifact inventory shows $outputText, with observables: $observablesText.")
    [void]$summaryBuilder.AppendLine($healthSentence)
    [void]$summaryBuilder.AppendLine()
}

Set-Content -LiteralPath $pendingSummariesMd -Value $summaryBuilder.ToString()

$statusCounts = $records | Group-Object status | Sort-Object Name
$experimentCounts = $records | Group-Object experiment | Sort-Object Name
$suspiciousPending = @($flagged | Where-Object { $_.status -eq 'pending_review' } | Select-Object -Unique run_id, experiment, label, timestamp, severity, reason)
$reportBuilder = New-Object System.Text.StringBuilder
[void]$reportBuilder.AppendLine('# Run Review Audit Report')
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine("Audit generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') for repository root $repoRootPath.")
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('## 1. Repository overview')
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine("- Total scanned runs: $($records.Count)")
[void]$reportBuilder.AppendLine("- Pending review: $($pendingRuns.Count)")
[void]$reportBuilder.AppendLine("- Runs with reports: $(@($records | Where-Object { $_.report_present }).Count)")
[void]$reportBuilder.AppendLine("- Runs without reports: $(@($records | Where-Object { -not $_.report_present }).Count)")
[void]$reportBuilder.AppendLine("- Runs with claims references: $(@($records | Where-Object { $_.claims_reference }).Count)")
[void]$reportBuilder.AppendLine('- Notes: `results/review` was excluded from the scan so this audit package does not count itself.')
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('## 2. Distribution of runs by experiment')
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('| Experiment | Runs | Pending review | Reports present |')
[void]$reportBuilder.AppendLine('| --- | ---: | ---: | ---: |')
foreach ($experimentRow in $experimentCounts) {
    $name = [string]$experimentRow.Name
    $pendingCount = @($pendingRuns | Where-Object { $_.experiment -eq $name }).Count
    $reportCount = @($records | Where-Object { $_.experiment -eq $name -and $_.report_present }).Count
    [void]$reportBuilder.AppendLine("| $name | $($experimentRow.Count) | $pendingCount | $reportCount |")
}
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('## 3. Review status breakdown')
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('| Status | Count |')
[void]$reportBuilder.AppendLine('| --- | ---: |')
foreach ($statusRow in $statusCounts) {
    [void]$reportBuilder.AppendLine("| $($statusRow.Name) | $($statusRow.Count) |")
}
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('## 4. List of suspicious runs')
[void]$reportBuilder.AppendLine()
if ($suspiciousPending.Count -eq 0) {
    [void]$reportBuilder.AppendLine('No suspicious pending-review runs were flagged by the repository scan heuristics.')
} else {
    [void]$reportBuilder.AppendLine('| Run ID | Experiment | Severity | Reason |')
    [void]$reportBuilder.AppendLine('| --- | --- | --- | --- |')
    foreach ($row in ($suspiciousPending | Sort-Object @{ Expression = 'severity'; Descending = $true }, experiment, timestamp, run_id | Select-Object -First 40)) {
        [void]$reportBuilder.AppendLine("| $($row.run_id) | $($row.experiment) | $(Get-SeverityLabel -Severity $row.severity) | $($row.reason) |")
    }
}
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('## 5. Suggested review order for the human')
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('Start with high-risk pending runs that have missing reports, missing observables, or inconsistent duplicate outputs. After that, move through the well-documented runs with reports and observable exports, grouped by experiment for efficiency.')
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('| Priority | Run ID | Why first |')
[void]$reportBuilder.AppendLine('| ---: | --- | --- |')
$priorityIndex = 1
foreach ($run in ($pendingRuns | Sort-Object `
        @{ Expression = { if ($flagSummaryByRun.ContainsKey($_.run_id)) { 0 } else { 1 } } },
        @{ Expression = { if ($_.report_present) { 0 } else { 1 } } },
        experiment,
        timestamp | Select-Object -First 20)) {
    $why = if ($flagSummaryByRun.ContainsKey($run.run_id)) {
        (($flagSummaryByRun[$run.run_id].ToArray() | Select-Object -Unique | Select-Object -First 2) -join '; ')
    } else {
        'rich output set and low structural risk'
    }
    [void]$reportBuilder.AppendLine("| $priorityIndex | $($run.run_id) | $why |")
    $priorityIndex += 1
}
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('## 6. Most important runs')
[void]$reportBuilder.AppendLine()
foreach ($run in ($pendingRuns | Sort-Object `
        @{ Expression = { if ($_.report_present) { 0 } else { 1 } } },
        @{ Expression = { if ($_.observables_present) { 0 } else { 1 } } },
        experiment,
        timestamp | Select-Object -First 10)) {
    $importanceNotes = New-Object System.Collections.Generic.List[string]
    if ($run.report_present) {
        [void]$importanceNotes.Add('includes a report')
    }
    if ($run.observables_present) {
        [void]$importanceNotes.Add('exports observables')
    }
    if ($run.claims_reference) {
        [void]$importanceNotes.Add('feeds a claim')
    }
    if ($flagSummaryByRun.ContainsKey($run.run_id)) {
        [void]$importanceNotes.Add('also has review flags')
    }
    if ($importanceNotes.Count -eq 0) {
        [void]$importanceNotes.Add('represents an active pending-review analysis')
    }
    [void]$reportBuilder.AppendLine("- **$($run.run_id)** ($($run.experiment)): $(($importanceNotes.ToArray()) -join ', ').")
}
[void]$reportBuilder.AppendLine()
[void]$reportBuilder.AppendLine('Supporting artifacts:')
[void]$reportBuilder.AppendLine('- `run_summary_table.csv` for the full scan')
[void]$reportBuilder.AppendLine('- `run_clusters.csv` for grouping context')
[void]$reportBuilder.AppendLine('- `flagged_runs.csv` for anomaly triage')
[void]$reportBuilder.AppendLine('- `pending_review_short_summaries.md` for per-run human review prep')

Set-Content -LiteralPath $auditReportMd -Value $reportBuilder.ToString()

$auditManifest = [ordered]@{
    run_id = $auditRunId
    timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    experiment = 'review'
    label = 'run_review_audit'
    run_type = 'repository_audit'
    repo_root = $repoRootPath
    source_scan = 'results/*/runs/run_* (excluding results/review)'
}
$auditManifest | ConvertTo-Json | Set-Content -LiteralPath $manifestOut

$logLines = @(
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Run review audit generated",
    "total_runs=$($records.Count)",
    "pending_review=$($pendingRuns.Count)",
    "flagged_rows=$($flagged.Count)",
    "output_dir=$auditRunDir"
)
Set-Content -LiteralPath $logOut -Value $logLines

$noteLines = @(
    "Run ID: $auditRunId",
    "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    'Executed scripts: tools/run_review_audit.ps1',
    "Primary analysis directory: $auditRunDir",
    'Generated artifacts: run_summary_table.csv, run_clusters.csv, flagged_runs.csv, pending_review_short_summaries.md, run_review_audit_report.md'
)
Set-Content -LiteralPath $notesOut -Value $noteLines

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -LiteralPath @($runSummaryCsv, $runClustersCsv, $flaggedCsv, $pendingSummariesMd) -DestinationPath $zipPath -CompressionLevel Optimal

Write-Output "Created audit run at: $auditRunDir"
Write-Output "Pending review runs: $($pendingRuns.Count)"
Write-Output "Flagged rows: $($flagged.Count)"





