# Phase 6E — Unit Refinement Discovery (read-only inputs -> new artifacts only)
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
Set-Location $root

function Get-AnalysisSuffix([string]$analysisId) {
    return [int]($analysisId -split '_')[1]
}

function Is-OuOrSc([string]$unitId) {
    if ($unitId -eq 'A6A4_NOISE' -or [string]::IsNullOrEmpty($unitId)) { return $false }
    return ($unitId -match '^A6A4_OU') -or ($unitId -match '^A6A4_SC')
}

$mapPath = Join-Path $root 'tables\phase6A4_unit_mapping_reintegrated_v2.csv'
$ambPath = Join-Path $root 'tables\phase6_mapping_ambiguous_v2.csv'
$anomPath = Join-Path $root 'tables\phase6_unit_anomalies.csv'
$distPath = Join-Path $root 'tables\phase6_mapping_unit_distribution_v2.csv'

$rows = Import-Csv $mapPath | ForEach-Object {
    [PSCustomObject]@{
        analysis_id        = $_.analysis_id
        analysis_unit_id   = $_.analysis_unit_id
        Suffix             = (Get-AnalysisSuffix $_.analysis_id)
    }
} | Sort-Object Suffix

$suffixToRow = @{}
foreach ($r in $rows) { $suffixToRow[$r.Suffix] = $r }

$ambiguousSet = @{}
Import-Csv $ambPath | ForEach-Object { $ambiguousSet[$_.analysis_id] = $true }

# --- 1) NOISE contiguous blocks (sorted by numeric suffix) ---
$noiseBlocks = [System.Collections.Generic.List[object]]::new()
$i = 0
while ($i -lt $rows.Count) {
    if ($rows[$i].analysis_unit_id -ne 'A6A4_NOISE') { $i++; continue }
    $start = $i
    $sSuf = $rows[$i].Suffix
    while ($i + 1 -lt $rows.Count -and $rows[$i + 1].analysis_unit_id -eq 'A6A4_NOISE' -and $rows[$i + 1].Suffix -eq ($rows[$i].Suffix + 1)) {
        $i++
    }
    $eSuf = $rows[$i].Suffix
    $bsize = $i - $start + 1
    $winLo = $sSuf - 5
    $winHi = $eSuf + 5
    $winCount = ($rows | Where-Object { $_.Suffix -ge $winLo -and $_.Suffix -le $winHi }).Count
    if ($winCount -lt 1) { $winCount = 1 }
    $density = [math]::Round($bsize / $winCount, 6)
    $cls = if ($bsize -le 2) { 'small' } elseif ($bsize -le 4) { 'medium' } else { 'large' }
    $noiseBlocks.Add([PSCustomObject]@{
            start_analysis_id = $rows[$start].analysis_id
            end_analysis_id   = $rows[$i].analysis_id
            start_suf         = $sSuf
            end_suf           = $eSuf
            block_size        = $bsize
            local_density     = $density
            classification    = $cls
        })
    $i++
}

# --- 2) Cluster NOISE blocks (proximity + size similarity) ---
$sortedBlocks = @($noiseBlocks | Sort-Object start_suf)
$nBlk = $sortedBlocks.Count
$UF = [int[]]::new($nBlk)
for ($u = 0; $u -lt $nBlk; $u++) { $UF[$u] = $u }

function Get-UfRoot([int[]]$par, [int]$x) {
    while ($par[$x] -ne $x) { $x = $par[$x] }
    return $x
}

function Merge-Uf([int[]]$par, [int]$a, [int]$b) {
    $ra = Get-UfRoot $par $a
    $rb = Get-UfRoot $par $b
    if ($ra -ne $rb) { $par[$ra] = $rb }
}

for ($a = 0; $a -lt $nBlk; $a++) {
    for ($b = $a + 1; $b -lt $nBlk; $b++) {
        $ba = $sortedBlocks[$a]
        $bb = $sortedBlocks[$b]
        if ($bb.start_suf - $ba.end_suf -gt 80) { break }
        $gap = if ($bb.start_suf -gt $ba.end_suf) { $bb.start_suf - $ba.end_suf - 1 } else { 0 }
        $sizeDiff = [math]::Abs($ba.block_size - $bb.block_size)
        $prox = ($gap -le 25)
        $simSize = ($sizeDiff -le 1) -or ($ba.block_size -eq $bb.block_size)
        if ($prox -and $simSize) {
            Merge-Uf $UF $a $b
        }
    }
}

$clusterMap = @{}
for ($ix = 0; $ix -lt $nBlk; $ix++) {
    $r = Get-UfRoot $UF $ix
    if (-not $clusterMap.ContainsKey($r)) { $clusterMap[$r] = [System.Collections.Generic.List[int]]::new() }
    $clusterMap[$r].Add($ix)
}

