# Stage B: Channel identity enforcement - create *_with_channel.csv artifacts only (never overwrite sources).
# See task: Channel Identity Enforcement in Canonical Artifacts.

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $repoRoot "tables"))) {
    $repoRoot = (Get-Location).Path
}

function Map-ChannelType {
    param([int]$Physical)
    if ($Physical -eq 1) { return "XY" }
    if ($Physical -eq 2 -or $Physical -eq 3) { return "XX" }
    throw "Unknown channel: switching_channel_physical=$Physical"
}

function Try-ParseInt {
    param($Text)
    $t = "$Text".Trim()
    if ($t -match '^-?\d+$') { return [int]$t }
    return $null
}

function Get-PhysicalFromRowsPerChannel {
    param([string]$RowsPerChannel, [int]$UniqueChannels)
    if ($UniqueChannels -ne 1) { return $null }
    if ($RowsPerChannel -match '^(\d+)\s*=') {
        return [int]$Matches[1]
    }
    return $null
}

function Extract-FromExecutionStatusCsv {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $rows = Import-Csv -Path $Path
        if (-not $rows) { return $null }
        $row = $rows | Select-Object -First 1
        $candidates = @(
            "switching_channel_physical", "SWITCHING_CHANNEL_PHYSICAL",
            "Switching_Channel_Physical", "CHANNEL_PHYSICAL", "channel_physical"
        )
        foreach ($name in $candidates) {
            if ($null -ne $row.$name -and "$($row.$name)".Trim() -ne "") {
                $p = Try-ParseInt $row.$name
                if ($null -ne $p) {
                    return @{ Physical = $p; Source = "execution_status.csv::$name" }
                }
            }
        }
    } catch { }
    return $null
}

function Extract-FromManifestJson {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $j = Get-Content -Raw -Path $Path | ConvertFrom-Json
        $walk = {
            param($Obj, $Depth)
            if ($Depth -gt 12) { return $null }
            if ($null -eq $Obj) { return $null }
            if ($Obj -is [System.Collections.IDictionary] -or $Obj.PSObject.Properties) {
                foreach ($prop in $Obj.PSObject.Properties) {
                    $n = $prop.Name
                    $v = $prop.Value
                    if ($n -match 'switching_channel_physical' -or ($n -eq 'channel' -and $v -is [int])) {
                        $p = Try-ParseInt $v
                        if ($null -ne $p) { return $p }
                    }
                    if ($v -is [PSCustomObject] -or $v -is [hashtable]) {
                        $inner = & $walk $v ($Depth + 1)
                        if ($null -ne $inner) { return $inner }
                    }
                }
            }
            return $null
        }
        $found = & $walk $j 0
        if ($null -ne $found) {
            return @{ Physical = [int]$found; Source = "run_manifest.json" }
        }
    } catch { }
    return $null
}

function Extract-FromConfigSnapshot {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $txt = Get-Content -Raw -Path $Path
        if ($txt -match 'switching_channel_physical["\s:=]+(\d+)') {
            return @{ Physical = [int]$Matches[1]; Source = "config_snapshot.m" }
        }
        if ($txt -match 'globalChannel["\s:=]+(\d+)') {
            return @{ Physical = [int]$Matches[1]; Source = "config_snapshot.m(globalChannel)" }
        }
    } catch { }
    return $null
}

function Extract-FromChannelIdentityValidation {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $rows = Import-Csv -Path $Path
        $row = $rows | Select-Object -First 1
        $uc = Try-ParseInt $row.unique_channels
        if ($null -eq $uc) { return $null }
        $rpc = "$($row.rows_per_channel)"
        $p = Get-PhysicalFromRowsPerChannel -RowsPerChannel $rpc -UniqueChannels $uc
        if ($null -ne $p) {
            return @{ Physical = $p; Source = "channel_identity_validation.csv ($Path)" }
        }
    } catch { }
    return $null
}

function Get-UniqueScalarPhysicalFromTable {
    param($Rows, [string]$Col)
    if (-not $Col) { return $null }
    $vals = @()
    foreach ($r in $Rows) {
        $cell = $r.$Col
        if ($null -eq $cell -or "$cell".Trim() -eq "") { continue }
        $p = Try-ParseInt $cell
        if ($null -ne $p) { $vals += $p }
    }
    $uniq = $vals | Sort-Object -Unique
    if ($uniq.Count -eq 1) { return $uniq[0] }
    return $null
}

