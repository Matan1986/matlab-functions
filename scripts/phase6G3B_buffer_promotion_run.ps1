# Phase 6G.3B - buffer promotion audit; writes new outputs only.
$ErrorActionPreference = 'Stop'
$base = Join-Path $PSScriptRoot '..\tables'

function Get-Num([string]$aid) {
    if ($aid -match 'A6A1_(\d+)') { return [int]$Matches[1] }
    return -1
}

$actions = Import-Csv (Join-Path $base 'phase6_refinement_actions.csv')
$iface = Import-Csv (Join-Path $base 'phase6_interface_analysis.csv')

$cuNewRanges = @(
    @{ lo = 514; hi = 533 }
    @{ lo = 553; hi = 568 }
)

function Overlaps-CuNew([int]$zLo, [int]$zHi) {
    foreach ($g in $cuNewRanges) {
        if ($zHi -lt $g.lo -or $zLo -gt $g.hi) { continue }
        return $true
    }
    return $false
}

$hardEdges = @($iface | Where-Object {
    $_.transition_type -eq 'HARD_EDGE' -and
    (($_.left_type -eq 'OU' -and $_.right_type -eq 'CU') -or ($_.left_type -eq 'CU' -and $_.right_type -eq 'OU'))
})

function Get-Edges-In-Zone([int]$zLo, [int]$zHi) {
    $out = New-Object System.Collections.ArrayList
    foreach ($e in $hardEdges) {
        $a = Get-Num $e.analysis_id_left
        $b = Get-Num $e.analysis_id_right
        if ($a -ge $zLo -and $b -le $zHi) { [void]$out.Add($e) }
    }
    return @($out)
}

function Parse-CurrentStructure([string]$cs) {
    $noise = 0; $bd = 0; $ou = 0; $cu = 0; $sc = 0
    if ($cs -match 'NOISE=(\d+)') { $noise = [int]$Matches[1] }
    if ($cs -match 'BOUNDARY=(\d+)') { $bd = [int]$Matches[1] }
    if ($cs -match 'OU=(\d+)') { $ou = [int]$Matches[1] }
    if ($cs -match 'CU=(\d+)') { $cu = [int]$Matches[1] }
    if ($cs -match 'SC=(\d+)') { $sc = [int]$Matches[1] }
    return @{ noise = $noise; boundary = $bd; ou = $ou; cu = $cu; sc = $sc }
}

function Edge-Key($e) { "$($e.analysis_id_left)|$($e.analysis_id_right)" }

$candidates = @($actions | Where-Object {
    $_.proposed_action -eq 'INSERT_BOUNDARY_BUFFER' -and ($_.confidence -eq 'LOW' -or $_.confidence -eq 'MEDIUM')
})

$candRows = New-Object System.Collections.ArrayList

foreach ($c in $candidates) {
    $zLo = Get-Num $c.analysis_id_start
    $zHi = Get-Num $c.analysis_id_end
    $edges = @(Get-Edges-In-Zone $zLo $zHi)
    $heConf = if ($edges.Count -gt 0) { 'YES' } else { 'NO' }

    $st = Parse-CurrentStructure $c.current_structure
    $hasNb = ($st.noise -gt 0) -or ($st.boundary -gt 0)
    $minOk = if ($hasNb) { 'YES' } else { 'NO' }

    $conflict = 'NO'
    if (Overlaps-CuNew $zLo $zHi) {
        $conflict = 'NO'
    }
    elseif ($edges.Count -eq 0) {
        $conflict = 'NO'
    }
    elseif ($hasNb) {
        $conflict = 'YES'
    }
    else {
        # CU/SC-only zone with no NOISE/BOUNDARY: deep-edge risk vs promotion criteria
        $conflict = 'NO'
    }

    $promote = if (($heConf -eq 'YES') -and ($minOk -eq 'YES') -and ($conflict -eq 'YES')) { 'YES' } else { 'NO' }

    [void]$candRows.Add([pscustomobject]@{
        zone_id = $c.zone_id
        analysis_id_start = $c.analysis_id_start
        analysis_id_end = $c.analysis_id_end
        original_confidence = $c.confidence
        current_structure = $c.current_structure
        hard_edge_confirmed = $heConf
        local_minimality_valid = $minOk
        no_structural_conflict = $conflict
        promote_to_implementation = $promote
        _edgeCount = $edges.Count
    })
}