$clusterRows = [System.Collections.Generic.List[object]]::new()
$cid = 0
foreach ($kv in ($clusterMap.GetEnumerator() | Sort-Object { [int]$_.Name })) {
    $idxs = $kv.Value
    $blocksInC = @($idxs | ForEach-Object { $sortedBlocks[$_] })
    $numB = $idxs.Count
    $avgSz = [math]::Round(($blocksInC | Measure-Object -Property block_size -Average).Average, 4)
    $totCov = ($blocksInC | Measure-Object -Property block_size -Sum).Sum
    $sizes = @($blocksInC | ForEach-Object { $_.block_size })
    $grp = $sizes | Group-Object | Sort-Object Count -Descending
    $maxSame = if ($grp) { $grp[0].Count } else { 0 }
    $span = ($blocksInC | Measure-Object -Property end_suf -Maximum).Maximum - ($blocksInC | Measure-Object -Property start_suf -Minimum).Minimum + 1
    $pattern = 'region'
    if ($numB -eq 1) { $pattern = 'isolated' }
    elseif ($numB -ge 2 -and ($maxSame -ge 2 -or (($grp | Where-Object { $_.Count -ge 2 }).Count -gt 0))) { $pattern = 'repeated' }
    elseif ($numB -ge 2) { $pattern = 'region' }
    $cid++
    $clusterRows.Add([PSCustomObject]@{
            cluster_id       = "C$($cid.ToString('000'))"
            num_blocks       = $numB
            avg_block_size   = $avgSz
            total_coverage   = $totCov
            pattern_type     = $pattern
        })
}

# --- 3) Large blocks: missing unit candidates ---
$missing = [System.Collections.Generic.List[object]]::new()
foreach ($b in $noiseBlocks) {
    if ($b.block_size -lt 5) { continue }
    $predUnit = $null
    $succUnit = $null
    for ($s = $b.start_suf - 1; $s -ge ($rows[0].Suffix); $s--) {
        if ($suffixToRow.ContainsKey($s)) {
            $predUnit = $suffixToRow[$s].analysis_unit_id
            break
        }
    }
    for ($s = $b.end_suf + 1; $s -le ($rows[-1].Suffix); $s++) {
        if ($suffixToRow.ContainsKey($s)) {
            $succUnit = $suffixToRow[$s].analysis_unit_id
            break
        }
    }
    $reason = ''
    $isCand = $false
    if ($predUnit -and $succUnit -and $predUnit -eq $succUnit -and $predUnit -ne 'A6A4_NOISE') {
        $isCand = $true
        $reason = "MISSING_UNIT_CANDIDATE: same OU/SC both sides ($predUnit)"
    }
    elseif ((-not $predUnit -or $predUnit -eq 'A6A4_NOISE') -and (-not $succUnit -or $succUnit -eq 'A6A4_NOISE')) {
        $isCand = $true
        $reason = 'MISSING_UNIT_CANDIDATE: isolated region (no OU/SC neighbor)'
    }
    elseif ($predUnit -eq 'A6A4_NOISE' -and $succUnit -eq 'A6A4_NOISE') {
        $isCand = $true
        $reason = 'MISSING_UNIT_CANDIDATE: embedded in NOISE / weak context'
    }
    if ($isCand) {
        $ctx = "between $(if($predUnit){$predUnit}else{'<none>'}) and $(if($succUnit){$succUnit}else{'<none>'})"
        $missing.Add([PSCustomObject]@{
                start_analysis_id = $b.start_analysis_id
                end_analysis_id   = $b.end_analysis_id
                size              = $b.block_size
                context           = $ctx
                reason            = $reason
            })
    }
}

# --- 4) COVERAGE_GAP analysis ---
$gapRows = [System.Collections.Generic.List[object]]::new()
$gapId = 0
Import-Csv $anomPath | Where-Object { $_.anomaly_type -eq 'COVERAGE_GAP' } | ForEach-Object {
    $gapId++
    $s0 = Get-AnalysisSuffix $_.start_analysis_id
    $s1 = Get-AnalysisSuffix $_.end_analysis_id
    $inRange = @($rows | Where-Object { $_.Suffix -ge $s0 -and $_.Suffix -le $s1 })
    # Inclusive span in analysis_id suffix space (matches anomaly run-length semantics)
    $len = [math]::Max($s1 - $s0 + 1, $inRange.Count)
    $hasOu = $false
    $nNoise = 0
    $nAmb = 0
    foreach ($r in $inRange) {
        if (Is-OuOrSc $r.analysis_unit_id) { $hasOu = $true }
        if ($r.analysis_unit_id -eq 'A6A4_NOISE') { $nNoise++ }
        if ($ambiguousSet.ContainsKey($r.analysis_id)) { $nAmb++ }
    }
    $gtype = if ($hasOu) { 'MIXED' } else { 'PURE' }
    $gapRows.Add([PSCustomObject]@{
            gap_id            = "G$($gapId.ToString('000'))"
            start_analysis_id = $_.start_analysis_id
            end_analysis_id   = $_.end_analysis_id
            length            = $len
            gap_type          = $gtype
        })
}

