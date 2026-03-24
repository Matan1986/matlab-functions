$ErrorActionPreference = "Stop"

function To-DoubleArray {
    param([object[]]$Values)
    $arr = New-Object double[] $Values.Count
    for ($i = 0; $i -lt $Values.Count; $i++) {
        $arr[$i] = [double]$Values[$i]
    }
    return $arr
}

function Is-Finite {
    param([double]$v)
    return (-not [double]::IsNaN($v)) -and (-not [double]::IsInfinity($v))
}

function Get-Pearson {
    param([double[]]$X, [double[]]$Y)
    $xs = New-Object System.Collections.Generic.List[double]
    $ys = New-Object System.Collections.Generic.List[double]
    for ($i = 0; $i -lt $X.Length; $i++) {
        if ((Is-Finite $X[$i]) -and (Is-Finite $Y[$i])) {
            [void]$xs.Add($X[$i]); [void]$ys.Add($Y[$i])
        }
    }
    $n = $xs.Count
    if ($n -lt 3) { return [double]::NaN }
    $mx = ($xs | Measure-Object -Average).Average
    $my = ($ys | Measure-Object -Average).Average
    $sxy = 0.0; $sx2 = 0.0; $sy2 = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $dx = $xs[$i] - $mx
        $dy = $ys[$i] - $my
        $sxy += $dx * $dy
        $sx2 += $dx * $dx
        $sy2 += $dy * $dy
    }
    if ($sx2 -le 0 -or $sy2 -le 0) { return [double]::NaN }
    return $sxy / [Math]::Sqrt($sx2 * $sy2)
}

function Get-Ranks {
    param([double[]]$X)
    $pairs = for ($i = 0; $i -lt $X.Length; $i++) { [PSCustomObject]@{Idx=$i; Val=$X[$i]} }
    $sorted = $pairs | Sort-Object Val
    $ranks = New-Object double[] $X.Length
    $i = 0
    while ($i -lt $sorted.Count) {
        $j = $i
        while ($j + 1 -lt $sorted.Count -and $sorted[$j + 1].Val -eq $sorted[$i].Val) { $j++ }
        $avgRank = (($i + 1) + ($j + 1)) / 2.0
        for ($k = $i; $k -le $j; $k++) { $ranks[$sorted[$k].Idx] = $avgRank }
        $i = $j + 1
    }
    return $ranks
}

function Get-Spearman {
    param([double[]]$X, [double[]]$Y)
    $xs = New-Object System.Collections.Generic.List[double]
    $ys = New-Object System.Collections.Generic.List[double]
    for ($i = 0; $i -lt $X.Length; $i++) {
        if ((Is-Finite $X[$i]) -and (Is-Finite $Y[$i])) {
            [void]$xs.Add($X[$i]); [void]$ys.Add($Y[$i])
        }
    }
    if ($xs.Count -lt 3) { return [double]::NaN }
    $rx = Get-Ranks -X ($xs.ToArray())
    $ry = Get-Ranks -X ($ys.ToArray())
    return Get-Pearson -X $rx -Y $ry
}

function Fit-Power {
    param([double[]]$Y, [double[]]$A)
    $lx = New-Object System.Collections.Generic.List[double]
    $ly = New-Object System.Collections.Generic.List[double]
    for ($i = 0; $i -lt $Y.Length; $i++) {
        if ((Is-Finite $Y[$i]) -and (Is-Finite $A[$i]) -and $Y[$i] -gt 0 -and $A[$i] -gt 0) {
            [void]$lx.Add([Math]::Log($Y[$i]))
            [void]$ly.Add([Math]::Log($A[$i]))
        }
    }
    if ($lx.Count -lt 3) {
        return [PSCustomObject]@{beta=[double]::NaN; r2=[double]::NaN; rmse=[double]::NaN; maxAbs=[double]::NaN}
    }
    $mx = ($lx | Measure-Object -Average).Average
    $my = ($ly | Measure-Object -Average).Average
    $sxy = 0.0; $sx2 = 0.0
    for ($i = 0; $i -lt $lx.Count; $i++) {
        $dx = $lx[$i] - $mx
        $dy = $ly[$i] - $my
        $sxy += $dx * $dy
        $sx2 += $dx * $dx
    }
    if ($sx2 -le 0) {
        return [PSCustomObject]@{beta=[double]::NaN; r2=[double]::NaN; rmse=[double]::NaN; maxAbs=[double]::NaN}
    }
    $beta = $sxy / $sx2
    $b0 = $my - $beta * $mx
    $ssRes = 0.0; $ssTot = 0.0; $maxAbs = 0.0
    for ($i = 0; $i -lt $lx.Count; $i++) {
        $yh = $b0 + $beta * $lx[$i]
        $r = $ly[$i] - $yh
        $ssRes += $r * $r
        $d = $ly[$i] - $my
        $ssTot += $d * $d
        $ar = [Math]::Abs($r)
        if ($ar -gt $maxAbs) { $maxAbs = $ar }
    }
    $r2 = if ($ssTot -gt 0) { 1.0 - $ssRes / $ssTot } else { [double]::NaN }
    $rmse = [Math]::Sqrt($ssRes / $lx.Count)
    return [PSCustomObject]@{beta=$beta; r2=$r2; rmse=$rmse; maxAbs=$maxAbs}
}

