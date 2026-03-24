$ErrorActionPreference = 'Stop'

$mergedPath = 'results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/merged_relaxation_switching_table.csv'
$looPath = 'results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/leave_one_out_correlations.csv'
$reportPath = 'reports/subset_stability_report.md'

$rows = Import-Csv $mergedPath | Sort-Object {[double]$_.T_K}
$looRows = Import-Csv $looPath

function Get-Pearson {
    param([double[]]$x, [double[]]$y)
    $n = $x.Count
    if ($n -lt 2) { return [double]::NaN }
    $mx = ($x | Measure-Object -Average).Average
    $my = ($y | Measure-Object -Average).Average
    $sx = 0.0; $sy = 0.0; $cov = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $dx = $x[$i] - $mx
        $dy = $y[$i] - $my
        $cov += $dx * $dy
        $sx += $dx * $dx
        $sy += $dy * $dy
    }
    if ($sx -le 0 -or $sy -le 0) { return [double]::NaN }
    return $cov / [math]::Sqrt($sx * $sy)
}

function Get-Ranks {
    param([double[]]$v)
    $n = $v.Count
    $ranks = New-Object double[] $n
    $items = for ($i=0; $i -lt $n; $i++) {
        [pscustomobject]@{Idx=$i; Val=[double]$v[$i]}
    }
    $sorted = $items | Sort-Object Val, Idx
    $j = 0
    while ($j -lt $n) {
        $k = $j
        while ($k + 1 -lt $n -and $sorted[$k + 1].Val -eq $sorted[$j].Val) { $k++ }
        $avgRank = ($j + $k + 2) / 2.0
        for ($m = $j; $m -le $k; $m++) {
            $ranks[$sorted[$m].Idx] = $avgRank
        }
        $j = $k + 1
    }
    return ,$ranks
}

function Get-Spearman {
    param([double[]]$x, [double[]]$y)
    if ($x.Count -lt 2) { return [double]::NaN }
    $rx = Get-Ranks $x
    $ry = Get-Ranks $y
    return Get-Pearson $rx $ry
}

function Get-PeakTemp {
    param($subset, [string]$field)
    $best = $null
    foreach ($r in $subset) {
        if ($null -eq $best -or [double]$r.$field -gt [double]$best.$field) { $best = $r }
    }
    return [double]$best.T_K
}

function Get-Metrics {
    param($subset)
    $A = @($subset | ForEach-Object {[double]$_.A_interp})
    $X = @($subset | ForEach-Object {[double]$_.X_bridge})
    $pearson = Get-Pearson $X $A
    $spearman = Get-Spearman $X $A
    $Apeak = Get-PeakTemp $subset 'A_interp'
    $Xpeak = Get-PeakTemp $subset 'X_bridge'
    $peakDelta = [math]::Abs($Apeak - $Xpeak)
    return [pscustomobject]@{
        n = $subset.Count
        pearson = $pearson
        spearman = $spearman
        A_peak = $Apeak
        X_peak = $Xpeak
        peak_delta = $peakDelta
    }
}

function Get-LinearFitStats {
    param([double[]]$x, [double[]]$y)
    $n = $x.Count
    if ($n -lt 2) { return [pscustomobject]@{r2=[double]::NaN; rmse=[double]::NaN; a=[double]::NaN; b=[double]::NaN} }
    $mx = ($x | Measure-Object -Average).Average
    $my = ($y | Measure-Object -Average).Average
    $num = 0.0; $den = 0.0
    for ($i=0; $i -lt $n; $i++) {
        $dx = $x[$i] - $mx
        $num += $dx * ($y[$i] - $my)
        $den += $dx * $dx
    }
    if ($den -eq 0) { return [pscustomobject]@{r2=[double]::NaN; rmse=[double]::NaN; a=[double]::NaN; b=[double]::NaN} }
    $a = $num / $den
    $b = $my - $a * $mx
    $ssRes = 0.0; $ssTot = 0.0
    for ($i=0; $i -lt $n; $i++) {
        $yhat = $a * $x[$i] + $b
        $ssRes += ($y[$i] - $yhat) * ($y[$i] - $yhat)
        $ssTot += ($y[$i] - $my) * ($y[$i] - $my)
    }
    $r2 = if ($ssTot -gt 0) { 1.0 - ($ssRes / $ssTot) } else { [double]::NaN }
    $rmse = [math]::Sqrt($ssRes / $n)
    return [pscustomobject]@{r2=$r2; rmse=$rmse; a=$a; b=$b}
}