function Extract-FromExistingCanonicalTables {
    param([string]$TablesDir)
    $targets = @(
        "switching_canonical_S_long.csv",
        "switching_canonical_observables.csv",
        "switching_canonical_phi1.csv"
    )
    foreach ($t in $targets) {
        $p = Join-Path $TablesDir $t
        if (-not (Test-Path $p)) { continue }
        try {
            $rows = Import-Csv -Path $p
            if (-not $rows) { continue }
            $cols = ($rows | Select-Object -First 1).PSObject.Properties.Name
            if ($cols -contains "switching_channel_physical") {
                $u = Get-UniqueScalarPhysicalFromTable -Rows $rows -Col "switching_channel_physical"
                if ($null -ne $u) {
                    return @{ Physical = $u; Source = "upstream_table:$t" }
                }
            }
        } catch { }
    }
    return $null
}

function Resolve-ChannelIdentity {
    param([string]$RunDir, [string]$RepoRoot, [switch]$AllowRepoScopedFallback)
    # Per-run only unless explicitly processing repo-level `tables/` (same RunDir as repo root).
    $r = Extract-FromExecutionStatusCsv (Join-Path $RunDir "execution_status.csv")
    if ($null -ne $r) { return (Resolve-ChannelIdentity-TryMap $r) }
    if ($AllowRepoScopedFallback) {
        $r = Extract-FromExecutionStatusCsv (Join-Path $RepoRoot "execution_status.csv")
        if ($null -ne $r) { return (Resolve-ChannelIdentity-TryMap $r) }
    }
    $r = Extract-FromManifestJson (Join-Path $RunDir "run_manifest.json")
    if ($null -ne $r) { return (Resolve-ChannelIdentity-TryMap $r) }
    $r = Extract-FromConfigSnapshot (Join-Path $RunDir "config_snapshot.m")
    if ($null -ne $r) { return (Resolve-ChannelIdentity-TryMap $r) }
    $r = Extract-FromExistingCanonicalTables (Join-Path $RunDir "tables")
    if ($null -ne $r) { return (Resolve-ChannelIdentity-TryMap $r) }
    $r = Extract-FromChannelIdentityValidation (Join-Path $RunDir "tables\channel_identity_validation.csv")
    if ($null -ne $r) { return (Resolve-ChannelIdentity-TryMap $r) }
    if ($AllowRepoScopedFallback) {
        $r = Extract-FromChannelIdentityValidation (Join-Path $RepoRoot "tables\channel_identity_validation.csv")
        if ($null -ne $r) { return (Resolve-ChannelIdentity-TryMap $r) }
    }
    return $null
}

function Resolve-ChannelIdentity-TryMap {
    param($r)
    try {
        $ct = Map-ChannelType -Physical $r.Physical
        return @{ Physical = $r.Physical; ChannelType = $ct; Source = $r.Source }
    }
    catch {
        return @{ Error = $_.Exception.Message; Source = $r.Source }
    }
}

function Test-NoBlankCellsInNewColumns {
    param($Rows, [string[]]$NewCols)
    foreach ($r in $Rows) {
        foreach ($c in $NewCols) {
            $v = $r.$c
            if ($null -eq $v -or "$v".Trim() -eq "") { return $false }
            if ("$v".Trim().ToUpper() -eq "NAN") { return $false }
        }
    }
    return $true
}