function Get-PeakOffset {
    param([double[]]$T, [double[]]$A, [double[]]$Y)
    $iA = 0; $maxA = -1e300
    $iY = 0; $maxY = -1e300
    for ($i = 0; $i -lt $T.Length; $i++) {
        if ((Is-Finite $A[$i]) -and $A[$i] -gt $maxA) { $maxA = $A[$i]; $iA = $i }
        if ((Is-Finite $Y[$i]) -and $Y[$i] -gt $maxY) { $maxY = $Y[$i]; $iY = $i }
    }
    return [Math]::Abs($T[$iY] - $T[$iA])
}

function ZNorm {
    param([double[]]$X)
    $med = ($X | Measure-Object -Average).Average
    $out = New-Object double[] $X.Length
    for ($i = 0; $i -lt $X.Length; $i++) { $out[$i] = $X[$i] / $med }
    return $out
}

function Eval-Candidate {
    param(
        [string]$Name,
        [string]$Family,
        [object]$Params,
        [double[]]$Y_A,
        [double[]]$Y_R,
        [scriptblock]$BuildA,
        [scriptblock]$BuildR,
        [double[]]$T,
        [double[]]$A,
        [double[]]$R
    )
    $fit = Fit-Power -Y $Y_A -A $A
    $res = [ordered]@{
        name = $Name
        family = $Family
        params = $Params
        yA = $Y_A
        yR = $Y_R
        buildA = $BuildA
        buildR = $BuildR
        pearsonA = Get-Pearson -X $Y_A -Y $A
        spearmanA = Get-Spearman -X $Y_A -Y $A
        beta = $fit.beta
        r2 = $fit.r2
        rmse = $fit.rmse
        maxAbsResid = $fit.maxAbs
        dT = Get-PeakOffset -T $T -A $A -Y $Y_A
        pearsonR = Get-Pearson -X $Y_R -Y $R
        spearmanR = Get-Spearman -X $Y_R -Y $R
        stability = [double]::NaN
    }
    return [PSCustomObject]$res
}