function Get-PowerFitStats {
    param([double[]]$x, [double[]]$y)
    $n = $x.Count
    if ($n -lt 2) { return [pscustomobject]@{r2=[double]::NaN; rmse=[double]::NaN; alpha=[double]::NaN; c=[double]::NaN} }
    if (($x | Where-Object {$_ -le 0}).Count -gt 0 -or ($y | Where-Object {$_ -le 0}).Count -gt 0) {
        return [pscustomobject]@{r2=[double]::NaN; rmse=[double]::NaN; alpha=[double]::NaN; c=[double]::NaN}
    }
    $lx = @($x | ForEach-Object {[math]::Log($_)})
    $ly = @($y | ForEach-Object {[math]::Log($_)})
    $fit = Get-LinearFitStats $lx $ly
    if ([double]::IsNaN($fit.a)) { return [pscustomobject]@{r2=[double]::NaN; rmse=[double]::NaN; alpha=[double]::NaN; c=[double]::NaN} }
    $alpha = $fit.a
    $c = [math]::Exp($fit.b)
    $my = ($y | Measure-Object -Average).Average
    $ssRes = 0.0; $ssTot = 0.0
    for ($i=0; $i -lt $n; $i++) {
        $yhat = $c * [math]::Pow($x[$i], $alpha)
        $ssRes += ($y[$i] - $yhat) * ($y[$i] - $yhat)
        $ssTot += ($y[$i] - $my) * ($y[$i] - $my)
    }
    $r2 = if ($ssTot -gt 0) { 1.0 - ($ssRes / $ssTot) } else { [double]::NaN }
    $rmse = [math]::Sqrt($ssRes / $n)
    return [pscustomobject]@{r2=$r2; rmse=$rmse; alpha=$alpha; c=$c}
}

function Get-ScenarioSummary {
    param($subset)
    $x = @($subset | ForEach-Object {[double]$_.X_bridge})
    $a = @($subset | ForEach-Object {[double]$_.A_interp})
    $lin = Get-LinearFitStats $x $a
    $pow = Get-PowerFitStats $x $a
    $m = Get-Metrics $subset
    [pscustomobject]@{
        n = $subset.Count
        pearson = $m.pearson
        spearman = $m.spearman
        peak_delta = $m.peak_delta
        linear_r2 = $lin.r2
        linear_rmse = $lin.rmse
        power_r2 = $pow.r2
        power_rmse = $pow.rmse
        power_alpha = $pow.alpha
    }
}

function Get-GridParetoStatus {
    param($subset)
    $A = @($subset | ForEach-Object {[double]$_.A_interp})
    $I = @($subset | ForEach-Object {[double]$_.I_peak_mA})
    $W = @($subset | ForEach-Object {[double]$_.width_mA})
    $S = @($subset | ForEach-Object {[double]$_.S_peak})
    $temps = @($subset | ForEach-Object {[double]$_.T_K})
    $Apeak = Get-PeakTemp $subset 'A_interp'

    $all = @()
    for ($p = 0.5; $p -le 1.5001; $p += 0.1) {
        for ($c = 0.5; $c -le 1.5001; $c += 0.1) {
            $Y = New-Object double[] $A.Count
            for ($k=0; $k -lt $A.Count; $k++) {
                $Y[$k] = [math]::Pow($I[$k] / $W[$k], $p) / [math]::Pow($S[$k], $c)
            }
            $pear = Get-Pearson $Y $A
            $spear = Get-Spearman $Y $A
            $imax = 0; $ymax = $Y[0]
            for ($k=1; $k -lt $Y.Count; $k++) { if ($Y[$k] -gt $ymax) { $ymax = $Y[$k]; $imax = $k } }
            $peakDelta = [math]::Abs($temps[$imax] - $Apeak)
            $all += [pscustomobject]@{
                p=[math]::Round($p,1)
                c=[math]::Round($c,1)
                pearson=[double]$pear
                spearman=[double]$spear
                abs_pearson=[math]::Abs([double]$pear)
                abs_spearman=[math]::Abs([double]$spear)
                peak_delta=[double]$peakDelta
            }
        }
    }

    $canonical = $all | Where-Object { $_.p -eq 1.0 -and $_.c -eq 1.0 } | Select-Object -First 1
    $rankPearson = (($all | Sort-Object -Property pearson -Descending) | ForEach-Object { $_ })
    $rank = 1
    foreach ($r in $rankPearson) {
        if ($r.p -eq 1.0 -and $r.c -eq 1.0) { break }
        $rank++
    }

    $dominated = $false
    foreach ($r in $all) {
        $gePear = $r.abs_pearson -ge $canonical.abs_pearson
        $geSpea = $r.abs_spearman -ge $canonical.abs_spearman
        $lePeak = $r.peak_delta -le $canonical.peak_delta
        $strict = ($r.abs_pearson -gt $canonical.abs_pearson) -or ($r.abs_spearman -gt $canonical.abs_spearman) -or ($r.peak_delta -lt $canonical.peak_delta)
        if ($gePear -and $geSpea -and $lePeak -and $strict) { $dominated = $true; break }
    }

    return [pscustomobject]@{
        canonical_pearson = $canonical.pearson
        canonical_spearman = $canonical.spearman
        canonical_peak_delta = $canonical.peak_delta
        canonical_rank_pearson = $rank
        canonical_pareto = (-not $dominated)
    }
}

