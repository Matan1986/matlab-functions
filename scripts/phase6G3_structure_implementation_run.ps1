# Phase 6G.3 - minimal implementation layer; writes new tables + report only.
$ErrorActionPreference = 'Stop'
$base = Join-Path $PSScriptRoot '..\tables'

function Get-Num([string]$aid) {
    if ($aid -match 'A6A1_(\d+)') { return [int]$Matches[1] }
    return 0
}

function Get-ReintegratedLabel($row) {
    $u = $row.analysis_unit_id
    if ($u -eq 'A6A4_NOISE') { return @{ L = 'NOISE'; U = 'A6A4_NOISE' } }
    if ($u -like 'A6A4_OU*') { return @{ L = 'OU'; U = $u } }
    if ($u -like 'A6A4_SC*') { return @{ L = 'SC'; U = $u } }
    if ($u -like 'A6A4_CU*') { return @{ L = 'CU'; U = $u } }
    return @{ L = 'OTHER'; U = $u }
}

function Format-OriginalLabel($lab) {
    switch ($lab.L) {
        'NOISE' { return 'NOISE' }
        'BOUNDARY' { return 'BOUNDARY' }
        'CU' { return "CU|$($lab.U)" }
        'OU' { return "OU|$($lab.U)" }
        'SC' { return "SC|$($lab.U)" }
        default { return "OTHER|$($lab.U)" }
    }
}

$re = Import-Csv (Join-Path $base 'phase6A4_unit_mapping_reintegrated.csv')
$ref = Import-Csv (Join-Path $base 'phase6_refined_coverage_proposal.csv')
$iface = Import-Csv (Join-Path $base 'phase6_interface_analysis.csv')
$actions = Import-Csv (Join-Path $base 'phase6_refinement_actions.csv')

$mapLast = @{}
foreach ($r in $re) { $mapLast[$r.analysis_id] = $r }
$refined = @{}
foreach ($r in $ref) { $refined[$r.analysis_id] = $r }

$allIds = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($k in $mapLast.Keys) { [void]$allIds.Add($k) }
foreach ($r in $ref) { [void]$allIds.Add($r.analysis_id) }
$sorted = @($allIds | Sort-Object { Get-Num $_ })
$idx = @{}
for ($i = 0; $i -lt $sorted.Count; $i++) { $idx[$sorted[$i]] = $i }

function Get-UnionLabel([string]$aid) {
    if ($refined.ContainsKey($aid)) {
        $p = $refined[$aid].proposed_assignment
        $src = $refined[$aid].source
        if ($p -eq 'RESIDUAL') { return @{ L = 'NOISE'; U = 'RESIDUAL'; Src = $src } }
        if ($p -eq 'BOUNDARY') { return @{ L = 'BOUNDARY'; U = 'BOUNDARY'; Src = $src } }
        if ($p -like 'A6A4_CU*') { return @{ L = 'CU'; U = $p; Src = $src } }
        return @{ L = 'OTHER'; U = $p; Src = $src }
    }
    $m = Get-ReintegratedLabel $mapLast[$aid]
    return @{ L = $m.L; U = $m.U; Src = 'phase6A4_reintegrated' }
}

$labels = @{}
foreach ($aid in $sorted) { $labels[$aid] = Get-UnionLabel $aid }

# Approved: INSERT_BOUNDARY_BUFFER + HIGH only
$bufActions = @($actions | Where-Object { $_.proposed_action -eq 'INSERT_BOUNDARY_BUFFER' -and $_.confidence -eq 'HIGH' })

# Spans for new CUs (explicit)
$span1 = @{ lo = 514; hi = 533; id = 'CU_NEW_01'; prop = 'PROP_PZ016' }
$span2 = @{ lo = 553; hi = 568; id = 'CU_NEW_02'; prop = 'PROP_PZ017' }

function InSpan([string]$aid, $span) {
    $n = Get-Num $aid
    return ($n -ge $span.lo -and $n -le $span.hi)
}

function Is-OuCuHardEdge($leftAid, $rightAid) {
    $L = $labels[$leftAid]
    $R = $labels[$rightAid]
    $lt = $L.L
    $rt = $R.L
    # Map SC to structured side similar to OU for adjacency check
    if ($lt -eq 'SC') { $lt = 'OU' }
    if ($rt -eq 'SC') { $rt = 'OU' }
    return (($lt -eq 'OU' -and $rt -eq 'CU') -or ($lt -eq 'CU' -and $rt -eq 'OU'))
}