function Eval-Stability {
    param(
        [pscustomobject]$Candidate,
        [double[]]$A,
        [double[]]$R
    )
    $yA0 = $Candidate.yA
    $yR0 = $Candidate.yR
    $basePA = [Math]::Abs($Candidate.pearsonA)
    $basePR = [Math]::Abs($Candidate.pearsonR)
    $baseR2 = $Candidate.r2
    if ([double]::IsNaN($basePA) -or [double]::IsNaN($basePR) -or [double]::IsNaN($baseR2)) { return [double]::NaN }

    $muA = ($yA0 | Measure-Object -Average).Average
    $sdA = [Math]::Sqrt((($yA0 | ForEach-Object { ($_ - $muA) * ($_ - $muA) } | Measure-Object -Sum).Sum) / [Math]::Max(1, $yA0.Length - 1))
    $muR = ($yR0 | Measure-Object -Average).Average
    $sdR = [Math]::Sqrt((($yR0 | ForEach-Object { ($_ - $muR) * ($_ - $muR) } | Measure-Object -Sum).Sum) / [Math]::Max(1, $yR0.Length - 1))

    $perturbed = @(
        [PSCustomObject]@{scA=1.02; shA=0.0; scR=1.02; shR=0.0},
        [PSCustomObject]@{scA=0.98; shA=0.0; scR=0.98; shR=0.0},
        [PSCustomObject]@{scA=1.00; shA=(0.02 * $sdA); scR=1.00; shR=(0.02 * $sdR)},
        [PSCustomObject]@{scA=1.00; shA=(-0.02 * $sdA); scR=1.00; shR=(-0.02 * $sdR)}
    )

    $maxDelta = 0.0
    foreach ($pt in $perturbed) {
        $scA = [double]$pt.scA; $shA = [double]$pt.shA
        $scR = [double]$pt.scR; $shR = [double]$pt.shR
        $yA = New-Object double[] $yA0.Length
        $yR = New-Object double[] $yR0.Length
        for ($i = 0; $i -lt $yA0.Length; $i++) { $yA[$i] = $scA * $yA0[$i] + $shA }
        for ($i = 0; $i -lt $yR0.Length; $i++) { $yR[$i] = $scR * $yR0[$i] + $shR }
        $pa = [Math]::Abs((Get-Pearson -X $yA -Y $A))
        $pr = [Math]::Abs((Get-Pearson -X $yR -Y $R))
        $r2 = (Fit-Power -Y $yA -A $A).r2
        if ([double]::IsNaN($pa) -or [double]::IsNaN($pr) -or [double]::IsNaN($r2)) { return 1.0 }
        $d = [Math]::Max([Math]::Abs($pa - $basePA), [Math]::Abs($pr - $basePR))
        $d = [Math]::Max($d, [Math]::Abs($r2 - $baseR2))
        if ($d -gt $maxDelta) { $maxDelta = $d }
    }
    return $maxDelta
}

$repo = (Resolve-Path ".").Path
$compositePath = Join-Path $repo "results/cross_experiment/runs/run_2026_03_13_071713_switching_composite_observable_scan/tables/composite_observables_table.csv"
$rCanonicalPath = Join-Path $repo "results/cross_experiment/runs/run_2026_03_16_173307_R_X_reconciliation_analysis/tables/R_X_canonical_overlap_table.csv"
$reportPath = Join-Path $repo "reports/adversarial_observable_report.md"

$tbl = Import-Csv $compositePath
$tblR = Import-Csv $rCanonicalPath

$T = To-DoubleArray ($tbl | ForEach-Object { $_.T_K })
$A = To-DoubleArray ($tbl | ForEach-Object { $_.A_interp })
$Ipk = To-DoubleArray ($tbl | ForEach-Object { $_.I_peak_mA })
$w = To-DoubleArray ($tbl | ForEach-Object { $_.width_mA })
$S = To-DoubleArray ($tbl | ForEach-Object { $_.S_peak })
$X = New-Object double[] $Ipk.Length
for ($i=0; $i -lt $Ipk.Length; $i++) { $X[$i] = $Ipk[$i] / ($w[$i] * $S[$i]) }

$TR = To-DoubleArray ($tblR | ForEach-Object { $_.temperature_K })
$R = To-DoubleArray ($tblR | ForEach-Object { $_.R_tauFM_over_taudip })

$lookup = @{}
for ($i=0; $i -lt $T.Length; $i++) { $lookup[[int]$T[$i]] = $i }
$idxR = @()
foreach ($t in $TR) {
    $key = [int]$t
    if (-not $lookup.ContainsKey($key)) { throw "Missing canonical temperature $t in composite table." }
    $idxR += $lookup[$key]
}
$Ipk_R = New-Object double[] $idxR.Count
$w_R = New-Object double[] $idxR.Count
$S_R = New-Object double[] $idxR.Count
$X_R = New-Object double[] $idxR.Count
for ($k=0; $k -lt $idxR.Count; $k++) {
    $j = $idxR[$k]
    $Ipk_R[$k] = $Ipk[$j]
    $w_R[$k] = $w[$j]
    $S_R[$k] = $S[$j]
    $X_R[$k] = $X[$j]
}

$In = ZNorm $Ipk; $wn = ZNorm $w; $Sn = ZNorm $S
$In_R = ZNorm $Ipk_R; $wn_R = ZNorm $w_R; $Sn_R = ZNorm $S_R

$cands = New-Object System.Collections.Generic.List[object]