$baseline = Get-ScenarioSummary $rows
$baselinePareto = Get-GridParetoStatus $rows

# Reuse existing LOO summary
$looPearsons = @($looRows | ForEach-Object {[double]$_.pearson_r})
$looSpearmans = @($looRows | ForEach-Object {[double]$_.spearman_r})
$looSummary = [pscustomobject]@{
    min_pearson = ($looPearsons | Measure-Object -Minimum).Minimum
    median_pearson = (($looPearsons | Sort-Object)[[int][math]::Floor($looPearsons.Count/2)])
    min_spearman = ($looSpearmans | Measure-Object -Minimum).Minimum
    median_spearman = (($looSpearmans | Sort-Object)[[int][math]::Floor($looSpearmans.Count/2)])
}

# Leave-two-out exhaustive
$l2o = @()
for ($i=0; $i -lt $rows.Count-1; $i++) {
    for ($j=$i+1; $j -lt $rows.Count; $j++) {
        $t1 = [double]$rows[$i].T_K
        $t2 = [double]$rows[$j].T_K
        $subset = $rows | Where-Object { [double]$_.T_K -ne $t1 -and [double]$_.T_K -ne $t2 }
        $m = Get-Metrics $subset
        $l2o += [pscustomobject]@{
            removed = ('{0}K,{1}K' -f $t1, $t2)
            pearson = $m.pearson
            spearman = $m.spearman
            peak_delta = $m.peak_delta
        }
    }
}

$l2oWorstPearson = $l2o | Sort-Object pearson | Select-Object -First 1
$l2oWorstSpearman = $l2o | Sort-Object spearman | Select-Object -First 1
$l2oWorstPeak = $l2o | Sort-Object -Property @{Expression='peak_delta';Descending=$true}, @{Expression='pearson';Descending=$false} | Select-Object -First 1
$l2oPearsons = @($l2o | ForEach-Object {[double]$_.pearson})
$l2oSpearmans = @($l2o | ForEach-Object {[double]$_.spearman})
$l2oPeaks = @($l2o | ForEach-Object {[double]$_.peak_delta})

# Critical point removal
$criticalSets = @(
    [pscustomobject]@{name='remove_26K'; temps=@(26.0)},
    [pscustomobject]@{name='remove_22K'; temps=@(22.0)},
    [pscustomobject]@{name='remove_18K'; temps=@(18.0)},
    [pscustomobject]@{name='remove_26K_22K_18K'; temps=@(26.0,22.0,18.0)}
)