function Enrich-AndWriteWithChannel {
    param(
        [string]$SrcPath,
        [nullable[int]]$MetaPhysical,
        [string]$MetaChannelType,
        [string]$MetaSource
    )
    $name = Split-Path -Leaf $SrcPath
    $dir = Split-Path -Parent $SrcPath
    if ($name -notmatch '\.csv$') { throw "Expected CSV: $SrcPath" }
    $outName = ($name -replace '\.csv$', '_with_channel.csv')
    $outPath = Join-Path $dir $outName

    $rows = Import-Csv -Path $SrcPath
    $nIn = $rows.Count
    if ($nIn -eq 0) {
        return @{ Ok = $false; Reason = "empty_csv" }
    }
    $first = $rows | Select-Object -First 1
    $cols = @($first.PSObject.Properties.Name)
    $hasPhys = $cols -contains "switching_channel_physical"
    $hasType = $cols -contains "channel_type"

    $outRows = @(foreach ($r in $rows) {
            $o = [ordered]@{}
            foreach ($c in $cols) { $o[$c] = $r.$c }
            if (-not $hasPhys -and -not $hasType) {
                if ($null -eq $MetaPhysical) {
                    throw "Internal: missing metadata for $name"
                }
                $o["switching_channel_physical"] = "$($MetaPhysical)"
                $o["channel_type"] = $MetaChannelType
            }
            elseif ($hasPhys -and -not $hasType) {
                $p = Try-ParseInt $r.switching_channel_physical
                if ($null -eq $p) { throw "Invalid switching_channel_physical in $name" }
                $o["channel_type"] = (Map-ChannelType -Physical $p)
            }
            elseif (-not $hasPhys -and $hasType) {
                throw "channel_type without switching_channel_physical in $name"
            }
            else {
                # both exist - verify mapping
                $p = Try-ParseInt $r.switching_channel_physical
                if ($null -eq $p) { throw "Invalid switching_channel_physical in $name" }
                $expect = Map-ChannelType -Physical $p
                if ("$($r.channel_type)" -ne $expect) {
                    throw "channel_type mismatch for physical $p in $name (expected $expect, got $($r.channel_type))"
                }
            }
            [PSCustomObject]$o
        })

    $newCols = @("switching_channel_physical", "channel_type")
    if (-not (Test-NoBlankCellsInNewColumns -Rows $outRows -NewCols $newCols)) {
        return @{ Ok = $false; Reason = "blank_or_nan_in_channel_columns" }
    }

    # Integrity: original columns preserved (same names and cell values)
    $i = 0
    foreach ($r in $rows) {
        $w = $outRows[$i]
        foreach ($c in $cols) {
            if ("$($r.$c)" -ne "$($w.$c)") {
                return @{ Ok = $false; Reason = "original_column_changed:$c" }
            }
        }
        $i++
    }

    if ($outRows.Count -ne $nIn) {
        return @{ Ok = $false; Reason = "row_count_mismatch" }
    }

    # Channel columns consistency check
    $physVals = $outRows | ForEach-Object { Try-ParseInt $_.switching_channel_physical } | Where-Object { $null -ne $_ } | Sort-Object -Unique
    $typeVals = $outRows | ForEach-Object { "$($_.channel_type)" } | Sort-Object -Unique
    if ($physVals.Count -lt 1) { return @{ Ok = $false; Reason = "no_physical_values" } }
    if ($typeVals.Count -lt 1) { return @{ Ok = $false; Reason = "no_channel_type_values" } }

    $outRows | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8
    return @{
        Ok = $true
        OutPath = $outPath
        Rows = $nIn
        UniquePhysical = $physVals.Count
        UniqueTypes = $typeVals.Count
    }
}

# --- Main ---
$runsRoot = Join-Path $repoRoot "results\switching\runs"
$targets = @(
    "switching_canonical_S_long.csv",
    "switching_canonical_observables.csv",
    "switching_canonical_phi1.csv"
)

$runDirs = @()
if (Test-Path $runsRoot) {
    $runDirs = Get-ChildItem -Path $runsRoot -Directory -Filter "run_*" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
}

$tableRows = New-Object System.Collections.Generic.List[object]
$reportLines = New-Object System.Collections.Generic.List[string]
[void]$reportLines.Add("# Channel identity enforcement (Stage B)")
[void]$reportLines.Add("")
[void]$reportLines.Add("## Scope")
[void]$reportLines.Add("- Run directories: ``$runsRoot`` (child folders ``run_*``)")
[void]$reportLines.Add("- Target basenames: switching_canonical_S_long.csv, switching_canonical_observables.csv, switching_canonical_phi1.csv")
[void]$reportLines.Add("- Outputs: parallel ``*_with_channel.csv`` files only; **source CSVs are not modified.**")
[void]$reportLines.Add("")
[void]$reportLines.Add("## Runs processed")
[void]$reportLines.Add("")