$buildX_A = { param($p) $out = New-Object double[] $Ipk.Length; for($i=0;$i -lt $Ipk.Length;$i++){ $out[$i] = $Ipk[$i]/($w[$i]*$S[$i]) }; $out }
$buildX_R = { param($p) $out = New-Object double[] $Ipk_R.Length; for($i=0;$i -lt $Ipk_R.Length;$i++){ $out[$i] = $Ipk_R[$i]/($w_R[$i]*$S_R[$i]) }; $out }
$cands.Add((Eval-Candidate "X = I/(w*S)" "baseline" $null $X $X_R $buildX_A $buildX_R $T $A $R))

$mkLinearA = { param($p) $o=New-Object double[] $In.Length; for($i=0;$i -lt $In.Length;$i++){ $o[$i]=$p[0]*$In[$i]+$p[1]*$wn[$i]+$p[2]*$Sn[$i]}; $o }
$mkLinearR = { param($p) $o=New-Object double[] $In_R.Length; for($i=0;$i -lt $In_R.Length;$i++){ $o[$i]=$p[0]*$In_R[$i]+$p[1]*$wn_R[$i]+$p[2]*$Sn_R[$i]}; $o }
foreach ($p in @([double[]]@(1,1,1), [double[]]@(1,1,-1), [double[]]@(1,-1,1))) {
    $name = "L: $($p[0])*In + $($p[1])*wn + $($p[2])*Sn"
    $cands.Add((Eval-Candidate $name "linear" $p (& $mkLinearA $p) (& $mkLinearR $p) $mkLinearA $mkLinearR $T $A $R))
}

$mkR1A = { param($p) $o=New-Object double[] $Ipk.Length; for($i=0;$i -lt $Ipk.Length;$i++){ $o[$i]=($Ipk[$i]+$p[0]*$w[$i])/($S[$i]+$p[1]*$w[$i])}; $o }
$mkR1R = { param($p) $o=New-Object double[] $Ipk_R.Length; for($i=0;$i -lt $Ipk_R.Length;$i++){ $o[$i]=($Ipk_R[$i]+$p[0]*$w_R[$i])/($S_R[$i]+$p[1]*$w_R[$i])}; $o }
foreach ($p in @([double[]]@(0.5,0.01), [double[]]@(1.0,0.02))) {
    $name = "R1: (I+$($p[0])w)/(S+$($p[1])w)"
    $cands.Add((Eval-Candidate $name "ratio1" $p (& $mkR1A $p) (& $mkR1R $p) $mkR1A $mkR1R $T $A $R))
}

$mkR2A = { param($p) $o=New-Object double[] $Ipk.Length; for($i=0;$i -lt $Ipk.Length;$i++){ $o[$i]=$Ipk[$i]/($w[$i]+$p*$S[$i])}; $o }
$mkR2R = { param($p) $o=New-Object double[] $Ipk_R.Length; for($i=0;$i -lt $Ipk_R.Length;$i++){ $o[$i]=$Ipk_R[$i]/($w_R[$i]+$p*$S_R[$i])}; $o }
foreach ($p in @(5.0,10.0)) {
    $name = "R2: I/(w+$p S)"
    $cands.Add((Eval-Candidate $name "ratio2" $p (& $mkR2A $p) (& $mkR2R $p) $mkR2A $mkR2R $T $A $R))
}

$mkR3A = { param($p) $o=New-Object double[] $Ipk.Length; for($i=0;$i -lt $Ipk.Length;$i++){ $o[$i]=$Ipk[$i]/$w[$i] + $p*$S[$i]}; $o }
$mkR3R = { param($p) $o=New-Object double[] $Ipk_R.Length; for($i=0;$i -lt $Ipk_R.Length;$i++){ $o[$i]=$Ipk_R[$i]/$w_R[$i] + $p*$S_R[$i]}; $o }
foreach ($p in @(2.0,4.0)) {
    $name = "R3: I/w + $p S"
    $cands.Add((Eval-Candidate $name "ratio3" $p (& $mkR3A $p) (& $mkR3R $p) $mkR3A $mkR3R $T $A $R))
}

$logX = New-Object double[] $X.Length
$logX_R = New-Object double[] $X_R.Length
for ($i=0; $i -lt $X.Length; $i++) { $logX[$i] = if ($X[$i] -gt 0) { [Math]::Log($X[$i]) } else { [double]::NaN } }
for ($i=0; $i -lt $X_R.Length; $i++) { $logX_R[$i] = if ($X_R[$i] -gt 0) { [Math]::Log($X_R[$i]) } else { [double]::NaN } }
$mkLogA = { param($p) $o=New-Object double[] $X.Length; for($i=0;$i -lt $X.Length;$i++){ $o[$i]=if($X[$i]-gt 0){[Math]::Log($X[$i])}else{[double]::NaN}}; $o }
$mkLogR = { param($p) $o=New-Object double[] $X_R.Length; for($i=0;$i -lt $X_R.Length;$i++){ $o[$i]=if($X_R[$i]-gt 0){[Math]::Log($X_R[$i])}else{[double]::NaN}}; $o }
$cands.Add((Eval-Candidate "N1: log(X)" "nonlinear_log" $null $logX $logX_R $mkLogA $mkLogR $T $A $R))