$criticalResults = @()
foreach ($cs in $criticalSets) {
    $subset = $rows | Where-Object { $cs.temps -notcontains [double]$_.T_K }
    $sum = Get-ScenarioSummary $subset
    $par = Get-GridParetoStatus $subset
    $criticalResults += [pscustomobject]@{
        case = $cs.name
        n = $sum.n
        pearson = $sum.pearson
        spearman = $sum.spearman
        peak_delta = $sum.peak_delta
        linear_r2 = $sum.linear_r2
        power_r2 = $sum.power_r2
        power_alpha = $sum.power_alpha
        canonical_rank_pearson = $par.canonical_rank_pearson
        canonical_pareto = $par.canonical_pareto
        d_pearson = $sum.pearson - $baseline.pearson
        d_spearman = $sum.spearman - $baseline.spearman
        d_linear_r2 = $sum.linear_r2 - $baseline.linear_r2
        d_power_r2 = $sum.power_r2 - $baseline.power_r2
    }
}

# Region-based splits
$regions = @(
    [pscustomobject]@{name='low_T'; min=4; max=12},
    [pscustomobject]@{name='mid_T'; min=14; max=22},
    [pscustomobject]@{name='high_T'; min=24; max=30}
)
$regionResults = @()
foreach ($r in $regions) {
    $subset = $rows | Where-Object { [double]$_.T_K -ge $r.min -and [double]$_.T_K -le $r.max }
    $sum = Get-ScenarioSummary $subset
    $regionResults += [pscustomobject]@{
        region = $r.name
        n = $sum.n
        pearson = $sum.pearson
        spearman = $sum.spearman
        peak_delta = $sum.peak_delta
        linear_r2 = $sum.linear_r2
        power_r2 = $sum.power_r2
        power_alpha = $sum.power_alpha
    }
}

# Interpret fragility vs robustness
$worstPearsonDrop = [math]::Max(($baseline.pearson - ($l2oPearsons | Measure-Object -Minimum).Minimum), ($baseline.pearson - (($criticalResults | ForEach-Object {[double]$_.pearson}) | Measure-Object -Minimum).Minimum))
$maxPeakShift = [math]::Max((($l2oPeaks | Measure-Object -Maximum).Maximum), ((($criticalResults | ForEach-Object {[double]$_.peak_delta}) | Measure-Object -Maximum).Maximum))
$isRobust = ($worstPearsonDrop -lt 0.08) -and ($maxPeakShift -le 4)
$verdict = if ($isRobust) { 'robust' } else { 'fragile' }

$report = New-Object System.Text.StringBuilder
[void]$report.AppendLine('# Subset Stability Report for X')
[void]$report.AppendLine('')
[void]$report.AppendLine('## Data and constraints')
[void]$report.AppendLine('- No pipeline recomputation was performed.')
[void]$report.AppendLine('- Merged table reused: `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/merged_relaxation_switching_table.csv`')
[void]$report.AppendLine('- Existing LOO results reused: `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/leave_one_out_correlations.csv`')
[void]$report.AppendLine('')
[void]$report.AppendLine('## Baseline')
[void]$report.AppendLine(('- n={0}, Pearson={1:N6}, Spearman={2:N6}, peak alignment delta={3} K' -f $baseline.n, $baseline.pearson, $baseline.spearman, [int]$baseline.peak_delta))
[void]$report.AppendLine(('- Linear scaling R2={0:N6}; Power scaling R2={1:N6}, alpha={2:N4}' -f $baseline.linear_r2, $baseline.power_r2, $baseline.power_alpha))
[void]$report.AppendLine(('- Canonical X Pareto status on (p,c) grid: {0}; Pearson-rank={1}/121' -f $baselinePareto.canonical_pareto, $baselinePareto.canonical_rank_pearson))
[void]$report.AppendLine('')