# --- 5) Ambiguous vs NOISE ---
$ambStruct = [System.Collections.Generic.List[object]]::new()
Import-Csv $ambPath | ForEach-Object {
    $aid = $_.analysis_id
    $suf = Get-AnalysisSuffix $aid
    $bestDist = [int]::MaxValue
    $bestBlock = $null
    foreach ($nb in $noiseBlocks) {
        if ($suf -lt $nb.start_suf) { $d = $nb.start_suf - $suf }
        elseif ($suf -gt $nb.end_suf) { $d = $suf - $nb.end_suf }
        else { $d = 0 }
        if ($d -lt $bestDist) {
            $bestDist = $d
            $bestBlock = "$($nb.start_analysis_id)-$($nb.end_analysis_id)"
        }
    }
    $cls = if ($bestDist -le 2) { 'BOUNDARY' } else { 'ISOLATED' }
    $ambStruct.Add([PSCustomObject]@{
            analysis_id         = $aid
            classification      = $cls
            nearest_noise_block = $bestBlock
        })
}

# --- 6) Unit pressure ---
$dist = Import-Csv $distPath
$highThreshold = 50
$pressureRows = [System.Collections.Generic.List[object]]::new()
foreach ($drow in $dist) {
    $uid = $drow.analysis_unit_id
    if ($uid -eq 'A6A4_NOISE') { continue }
    $cnt = [int]$drow.count
    $adj = 0
    foreach ($nb in $noiseBlocks) {
        $near = $false
        for ($s = $nb.start_suf - 2; $s -le $nb.end_suf + 2; $s++) {
            if (-not $suffixToRow.ContainsKey($s)) { continue }
            if ($suffixToRow[$s].analysis_unit_id -eq $uid) { $near = $true; break }
        }
        if ($near) { $adj++ }
    }
    $flag = if ($cnt -ge $highThreshold -and $adj -ge 1) { 'YES' } else { 'NO' }
    $pressureRows.Add([PSCustomObject]@{
            unit_id               = $uid
            assignment_count      = $cnt
            adjacent_noise_blocks = $adj
            pressure_flag         = $flag
        })
}

# --- Status row (interpretation) ---
$anoms = Import-Csv $anomPath
$disc = ($anoms | Where-Object { $_.anomaly_type -eq 'DISCONTINUITY' }).Count
$noiseHasStructure = if (($clusterRows | Where-Object { $_.pattern_type -ne 'isolated' }).Count -gt 0) { 'YES' } else { 'NO' }
$missingDetected = if ($missing.Count -gt 0) { 'YES' } else { 'NO' }
$boundaryShare = if ($ambStruct.Count -gt 0) { ($ambStruct | Where-Object { $_.classification -eq 'BOUNDARY' }).Count / $ambStruct.Count } else { 0 }
$boundaryInst = 'NO'
if ($boundaryShare -ge 0.35) { $boundaryInst = 'YES' }
if ($disc -ge 5) { $boundaryInst = 'YES' }
$overload = if (($pressureRows | Where-Object { $_.pressure_flag -eq 'YES' }).Count -gt 0) { 'YES' } else { 'NO' }
$ready = if ($missingDetected -eq 'YES' -or $noiseHasStructure -eq 'YES' -or $boundaryInst -eq 'YES' -or $overload -eq 'YES') { 'YES' } else { 'NO' }

# --- Write CSVs ---
$outNoise = Join-Path $root 'tables\phase6_noise_blocks.csv'
$noiseBlocks | ForEach-Object {
    [PSCustomObject]@{
        start_analysis_id = $_.start_analysis_id
        end_analysis_id   = $_.end_analysis_id
        block_size        = $_.block_size
        local_density     = $_.local_density
        classification    = $_.classification
    }
} | Export-Csv -NoTypeInformation -Encoding UTF8 $outNoise

$clusterRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $root 'tables\phase6_noise_clusters.csv')

$missing | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $root 'tables\phase6_missing_unit_candidates.csv')

$gapRows | Select-Object gap_id, start_analysis_id, end_analysis_id, length, gap_type | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $root 'tables\phase6_gap_analysis.csv')

$ambStruct | ForEach-Object {
    [PSCustomObject]@{
        analysis_id         = $_.analysis_id
        classification      = if ($_.classification -eq 'BOUNDARY') { 'BOUNDARY' } else { 'ISOLATED' }
        nearest_noise_block = $_.nearest_noise_block
    }
} | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $root 'tables\phase6_ambiguous_structure.csv')

$pressureRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $root 'tables\phase6_unit_pressure.csv')

[PSCustomObject]@{
    NOISE_HAS_STRUCTURE     = $noiseHasStructure
    MISSING_UNITS_DETECTED  = $missingDetected
    BOUNDARY_INSTABILITY    = $boundaryInst
    UNIT_OVERLOAD_PRESENT   = $overload
    READY_FOR_REFACTOR      = $ready
} | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $root 'tables\phase6_refinement_status.csv')

Write-Host "Done. Blocks: $($noiseBlocks.Count) Clusters: $($clusterRows.Count)"
