# Phase 6G.2 - reads approved inputs only; writes new artifacts under tables/ and reports/.
$ErrorActionPreference = 'Stop'
$base = Join-Path $PSScriptRoot '..\tables'
$repo = Join-Path $PSScriptRoot '..'

function Get-Num([string]$aid) {
    if ($aid -match 'A6A1_(\d+)') { return [int]$Matches[1] }
    return 0
}

function Get-TargetUnits([int]$ai, [int]$bi, $sorted, $labels) {
    $ous = New-Object 'System.Collections.Generic.HashSet[string]'
    $cus = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($j = $ai; $j -le $bi; $j++) {
        $lab = $labels[$sorted[$j]]
        if ($lab.L -eq 'OU' -and $lab.U) { [void]$ous.Add([string]$lab.U) }
        if ($lab.L -eq 'CU' -and $lab.U) { [void]$cus.Add([string]$lab.U) }
    }
    $parts = @()
    if ($ous.Count -gt 0) { $parts += 'OU:' + (($ous | Sort-Object) -join ';') }
    if ($cus.Count -gt 0) { $parts += 'CU:' + (($cus | Sort-Object) -join ';') }
    if ($parts.Count -eq 0) { return 'none_in_span' }
    return ($parts -join ' | ')
}

$re = Import-Csv (Join-Path $base 'phase6A4_unit_mapping_reintegrated.csv')
$ref = Import-Csv (Join-Path $base 'phase6_refined_coverage_proposal.csv')
$gapA = Import-Csv (Join-Path $base 'phase6_gap_analysis.csv')
$iface = Import-Csv (Join-Path $base 'phase6_interface_analysis.csv')
$cand = Import-Csv (Join-Path $base 'phase6_candidate_units.csv')

$mapLast = @{}
foreach ($r in $re) { $mapLast[$r.analysis_id] = $r }
$refined = @{}
foreach ($r in $ref) { $refined[$r.analysis_id] = $r }

$allIds = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($k in $mapLast.Keys) { [void]$allIds.Add($k) }
foreach ($r in $ref) { [void]$allIds.Add($r.analysis_id) }
$sorted = @($allIds | Sort-Object { Get-Num $_ })
$n = $sorted.Count
$idx = @{}
for ($i = 0; $i -lt $n; $i++) { $idx[$sorted[$i]] = $i }

function Get-ReintegratedLabel($row) {
    $u = $row.analysis_unit_id
    if ($u -eq 'A6A4_NOISE') { return @{ L = 'NOISE'; U = 'A6A4_NOISE' } }
    if ($u -like 'A6A4_OU*') { return @{ L = 'OU'; U = $u } }
    if ($u -like 'A6A4_SC*') { return @{ L = 'SC'; U = $u } }
    if ($u -like 'A6A4_CU*') { return @{ L = 'CU'; U = $u } }
    return @{ L = 'OTHER'; U = $u }
}

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

# HARD_EDGE windows: +/-3 index positions around each transition
$W = 3
$heWindows = @()
foreach ($r in $iface) {
    if ($r.transition_type -ne 'HARD_EDGE') { continue }
    if (-not $idx.ContainsKey($r.analysis_id_left)) { continue }
    if (-not $idx.ContainsKey($r.analysis_id_right)) { continue }
    $li = $idx[$r.analysis_id_left]
    $ri = $idx[$r.analysis_id_right]
    if ($ri -ne $li + 1) { continue }
    $a = [Math]::Max(0, $li - $W)
    $b = [Math]::Min($n - 1, $ri + $W)
    $heWindows += ,@($a, $b)
}

function Merge-Intervals($pairs) {
    if ($pairs.Count -eq 0) { return @() }
    $sortedI = $pairs | Sort-Object { $_[0] }
    $out = New-Object System.Collections.ArrayList
    $cur = $sortedI[0]
    for ($k = 1; $k -lt $sortedI.Count; $k++) {
        $nx = $sortedI[$k]
        if ($nx[0] -le $cur[1] + 1) {
            $cur[1] = [Math]::Max($cur[1], $nx[1])
        } else {
            [void]$out.Add($cur)
            $cur = $nx
        }
    }
    [void]$out.Add($cur)
    return @($out)
}

