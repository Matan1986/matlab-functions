# Phase 4C — collapse-candidate stress execution (Switching only).
# Stress tests ST01–ST07 per tables/switching_phase4B_collapse_candidate_stress_tests.csv
# Locked canonical S_long: results/switching/runs/<CanonicalRunId>/tables/switching_canonical_S_long.csv
#
# Execute from repo root (runtime ~3–6 min):  & .\scripts\run_switching_phase4C_collapse_stress_tests.ps1
# Avoid spawning a nested powershell.exe for the same script (startup cost).
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$CanonicalRunId = 'run_2026_04_03_000147_switching_canonical'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

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

function Parse-Double([string]$s) {
    try { [double]$s } catch { [double]::NaN }
}

$SlongPath = Join-Path $RepoRoot "results/switching/runs/$CanonicalRunId/tables/switching_canonical_S_long.csv"
if (-not (Test-Path $SlongPath)) { throw "Missing locked canonical table: $SlongPath" }

$stressDefPath = Join-Path $RepoRoot 'tables/switching_phase4B_collapse_candidate_stress_tests.csv'
if (-not (Test-Path $stressDefPath)) { throw "Missing Phase 4B stress definitions: $stressDefPath" }

$ridgePath = Join-Path $RepoRoot 'tables/switching_geocanon_T1_weighted_ridge_values.csv'
$ridgeByT = @{}
if (Test-Path $ridgePath) {
    Import-Csv $ridgePath | ForEach-Object { $ridgeByT[[double]$_.T_K] = [double]$_.ridge_center_geocanon_primary }
}

$rows = Import-Csv $SlongPath | ForEach-Object {
    [pscustomobject]@{
        T_K              = [double]$_.T_K
        current_mA       = [double]$_.current_mA
        S_percent        = [double]$_.S_percent
        S_model_pt_percent = [double]$_.S_model_pt_percent
        residual_percent = [double]$_.residual_percent
        PT_pdf           = [double]$_.PT_pdf
        CDF_pt           = [double]$_.CDF_pt
    }
}

$byT = $rows | Group-Object { $_.T_K }
$TlistAll = @($byT | ForEach-Object { [double]$_.Name } | Sort-Object)

$iPeakByT = @{}
foreach ($g in $byT) {
    $tk = [double]$g.Name
    $sl = @($g.Group | Where-Object { Test-Finite $_.S_percent })
    if ($sl.Count -eq 0) { continue }
    $best = @($sl | Sort-Object S_percent -Descending)[0]
    $iPeakByT[$tk] = $best.current_mA
}

# Per-T amplitude-normalized S: S_amp = (S-min)/(max-min) on finite ladder
$SampByKey = @{}
foreach ($g in $byT) {
    $tk = [double]$g.Name
    $sv = @($g.Group | Where-Object { Test-Finite $_.S_percent } | ForEach-Object { $_.S_percent })
    if ($sv.Count -lt 2) { continue }
    $mn = ($sv | Measure-Object -Minimum).Minimum
    $mx = ($sv | Measure-Object -Maximum).Maximum
    $den = $mx - $mn
    if ($den -lt 1e-18) { continue }
    foreach ($r in $g.Group) {
        if (-not (Test-Finite $r.S_percent)) { continue }
        $key = "$tk|$($r.current_mA)"
        $SampByKey[$key] = ($r.S_percent - $mn) / $den
    }
}

function Get-Coords {
    param(
        [string]$familyId,
        $rowsIn,
        $iPeakByT,
        $ridgeByT,
        [string]$band = 'all' # all|low|mid|high by CDF_pt on row
    )
    $cdfLo = 0.0; $cdfHi = 1.0
    if ($band -eq 'low') { $cdfHi = 1.0 / 3.0 }
    elseif ($band -eq 'mid') { $cdfLo = 1.0 / 3.0; $cdfHi = 2.0 / 3.0 }
    elseif ($band -eq 'high') { $cdfLo = 2.0 / 3.0; $cdfHi = 1.0 }
    $out = foreach ($r in $rowsIn) {
        if (-not (Test-Finite $r.S_percent)) { continue }
        if ($band -ne 'all') {
            if (-not (Test-Finite $r.CDF_pt)) { continue }
            if ($r.CDF_pt -lt $cdfLo -or $r.CDF_pt -ge $cdfHi) { continue }
        }
        $tk = $r.T_K
        $I = $r.current_mA
        $x = [double]::NaN
        switch ($familyId) {
            'I_raw_candidate' { $x = $I }
            'eta_Ipeak_candidate' { if ($iPeakByT.ContainsKey($tk)) { $x = $I - $iPeakByT[$tk] } }
            'eta_ridge_candidate' { if ($ridgeByT.ContainsKey($tk)) { $x = $I - $ridgeByT[$tk] } }
            'CDF_pt_candidate' { $x = $r.CDF_pt }
            'PT_pdf_axis_candidate' { $x = $r.PT_pdf }
        }
        if (-not (Test-Finite $x)) { continue }
        $sAmp = [double]::NaN
        $kAmp = "$tk|$I"
        if ($SampByKey.ContainsKey($kAmp)) { $sAmp = $SampByKey[$kAmp] }
        [pscustomobject]@{
            T_K = $tk; x = $x
            S = $r.S_percent; Sm = $r.S_model_pt_percent; Res = $r.residual_percent
            S_amp = $sAmp; I = $I; CDF = $r.CDF_pt
        }
    }
    @($out)
}