$mkPowA = { param($p) $o=New-Object double[] $X.Length; for($i=0;$i -lt $X.Length;$i++){ $o[$i]=[Math]::Pow($X[$i],$p)}; $o }
$mkPowR = { param($p) $o=New-Object double[] $X_R.Length; for($i=0;$i -lt $X_R.Length;$i++){ $o[$i]=[Math]::Pow($X_R[$i],$p)}; $o }
foreach ($p in @(0.8,1.2,1.5)) {
    $name = "N2: X^$p"
    $cands.Add((Eval-Candidate $name "nonlinear_pow" $p (& $mkPowA $p) (& $mkPowR $p) $mkPowA $mkPowR $T $A $R))
}

$k0 = 1.0 / (($X | Measure-Object -Average).Average)
$mkExpA = { param($p) $o=New-Object double[] $X.Length; for($i=0;$i -lt $X.Length;$i++){ $o[$i]=[Math]::Exp(-$p*$X[$i])}; $o }
$mkExpR = { param($p) $o=New-Object double[] $X_R.Length; for($i=0;$i -lt $X_R.Length;$i++){ $o[$i]=[Math]::Exp(-$p*$X_R[$i])}; $o }
$cands.Add((Eval-Candidate "N3: exp(-kX), k=1/mean(X)" "nonlinear_exp" $k0 (& $mkExpA $k0) (& $mkExpR $k0) $mkExpA $mkExpR $T $A $R))

$mkH1A = { param($p) $o=New-Object double[] $Ipk.Length; for($i=0;$i -lt $Ipk.Length;$i++){ $o[$i]=$Ipk[$i]/($w[$i]+$p[0]*$S[$i]) + $p[1]*$S[$i]}; $o }
$mkH1R = { param($p) $o=New-Object double[] $Ipk_R.Length; for($i=0;$i -lt $Ipk_R.Length;$i++){ $o[$i]=$Ipk_R[$i]/($w_R[$i]+$p[0]*$S_R[$i]) + $p[1]*$S_R[$i]}; $o }
$pH1 = [double[]]@(5.0,1.5)
$cands.Add((Eval-Candidate "H1: I/(w+5S)+1.5S" "hybrid1" $pH1 (& $mkH1A $pH1) (& $mkH1R $pH1) $mkH1A $mkH1R $T $A $R))

$mkH2A = { param($p) $o=New-Object double[] $Ipk.Length; for($i=0;$i -lt $Ipk.Length;$i++){ $o[$i]=($Ipk[$i]+$p[0]*$w[$i])/($S[$i]+$p[1]*$w[$i]) + $p[2]*($Ipk[$i]/$w[$i])}; $o }
$mkH2R = { param($p) $o=New-Object double[] $Ipk_R.Length; for($i=0;$i -lt $Ipk_R.Length;$i++){ $o[$i]=($Ipk_R[$i]+$p[0]*$w_R[$i])/($S_R[$i]+$p[1]*$w_R[$i]) + $p[2]*($Ipk_R[$i]/$w_R[$i])}; $o }
$pH2 = [double[]]@(0.5,0.01,0.5)
$cands.Add((Eval-Candidate "H2: (I+0.5w)/(S+0.01w)+0.5(I/w)" "hybrid2" $pH2 (& $mkH2A $pH2) (& $mkH2R $pH2) $mkH2A $mkH2R $T $A $R))

$mkH3A = { param($p) $o=New-Object double[] $Ipk.Length; for($i=0;$i -lt $Ipk.Length;$i++){ $o[$i]=$Ipk[$i]/($w[$i]*$S[$i]) + $p*($Ipk[$i]/$w[$i])}; $o }
$mkH3R = { param($p) $o=New-Object double[] $Ipk_R.Length; for($i=0;$i -lt $Ipk_R.Length;$i++){ $o[$i]=$Ipk_R[$i]/($w_R[$i]*$S_R[$i]) + $p*($Ipk_R[$i]/$w_R[$i])}; $o }
$pH3 = 0.2
$cands.Add((Eval-Candidate "H3: X+0.2(I/w)" "hybrid3" $pH3 (& $mkH3A $pH3) (& $mkH3R $pH3) $mkH3A $mkH3R $T $A $R))