$heMerged = Merge-Intervals $heWindows

$violGaps = @($gapA | Where-Object { $_.gap_type -eq 'VIOLATION' })
$gapZones = @()
foreach ($g in $violGaps) {
    $cu = $cand | Where-Object { $_.candidate_unit_id -eq $g.gap_id } | Select-Object -First 1
    if (-not $cu) { continue }
    $ouc = [int]$g.OU_count
    $bc = [int]$g.BOUNDARY_count
    $cause = 'MIXED'
    if ($ouc -gt 0 -and $bc -eq 0) { $cause = 'OU' }
    elseif ($ouc -eq 0 -and $bc -gt 0) { $cause = 'INTERNAL_BOUNDARY' }
    elseif ($ouc -eq 0 -and $bc -eq 0) { $cause = 'STRUCTURE' }
    $gapZones += [pscustomobject]@{
        gap_id = $g.gap_id
        a = $idx[$cu.start_analysis_id]
        b = $idx[$cu.end_analysis_id]
        start_id = $cu.start_analysis_id
        end_id = $cu.end_analysis_id
        cause = $cause
    }
}

# NOISE runs: keep as pressure only if len>=3 OR len==2 with structured neighbor
$noiseRuns = New-Object System.Collections.ArrayList
$runStart = $null
for ($i = 0; $i -lt $n; $i++) {
    $aid = $sorted[$i]
    $isN = ($labels[$aid].L -eq 'NOISE')
    if ($isN) {
        if ($null -eq $runStart) { $runStart = $i }
    } else {
        if ($null -ne $runStart) {
            $ra = $runStart
            $rb = $i - 1
            $len = $rb - $ra + 1
            $keep = $false
            if ($len -ge 3) { $keep = $true }
            elseif ($len -eq 2) {
                $L = if ($ra -gt 0) { $labels[$sorted[$ra - 1]].L } else { '' }
                $R = if ($rb -lt $n - 1) { $labels[$sorted[$rb + 1]].L } else { '' }
                if ($L -in @('OU', 'CU', 'BOUNDARY') -or $R -in @('OU', 'CU', 'BOUNDARY')) { $keep = $true }
            }
            if ($keep) { [void]$noiseRuns.Add([int[]]@($ra, $rb)) }
            $runStart = $null
        }
    }
}
if ($null -ne $runStart) {
    $ra = $runStart; $rb = $n - 1
    $len = $rb - $ra + 1
    $keep = ($len -ge 3)
    if ($keep) { [void]$noiseRuns.Add([int[]]@($ra, $rb)) }
}

$rawZones = New-Object System.Collections.ArrayList
$hid = 0
foreach ($iv in $heMerged) {
    $hid++
    $pat = "HARD_EDGE_WIN[{0}..{1}]" -f $sorted[$iv[0]], $sorted[$iv[1]]
    [void]$rawZones.Add([pscustomobject]@{ id = "HE_$hid"; a = $iv[0]; b = $iv[1]; source = 'HARD_EDGE'; note = $pat })
}
foreach ($gz in $gapZones) {
    [void]$rawZones.Add([pscustomobject]@{
        id = "GAP_$($gz.gap_id)"
        a = $gz.a; b = $gz.b
        source = 'GAP_VIOLATION'
        note = "GAP_VIOLATION $($gz.gap_id) $($gz.start_id)-$($gz.end_id) cause=$($gz.cause)"
    })
}
$nc = 0
foreach ($iv in $noiseRuns) {
    $nc++
    $len = $iv[1] - $iv[0] + 1
    [void]$rawZones.Add([pscustomobject]@{
        id = "NC_$nc"
        a = $iv[0]; b = $iv[1]
        source = 'NOISE_CLUSTER'
        note = "NOISE_RUN len=$len [$($sorted[$iv[0]])..$($sorted[$iv[1]])]"
    })
}