function Compute-StackBlock {
    param(
        $pts,
        $byT,
        [double[]]$excludeT,
        [string]$obs, # S|Sm|Res|S_amp
        [switch]$SkipPairwise,
        [int]$pairSamples = 16,
        [int]$MaxPairs = 9999
    )
    if ($pts.Count -lt 10) {
        return @{ meanVar = [double]::NaN; coverage = [double]::NaN; meanPair = [double]::NaN; meanVarR = [double]::NaN; resScore = [double]::NaN; tActive = @() }
    }
    $excludeSet = @{}
    foreach ($e in $excludeT) { $excludeSet[$e] = $true }

    $curves = @{}
    foreach ($tk in ($pts | ForEach-Object { $_.T_K } | Sort-Object -Unique)) {
        if ($excludeSet.ContainsKey($tk)) { continue }
        $sel = @($pts | Where-Object { $_.T_K -eq $tk } | Sort-Object x)
        if ($sel.Count -lt 2) { continue }
        $xv = @($sel | ForEach-Object { $_.x })
        $Sv = @($sel | ForEach-Object {
                switch ($obs) {
                    'S' { $_.S }
                    'Sm' { $_.Sm }
                    'Res' { $_.Res }
                    'S_amp' { $_.S_amp }
                }
            })
        if (@($Sv | Where-Object { Test-Finite $_ }).Count -lt 2) { continue }
        $curves[$tk] = @{ x = $xv; S = $Sv; R = @($sel | ForEach-Object { $_.Res }) }
    }
    $tActive = @($curves.Keys | Sort-Object)
    if ($tActive.Count -lt 4) {
        return @{ meanVar = [double]::NaN; coverage = [double]::NaN; meanPair = [double]::NaN; meanVarR = [double]::NaN; resScore = [double]::NaN; tActive = $tActive }
    }

    $xAll = @($pts | Where-Object { -not $excludeSet.ContainsKey($_.T_K) } | ForEach-Object { $_.x })
    $xg0 = ($xAll | Measure-Object -Minimum).Minimum
    $xg1 = ($xAll | Measure-Object -Maximum).Maximum
    if (-not ((Test-Finite $xg0) -and (Test-Finite $xg1)) -or ($xg1 - $xg0) -lt 1e-14) {
        return @{ meanVar = [double]::NaN; coverage = [double]::NaN; meanPair = [double]::NaN; meanVarR = [double]::NaN; resScore = [double]::NaN; tActive = $tActive }
    }

    $nb = 28
    $dx = ($xg1 - $xg0) / ($nb - 1)
    $stackS = New-Object System.Collections.ArrayList
    $stackR = New-Object System.Collections.ArrayList
    $coverBins = 0
    foreach ($xb in (0..($nb - 1) | ForEach-Object { $xg0 + $_ * $dx })) {
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
    $meanVar = if ($stackS.Count) { ($stackS | Measure-Object -Average).Average } else { [double]::NaN }
    $meanVarR = if ($stackR.Count) { ($stackR | Measure-Object -Average).Average } else { [double]::NaN }
    $coverage = if ($nb -gt 0) { $coverBins / $nb } else { [double]::NaN }
    $resScore = if ((Test-Finite $meanVarR) -and $meanVarR -gt 0) { 1.0 / (1.0 + $meanVarR * 1e6) } else { [double]::NaN }

    $pairs = @()
    $meanPair = [double]::NaN
    if (-not $SkipPairwise) {
        $pairCount = 0
        :outerpair for ($a = 0; $a -lt $tActive.Count; $a++) {
            for ($b = $a + 1; $b -lt $tActive.Count; $b++) {
                if ($pairCount -ge $MaxPairs) { break outerpair }
                $ta = $tActive[$a]; $tb = $tActive[$b]
                $ca = $curves[$ta]; $cb = $curves[$tb]
                $xlo = [math]::Max(($ca.x | Measure-Object -Minimum).Minimum, ($cb.x | Measure-Object -Minimum).Minimum)
                $xhi = [math]::Min(($ca.x | Measure-Object -Maximum).Maximum, ($cb.x | Measure-Object -Maximum).Maximum)
                if ($xhi - $xlo -lt 1e-10) { continue }
                $nq = [math]::Max(8, $pairSamples)
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
                    if (Test-Finite $pr) { $pairs += $pr; $pairCount++ }
                }
            }
        }
        $meanPair = if ($pairs.Count) { ($pairs | Measure-Object -Average).Average } else { [double]::NaN }
    }
    return @{
        meanVar = $meanVar; meanVarR = $meanVarR; coverage = $coverage; meanPair = $meanPair; resScore = $resScore; tActive = $tActive
    }
}