$anyFailure = $false
$allOk = $true
$processedArtifacts = 0

function Process-OneRunLocation {
    param([string]$RunId, [string]$RunDir, [string]$RepoRoot)
    $tablesDir = Join-Path $RunDir "tables"
    $present = @()
    foreach ($t in $targets) {
        if (Test-Path (Join-Path $tablesDir $t)) { $present += $t }
    }
    if ($present.Count -eq 0) {
        [void]$script:reportLines.Add("### $RunId")
        [void]$script:reportLines.Add("- **Status:** SKIP (no target CSVs under ``tables``)")
        [void]$script:reportLines.Add("")
        $script:tableRows.Add([PSCustomObject]@{
                run_id            = $RunId
                files_processed   = 0
                channel_detected  = ""
                channel_type      = ""
                rows_verified     = 0
                status            = "SKIP_NO_TARGETS"
            })
        return
    }

    $allowRepo = ($RunId -eq "repo_tables")
    $id = Resolve-ChannelIdentity -RunDir $RunDir -RepoRoot $RepoRoot -AllowRepoScopedFallback:$allowRepo
    [void]$script:reportLines.Add("### $RunId")
    if ($null -eq $id -or $id.Error) {
        $msg = if ($id.Error) { $id.Error } else { "channel identity not found" }
        [void]$script:reportLines.Add("- **Status:** SKIP - $msg")
        [void]$script:reportLines.Add("- **Present files:** $($present -join ', ')")
        [void]$script:reportLines.Add("")
        $script:tableRows.Add([PSCustomObject]@{
                run_id            = $RunId
                files_processed   = 0
                channel_detected  = ""
                channel_type      = ""
                rows_verified     = 0
                status            = "SKIP_NO_CHANNEL_METADATA"
            })
        foreach ($t in $present) {
            $outName = ($t -replace '\.csv$', '_with_channel.csv')
            $wc = Join-Path $tablesDir $outName
            if (Test-Path -LiteralPath $wc) {
                Remove-Item -LiteralPath $wc -Force
                [void]$script:reportLines.Add("- **Removed unverifiable derived file:** $outName")
            }
        }
        [void]$script:reportLines.Add("")
        return
    }

    [void]$script:reportLines.Add("- **Channel source:** $($id.Source)")
    [void]$script:reportLines.Add("- **switching_channel_physical:** $($id.Physical)")
    [void]$script:reportLines.Add("- **channel_type:** $($id.ChannelType)")
    [void]$script:reportLines.Add("")

    $filesOk = 0
    $rowsTotal = 0
    $runAllOk = $true
    foreach ($t in $present) {
        $src = Join-Path $tablesDir $t
        try {
            $r = Enrich-AndWriteWithChannel -SrcPath $src -MetaPhysical $id.Physical -MetaChannelType $id.ChannelType -MetaSource $id.Source
            if (-not $r.Ok) {
                [void]$script:reportLines.Add("- **FAIL** $t - $($r.Reason)")
                $runAllOk = $false
                $script:allOk = $false
                continue
            }
            [void]$script:reportLines.Add("- **OK** $t -> $(Split-Path -Leaf $r.OutPath) (rows=$($r.Rows), unique physical=$($r.UniquePhysical), unique types=$($r.UniqueTypes))")
            $filesOk++
            $rowsTotal += [int]$r.Rows
            $script:processedArtifacts++
        }
        catch {
            [void]$script:reportLines.Add("- **FAIL** $t - $($_.Exception.Message)")
            $runAllOk = $false
            $script:allOk = $false
        }
    }

    $st = if ($filesOk -eq $present.Count -and $runAllOk) { "SUCCESS" } else { "PARTIAL_OR_FAIL" }
    if ($st -ne "SUCCESS") { $script:anyFailure = $true }

    $script:tableRows.Add([PSCustomObject]@{
            run_id            = $RunId
            files_processed   = $filesOk
            channel_detected  = "$($id.Physical)"
            channel_type      = "$($id.ChannelType)"
            rows_verified     = $rowsTotal
            status            = $st
        })
}