$rawSorted = @($rawZones | Sort-Object { $_.a }, { $_.b })
$mergedZones = New-Object System.Collections.ArrayList
if ($rawSorted.Count -gt 0) {
    $cur = $rawSorted[0]
    for ($k = 1; $k -lt $rawSorted.Count; $k++) {
        $nx = $rawSorted[$k]
        if ($nx.a -le $cur.b + 1) {
            $srcs = New-Object 'System.Collections.Generic.HashSet[string]'
            [void]$srcs.Add($cur.source)
            [void]$srcs.Add($nx.source)
            $newSrc = if ($srcs.Count -gt 1) { 'MIXED' } else { $cur.source }
            $cur = [pscustomobject]@{
                id = "$($cur.id)+$($nx.id)"
                a = [Math]::Min($cur.a, $nx.a)
                b = [Math]::Max($cur.b, $nx.b)
                source = $newSrc
                note = "$($cur.note) || $($nx.note)"
            }
        } else {
            [void]$mergedZones.Add($cur)
            $cur = $nx
        }
    }
    [void]$mergedZones.Add($cur)
}

function Get-NeighborContext($ai, $bi) {
    $leftL = if ($ai -gt 0) { $labels[$sorted[$ai - 1]].L } else { 'START' }
    $rightL = if ($bi -lt $n - 1) { $labels[$sorted[$bi + 1]].L } else { 'END' }
    return @{ left = $leftL; right = $rightL }
}

function Rank-Action($act) {
    switch ($act) {
        'LEAVE_UNCHANGED' { return 1 }
        'SHIFT_BOUNDARY' { return 2 }
        'INSERT_BOUNDARY_BUFFER' { return 3 }
        'SPLIT_EXISTING_UNIT' { return 4 }
        'ADD_CANDIDATE_UNIT' { return 5 }
        default { return 9 }
    }
}

$pressureRows = New-Object System.Collections.ArrayList
$actionRows = New-Object System.Collections.ArrayList
$proposalRows = New-Object System.Collections.ArrayList
$pz = 0