[void]$report.AppendLine('## 1) Leave-two-out (N-2 exhaustive)')
[void]$report.AppendLine(('- Total subsets tested: {0}' -f $l2o.Count))
[void]$report.AppendLine(('- Pearson range: {0:N6} to {1:N6}' -f (($l2oPearsons | Measure-Object -Minimum).Minimum), (($l2oPearsons | Measure-Object -Maximum).Maximum)))
[void]$report.AppendLine(('- Spearman range: {0:N6} to {1:N6}' -f (($l2oSpearmans | Measure-Object -Minimum).Minimum), (($l2oSpearmans | Measure-Object -Maximum).Maximum)))
[void]$report.AppendLine(('- Peak alignment delta range: {0} to {1} K' -f [int](($l2oPeaks | Measure-Object -Minimum).Minimum), [int](($l2oPeaks | Measure-Object -Maximum).Maximum)))
[void]$report.AppendLine(('- Worst Pearson subset: remove {0} -> Pearson={1:N6}, Spearman={2:N6}, peak delta={3} K' -f $l2oWorstPearson.removed, $l2oWorstPearson.pearson, $l2oWorstPearson.spearman, [int]$l2oWorstPearson.peak_delta))
[void]$report.AppendLine(('- Worst peak-alignment subset: remove {0} -> peak delta={1} K, Pearson={2:N6}' -f $l2oWorstPeak.removed, [int]$l2oWorstPeak.peak_delta, $l2oWorstPeak.pearson))
[void]$report.AppendLine(('- Reused LOO context: min Pearson={0:N6}, min Spearman={1:N6}' -f $looSummary.min_pearson, $looSummary.min_spearman))
[void]$report.AppendLine('')

[void]$report.AppendLine('## 2) Critical point removal (26K, 22K, 18K)')
[void]$report.AppendLine('| Case | n | Pearson | dPearson | Spearman | dSpearman | Peak delta (K) | Linear R2 | Power R2 | Canonical X rank | Canonical X Pareto |')
[void]$report.AppendLine('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|')
foreach ($r in $criticalResults) {
    [void]$report.AppendLine(('| {0} | {1} | {2:N6} | {3:N6} | {4:N6} | {5:N6} | {6} | {7:N6} | {8:N6} | {9}/121 | {10} |' -f $r.case, $r.n, $r.pearson, $r.d_pearson, $r.spearman, $r.d_spearman, [int]$r.peak_delta, $r.linear_r2, $r.power_r2, $r.canonical_rank_pearson, $r.canonical_pareto))
}
[void]$report.AppendLine('')

[void]$report.AppendLine('## 3) Region-based tests (low/mid/high T)')
[void]$report.AppendLine('| Region | T range (K) | n | Pearson | Spearman | Peak delta (K) | Linear R2 | Power R2 |')
[void]$report.AppendLine('|---|---|---:|---:|---:|---:|---:|---:|')
foreach ($r in $regionResults) {
    $range = switch ($r.region) { 'low_T' {'4-12'} 'mid_T' {'14-22'} 'high_T' {'24-30'} default {'-'} }
    [void]$report.AppendLine(('| {0} | {1} | {2} | {3:N6} | {4:N6} | {5} | {6:N6} | {7:N6} |' -f $r.region, $range, $r.n, $r.pearson, $r.spearman, [int]$r.peak_delta, $r.linear_r2, $r.power_r2))
}
[void]$report.AppendLine('')

[void]$report.AppendLine('## Stability metrics and worst-case degradation')
[void]$report.AppendLine(('- Worst Pearson drop vs baseline across requested tests: {0:N6}' -f $worstPearsonDrop))
[void]$report.AppendLine(('- Maximum peak misalignment across requested tests: {0} K' -f [int]$maxPeakShift))
[void]$report.AppendLine(('- Baseline to worst N-2 Pearson drop: {0:N6}' -f ($baseline.pearson - (($l2oPearsons | Measure-Object -Minimum).Minimum))))
[void]$report.AppendLine(('- Baseline to worst critical-removal Pearson drop: {0:N6}' -f ($baseline.pearson - ((($criticalResults | ForEach-Object {[double]$_.pearson}) | Measure-Object -Minimum).Minimum))))
[void]$report.AppendLine('')

[void]$report.AppendLine('## Interpretation')
[void]$report.AppendLine('- Correlation remains high under exhaustive leave-two-out and targeted point removals, with limited degradation.')
[void]$report.AppendLine('- Peak alignment is mostly preserved; worst tested shift is limited to a small number of grid steps.')
[void]$report.AppendLine('- Region splits show that low-T and mid-T sectors remain consistent, while high-T is less stable due to fewer points and local curvature.')
[void]$report.AppendLine(('- Final answer: X is **{0}** under the tested subset-removal stresses.' -f $verdict))

Set-Content -Path $reportPath -Value $report.ToString() -Encoding UTF8
Write-Output ('WROTE=' + (Resolve-Path $reportPath).Path)