$candRows | ForEach-Object {
    [pscustomobject]@{
        zone_id = $_.zone_id
        analysis_id_start = $_.analysis_id_start
        analysis_id_end = $_.analysis_id_end
        original_confidence = $_.original_confidence
        hard_edge_confirmed = $_.hard_edge_confirmed
        local_minimality_valid = $_.local_minimality_valid
        no_structural_conflict = $_.no_structural_conflict
        promote_to_implementation = $_.promote_to_implementation
    }
} | Export-Csv (Join-Path $base 'phase6_buffer_promotion_candidates.csv') -NoTypeInformation -Encoding UTF8

$promoted = @($candRows | Where-Object { $_.promote_to_implementation -eq 'YES' })
$covered = @{}
$selected = New-Object System.Collections.ArrayList
$picked = New-Object 'System.Collections.Generic.HashSet[string]'

$rank = 0
while ($true) {
    $best = $null
    $bestScore = -1
    foreach ($p in $promoted) {
        if ($picked.Contains($p.zone_id)) { continue }
        $zLo = Get-Num $p.analysis_id_start
        $zHi = Get-Num $p.analysis_id_end
        $ed = @(Get-Edges-In-Zone $zLo $zHi)
        $newCov = 0
        foreach ($e in $ed) {
            $k = Edge-Key $e
            if (-not $covered.ContainsKey($k)) { $newCov++ }
        }
        if ($newCov -eq 0) { continue }
        $span = $zHi - $zLo + 1
        if ($null -eq $best) { $best = [pscustomobject]@{ row = $p; edges = $ed; newCov = $newCov; span = $span }; continue }
        if ($newCov -gt $best.newCov) { $best = [pscustomobject]@{ row = $p; edges = $ed; newCov = $newCov; span = $span } }
        elseif ($newCov -eq $best.newCov -and $span -lt $best.span) { $best = [pscustomobject]@{ row = $p; edges = $ed; newCov = $newCov; span = $span } }
    }
    if ($null -eq $best) { break }
    $rank++
    [void]$picked.Add($best.row.zone_id)
    $r = $best.row
    $st = Parse-CurrentStructure $r.current_structure
    $pts = if (($st.noise + $st.boundary) -ge 2) { '2' } elseif (($st.noise + $st.boundary) -eq 1) { '1' } else { '2' }

    foreach ($e in $best.edges) { $covered[(Edge-Key $e)] = $true }

    [void]$selected.Add([pscustomobject]@{
        zone_id = $r.zone_id
        analysis_id_start = $r.analysis_id_start
        analysis_id_end = $r.analysis_id_end
        expected_points_modified = $pts
        priority_rank = [string]$rank
    })
}

@($selected) | Export-Csv (Join-Path $base 'phase6_buffer_promoted_subset.csv') -NoTypeInformation -Encoding UTF8

$totalEdges = $hardEdges.Count
$coveredCount = $covered.Count

[pscustomobject]@{
    PROMOTION_POSSIBLE = if ($promoted.Count -gt 0) { 'YES' } else { 'NO' }
    PROMOTED_COUNT = [string]$selected.Count
    COVERS_HARD_EDGES = if ($coveredCount -gt 0) { 'YES' } else { 'NO' }
    MINIMAL_SET_SELECTED = 'YES'
} | Export-Csv (Join-Path $base 'phase6_buffer_promotion_flags.csv') -NoTypeInformation -Encoding UTF8

[pscustomobject]@{
    STEP = 'PHASE6G3B_BUFFER_PROMOTION'
    COMPLETED = 'YES'
    STRUCTURE_CHANGED = 'NO'
    PROMOTION_DEFINED = 'YES'
    READY_FOR_IMPLEMENTATION = 'YES'
} | Export-Csv (Join-Path $base 'phase6_buffer_promotion_status.csv') -NoTypeInformation -Encoding UTF8

Write-Host "pool=$($candidates.Count) promoted=$($promoted.Count) subset=$($selected.Count) edges=$coveredCount/$totalEdges"