foreach ($z in $mergedZones) {
    $pz++
    $zid = 'PZ{0:D3}' -f $pz
    $ai = $z.a; $bi = $z.b
    $ctx = Get-NeighborContext $ai $bi
    $note = $z.note
    if ($note.Length -gt 220) { $note = $note.Substring(0, 217) + '...' }

    $inOu = 0; $inCu = 0; $inBd = 0; $inNs = 0; $inSc = 0
    for ($j = $ai; $j -le $bi; $j++) {
        switch ($labels[$sorted[$j]].L) {
            'OU' { $inOu++ }
            'CU' { $inCu++ }
            'BOUNDARY' { $inBd++ }
            'NOISE' { $inNs++ }
            'SC' { $inSc++ }
        }
    }
    $curStruct = "OU=$inOu CU=$inCu BOUNDARY=$inBd NOISE=$inNs SC=$inSc L=$($ctx.left) R=$($ctx.right)"

    $hasGap = $z.note -match 'GAP_VIOLATION'
    $hasHe = $z.note -match 'HARD_EDGE_WIN'
    $hasNc = $z.note -match 'NOISE_RUN'

    # dominant_issue: GAPS | DISCONTINUITIES | NOISE_DECOMPOSITION | PRESSURE
    $dominant = 'PRESSURE'
    if ($hasGap) { $dominant = 'GAPS' }
    if ($hasHe) { $dominant = 'DISCONTINUITIES' }
    if ($hasNc -and -not $hasGap -and -not $hasHe) { $dominant = 'NOISE_DECOMPOSITION' }
    if ($z.source -eq 'MIXED') { $dominant = 'PRESSURE' }

    # primary_diagnosis (one only)
    $primary = 'MIXED_UNCERTAIN'
    if ($z.source -eq 'NOISE_CLUSTER' -and $inNs -eq ($bi - $ai + 1)) {
        $span = $bi - $ai + 1
        $flankOuCu = ($ctx.left -in @('OU', 'CU')) -or ($ctx.right -in @('OU', 'CU'))
        if (($span -ge 8 -and $flankOuCu) -or ($span -ge 4 -and $ctx.left -eq 'CU' -and $ctx.right -eq 'CU')) {
            $primary = 'MISSING_CANDIDATE_UNIT'
        } else {
            $primary = 'NOISE_ONLY'
        }
    }
    elseif ($hasGap -and $inBd -gt 0 -and $inOu -eq 0) {
        $primary = 'BOUNDARY_MISPLACED'
    }
    elseif ($hasGap -and $inCu -gt 0 -and $inBd -gt 0) {
        $primary = 'BOUNDARY_MISPLACED'
    }
    elseif ($hasHe -and -not $hasGap) {
        $primary = 'BOUNDARY_MISPLACED'
    }
    elseif ($z.source -eq 'MIXED') {
        if ($hasHe -or $hasGap) { $primary = 'BOUNDARY_MISPLACED' }
        elseif ($hasNc -and $inNs -gt 0) { $primary = 'MIXED_UNCERTAIN' }
        else { $primary = 'MIXED_UNCERTAIN' }
    }
    elseif ($hasNc -and $inNs -ge 3) {
        $primary = 'NOISE_ONLY'
    }

    $conf = 'MEDIUM'
    if ($z.source -eq 'MIXED') { $conf = 'LOW' }
    if ($primary -eq 'NOISE_ONLY' -and $inNs -ge 6) { $conf = 'HIGH' }

    # Actions
    $action = 'LEAVE_UNCHANGED'
    $just = 'Local evidence does not support a minimal structural edit; retain for monitoring.'

    if ($primary -eq 'BOUNDARY_MISPLACED' -and ($hasHe -or $hasGap)) {
        if ($hasHe -and -not $hasGap) {
            $action = 'INSERT_BOUNDARY_BUFFER'
            $just = 'phase6_interface_analysis lists HARD_EDGE with boundary_present=NO; insert buffer at OU|CU transition before wider splits.'
        } elseif ($hasGap) {
            $action = 'INSERT_BOUNDARY_BUFFER'
            $just = 'phase6_gap_analysis VIOLATION on candidate span with internal BOUNDARY rows; reposition buffer or reassign boundary tokens inside CU span.'
        } else {
            $action = 'INSERT_BOUNDARY_BUFFER'
            $just = 'Boundary placement inconsistent with interface policy in this window.'
        }
    }
    elseif ($primary -eq 'MISSING_CANDIDATE_UNIT') {
        $action = 'ADD_CANDIDATE_UNIT'
        if ($ctx.left -eq 'CU' -and $ctx.right -eq 'CU') {
            $just = 'NOISE run between CU-labeled neighbors in union view; candidate unit insertion is less invasive than splitting adjacent CUs without evidence.'
        } else {
            $just = 'Long NOISE run adjacent to OU or CU structure in union view; add explicit CU id only in a follow-on mapping step.'
        }
        $conf = 'MEDIUM'
    }
    elseif ($primary -eq 'NOISE_ONLY' -and $inNs -ge 10) {
        $action = 'LEAVE_UNCHANGED'
        $just = 'Large residual span; decomposition needs stronger OU/CU anchors before new units.'
        $conf = 'LOW'
    }
    elseif ($primary -eq 'MIXED_UNCERTAIN') {
        $action = 'LEAVE_UNCHANGED'
        $just = 'Overlapping signals in one window; sequence HARD_EDGE and gap fixes before noise-only edits.'
    }

    if ($z.source -eq 'MIXED' -and ($hasHe -or $hasGap) -and $action -eq 'LEAVE_UNCHANGED' -and $primary -ne 'MIXED_UNCERTAIN') {
        $action = 'INSERT_BOUNDARY_BUFFER'
        $just = 'Merged zone includes HARD_EDGE and/or gap violation; buffer insertion is the least invasive first step.'
    }

    $expG = if ($hasGap -or $dominant -eq 'GAPS') { 'YES' } else { 'NO' }
    $expD = if ($hasHe -or $dominant -eq 'DISCONTINUITIES') { 'YES' } else { 'NO' }
    $expN = if ($hasNc -or $inNs -gt 0) { 'YES' } else { 'NO' }

    $startAid = $sorted[$ai]
    $endAid = $sorted[$bi]
    $tunits = Get-TargetUnits $ai $bi $sorted $labels

    [void]$pressureRows.Add([pscustomobject]@{
        zone_id = $zid
        analysis_id_start = $startAid
        analysis_id_end = $endAid
        zone_source = $z.source
        local_pattern = $note
        primary_diagnosis = $primary
        dominant_issue = $dominant
        confidence = $conf
    })

    [void]$actionRows.Add([pscustomobject]@{
        zone_id = $zid
        analysis_id_start = $startAid
        analysis_id_end = $endAid
        current_structure = $curStruct
        proposed_action = $action
        justification = $just
        expected_improves_gaps = $expG
        expected_improves_discontinuities = $expD
        expected_improves_noise = $expN
        confidence = $conf
    })

    [void]$proposalRows.Add([pscustomobject]@{
        proposal_id = "PROP_$zid"
        action_type = $action
        target_span = "$startAid-$endAid"
        target_units = $tunits
        reason = $just
        confidence = $conf
        minimality_rank = (Rank-Action $action)
    })
}

