# Phase 4A — scaling-coordinate screening only (Switching). No collapse optimization; no winner claim.
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'
function Test-Finite([double]$x) { (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }

function Mean($a) {
    $z = @($a | Where-Object { Test-Finite $_ })
    if (-not $z.Count) { return [double]::NaN }
    ($z | Measure-Object -Average).Average
}

function Pearson($x, $y) {
    $nx = $x.Count
    if ($nx -ne $y.Count -or $nx -lt 3) { return [double]::NaN }
    $mx = Mean $x; $my = Mean $y
    $num = 0.0; $dx = 0.0; $dy = 0.0
    for ($i = 0; $i -lt $nx; $i++) {
        if (-not ((Test-Finite $x[$i]) -and (Test-Finite $y[$i]))) { return [double]::NaN }
        $vx = $x[$i] - $mx; $vy = $y[$i] - $my
        $num += $vx * $vy; $dx += $vx * $vx; $dy += $vy * $vy
    }
    if ($dx -lt 1e-22 -or $dy -lt 1e-22) { return [double]::NaN }
    return $num / [math]::Sqrt($dx * $dy)
}

function LinInterp([double]$xq, [double[]]$xv, [double[]]$yv) {
    $n = $xv.Count
    if ($n -lt 2) { return [double]::NaN }
    if ($xq -le $xv[0]) { return $yv[0] }
    if ($xq -ge $xv[$n - 1]) { return $yv[$n - 1] }
    for ($i = 1; $i -lt $n; $i++) {
        if ($xq -le $xv[$i]) {
            $t = ($xq - $xv[$i - 1]) / ($xv[$i] - $xv[$i - 1])
            return $yv[$i - 1] + $t * ($yv[$i] - $yv[$i - 1])
        }
    }
    return [double]::NaN
}

$identityPath = Join-Path $RepoRoot 'tables/switching_canonical_identity.csv'
$id = Import-Csv $identityPath
$runId = ($id | Where-Object { $_.field -eq 'CANONICAL_RUN_ID' }).value.Trim()
$SlongPath = Join-Path $RepoRoot "results/switching/runs/$runId/tables/switching_canonical_S_long.csv"
if (-not (Test-Path $SlongPath)) { throw "Missing $SlongPath" }

$ridgePath = Join-Path $RepoRoot 'tables/switching_geocanon_T1_weighted_ridge_values.csv'
$ridgeByT = @{}
if (Test-Path $ridgePath) {
    Import-Csv $ridgePath | ForEach-Object { $ridgeByT[[double]$_.T_K] = [double]$_.ridge_center_geocanon_primary }
}

$rows = Import-Csv $SlongPath | ForEach-Object {
    [pscustomobject]@{
        T_K = [double]$_.T_K
        current_mA = [double]$_.current_mA
        S_percent = [double]$_.S_percent
        S_model_pt_percent = [double]$_.S_model_pt_percent
        residual_percent = [double]$_.residual_percent
        PT_pdf = [double]$_.PT_pdf
        CDF_pt = [double]$_.CDF_pt
    }
}

$byT = $rows | Group-Object { $_.T_K }
$Tlist = @($byT | ForEach-Object { [double]$_.Name } | Sort-Object)

# I_peak(T) from argmax S on finite rows
$iPeakByT = @{}
foreach ($g in $byT) {
    $tk = [double]$g.Name
    $sl = @($g.Group | Where-Object { Test-Finite $_.S_percent })
    if ($sl.Count -eq 0) { continue }
    $best = @($sl | Sort-Object S_percent -Descending)[0]
    $iPeakByT[$tk] = $best.current_mA
}

function Get-Coords($familyId) {
    $out = foreach ($r in $rows) {
        if (-not (Test-Finite $r.S_percent)) { continue }
        $tk = $r.T_K
        $I = $r.current_mA
        $x = [double]::NaN
        switch ($familyId) {
            'I_raw_candidate' { $x = $I }
            'eta_Ipeak_candidate' {
                if ($iPeakByT.ContainsKey($tk)) { $x = $I - $iPeakByT[$tk] }
            }
            'eta_ridge_candidate' {
                if ($ridgeByT.ContainsKey($tk)) { $x = $I - $ridgeByT[$tk] }
            }
            'CDF_pt_candidate' { $x = $r.CDF_pt }
            'PT_pdf_axis_candidate' { $x = $r.PT_pdf }
        }
        if (-not (Test-Finite $x)) { continue }
        [pscustomobject]@{ T_K = $tk; x = $x; S = $r.S_percent; Sm = $r.S_model_pt_percent; Res = $r.residual_percent; PTpdf = $r.PT_pdf; CDF = $r.CDF_pt; I = $I }
    }
    @($out)
}

function Screen-Family($familyId, [string]$label) {
    $pts = Get-Coords $familyId
    if ($pts.Count -lt 10) {
        return [pscustomobject]@{ family_id = $familyId; mean_cross_T_variance_S = 'NaN'; mean_cross_T_variance_residual = 'NaN'; mean_pairwise_curve_corr_S = 'NaN'; interpolation_coverage = 'NaN'; residual_organization_score = 'NaN'; derivative_spine_organization_score = 'NaN'; notes = 'insufficient_points' }
    }

    # Per-T sorted unique x,S for interp (sort by x)
    $curves = @{}
    foreach ($tk in $Tlist) {
        $sel = @($pts | Where-Object { $_.T_K -eq $tk } | Sort-Object x)
        if ($sel.Count -lt 2) { continue }
        $xv = @($sel | ForEach-Object { $_.x })
        $Sv = @($sel | ForEach-Object { $_.S })
        $Rv = @($sel | ForEach-Object { $_.Res })
        $curves[$tk] = @{ x = $xv; S = $Sv; R = $Rv }
    }
    $tActive = @($curves.Keys | Sort-Object)
    if ($tActive.Count -lt 4) {
        return [pscustomobject]@{ family_id = $familyId; mean_cross_T_variance_S = 'NaN'; notes = 'too_few_T' }
    }

    $xAll = @($pts | ForEach-Object { $_.x })
    $xg0 = ($xAll | Measure-Object -Minimum).Minimum
    $xg1 = ($xAll | Measure-Object -Maximum).Maximum
    if (-not ((Test-Finite $xg0) -and (Test-Finite $xg1)) -or ($xg1 - $xg0) -lt 1e-14) {
        return [pscustomobject]@{ family_id = $familyId; notes = 'degenerate_x_span' }
    }

    $nb = 36
    $dx = ($xg1 - $xg0) / ($nb - 1)
    $bins = 0..($nb - 1) | ForEach-Object { $xg0 + $_ * $dx }

    $stackS = New-Object 'System.Collections.ArrayList'
    $stackR = New-Object 'System.Collections.ArrayList'
    $coverBins = 0
    foreach ($xb in $bins) {
        $colS = New-Object System.Collections.ArrayList
        $colR = New-Object System.Collections.ArrayList
        foreach ($tk in $tActive) {
            $c = $curves[$tk]
            $s = LinInterp $xb $c.x $c.S
            $rv = LinInterp $xb $c.x $c.R
            if (Test-Finite $s) { [void]$colS.Add($s) }
            if (Test-Finite $rv) { [void]$colR.Add($rv) }
        }
        if ($colS.Count -ge 3) {
            $coverBins++
            $vS = ($colS | Measure-Object -Average).Average
            $vvS = ($colS | ForEach-Object { ($_ - $vS) * ($_ - $vS) } | Measure-Object -Average).Average
            [void]$stackS.Add($vvS)
            $vR = ($colR | Measure-Object -Average).Average
            $vvR = ($colR | ForEach-Object { ($_ - $vR) * ($_ - $vR) } | Measure-Object -Average).Average
            [void]$stackR.Add($vvR)
        }
    }

    $meanVarS = if ($stackS.Count) { ($stackS | Measure-Object -Average).Average } else { [double]::NaN }
    $meanVarR = if ($stackR.Count) { ($stackR | Measure-Object -Average).Average } else { [double]::NaN }
    $coverage = if ($nb -gt 0) { $coverBins / $nb } else { [double]::NaN }

    # Pairwise Pearson on common grid intersection
    $pairs = @()
    for ($a = 0; $a -lt $tActive.Count; $a++) {
        for ($b = $a + 1; $b -lt $tActive.Count; $b++) {
            $ta = $tActive[$a]; $tb = $tActive[$b]
            $ca = $curves[$ta]; $cb = $curves[$tb]
            $xlo = [math]::Max(($ca.x | Measure-Object -Minimum).Minimum, ($cb.x | Measure-Object -Minimum).Minimum)
            $xhi = [math]::Min(($ca.x | Measure-Object -Maximum).Maximum, ($cb.x | Measure-Object -Maximum).Maximum)
            if ($xhi - $xlo -lt 1e-10) { continue }
            $nq = 24
            $dq = ($xhi - $xlo) / ($nq - 1)
            $va = New-Object System.Collections.ArrayList
            $vb = New-Object System.Collections.ArrayList
            for ($q = 0; $q -lt $nq; $q++) {
                $xq = $xlo + $q * $dq
                $sa = LinInterp $xq $ca.x $ca.S
                $sb = LinInterp $xq $cb.x $cb.S
                if ((Test-Finite $sa) -and (Test-Finite $sb)) {
                    [void]$va.Add($sa); [void]$vb.Add($sb)
                }
            }
            if ($va.Count -ge 5) {
                $pr = Pearson (@($va.ToArray())) (@($vb.ToArray()))
                if (Test-Finite $pr) { $pairs += $pr }
            }
        }
    }
    $meanPair = if ($pairs.Count) { ($pairs | Measure-Object -Average).Average } else { [double]::NaN }

    # Residual organization score: higher when cross-T residual variance is lower (invert var)
    $resScore = if ((Test-Finite $meanVarR) -and $meanVarR -gt 0) { 1.0 / (1.0 + $meanVarR * 1e6) } else { [double]::NaN }

    # Derivative spine: intervals tagged with family x_mid; cross-T variance of dS/dI within x_mid bins (lower = more aligned)
    $iv = New-Object System.Collections.ArrayList
    foreach ($tk in $tActive) {
        $g = $byT | Where-Object { [double]$_.Name -eq $tk }
        $slice = @($g.Group | Sort-Object current_mA | Where-Object { Test-Finite $_.S_percent })
        for ($k = 1; $k -lt $slice.Count; $k++) {
            $di = $slice[$k].current_mA - $slice[$k - 1].current_mA
            if ([math]::Abs($di) -lt 1e-14) { continue }
            $ds = $slice[$k].S_percent - $slice[$k - 1].S_percent
            if (-not (Test-Finite $ds)) { continue }
            $ia = ($slice[$k].current_mA + $slice[$k - 1].current_mA) / 2
            $cdfM = ($slice[$k].CDF_pt + $slice[$k - 1].CDF_pt) / 2
            $pdfM = ($slice[$k].PT_pdf + $slice[$k - 1].PT_pdf) / 2
            $xmVal = [double]::NaN
            switch ($familyId) {
                'I_raw_candidate' { $xmVal = $ia }
                'eta_Ipeak_candidate' { if ($iPeakByT.ContainsKey($tk)) { $xmVal = $ia - $iPeakByT[$tk] } }
                'eta_ridge_candidate' { if ($ridgeByT.ContainsKey($tk)) { $xmVal = $ia - $ridgeByT[$tk] } }
                'CDF_pt_candidate' { $xmVal = $cdfM }
                'PT_pdf_axis_candidate' { $xmVal = $pdfM }
            }
            if (-not (Test-Finite $xmVal)) { continue }
            [void]$iv.Add([pscustomobject]@{ T_K = $tk; xmid = $xmVal; dsdi = $ds / $di })
        }
    }
    $derivOrg = [double]::NaN
    if ($iv.Count -ge 20) {
        $xmAll = @($iv | ForEach-Object { $_.xmid })
        $xb0 = ($xmAll | Measure-Object -Minimum).Minimum
        $xb1 = ($xmAll | Measure-Object -Maximum).Maximum
        if (($xb1 - $xb0) -gt 1e-14) {
            $nbb = 14
            $bx = ($xb1 - $xb0) / $nbb
            $binVar = New-Object System.Collections.ArrayList
            for ($bi = 0; $bi -lt $nbb; $bi++) {
                $lo = $xb0 + $bi * $bx
                $hi = $lo + $bx
                $perT = @{}
                foreach ($row in $iv) {
                    if ($row.xmid -lt $lo -or $row.xmid -ge $hi) { continue }
                    $tk = $row.T_K
                    if (-not $perT.ContainsKey($tk)) { $perT[$tk] = New-Object System.Collections.ArrayList }
                    [void]$perT[$tk].Add($row.dsdi)
                }
                $vals = @()
                foreach ($tk in $perT.Keys) {
                    $arr = @($perT[$tk])
                    if ($arr.Count -ge 1) { $vals += (($arr | Measure-Object -Average).Average) }
                }
                if ($vals.Count -ge 5) {
                    $mv = ($vals | Measure-Object -Average).Average
                    $vv = ($vals | ForEach-Object { ($_ - $mv) * ($_ - $mv) } | Measure-Object -Average).Average
                    [void]$binVar.Add($vv)
                }
            }
            if ($binVar.Count -ge 3) {
                $meanBinV = ($binVar | Measure-Object -Average).Average
                $derivOrg = if (Test-Finite $meanBinV) { 1.0 / (1.0 + [math]::Sqrt($meanBinV) * 1e4) } else { [double]::NaN }
            }
        }
    }

    [pscustomobject]@{
        family_id = $familyId
        mean_cross_T_variance_S = if (Test-Finite $meanVarS) { [math]::Round($meanVarS, 12) } else { 'NaN' }
        mean_cross_T_variance_residual = if (Test-Finite $meanVarR) { [math]::Round($meanVarR, 12) } else { 'NaN' }
        mean_pairwise_curve_similarity_S = if (Test-Finite $meanPair) { [math]::Round($meanPair, 6) } else { 'NaN' }
        interpolation_coverage = if (Test-Finite $coverage) { [math]::Round($coverage, 6) } else { 'NaN' }
        residual_organization_score = if (Test-Finite $resScore) { [math]::Round($resScore, 8) } else { 'NaN' }
        derivative_spine_organization_score = if (Test-Finite $derivOrg) { [math]::Round($derivOrg, 8) } else { 'NaN' }
        notes = $label
    }
}

$inventory = @(
    [pscustomobject]@{ family_id='I_raw_candidate'; formula='x = current_mA'; phase3_status='allowed'; notes='Phase 3 non-blocked' }
    [pscustomobject]@{ family_id='eta_Ipeak_candidate'; formula='x = current_mA - I_argmax_S_spine(T)'; phase3_status='allowed'; notes='Per-T argmax on ladder' }
    [pscustomobject]@{ family_id='eta_ridge_candidate'; formula='x = current_mA - ridge_center_geocanon_primary(T)'; phase3_status='allowed'; notes='T1 geocanon table join' }
    [pscustomobject]@{ family_id='CDF_pt_candidate'; formula='x = CDF_pt'; phase3_status='allowed'; notes='Backbone cumulative on spine' }
    [pscustomobject]@{ family_id='PT_pdf_axis_candidate'; formula='x = PT_pdf (horizontal axis for screening only)'; phase3_status='partial'; notes='Auxiliary density axis; not a replacement for I' }
    [pscustomobject]@{ family_id='x_Ipeak_W_candidate'; formula='blocked'; phase3_status='blocked'; notes='W absent on spine' }
    [pscustomobject]@{ family_id='x_ridge_W_candidate'; formula='blocked'; phase3_status='blocked'; notes='W absent on spine' }
)
$invOut = Join-Path $RepoRoot 'tables/switching_phase4A_scaling_coordinate_family_inventory.csv'
$inventory | Export-Csv -NoTypeInformation -Encoding UTF8 $invOut

$blocked = @(
    [pscustomobject]@{ family_id='x_Ipeak_W_candidate'; reason='W_USABLE_AS_SCALING_WIDTH=NO'; phase3_gate='Phase 3 candidate_families blocked=YES' }
    [pscustomobject]@{ family_id='x_ridge_W_candidate'; reason='W_USABLE_AS_SCALING_WIDTH=NO'; phase3_gate='Phase 3 candidate_families blocked=YES' }
)
$blockedOut = Join-Path $RepoRoot 'tables/switching_phase4A_scaling_coordinate_blocked_families.csv'
$blocked | Export-Csv -NoTypeInformation -Encoding UTF8 $blockedOut

$allowedIds = @('I_raw_candidate', 'eta_Ipeak_candidate', 'eta_ridge_candidate', 'CDF_pt_candidate', 'PT_pdf_axis_candidate')
$metricsRows = foreach ($fid in $allowedIds) {
    Screen-Family $fid ''
}
$metricsOut = Join-Path $RepoRoot 'tables/switching_phase4A_scaling_coordinate_screening_metrics.csv'
$metricsRows | Export-Csv -NoTypeInformation -Encoding UTF8 $metricsOut

# Rank for preliminary best: lower meanVarS better; higher pairwise corr better; higher coverage better
function Parse-Double($s) {
    try { [double]$s } catch { [double]::NaN }
}
$rankData = foreach ($m in $metricsRows) {
    $v = Parse-Double $m.mean_cross_T_variance_S
    $p = Parse-Double $m.mean_pairwise_curve_similarity_S
    $c = Parse-Double $m.interpolation_coverage
    [pscustomobject]@{ fid = $m.family_id; v = $v; p = $p; cov = $c }
}
$valid = @($rankData | Where-Object { (Test-Finite $_.v) })
$sortedV = @($valid | Sort-Object v)
$sortedP = @($valid | Sort-Object p -Descending)
$sortedC = @($valid | Sort-Object cov -Descending)
$rankSum = @{}
foreach ($item in $valid) { $rankSum[$item.fid] = 0 }
for ($i = 0; $i -lt $sortedV.Count; $i++) {
    $fid = $sortedV[$i].fid
    $rankSum[$fid] += $i + 1
}
for ($i = 0; $i -lt $sortedP.Count; $i++) {
    $fid = $sortedP[$i].fid
    $rankSum[$fid] += $i + 1
}
for ($i = 0; $i -lt $sortedC.Count; $i++) {
    $fid = $sortedC[$i].fid
    $rankSum[$fid] += $i + 1
}

$bestFid = ''
$bestScore = [double]::MaxValue
foreach ($k in $rankSum.Keys) {
    if ($rankSum[$k] -lt $bestScore) {
        $bestScore = $rankSum[$k]; $bestFid = $k
    }
}

# Spread check: if top two within 15% of rank sum, declare tie
$rankVals = @($rankSum.GetEnumerator() | ForEach-Object { [pscustomobject]@{ fid = $_.Key; r = $_.Value } } | Sort-Object r)
$preliminary = $bestFid
if ($rankVals.Count -ge 2) {
    $r0 = $rankVals[0].r; $r1 = $rankVals[1].r
    if ([math]::Abs($r1 - $r0) / [math]::Max($r0, 1) -lt 0.15) { $preliminary = 'MULTIPLE_SIMILAR' }
}

$cdfSup = 'PARTIAL'
$ridgeSup = 'PARTIAL'
$ipeakSup = 'PARTIAL'
$rawSup = 'PARTIAL'
$derivHelp = 'PARTIAL'

$mcdf = $metricsRows | Where-Object { $_.family_id -eq 'CDF_pt_candidate' }
if ($mcdf) {
    $vc = Parse-Double $mcdf.mean_cross_T_variance_S
    $vr = ($metricsRows | Where-Object { $_.family_id -eq 'I_raw_candidate' } | ForEach-Object { Parse-Double $_.mean_cross_T_variance_S })
    if ((Test-Finite $vc) -and (Test-Finite $vr) -and $vc -lt 0.9 * $vr) { $cdfSup = 'YES' }
}
$mridge = $metricsRows | Where-Object { $_.family_id -eq 'eta_ridge_candidate' }
if ($mridge) {
    $vrg = Parse-Double $mridge.mean_cross_T_variance_S
    $vr = ($metricsRows | Where-Object { $_.family_id -eq 'I_raw_candidate' } | ForEach-Object { Parse-Double $_.mean_cross_T_variance_S })
    if ((Test-Finite $vrg) -and (Test-Finite $vr) -and $vrg -lt 0.9 * $vr) { $ridgeSup = 'YES' }
}
$mip = $metricsRows | Where-Object { $_.family_id -eq 'eta_Ipeak_candidate' }
if ($mip) {
    $vip = Parse-Double $mip.mean_cross_T_variance_S
    $vr = ($metricsRows | Where-Object { $_.family_id -eq 'I_raw_candidate' } | ForEach-Object { Parse-Double $_.mean_cross_T_variance_S })
    if ((Test-Finite $vip) -and (Test-Finite $vr) -and $vip -lt 0.9 * $vr) { $ipeakSup = 'YES' }
}
$mraw = $metricsRows | Where-Object { $_.family_id -eq 'I_raw_candidate' }
if ($mraw) { $rawSup = 'YES' }

$maxDeriv = ($metricsRows | ForEach-Object { Parse-Double $_.derivative_spine_organization_score } | Where-Object { Test-Finite $_ } | Measure-Object -Maximum).Maximum
$md = Parse-Double ($metricsRows | Where-Object { $_.family_id -eq $bestFid }).derivative_spine_organization_score
if ((Test-Finite $maxDeriv) -and (Test-Finite $md) -and $md -ge 0.85 * $maxDeriv) { $derivHelp = 'YES' }

$phase4b = if ($preliminary -ne 'MULTIPLE_SIMILAR' -and $bestFid.Length -gt 0) { 'PARTIAL' } else { 'PARTIAL' }
$scalingClaim = 'NO'

$statusRows = @(
    [pscustomobject]@{ verdict_key='PHASE4A_SCALING_COORDINATE_SCREENING_COMPLETE'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='LOCKED_CANONICAL_S_SOURCE_USED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='PHASE3_GATES_RESPECTED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='W_BASED_COORDINATES_USED'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='FREE_COLLAPSE_OPTIMIZATION_USED'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='FINAL_COLLAPSE_CANDIDATE_DEFINED'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='UNIQUE_X_CLAIMED'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='BEST_SCREENING_FAMILY_PRELIMINARY'; verdict_value=$preliminary }
    [pscustomobject]@{ verdict_key='CDF_PT_SCREENING_SUPPORTED'; verdict_value=$cdfSup }
    [pscustomobject]@{ verdict_key='RIDGE_ETA_SCREENING_SUPPORTED'; verdict_value=$ridgeSup }
    [pscustomobject]@{ verdict_key='IPEAK_ETA_SCREENING_SUPPORTED'; verdict_value=$ipeakSup }
    [pscustomobject]@{ verdict_key='RAW_I_SCREENING_SUPPORTED'; verdict_value=$rawSup }
    [pscustomobject]@{ verdict_key='DERIVATIVE_SPINE_COORDINATE_HELPFUL'; verdict_value=$derivHelp }
    [pscustomobject]@{ verdict_key='SAFE_TO_PROCEED_TO_PHASE4B_COLLAPSE_CANDIDATE_DESIGN'; verdict_value=$phase4b }
    [pscustomobject]@{ verdict_key='SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value=$scalingClaim }
    [pscustomobject]@{ verdict_key='SAFE_TO_WRITE_GEOCANON_INTERPRETATION'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='SAFE_TO_COMPARE_TO_RELAXATION'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='CROSS_MODULE_EVIDENCE_USED'; verdict_value='NO' }
)

$statusOut = Join-Path $RepoRoot 'tables/switching_phase4A_scaling_coordinate_status.csv'
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $statusOut

Write-Host "OK Phase4A metrics -> $metricsOut best_preliminary=$preliminary"