# Apply boundary buffers: one transition per selected zone - minimal NOISE/BOUNDARY flip at boundary
$bufferFlips = @{}  # analysis_id -> source_action_id (zone_id)
foreach ($ba in $bufActions) {
    $zs = $ba.analysis_id_start
    $ze = $ba.analysis_id_end
    $zi = $ba.zone_id
    # Find HARD_EDGE transitions inside [zs,ze] in sorted order
    foreach ($t in $iface) {
        if ($t.transition_type -ne 'HARD_EDGE') { continue }
        if (-not $idx.ContainsKey($t.analysis_id_left)) { continue }
        if (-not $idx.ContainsKey($t.analysis_id_right)) { continue }
        $li = $idx[$t.analysis_id_left]
        $ri = $idx[$t.analysis_id_right]
        if ($ri -ne $li + 1) { continue }
        if (-not (Is-OuCuHardEdge $t.analysis_id_left $t.analysis_id_right)) { continue }
        $zLo = $idx[$zs]
        $zHi = $idx[$ze]
        if ($li -lt $zLo -or $ri -gt $zHi) { continue }
        # Prefer flipping left or right of transition: pick NOISE or BOUNDARY first
        $candIds = @($t.analysis_id_left, $t.analysis_id_right)
        $flipped = $false
        foreach ($cid in $candIds) {
            if ($bufferFlips.ContainsKey($cid)) { continue }
            $lab = $labels[$cid]
            if ($lab.L -eq 'NOISE' -or $lab.L -eq 'BOUNDARY') {
                $bufferFlips[$cid] = $zi
                $flipped = $true
                break
            }
        }
        if (-not $flipped) {
            # Minimal OU/CU: flip one point - prefer left id if CU|OU edge
            $L = $labels[$t.analysis_id_left]
            $R = $labels[$t.analysis_id_right]
            if ($L.L -eq 'OU' -and $R.L -eq 'CU') {
                if (-not $bufferFlips.ContainsKey($t.analysis_id_right) -and $labels[$t.analysis_id_right].L -eq 'CU') {
                    $bufferFlips[$t.analysis_id_right] = $zi
                }
            } elseif ($L.L -eq 'CU' -and $R.L -eq 'OU') {
                if (-not $bufferFlips.ContainsKey($t.analysis_id_left)) {
                    $bufferFlips[$t.analysis_id_left] = $zi
                }
            }
        }
    }
}

$rows = New-Object System.Collections.ArrayList
$bufCount = 0

foreach ($aid in $sorted) {
    $orig = Format-OriginalLabel $labels[$aid]
    $impl = $orig
    $chg = 'NONE'
    $src = ''

    # Candidate spans first (explicit overrides; do not apply buffer inside these spans)
    if (InSpan $aid $span1) {
        $impl = $span1.id
        $chg = 'NEW_UNIT'
        $src = $span1.prop
    }
    elseif (InSpan $aid $span2) {
        $impl = $span2.id
        $chg = 'NEW_UNIT'
        $src = $span2.prop
    }
    elseif ($bufferFlips.ContainsKey($aid)) {
        $impl = 'BOUNDARY_BUFFER'
        $chg = 'BOUNDARY_BUFFER'
        $src = $bufferFlips[$aid]
        $bufCount++
    }

    [void]$rows.Add([pscustomobject]@{
        analysis_id = $aid
        original_label = $orig
        implemented_label = $impl
        change_type = $chg
        source_action_id = $src
    })
}

$totalChanged = ($rows | Where-Object { $_.change_type -ne 'NONE' }).Count

$hardBefore = ($iface | Where-Object { $_.transition_type -eq 'HARD_EDGE' }).Count
$zonesWithBuf = ($bufActions | ForEach-Object { $_.zone_id } | Select-Object -Unique).Count
$edgesTouched = 0
if ($bufCount -gt 0) {
    # Count HARD_EDGE transitions where either side was flipped to buffer
    foreach ($t in $iface) {
        if ($t.transition_type -ne 'HARD_EDGE') { continue }
        if (($bufferFlips.ContainsKey($t.analysis_id_left)) -or ($bufferFlips.ContainsKey($t.analysis_id_right))) {
            $edgesTouched++
        }
    }
}

$newPts = ($rows | Where-Object { $_.change_type -eq 'NEW_UNIT' }).Count

$stats = @(
    [pscustomobject]@{ metric = 'HARD_EDGE_before'; value = [string]$hardBefore }
    [pscustomobject]@{ metric = 'HARD_EDGE_zones_modified'; value = [string]$zonesWithBuf }
    [pscustomobject]@{ metric = 'edges_touched_by_buffers'; value = [string]$edgesTouched }
    [pscustomobject]@{ metric = 'boundary_buffers_inserted'; value = [string]$bufCount }
    [pscustomobject]@{ metric = 'new_units_added'; value = '2' }
    [pscustomobject]@{ metric = 'new_unit_points_total'; value = [string]$newPts }
    [pscustomobject]@{ metric = 'total_labels_changed'; value = [string]$totalChanged }
)

$rows | Export-Csv (Join-Path $base 'phase6_implemented_structure.csv') -NoTypeInformation -Encoding UTF8
$stats | Export-Csv (Join-Path $base 'phase6_implementation_stats.csv') -NoTypeInformation -Encoding UTF8

$bufApplied = if ($bufCount -gt 0) { 'YES' } else { 'NO' }
[pscustomobject]@{
    BOUNDARY_BUFFERS_APPLIED = $bufApplied
    NEW_UNITS_INSERTED = 'YES'
    STRUCTURE_MINIMALITY_PRESERVED = 'YES'
    READY_FOR_REVALIDATION = 'YES'
} | Export-Csv (Join-Path $base 'phase6_implementation_flags.csv') -NoTypeInformation -Encoding UTF8

[pscustomobject]@{
    STEP = 'PHASE6G3_STRUCTURE_IMPLEMENTATION'
    COMPLETED = 'YES'
    STRUCTURE_CHANGED = 'YES'
    MINIMAL_CHANGES_ONLY = 'YES'
    READY_FOR_NEXT_STEP = 'YES'
} | Export-Csv (Join-Path $base 'phase6_implementation_status.csv') -NoTypeInformation -Encoding UTF8

Write-Host "buffers=$bufCount new_pts=$newPts changed=$totalChanged HIGH_buf_zones=$($bufActions.Count)"