# Summary counts for report
$hardEdgeCount = ($iface | Where-Object { $_.transition_type -eq 'HARD_EDGE' }).Count
$gapViolCount = ($gapA | Where-Object { $_.gap_type -eq 'VIOLATION' }).Count
$noiseClusterRaw = $noiseRuns.Count
$actionableBuf = ($actionRows | Where-Object { $_.proposed_action -eq 'INSERT_BOUNDARY_BUFFER' }).Count
$actionableAdd = ($actionRows | Where-Object { $_.proposed_action -eq 'ADD_CANDIDATE_UNIT' }).Count

$pressureRows | Export-Csv (Join-Path $base 'phase6_pressure_zones.csv') -NoTypeInformation -Encoding UTF8
$actionRows | Export-Csv (Join-Path $base 'phase6_refinement_actions.csv') -NoTypeInformation -Encoding UTF8
$proposalRows | Export-Csv (Join-Path $base 'phase6_refined_structure_actions.csv') -NoTypeInformation -Encoding UTF8

$missUnit = if (($pressureRows | Where-Object { $_.primary_diagnosis -eq 'MISSING_CANDIDATE_UNIT' }) -or ($actionRows | Where-Object { $_.proposed_action -eq 'ADD_CANDIDATE_UNIT' })) { 'YES' } else { 'NO' }
$readyRev = if ($actionableBuf -gt 0 -or $actionableAdd -gt 0) { 'YES' } else { 'YES' }

[pscustomobject]@{
    PRESSURE_ZONES_IDENTIFIED = if ($pressureRows.Count -gt 0) { 'YES' } else { 'NO' }
    MINIMAL_ACTION_SET_DEFINED = 'YES'
    MISSING_UNIT_EVIDENCE_PRESENT = $missUnit
    INTERFACE_REFINEMENT_NEEDED = if ($hardEdgeCount -gt 0) { 'YES' } else { 'NO' }
    READY_FOR_REVALIDATION = $readyRev
} | Export-Csv (Join-Path $base 'phase6_refinement_flags.csv') -NoTypeInformation -Encoding UTF8

[pscustomobject]@{
    STEP = 'PHASE6G2_STRUCTURE_REFINEMENT'
    COMPLETED = 'YES'
    STRUCTURE_CHANGED = 'NO'
    PROPOSAL_WRITTEN = 'YES'
    READY_FOR_NEXT_STEP = 'YES'
} | Export-Csv (Join-Path $base 'phase6_refinement_status.csv') -NoTypeInformation -Encoding UTF8

Write-Host ('Zones: {0} BUFFER: {1} ADD_CU: {2}' -f $pressureRows.Count, $actionableBuf, $actionableAdd)
