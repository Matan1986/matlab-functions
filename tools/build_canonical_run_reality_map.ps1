# Read-only scan: results/switching/runs/run_* -> tables/canonical_run_reality_map.csv
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$base = Join-Path $repoRoot 'results\switching\runs'
$outCsv = Join-Path $repoRoot 'tables\canonical_run_reality_map.csv'

function Test-MappingConsistent {
    param([string]$p, [string]$t)
    if ($p -eq '1' -and $t -eq 'XY') { return $true }
    if (($p -eq '2' -or $p -eq '3') -and $t -eq 'XX') { return $true }
    return $false
}

function Get-ChannelIdentityFromRun {
    param([string]$root)
    $tbl = Join-Path $root 'tables'
    if (-not (Test-Path $tbl)) { return $null }
    $files = @(Get-ChildItem $tbl -Filter '*.csv' -ErrorAction SilentlyContinue | Where-Object {
            $h = Get-Content $_.FullName -TotalCount 1 -ErrorAction SilentlyContinue
            ($h -match 'switching_channel_physical') -and ($h -match 'channel_type')
        })
    if ($files.Count -lt 1) { return $null }
    $aggPhys = [System.Collections.Generic.HashSet[string]]::new()
    $aggTyp = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($f in $files) {
        try {
            $rows = Import-Csv $f.FullName
        } catch {
            continue
        }
        if (-not $rows) { continue }
        $phys = @($rows | ForEach-Object { $_.switching_channel_physical } | Where-Object { $_ -ne '' -and $null -ne $_ })
        $typ = @($rows | ForEach-Object { $_.channel_type } | Where-Object { $_ -ne '' -and $null -ne $_ })
        foreach ($x in ($phys | Sort-Object -Unique)) { [void]$aggPhys.Add([string]$x) }
        foreach ($x in ($typ | Sort-Object -Unique)) { [void]$aggTyp.Add([string]$x) }
    }
    return [PSCustomObject]@{ aggPhys = $aggPhys; aggTyp = $aggTyp }
}

$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('run_id,has_data,channel_known,channel_value,channel_type,is_consistent,classification')

$stats = @{ VALID = 0; AMBIGUOUS = 0; INVALID = 0 }
$lists = @{ VALID = [System.Collections.ArrayList]::new(); AMBIGUOUS = [System.Collections.ArrayList]::new(); INVALID = [System.Collections.ArrayList]::new() }

Get-ChildItem $base -Directory | Where-Object { $_.Name -like 'run_*' } | Sort-Object Name | ForEach-Object {
    $runId = $_.Name
    $root = $_.FullName
    $longPath = Join-Path $root 'tables\switching_canonical_S_long.csv'
    $hasData = $false
    if (Test-Path $longPath) {
        $nlines = (Get-Content $longPath | Measure-Object -Line).Lines
        $hasData = ($nlines -ge 2)
    }
    $hd = if ($hasData) { 'TRUE' } else { 'FALSE' }

    $chKnown = 'FALSE'
    $chVal = ''
    $chType = ''
    $cons = 'NA'

    $id = Get-ChannelIdentityFromRun $root

    if ($null -ne $id) {
        # Do not use Sort-Object on string arrays: PowerShell may split a single "XY" into chars.
        $physList = @($id.aggPhys | ForEach-Object { [string]$_ })
        $typList = @($id.aggTyp | ForEach-Object { [string]$_ })
        if ($physList.Count -gt 1) { [Array]::Sort($physList) }
        if ($typList.Count -gt 1) { [Array]::Sort($typList) }
        $physOk = ($physList.Count -eq 1) -and ($physList[0] -match '^[1234]$')
        $typOk = ($typList.Count -eq 1) -and ($typList[0] -in @('XX', 'XY'))

        if ($physOk -and $typOk) {
            $chKnown = 'TRUE'
            $chVal = [string]$physList[0]
            $chType = [string]$typList[0]
            $mc = Test-MappingConsistent -p $chVal -t $chType
            $cons = if ($mc) { 'TRUE' } else { 'FALSE' }
        } elseif (($physList.Count -gt 1) -or ($typList.Count -gt 1)) {
            $chKnown = 'TRUE'
            $chVal = $physList -join '|'
            $chType = $typList -join '|'
            $cons = 'FALSE'
        }
    }

    $class = 'INVALID'
    if (-not $hasData) {
        $class = 'INVALID'
        if ($cons -eq 'NA') { $cons = 'FALSE' }
    } elseif ($chKnown -eq 'TRUE' -and $cons -eq 'TRUE') {
        $class = 'VALID'
    } elseif ($chKnown -eq 'FALSE') {
        $class = 'AMBIGUOUS'
        $cons = 'NA'
    } else {
        $class = 'INVALID'
    }

    $stats[$class]++
    [void]$lists[$class].Add($runId)

    [void]$lines.Add("$runId,$hd,$chKnown,$chVal,$chType,$cons,$class")
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($outCsv, $lines, $utf8)

Write-Output "Wrote $outCsv"