function Compute-DerivativeSpine {
    param([string]$familyId, $byT, $iPeakByT, $ridgeByT, [double[]]$excludeT)
    $excludeSet = @{}
    foreach ($e in $excludeT) { $excludeSet[$e] = $true }
    $iv = New-Object System.Collections.ArrayList
    foreach ($g in $byT) {
        $tk = [double]$g.Name
        if ($excludeSet.ContainsKey($tk)) { continue }
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
                    $ttk = $row.T_K
                    if (-not $perT.ContainsKey($ttk)) { $perT[$ttk] = New-Object System.Collections.ArrayList }
                    [void]$perT[$ttk].Add($row.dsdi)
                }
                $vals = @()
                foreach ($ttk in $perT.Keys) {
                    $arr = @($perT[$ttk])
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
    return $derivOrg
}

$leadFamilies = @('CDF_pt_candidate', 'eta_ridge_candidate', 'eta_Ipeak_candidate', 'I_raw_candidate')
$auxFamily = 'PT_pdf_axis_candidate'
$allFamilies = $leadFamilies + @($auxFamily)

# ---- per-family aggregates
$agg = @{}
foreach ($fid in $allFamilies) {
    $ptsAll = Get-Coords -familyId $fid -rowsIn $rows -iPeakByT $iPeakByT -ridgeByT $ridgeByT -band 'all'
    $stS = Compute-StackBlock -pts $ptsAll -byT $byT -excludeT @() -obs 'S' -MaxPairs 56
    $stSm = Compute-StackBlock -pts $ptsAll -byT $byT -excludeT @() -obs 'Sm' -SkipPairwise
    $stRes = Compute-StackBlock -pts $ptsAll -byT $byT -excludeT @() -obs 'Res' -SkipPairwise
    $stAmp = Compute-StackBlock -pts $ptsAll -byT $byT -excludeT @() -obs 'S_amp' -SkipPairwise
    $deriv = Compute-DerivativeSpine -familyId $fid -byT $byT -iPeakByT $iPeakByT -ridgeByT $ridgeByT -excludeT @()

    $bandLow = Get-Coords -familyId $fid -rowsIn $rows -iPeakByT $iPeakByT -ridgeByT $ridgeByT -band 'low'
    $bandMid = Get-Coords -familyId $fid -rowsIn $rows -iPeakByT $iPeakByT -ridgeByT $ridgeByT -band 'mid'
    $bandHigh = Get-Coords -familyId $fid -rowsIn $rows -iPeakByT $iPeakByT -ridgeByT $ridgeByT -band 'high'
    $bvL = Compute-StackBlock -pts $bandLow -byT $byT -excludeT @() -obs 'S' -SkipPairwise
    $bvM = Compute-StackBlock -pts $bandMid -byT $byT -excludeT @() -obs 'S' -SkipPairwise
    $bvH = Compute-StackBlock -pts $bandHigh -byT $byT -excludeT @() -obs 'S' -SkipPairwise

    $agg[$fid] = @{
        naiveVarS = $stS.meanVar; ampVarS = $stAmp.meanVar; pairS = $stS.meanPair; cov = $stS.coverage
        varSm = $stSm.meanVar; varRes = $stRes.meanVar; meanVarR = $stRes.meanVarR; resScore = $stRes.resScore
        derivOrg = $deriv
        bandL = $bvL.meanVar; bandM = $bvM.meanVar; bandH = $bvH.meanVar
        tActive = $stS.tActive
    }
}

# ST01 LOO-T
$looRows = @()
foreach ($fid in $allFamilies) {
    $base = $agg[$fid]
    $fullV = $base.naiveVarS
    $fullVR = $base.meanVarR
    $fullP = $base.pairS
    $ptsAll = Get-Coords -familyId $fid -rowsIn $rows -iPeakByT $iPeakByT -ridgeByT $ridgeByT -band 'all'
    $tList = $base.tActive
    $ratiosV = New-Object System.Collections.ArrayList
    $ratiosVR = New-Object System.Collections.ArrayList
    $ratiosPdrop = New-Object System.Collections.ArrayList
    foreach ($hold in $tList) {
        $st = Compute-StackBlock -pts $ptsAll -byT $byT -excludeT @([double]$hold) -obs 'S' -SkipPairwise:$false -pairSamples 10 -MaxPairs 28
        $stR = Compute-StackBlock -pts $ptsAll -byT $byT -excludeT @([double]$hold) -obs 'Res' -SkipPairwise:$true
        $rv = $st.meanVar
        $rvR = $stR.meanVarR
        $rp = $st.meanPair
        $epsV = 1e-22
        $ratioV = [double]::NaN
        if ((Test-Finite $fullV) -and (Test-Finite $rv)) {
            if ($fullV -lt $epsV -and $rv -lt $epsV) { $ratioV = 1.0 }
            elseif ($fullV -lt $epsV -and $rv -ge $epsV * 100.0) { $ratioV = [double]::PositiveInfinity }
            elseif ($fullV -ge $epsV) { $ratioV = $rv / $fullV }
        }
        $ratioVR = [double]::NaN
        if ((Test-Finite $fullVR) -and (Test-Finite $rvR)) {
            if ($fullVR -lt $epsV -and $rvR -lt $epsV) { $ratioVR = 1.0 }
            elseif ($fullVR -lt $epsV -and $rvR -ge $epsV * 100.0) { $ratioVR = [double]::PositiveInfinity }
            elseif ($fullVR -ge $epsV) { $ratioVR = $rvR / $fullVR }
        }
        if (Test-Finite $ratioV) { [void]$ratiosV.Add($ratioV) }
        if (Test-Finite $ratioVR) { [void]$ratiosVR.Add($ratioVR) }
        $looRows += [pscustomobject]@{
            family_id = $fid
            held_out_T_K = $hold
            mean_cross_T_variance_S_loo = if (Test-Finite $rv) { [math]::Round($rv, 12) } else { 'NaN' }
            mean_cross_T_variance_residual_loo = if (Test-Finite $rvR) { [math]::Round($rvR, 12) } else { 'NaN' }
            mean_pairwise_curve_similarity_S_loo = if (Test-Finite $rp) { [math]::Round($rp, 6) } else { 'NaN' }
            ratio_varS_loo_to_full = if (Test-Finite $ratioV) { [math]::Round($ratioV, 6) } else { 'NaN' }
            ratio_varR_loo_to_full = if (Test-Finite $ratioVR) { [math]::Round($ratioVR, 6) } else { 'NaN' }
        }
    }
    $medianRV = [double]::NaN
    $worstRV = [double]::NaN
    if ($ratiosV.Count) {
        $sorted = @($ratiosV.ToArray() | Where-Object { Test-Finite $_ } | Sort-Object)
        if ($sorted.Count) {
            $medianRV = $sorted[[int][math]::Floor(($sorted.Count - 1) / 2)]
            $worstRV = ($sorted | Measure-Object -Maximum).Maximum
        }
    }
    $agg[$fid].looMedianRatioVarS = $medianRV
    $agg[$fid].looWorstRatioVarS = $worstRV
}

# Ridge coverage for ST06
$TwithData = @($agg['I_raw_candidate'].tActive)
$TwithRidge = @($ridgeByT.Keys | Sort-Object)
$Tneed = $TwithData.Count
$Tmatch = ($TwithData | Where-Object { $ridgeByT.ContainsKey($_) }).Count
$ridgeCoverage = if ($Tneed -gt 0) { $Tmatch / $Tneed } else { [double]::NaN }

$rawVar = $agg['I_raw_candidate'].naiveVarS
$metricsRows = @()

foreach ($fid in $allFamilies) {
    $a = $agg[$fid]
    $vrat = if ((Test-Finite $rawVar) -and (Test-Finite $a.naiveVarS) -and $rawVar -gt 1e-22) { $a.naiveVarS / $rawVar } else { [double]::NaN }

    # ST02
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST02'; family_id = $fid; metric_key = 'mean_cross_T_variance_S_naive'; metric_value = if (Test-Finite $a.naiveVarS) { [math]::Round($a.naiveVarS, 12) } else { 'NaN' }; notes = 'full_map' }
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST02'; family_id = $fid; metric_key = 'mean_cross_T_variance_S_ampnorm'; metric_value = if (Test-Finite $a.ampVarS) { [math]::Round($a.ampVarS, 12) } else { 'NaN' }; notes = 'per_T_minmax_S' }
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST02'; family_id = $fid; metric_key = 'mean_pairwise_curve_similarity_S'; metric_value = if (Test-Finite $a.pairS) { [math]::Round($a.pairS, 6) } else { 'NaN' }; notes = '' }
    # ST03
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST03'; family_id = $fid; metric_key = 'band_mean_var_S_low_CDF'; metric_value = if (Test-Finite $a.bandL) { [math]::Round($a.bandL, 12) } else { 'NaN' }; notes = 'CDF_pt bins on rows' }
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST03'; family_id = $fid; metric_key = 'band_mean_var_S_mid_CDF'; metric_value = if (Test-Finite $a.bandM) { [math]::Round($a.bandM, 12) } else { 'NaN' }; notes = '' }
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST03'; family_id = $fid; metric_key = 'band_mean_var_S_high_CDF'; metric_value = if (Test-Finite $a.bandH) { [math]::Round($a.bandH, 12) } else { 'NaN' }; notes = '' }
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST03'; family_id = $fid; metric_key = 'derivative_spine_organization_score'; metric_value = if (Test-Finite $a.derivOrg) { [math]::Round($a.derivOrg, 8) } else { 'NaN' }; notes = 'dS/dI tagged in candidate x_mid' }
    # ST04
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST04'; family_id = $fid; metric_key = 'mean_cross_T_variance_residual'; metric_value = if (Test-Finite $a.meanVarR) { [math]::Round($a.meanVarR, 12) } else { 'NaN' }; notes = '' }
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST04'; family_id = $fid; metric_key = 'residual_organization_score'; metric_value = if (Test-Finite $a.resScore) { [math]::Round($a.resScore, 8) } else { 'NaN' }; notes = '' }
    # ST05
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST05'; family_id = $fid; metric_key = 'mean_cross_T_variance_S_percent'; metric_value = if (Test-Finite $a.naiveVarS) { [math]::Round($a.naiveVarS, 12) } else { 'NaN' }; notes = '' }
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST05'; family_id = $fid; metric_key = 'mean_cross_T_variance_S_model_pt_percent'; metric_value = if (Test-Finite $a.varSm) { [math]::Round($a.varSm, 12) } else { 'NaN' }; notes = '' }
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST05'; family_id = $fid; metric_key = 'mean_cross_T_variance_residual_percent'; metric_value = if (Test-Finite $a.varRes) { [math]::Round($a.varRes, 12) } else { 'NaN' }; notes = '' }
    # ST01 summary (attach to metrics)
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST01'; family_id = $fid; metric_key = 'median_ratio_varS_loo_to_full'; metric_value = if (Test-Finite $a.looMedianRatioVarS) { [math]::Round($a.looMedianRatioVarS, 6) } else { 'NaN' }; notes = '' }
    $worstStr = 'NaN'
    if ([double]::IsPositiveInfinity($a.looWorstRatioVarS)) { $worstStr = 'Inf' }
    elseif (Test-Finite $a.looWorstRatioVarS) { $worstStr = [math]::Round($a.looWorstRatioVarS, 6).ToString() }
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST01'; family_id = $fid; metric_key = 'worst_ratio_varS_loo_to_full'; metric_value = $worstStr; notes = '' }
    # ST06
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST06'; family_id = $fid; metric_key = 'varS_ratio_to_I_raw'; metric_value = if (Test-Finite $vrat) { [math]::Round($vrat, 6) } else { 'NaN' }; notes = 'naive stack variance ratio' }
    # ST07 flag
    $auxFlag = if ($fid -eq 'PT_pdf_axis_candidate') { 'YES' } else { 'NO' }
    $metricsRows += [pscustomobject]@{ stress_test_id = 'ST07'; family_id = $fid; metric_key = 'auxiliary_PT_pdf_axis_only'; metric_value = $auxFlag; notes = 'PARTIAL axis rule' }
}

$metricsRows += [pscustomobject]@{ stress_test_id = 'ST06'; family_id = '_global'; metric_key = 'ridge_T_coverage_fraction_active_T'; metric_value = if (Test-Finite $ridgeCoverage) { [math]::Round($ridgeCoverage, 6) } else { 'NaN' }; notes = 'geocanon ridge table join' }

$metricsOut = Join-Path $RepoRoot 'tables/switching_phase4C_collapse_stress_metrics.csv'
$metricsRows | Export-Csv -NoTypeInformation -Encoding UTF8 $metricsOut

$looOut = Join-Path $RepoRoot 'tables/switching_phase4C_collapse_stress_looT.csv'
$looRows | Export-Csv -NoTypeInformation -Encoding UTF8 $looOut

# ---- Gates (documented constants; not a scaling claim)
$cdf = $agg['CDF_pt_candidate']
$raw = $agg['I_raw_candidate']
$ridge = $agg['eta_ridge_candidate']
$ipeak = $agg['eta_Ipeak_candidate']

$mRawVarR = $raw.meanVarR
$mCdfVarR = $cdf.meanVarR
$mRidgeVarR = $ridge.meanVarR
$mIpVarR = $ipeak.meanVarR

$cdfSurvivesResidual = 'NO'
if ((Test-Finite $mCdfVarR) -and (Test-Finite $mRawVarR)) {
    if (($mCdfVarR -lt $mRawVarR * 0.98) -or (($cdf.resScore -gt $raw.resScore * 1.05) -and (Test-Finite $cdf.resScore))) {
        $cdfSurvivesResidual = 'YES'
    }
}

$cdfSurvivesLoo = 'NO'
if ([double]::IsPositiveInfinity($cdf.looWorstRatioVarS)) {
    $cdfSurvivesLoo = 'NO'
}
elseif ((Test-Finite $cdf.looWorstRatioVarS) -and $cdf.looWorstRatioVarS -gt 2.75) {
    $cdfSurvivesLoo = 'NO'
}
elseif ((Test-Finite $cdf.looMedianRatioVarS) -and $cdf.looMedianRatioVarS -le 1.85 -and (Test-Finite $cdf.looWorstRatioVarS) -and $cdf.looWorstRatioVarS -le 2.75) {
    $cdfSurvivesLoo = 'YES'
}

$cdfBackboneTrivial = 'NO'
if (($cdfSurvivesResidual -ne 'YES') -and ($cdfSurvivesLoo -ne 'YES')) {
    $spineOnlyApparent = ($cdf.naiveVarS -lt 1e-22) -and ($cdf.varSm -lt 1e-22)
    if ($spineOnlyApparent) { $cdfBackboneTrivial = 'YES' }
}

$cdfSurvivesBackbone = if ($cdfBackboneTrivial -eq 'YES') { 'NO' } else { 'YES' }

$cdfBeatsRaw = 'NO'
if ((Test-Finite $cdf.pairS) -and (Test-Finite $raw.pairS) -and ($cdf.pairS -gt $raw.pairS + 0.02) -and (Test-Finite $cdf.naiveVarS) -and (Test-Finite $raw.naiveVarS) -and ($raw.naiveVarS -gt 1e-22) -and ($cdf.naiveVarS -lt $raw.naiveVarS * 0.95)) {
    $cdfBeatsRaw = 'YES'
}
elseif ((Test-Finite $mCdfVarR) -and (Test-Finite $mRawVarR) -and ($mCdfVarR -lt $mRawVarR * 0.98)) {
    $cdfBeatsRaw = 'YES'
}

function Test-FamilySurvival {
    param($a, $rawRef, [string]$label)
    $survRes = 'NO'
    if ((Test-Finite $a.meanVarR) -and (Test-Finite $rawRef.meanVarR)) {
        if (($a.meanVarR -lt $rawRef.meanVarR * 0.98) -or (($a.resScore -gt $rawRef.resScore * 1.05) -and (Test-Finite $a.resScore))) { $survRes = 'YES' }
    }
    $survLoo = 'NO'
    if (-not [double]::IsPositiveInfinity($a.looWorstRatioVarS) -and (Test-Finite $a.looWorstRatioVarS) -and $a.looWorstRatioVarS -le 2.75 -and (Test-Finite $a.looMedianRatioVarS) -and $a.looMedianRatioVarS -le 1.85) {
        $survLoo = 'YES'
    }
    $triv = 'NO'
    if (($survRes -ne 'YES') -and ($survLoo -ne 'YES')) {
        if (($a.naiveVarS -lt 1e-22) -and ($a.varSm -lt 1e-22)) { $triv = 'YES' }
    }
    $survAll = (($survRes -eq 'YES') -and ($survLoo -eq 'YES') -and ($triv -ne 'YES'))
    return @{ res = $survRes; loo = $survLoo; trivial = $triv; survival = $survAll }
}

$rRidge = Test-FamilySurvival -a $ridge -rawRef $raw -label 'ridge'
$rIp = Test-FamilySurvival -a $ipeak -rawRef $raw -label 'ipeak'

$ridgeSurvives = if ($rRidge.survival) { 'YES' } else { 'NO' }
$ipSurvives = if ($rIp.survival) { 'YES' } else { 'NO' }

$cdfPhase4d = (($cdfSurvivesResidual -eq 'YES') -and ($cdfSurvivesLoo -eq 'YES') -and ($cdfBackboneTrivial -eq 'NO'))
$ridgePhase4d = ($rRidge.survival -and ($ridgeCoverage -ge 0.85))
$ipPhase4d = $rIp.survival

$anyPhase4d = ($cdfPhase4d -or $ridgePhase4d -or $ipPhase4d)

$riskRows = @(
    [pscustomobject]@{ family_id = 'CDF_pt_candidate'; survives_residual_gate = $cdfSurvivesResidual; survives_loo_T = $cdfSurvivesLoo; backbone_trivial_risk = $cdfBackboneTrivial; beats_I_raw_nontrivially = $cdfBeatsRaw; eligible_phase4d_collapsecandidate_only = ($(if ($cdfPhase4d) { 'YES' } else { 'NO' })); notes = 'Leading Phase 4A axis - stress-tested only' }
    [pscustomobject]@{ family_id = 'eta_ridge_candidate'; survives_residual_gate = $rRidge.res; survives_loo_T = $rRidge.loo; backbone_trivial_risk = $rRidge.trivial; beats_I_raw_nontrivially = $(if ((Test-Finite $ridge.naiveVarS) -and (Test-Finite $raw.naiveVarS) -and $ridge.naiveVarS -lt $raw.naiveVarS * 0.95) { 'PARTIAL' } else { 'NO' }); eligible_phase4d_collapsecandidate_only = ($(if ($ridgePhase4d) { 'YES' } else { 'NO' })); notes = 'Requires ridge coverage' }
    [pscustomobject]@{ family_id = 'eta_Ipeak_candidate'; survives_residual_gate = $rIp.res; survives_loo_T = $rIp.loo; backbone_trivial_risk = $rIp.trivial; beats_I_raw_nontrivially = $(if ((Test-Finite $ipeak.naiveVarS) -and (Test-Finite $raw.naiveVarS) -and $ipeak.naiveVarS -lt $raw.naiveVarS * 0.95) { 'PARTIAL' } else { 'NO' }); eligible_phase4d_collapsecandidate_only = ($(if ($ipPhase4d) { 'YES' } else { 'NO' })); notes = 'Discrete I_peak ladder' }
    [pscustomobject]@{ family_id = 'I_raw_candidate'; survives_residual_gate = 'NA_baseline'; survives_loo_T = 'NA_baseline'; backbone_trivial_risk = 'NA_baseline'; beats_I_raw_nontrivially = 'NA_baseline'; eligible_phase4d_collapsecandidate_only = 'NO'; notes = 'Mandatory comparator - not a collapse axis claim' }
    [pscustomobject]@{ family_id = 'PT_pdf_axis_candidate'; survives_residual_gate = 'PARTIAL_auxiliary'; survives_loo_T = 'PARTIAL_auxiliary'; backbone_trivial_risk = 'PARTIAL_auxiliary'; beats_I_raw_nontrivially = 'PARTIAL_auxiliary'; eligible_phase4d_collapsecandidate_only = 'NO'; notes = 'ST07 auxiliary-only; do not promote as sole axis' }
)

$riskOut = Join-Path $RepoRoot 'tables/switching_phase4C_collapse_stress_risk_summary.csv'
$riskRows | Export-Csv -NoTypeInformation -Encoding UTF8 $riskOut

$safe4d = if ($anyPhase4d) { 'PARTIAL' } else { 'NO' }
$scalingClaim = 'NO'
$compareRelax = 'NO'

$statusRows = @(
    [pscustomobject]@{ verdict_key = 'PHASE4C_COLLAPSE_STRESS_TEST_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'LOCKED_CANONICAL_S_SOURCE_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'LOCKED_CANONICAL_RUN_ID'; verdict_value = $CanonicalRunId }
    [pscustomobject]@{ verdict_key = 'PHASE4B_STRESS_TESTS_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'W_BASED_COORDINATES_USED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'FREE_COLLAPSE_OPTIMIZATION_USED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'FINAL_COLLAPSE_CANDIDATE_DEFINED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'UNIQUE_X_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CDF_PT_SURVIVES_RESIDUAL_TEST'; verdict_value = $cdfSurvivesResidual }
    [pscustomobject]@{ verdict_key = 'CDF_PT_SURVIVES_LOOT_STABILITY'; verdict_value = $cdfSurvivesLoo }
    [pscustomobject]@{ verdict_key = 'CDF_PT_SURVIVES_BACKBONE_TRIVIALITY_CHECK'; verdict_value = $(if ($cdfSurvivesBackbone -eq 'YES') { 'YES' } else { 'NO' }) }
    [pscustomobject]@{ verdict_key = 'CDF_PT_BEATS_RAW_I_BASELINE_NONTRIVIALLY'; verdict_value = $cdfBeatsRaw }
    [pscustomobject]@{ verdict_key = 'RIDGE_ETA_SURVIVES_STRESS_TESTS'; verdict_value = $ridgeSurvives }
    [pscustomobject]@{ verdict_key = 'IPEAK_ETA_SURVIVES_STRESS_TESTS'; verdict_value = $ipSurvives }
    [pscustomobject]@{ verdict_key = 'ANY_COORDINATE_SURVIVES_AS_PHASE4D_CANDIDATE'; verdict_value = $(if ($anyPhase4d) { 'YES' } else { 'NO' }) }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_PROCEED_TO_PHASE4D_COLLAPSE_SPECIFICATION'; verdict_value = $safe4d }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = $scalingClaim }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_COMPARE_TO_RELAXATION'; verdict_value = $compareRelax }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_EVIDENCE_USED'; verdict_value = 'NO' }
)