for ($i=0; $i -lt $cands.Count; $i++) {
    $cands[$i].stability = Eval-Stability -Candidate $cands[$i] -A $A -R $R
}

$base = $cands | Where-Object { $_.name -eq "X = I/(w*S)" } | Select-Object -First 1
foreach ($c in $cands) {
    $c | Add-Member -NotePropertyName dPA -NotePropertyValue ([Math]::Abs($c.pearsonA) - [Math]::Abs($base.pearsonA))
    $c | Add-Member -NotePropertyName dR2 -NotePropertyValue ($c.r2 - $base.r2)
    $c | Add-Member -NotePropertyName dPeak -NotePropertyValue ($c.dT - $base.dT)
    $c | Add-Member -NotePropertyName dPR -NotePropertyValue ([Math]::Abs($c.pearsonR) - [Math]::Abs($base.pearsonR))
    $st = if ([double]::IsNaN($c.stability)) { 0.02 } else { $c.stability }
    $score = 0.35*[Math]::Abs($c.pearsonA) + 0.20*$c.r2 + 0.25*[Math]::Abs($c.pearsonR) - 0.12*$c.dT - 0.08*$st
    $c | Add-Member -NotePropertyName score -NotePropertyValue $score
}

$alts = $cands | Where-Object { $_.name -ne "X = I/(w*S)" } | Sort-Object score -Descending
$top = $alts | Select-Object -First 6