foreach ($rd in $runDirs) {
    $rid = Split-Path -Leaf $rd
    Process-OneRunLocation -RunId $rid -RunDir $rd -RepoRoot $repoRoot
}

# Repo-root tables (optional): same three basenames
$rootTables = Join-Path $repoRoot "tables"
$rootPresent = @()
foreach ($t in $targets) {
    if (Test-Path (Join-Path $rootTables $t)) { $rootPresent += $t }
}
if ($rootPresent.Count -gt 0) {
    Process-OneRunLocation -RunId "repo_tables" -RunDir $repoRoot -RepoRoot $repoRoot
}

if ($runDirs.Count -eq 0 -and $rootPresent.Count -eq 0) {
    [void]$reportLines.Add("(No ``results\switching\runs\run_*`` directories found and no repo ``tables\switching_canonical_*.csv`` targets present.)")
    [void]$reportLines.Add("")
    $tableRows.Add([PSCustomObject]@{
            run_id            = "_none_"
            files_processed   = 0
            channel_detected  = ""
            channel_type      = ""
            rows_verified     = 0
            status            = "NO_RUNS_OR_TARGETS"
        })
    $allOk = $false
}

$rowsForSummary = $tableRows | ForEach-Object { $_ }
$nSucc = ($rowsForSummary | Where-Object { $_.status -eq "SUCCESS" }).Count
$nSkipMeta = ($rowsForSummary | Where-Object { $_.status -eq "SKIP_NO_CHANNEL_METADATA" }).Count
$nSkipTgt = ($rowsForSummary | Where-Object { $_.status -eq "SKIP_NO_TARGETS" }).Count
[void]$reportLines.Add("## Summary")
[void]$reportLines.Add("")
[void]$reportLines.Add("- Runs with SUCCESS: **$nSucc**")
[void]$reportLines.Add("- Runs SKIP (targets present, channel metadata missing): **$nSkipMeta**")
[void]$reportLines.Add("- Runs SKIP (no target CSVs): **$nSkipTgt**")
[void]$reportLines.Add("- ``*_with_channel.csv`` files written this pass: **$processedArtifacts**")
[void]$reportLines.Add("")

[void]$reportLines.Add("## Missing metadata")
[void]$reportLines.Add("")
[void]$reportLines.Add("Runs with targets but no resolvable ``switching_channel_physical`` are **skipped** (no guessing, no inference from numeric data patterns). Accepted sources are **run-scoped**: extended ``execution_status.csv`` in that run, ``run_manifest.json``, ``config_snapshot.m``, existing channel columns in that run's canonical tables, and single-channel ``tables/channel_identity_validation.csv`` **in that run**. For repo-root ``tables/`` targets only, repo ``execution_status.csv`` and repo ``tables/channel_identity_validation.csv`` are allowed as fallbacks.")
[void]$reportLines.Add("")

$finalFlag = "NO"
if ($allOk -and -not $anyFailure -and $processedArtifacts -gt 0) {
    $finalFlag = "YES"
}

[void]$reportLines.Add("## Final criteria")
[void]$reportLines.Add("")
[void]$reportLines.Add("``````")
[void]$reportLines.Add("CHANNEL_IDENTITY_ENFORCED = $finalFlag")
[void]$reportLines.Add("``````")
[void]$reportLines.Add("")
if ($finalFlag -ne "YES") {
    [void]$reportLines.Add("*Set to YES only when at least one ``*_with_channel.csv`` was written, all writes passed integrity checks, and no enrichment attempt failed (runs skipped for missing metadata do not by themselves force NO).*")
}

$outTable = Join-Path $repoRoot "tables\channel_identity_enforcement.csv"
$outReport = Join-Path $repoRoot "reports\channel_identity_enforcement.md"
$tableRows | Export-Csv -Path $outTable -NoTypeInformation -Encoding UTF8
$reportLines -join "`r`n" | Set-Content -Path $outReport -Encoding UTF8

Write-Host "Wrote $outTable"
Write-Host "Wrote $outReport"
Write-Host "CHANNEL_IDENTITY_ENFORCED = $finalFlag"