$statusOut = Join-Path $RepoRoot 'tables/switching_phase4C_collapse_stress_status.csv'
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $statusOut

# --- Markdown report
$lines = @()
$lines += '# Phase 4C - collapse-candidate stress tests (Switching)'
$lines += ''
$lines += '## Scope and non-claims'
$lines += '- **Switching only.** No Relaxation/Aging comparison, no cross-module evidence, no scaling law claim, no canonical **X**, no Phi/residual-mode absorption, no geocanon T2, no W-normalized coordinates, no exponent/collapse-parameter optimization.'
$lines += '- **Locked source:** `' + $CanonicalRunId + '/tables/switching_canonical_S_long.csv`.'
$lines += '- **Phase 4B stress map:** `tables/switching_phase4B_collapse_candidate_stress_tests.csv` (**ST01-ST07**).'
$lines += ''
$lines += '## Procedure summary'
$lines += '| ID | Content |'
$lines += '|----|---------|'
$lines += '| ST01 | Leave-one-`T` stability: ratios of LOO vs full-sample cross-`T` stack variance (`S` and residual). |'
$lines += '| ST02 | Naive full-map stack + per-`T` amplitude-stripped (`S` min-max per temperature) stack; pairwise curve similarity on `S`. |'
$lines += '| ST03 | CDF_pt row bands (low/mid/high) for **stratification** while evaluating each family''s horizontal `x`; derivative-spine `dS/dI` tagged in candidate `x_mid`. |'
$lines += '| ST04 | Residual-only stack (`residual_percent`). |'
$lines += '| ST05 | Backbone panel: stack variances for `S_percent`, `S_model_pt_percent`, `residual_percent` separately. |'
$lines += '| ST06 | Ridge coverage on active temperatures; naive `varS` ratio vs `I_raw_candidate`. |'
$lines += '| ST07 | `PT_pdf_axis_candidate` runs with **PARTIAL/auxiliary** labeling only. |'
$lines += ''
$lines += '## Metric caveat (naive stack variance)'
$lines += '- When **mean cross-T variance of `S`** is numerically zero on several families (exact overlay at shared bins), naive pairwise Pearson can be undefined; interpret **ST04 residual**, **ST03 derivative**, and **ST01 LOO ratios** (with degenerate-safe ratio=1 when both stacks are flat).'
$lines += ''
$lines += '## Artifacts'
$lines += '- `tables/switching_phase4C_collapse_stress_metrics.csv`'
$lines += '- `tables/switching_phase4C_collapse_stress_looT.csv`'
$lines += '- `tables/switching_phase4C_collapse_stress_risk_summary.csv`'
$lines += '- `tables/switching_phase4C_collapse_stress_status.csv`'
$lines += ''
$lines += '## Interpretation (Phase 4C only)'
if ($cdfBackboneTrivial -eq 'YES') {
    $lines += '- **`CDF_pt_candidate` shows backbone-trivial risk pattern:** strong spine alignment on `S`/`S_model` gates with residual/LOO failure - do **not** read as independent physical collapse.'
}
if (-not $anyPhase4d) {
    $lines += '- **No axis passed all Phase 4C gates for a Phase 4D-only candidate.** Consider **stopping Phase 4** advancement and preserving the coordinate-family interpretation (multiplicity / non-uniqueness).'
} else {
    $lines += '- **At least one coordinate may be carried as a `Phase4D candidate` specification target** - still **not** canonical **X** and **not** a scaling claim.'
}
$lines += ''
$lines += '## Verdict table (machine keys)'
foreach ($s in $statusRows) {
    $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`')
}

$reportPath = Join-Path $RepoRoot 'reports/switching_phase4C_collapse_stress_tests.md'
$lines | Set-Content -Encoding UTF8 $reportPath

Write-Host "Phase 4C complete. Metrics: $metricsOut Report: $reportPath"