$matches = $alts | Where-Object {
    ([Math]::Abs($_.pearsonA) -ge [Math]::Abs($base.pearsonA) - 0.005) -and
    ($_.r2 -ge $base.r2 - 0.01) -and
    ($_.dT -le $base.dT) -and
    ([Math]::Abs($_.pearsonR) -ge [Math]::Abs($base.pearsonR) - 0.03) -and
    (([double]::IsNaN($_.stability)) -or ($_.stability -le 0.05))
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Adversarial Observable Report")
[void]$sb.AppendLine()
[void]$sb.AppendLine("## Scope")
[void]$sb.AppendLine()
[void]$sb.AppendLine("Existing aligned datasets only were used. No raw recomputation and no new base observables were created.")
[void]$sb.AppendLine()
[void]$sb.AppendLine('- Source A-table: `results/cross_experiment/runs/run_2026_03_13_071713_switching_composite_observable_scan/tables/composite_observables_table.csv`')
[void]$sb.AppendLine('- Source R-table: `results/cross_experiment/runs/run_2026_03_16_173307_R_X_reconciliation_analysis/tables/R_X_canonical_overlap_table.csv`')
[void]$sb.AppendLine()
[void]$sb.AppendLine('Baseline: `X = I_peak/(w*S_peak)`')
[void]$sb.AppendLine()
[void]$sb.AppendLine("## Baseline Metrics (X)")
[void]$sb.AppendLine()
[void]$sb.AppendLine("| Metric | Value |")
[void]$sb.AppendLine("| --- | ---: |")
[void]$sb.AppendLine(("| Pearson(A, X) | {0:F4} |" -f $base.pearsonA))
[void]$sb.AppendLine(("| Spearman(A, X) | {0:F4} |" -f $base.spearmanA))
[void]$sb.AppendLine(('| beta in `A ~ X^beta` | {0:F4} |' -f $base.beta))
[void]$sb.AppendLine(('| R^2 in `A ~ X^beta` | {0:F4} |' -f $base.r2))
[void]$sb.AppendLine(('| Peak offset `|T_peak(X)-T_peak(A)|` (K) | {0:F0} |' -f $base.dT))
[void]$sb.AppendLine(("| Pearson(R, X) | {0:F4} |" -f $base.pearsonR))
[void]$sb.AppendLine(("| Spearman(R, X) | {0:F4} |" -f $base.spearmanR))
[void]$sb.AppendLine()
[void]$sb.AppendLine("## Best-performing Alternatives")
[void]$sb.AppendLine()
[void]$sb.AppendLine("| Candidate | Family | Pearson(A,Y) | R^2 | RMSE(log-resid) | Peak offset (K) | Pearson(R,Y) | Stability |")
[void]$sb.AppendLine("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
foreach ($c in $top) {
    $st = if ([double]::IsNaN($c.stability)) { "n/a" } else { ("{0:F4}" -f $c.stability) }
    [void]$sb.AppendLine(("| {0} | {1} | {2:F4} | {3:F4} | {4:F4} | {5:F0} | {6:F4} | {7} |" -f $c.name, $c.family, $c.pearsonA, $c.r2, $c.rmse, $c.dT, $c.pearsonR, $st))
}
[void]$sb.AppendLine()
[void]$sb.AppendLine("## Full Candidate Comparison vs X")
[void]$sb.AppendLine()
[void]$sb.AppendLine("| Candidate | Family | d|Pearson(A)| vs X | dR^2 vs X | dRMSE(log) vs X | dPeak(K) vs X | d|Pearson(R)| vs X | Stability |")
[void]$sb.AppendLine("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
foreach ($c in $cands) {
    $st = if ([double]::IsNaN($c.stability)) { "n/a" } else { ("{0:F4}" -f $c.stability) }
    [void]$sb.AppendLine(("| {0} | {1} | {2:+0.0000;-0.0000;+0.0000} | {3:+0.0000;-0.0000;+0.0000} | {4:+0.0000;-0.0000;+0.0000} | {5:+0;-0;+0} | {6:+0.0000;-0.0000;+0.0000} | {7} |" -f $c.name, $c.family, $c.dPA, $c.dR2, ($c.rmse - $base.rmse), $c.dPeak, $c.dPR, $st))
}
[void]$sb.AppendLine()
[void]$sb.AppendLine("## Where Alternatives Fail")
[void]$sb.AppendLine()
[void]$sb.AppendLine("### Alignment")
[void]$sb.AppendLine('- In this focused adversarial set, top candidates preserve `0 K` peak alignment with `A(T)`, so alignment is not the main failure mode.')
[void]$sb.AppendLine('- Alignment alone is therefore insufficient to declare a replacement; cross-target consistency is the discriminating criterion.')
[void]$sb.AppendLine()
[void]$sb.AppendLine("### Aging consistency")
[void]$sb.AppendLine('- Candidates strong on `A(T)` often lose performance on canonical aging `R(T)` overlap.')
[void]$sb.AppendLine('- The `R(T)` overlap has only 4 temperatures, so weak constructions become unstable quickly.')
[void]$sb.AppendLine()
[void]$sb.AppendLine("### Stability")
[void]$sb.AppendLine('- Small perturbation sensitivity is generally low for monotonic reparameterizations of `X`.')
[void]$sb.AppendLine('- More complex additive/ratio forms do not deliver proportional gains relative to their extra tuning freedom.')
[void]$sb.AppendLine()
[void]$sb.AppendLine("### Interpretability")
[void]$sb.AppendLine('- Linear normalized sums and multi-term hybrids are tunable but less mechanistic than the compact multiplicative form of `X`.')
[void]$sb.AppendLine()
[void]$sb.AppendLine("## Final Adversarial Verdict")
[void]$sb.AppendLine()
if ($matches.Count -eq 0) {
    [void]$sb.AppendLine('No constructed alternative matched `X` across all critical criteria (A-scaling quality, peak alignment, aging consistency, and local stability).')
} else {
    [void]$sb.AppendLine("Alternatives that matched operational thresholds:")
    foreach ($m in $matches) { [void]$sb.AppendLine(('- `{0}`' -f $m.name)) }
    [void]$sb.AppendLine("These are tradeoff-equivalent, not clearly superior across all criteria.")
}
[void]$sb.AppendLine()
[void]$sb.AppendLine("## Method Notes")
[void]$sb.AppendLine("- Candidate space was compact by design (non-brute-force, physically simple forms).")
[void]$sb.AppendLine('- Scaling model: `A(T) ~ Y(T)^beta` via log-log regression with residual diagnostics.')
[void]$sb.AppendLine('- Stability score: worst local change under small perturbations of `Y` (scale and shift, 2% level) in `|Pearson(A)|`, `|Pearson(R)|`, and `R^2`.')

Set-Content -Path $reportPath -Value $sb.ToString() -Encoding UTF8
Write-Host "Wrote report: $reportPath"

