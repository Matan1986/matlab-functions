# Agent 24I — LOOCV OLS via leverage (same as MATLAB localLoocvOls)
$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Test-DoubleFinite {
    param([double]$x)
    return -not ([double]::IsNaN($x) -or [double]::IsPositiveInfinity($x) -or [double]::IsNegativeInfinity($x))
}

function Solve-LinearSystem {
    param([double[][]]$A, [double[]]$b)
    $n = $b.Count
    $M = @()
    for ($r = 0; $r -lt $n; $r++) {
        $row = @($A[$r] + @($b[$r]))
        $M += ,$row
    }
    for ($col = 0; $col -lt $n; $col++) {
        $piv = $col
        $maxv = [math]::Abs($M[$piv][$col])
        for ($r = $col + 1; $r -lt $n; $r++) {
            $v = [math]::Abs($M[$r][$col])
            if ($v -gt $maxv) { $maxv = $v; $piv = $r }
        }
        if ($maxv -lt 1e-15) { return $null }
        if ($piv -ne $col) { $tmp = $M[$col]; $M[$col] = $M[$piv]; $M[$piv] = $tmp }
        $div = $M[$col][$col]
        for ($c = $col; $c -le $n; $c++) { $M[$col][$c] /= $div }
        for ($r = 0; $r -lt $n; $r++) {
            if ($r -eq $col) { continue }
            $f = $M[$r][$col]
            if ([math]::Abs($f) -lt 1e-18) { continue }
            for ($c = $col; $c -le $n; $c++) {
                $M[$r][$c] -= $f * $M[$col][$c]
            }
        }
    }
    $x = [Array]::CreateInstance([System.Double], [int32]$n)
    for ($i = 0; $i -lt $n; $i++) { $x[$i] = $M[$i][$n] }
    return ,$x
}

function Loocv-Ols-Leverage {
    param([double[]]$y, [double[][]]$Xcols)
    $n = $y.Count
    $p = $Xcols.Count
    $yhat = [Array]::CreateInstance([System.Double], [int32]$n)
    if ($n -le $p + 1) { return @{ rmse = [double]::NaN; pearson = [double]::NaN; yhat = $yhat } }
    $Z = @()
    for ($i = 0; $i -lt $n; $i++) {
        $zr = [Array]::CreateInstance([System.Double], [int32]($p + 1))
        $zr[0] = 1.0
        $cc = 1
        foreach ($col in $Xcols) { $zr[$cc] = [double]$col[$i]; $cc++ }
        $Z += ,$zr
    }
    $dim = $p + 1
    $ZtZ = @()
    for ($a = 0; $a -lt $dim; $a++) {
        $row = [Array]::CreateInstance([System.Double], [int32]$dim)
        for ($b = 0; $b -lt $dim; $b++) {
            $s = 0.0
            for ($i = 0; $i -lt $n; $i++) { $s += $Z[$i][$a] * $Z[$i][$b] }
            $row[$b] = $s
        }
        $ZtZ += ,$row
    }
    $Zty = [Array]::CreateInstance([System.Double], [int32]$dim)
    for ($a = 0; $a -lt $dim; $a++) {
        $s = 0.0
        for ($i = 0; $i -lt $n; $i++) { $s += $Z[$i][$a] * $y[$i] }
        $Zty[$a] = $s
    }
    $beta = Solve-LinearSystem -A $ZtZ -b $Zty
    if ($null -eq $beta) { return @{ rmse = [double]::NaN; pearson = [double]::NaN; yhat = $yhat } }
    $yfit = [Array]::CreateInstance([System.Double], [int32]$n)
    for ($i = 0; $i -lt $n; $i++) {
        $s = 0.0
        for ($a = 0; $a -lt $dim; $a++) { $s += $Z[$i][$a] * $beta[$a] }
        $yfit[$i] = $s
    }
    $e = [Array]::CreateInstance([System.Double], [int32]$n)
    for ($i = 0; $i -lt $n; $i++) { $e[$i] = $y[$i] - $yfit[$i] }
    # h_i = z_i' (Z'Z)^{-1} z_i via Solve(Z'Z, z_i)
    $sloo = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $zi = [Array]::CreateInstance([System.Double], [int32]$dim)
        for ($a = 0; $a -lt $dim; $a++) { $zi[$a] = $Z[$i][$a] }
        $wi = Solve-LinearSystem -A $ZtZ -b $zi
        if ($null -eq $wi) { return @{ rmse = [double]::NaN; pearson = [double]::NaN; yhat = $yhat } }
        $h = 0.0
        for ($a = 0; $a -lt $dim; $a++) { $h += $Z[$i][$a] * $wi[$a] }
        $loo = $e[$i] / [math]::Max(1.0 - $h, 1e-12)
        $yhat[$i] = $y[$i] - $loo
        $sloo += $loo * $loo
    }
    $rmse = [math]::Sqrt($sloo / $n)
    $my = ($y | Measure-Object -Average).Average
    $mh = ($yhat | Measure-Object -Average).Average
    $num = 0.0; $d1 = 0.0; $d2 = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $num += ($y[$i] - $my) * ($yhat[$i] - $mh)
        $d1 += [math]::Pow($y[$i] - $my, 2)
        $d2 += [math]::Pow($yhat[$i] - $mh, 2)
    }
    $pearson = if ($d1 -gt 1e-30 -and $d2 -gt 1e-30) { $num / [math]::Sqrt($d1 * $d2) } else { [double]::NaN }
    return @{ rmse = $rmse; pearson = $pearson; yhat = $yhat }
}

function Mean-Abs-Window {
    param([double[]]$T, [double[]]$y, [double[]]$yh, [scriptblock]$mask)
    $s = 0.0; $c = 0
    for ($i = 0; $i -lt $T.Count; $i++) {
        if (& $mask $T[$i]) {
            $s += [math]::Abs($y[$i] - $yh[$i])
            $c++
        }
    }
    if ($c -eq 0) { return [double]::NaN }
    return $s / $c
}

function Support-Label {
    param([double]$rmseNew, [double]$rmseRef, [double]$m22New, [double]$m22Ref, [double]$thrR, [double]$thrT)
    if (-not (Test-DoubleFinite $rmseNew) -or -not (Test-DoubleFinite $m22New)) { return "NO (model not fitted)" }
    $pctR = 100.0 * ($rmseRef - $rmseNew) / [math]::Max($rmseRef, 1e-12)
    $pctT = 100.0 * ($m22Ref - $m22New) / [math]::Max($m22Ref, 1e-12)
    $g = $pctR -ge $thrR
    $t = (Test-DoubleFinite $m22Ref) -and $m22Ref -gt 0 -and $pctT -ge $thrT
    if ($g -and $t) { return "YES" }
    if ($g -or $t) { return "PARTIAL" }
    return "NO"
}

$barrierP = Join-Path $RepoRoot "results\cross_experiment\runs\run_2026_03_25_031904_barrier_to_relaxation_mechanism\tables\barrier_descriptors.csv"
$energyP = Join-Path $RepoRoot "results\switching\runs\run_2026_03_24_233256_energy_mapping\tables\energy_stats.csv"
$clkP = Join-Path $RepoRoot "results\aging\runs\run_2026_03_14_074613_aging_clock_ratio_analysis\tables\table_clock_ratio.csv"
$alphaP = Join-Path $RepoRoot "tables\alpha_structure.csv"
$decompP = Join-Path $RepoRoot "tables\alpha_decomposition.csv"

$bar = Import-Csv $barrierP
$en = Import-Csv $energyP
if ($en[0].PSObject.Properties.Name -notcontains 'T_K') {
    $en = $en | ForEach-Object {
        $_ | Add-Member -NotePropertyName T_K -NotePropertyValue $_.T -Force
        $_
    }
}
$bar = $bar | ForEach-Object {
    $tk = [string]$_.T_K
    $e = $en | Where-Object { [string]$_.T_K -eq $tk } | Select-Object -First 1
    if (-not $e) { return }
    $_ | Add-Member -NotePropertyName mean_E -NotePropertyValue $e.mean_E -Force
    $_ | Add-Member -NotePropertyName std_E -NotePropertyValue $e.std_E -Force
    $_
}
$bar = $bar | Where-Object { $_.mean_E }

$bar = $bar | ForEach-Object {
    $q90 = [double]$_.q90_I_mA
    $q50 = [double]$_.q50_I_mA
    $_ | Add-Member -NotePropertyName spread90_50 -NotePropertyValue ($q90 - $q50) -Force
    $_
}

$aS = Import-Csv $alphaP
$aD = Import-Csv $decompP

$merged = @()
foreach ($s in $aS) {
    $tk = [double]$s.T_K
    $d = $aD | Where-Object { [double]$_.T_K -eq $tk } | Select-Object -First 1
    if (-not $d) { continue }
    $b = $bar | Where-Object { [double]$_.T_K -eq $tk } | Select-Object -First 1
    if (-not $b) { continue }
    if ([double]$d.PT_geometry_valid -eq 0) { continue }
    if ([double]$b.row_valid -eq 0) { continue }
    $merged += [pscustomobject]@{
        T_K            = $tk
        R              = [double]$b.R_T_interp
        spread90_50    = [double]$b.spread90_50
        kappa1         = [double]$s.kappa1
        kappa2         = [double]$s.kappa2
        alpha          = [double]$s.alpha
        alpha_res      = if ($d.alpha_res -eq "" -or $d.alpha_res -eq $null) { [double]::NaN } else { [double]$d.alpha_res }
    }
}
$merged = $merged | Sort-Object T_K

$T = @(); $R = @(); $sp = @(); $k1 = @(); $k2 = @(); $al = @(); $ares = @()
foreach ($m in $merged) {
    $T += $m.T_K
    $R += $m.R
    $sp += $m.spread90_50
    $k1 += $m.kappa1
    $k2 += $m.kappa2
    $al += $m.alpha
    $ares += $m.alpha_res
}

$nAll = $T.Count
$ok = [Array]::CreateInstance([System.Int32], [int32]$nAll)
for ($i = 0; $i -lt $nAll; $i++) {
    $ok[$i] = (Test-DoubleFinite $R[$i]) -and (Test-DoubleFinite $sp[$i]) -and (Test-DoubleFinite $k1[$i]) -and (Test-DoubleFinite $k2[$i]) -and (Test-DoubleFinite $al[$i])
}
$idx = @()
for ($i = 0; $i -lt $nAll; $i++) { if ($ok[$i]) { $idx += $i } }
if ($idx.Count -lt 5) { throw "Insufficient rows" }

$y = @(); $Tplot = @(); $spread = @(); $kk1 = @(); $kk2 = @(); $alpha = @(); $ar = @()
foreach ($i in $idx) {
    $y += $R[$i]
    $Tplot += $T[$i]
    $spread += $sp[$i]
    $kk1 += $k1[$i]
    $kk2 += $k2[$i]
    $alpha += $al[$i]
    $ar += $ares[$i]
}
$n = $y.Count

$modelCok = $true
foreach ($x in $ar) { if (-not (Test-DoubleFinite $x)) { $modelCok = $false } }

$sigmaG = 1.5; $t0g = 23.0
$g23 = [Array]::CreateInstance([System.Double], [int32]$n)
$k1a = [Array]::CreateInstance([System.Double], [int32]$n)
$absAr = [Array]::CreateInstance([System.Double], [int32]$n)
for ($i = 0; $i -lt $n; $i++) {
    $g23[$i] = [math]::Exp(-[math]::Pow($Tplot[$i] - $t0g, 2) / (2 * $sigmaG * $sigmaG))
    $k1a[$i] = $kk1[$i] * $alpha[$i]
    $absAr[$i] = [math]::Abs($ar[$i])
}

$models = @(
    @{ id = "R ~ spread90_50 + kappa1 + alpha"; ext = $false; cols = @($spread, $kk1, $alpha) }
    @{ id = "R ~ spread90_50 + kappa1 + alpha + kappa1*alpha"; ext = $true; cols = @($spread, $kk1, $alpha, $k1a) }
    @{ id = "R ~ spread90_50 + kappa1 + alpha + g23(T)"; ext = $true; cols = @($spread, $kk1, $alpha, $g23) }
)
if ($modelCok) {
    $models += @{ id = "R ~ spread90_50 + kappa1 + alpha + abs(alpha_res)"; ext = $true; cols = @($spread, $kk1, $alpha, $absAr) }
}

$results = @()
$yStore = @{}
foreach ($md in $models) {
    $Xcols = @()
    foreach ($c in $md.cols) { $Xcols += ,$c }
    $out = Loocv-Ols-Leverage -y $y -Xcols $Xcols
    $yStore[$md.id] = $out.yhat
    $results += [pscustomobject]@{
        model = $md.id; n = $n; loocv_rmse = $out.rmse; pearson_y_yhat = $out.pearson; is_extension = $md.ext
    }
}

$refId = "R ~ spread90_50 + kappa1 + alpha"
$rmseRef = ($results | Where-Object { $_.model -eq $refId }).loocv_rmse
$yhatRef = $yStore[$refId]
$m22Ref = Mean-Abs-Window -T $Tplot -y $y -yh $yhatRef -mask { param($t) $t -ge 22 -and $t -le 24 }
$mOutRef = Mean-Abs-Window -T $Tplot -y $y -yh $yhatRef -mask { param($t) -not ($t -ge 22 -and $t -le 24) }

foreach ($r in $results) {
    $yh = $yStore[$r.model]
    $m22 = Mean-Abs-Window -T $Tplot -y $y -yh $yh -mask { param($t) $t -ge 22 -and $t -le 24 }
    $mOut = Mean-Abs-Window -T $Tplot -y $y -yh $yh -mask { param($t) -not ($t -ge 22 -and $t -le 24) }
    $r | Add-Member -NotePropertyName mean_abs_res_22_24K -NotePropertyValue $m22 -Force
    $r | Add-Member -NotePropertyName mean_abs_res_outside_22_24K -NotePropertyValue $mOut -Force
    $r | Add-Member -NotePropertyName pct_loocv_rmse_vs_reference -NotePropertyValue (100.0 * ($r.loocv_rmse - $rmseRef) / [math]::Max($rmseRef, 1e-12)) -Force
    $r | Add-Member -NotePropertyName pct_transition_mean_abs_res_vs_reference -NotePropertyValue (100.0 * ($m22 - $m22Ref) / [math]::Max($m22Ref, 1e-12)) -Force
}

$fin = $results | Where-Object { Test-DoubleFinite $_.loocv_rmse }
$best = $fin | Sort-Object loocv_rmse | Select-Object -First 1
$bestId = $best.model
$bestRmse = $best.loocv_rmse
$yhatBest = $yStore[$bestId]
$m22Best = Mean-Abs-Window -T $Tplot -y $y -yh $yhatBest -mask { param($t) $t -ge 22 -and $t -le 24 }

$idA = "R ~ spread90_50 + kappa1 + alpha + kappa1*alpha"
$idB = "R ~ spread90_50 + kappa1 + alpha + g23(T)"
$idC = "R ~ spread90_50 + kappa1 + alpha + abs(alpha_res)"
function Get-R ($id) { ($results | Where-Object { $_.model -eq $id }).loocv_rmse }
function Get-M22 ($id) { ($results | Where-Object { $_.model -eq $id }).mean_abs_res_22_24K }

$thrR = 3; $thrT = 10
$vInt = Support-Label -rmseNew (Get-R $idA) -rmseRef $rmseRef -m22New (Get-M22 $idA) -m22Ref $m22Ref -thrR $thrR -thrT $thrT
$vLoc = Support-Label -rmseNew (Get-R $idB) -rmseRef $rmseRef -m22New (Get-M22 $idB) -m22Ref $m22Ref -thrR $thrR -thrT $thrT
if ($modelCok) {
    $vRes = Support-Label -rmseNew (Get-R $idC) -rmseRef $rmseRef -m22New (Get-M22 $idC) -m22Ref $m22Ref -thrR $thrR -thrT $thrT
} else {
    $vRes = "SKIPPED (alpha_res not available on all overlap rows)"
}

$improve = 100.0 * ($rmseRef - $bestRmse) / [math]::Max($rmseRef, 1e-12)
$transDrop = 100.0 * ($m22Ref - $m22Best) / [math]::Max($m22Ref, 1e-12)
$loocvOk = (Test-DoubleFinite $bestRmse) -and $bestRmse -lt $rmseRef - 1e-9
$transOk = (Test-DoubleFinite $m22Best) -and $m22Ref -gt 0 -and $transDrop -ge $thrT
$globalOk = $improve -ge $thrR
# Hermetic closure: YES if *any* extension simultaneously clears global + transition thresholds (same model).
$anyHerm = $false
foreach ($rr in $results) {
    if (-not $rr.is_extension) { continue }
    if (-not (Test-DoubleFinite $rr.loocv_rmse)) { continue }
    $pr = 100.0 * ($rmseRef - $rr.loocv_rmse) / [math]::Max($rmseRef, 1e-12)
    $pt = 100.0 * ($m22Ref - $rr.mean_abs_res_22_24K) / [math]::Max($m22Ref, 1e-12)
    if ($pr -ge $thrR -and $pt -ge $thrT) { $anyHerm = $true; break }
}
if ($anyHerm) { $vHerm = "YES" }
elseif ($loocvOk -and ($transOk -or $globalOk)) { $vHerm = "PARTIAL" }
else { $vHerm = "NO" }

$tables = Join-Path $RepoRoot "tables"
$figs = Join-Path $RepoRoot "figures"
$reps = Join-Path $RepoRoot "reports"
foreach ($d in @($tables, $figs, $reps)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null } }

$results | Export-Csv -Path (Join-Path $tables "aging_hermetic_closure_models.csv") -NoTypeInformation

$resLines = @("model,T_K,R,yhat_loocv,residual")
foreach ($r in $results) {
    if (-not (Test-DoubleFinite $r.loocv_rmse)) { continue }
    $yh = $yStore[$r.model]
    for ($i = 0; $i -lt $n; $i++) {
        $res = $y[$i] - $yh[$i]
        $resLines += "{0},{1},{2},{3},{4}" -f $r.model, $Tplot[$i], $y[$i], $yh[$i], $res
    }
}
$resLines | Set-Content -Path (Join-Path $tables "aging_hermetic_closure_residuals.csv") -Encoding utf8

Write-Host "INTERACTION_TERM_SUPPORTED: $vInt"
Write-Host "LOCAL_TRANSITION_TERM_SUPPORTED: $vLoc"
Write-Host "RESIDUAL_DEFORMATION_TERM_SUPPORTED: $vRes"
Write-Host "HERMETIC_CLOSURE_ACHIEVED: $vHerm"
Write-Host "best_model: $bestId"
Write-Host "loocv_rmse_best: $bestRmse"

# Report MD (ASCII only: avoid en-dash and unicode in PS source)
$clkPos = $clkP.Replace("\", "/")
$barPos = $barrierP.Replace("\", "/")
$enPos = $energyP.Replace("\", "/")
$alPos = $alphaP.Replace("\", "/")
$dePos = $decompP.Replace("\", "/")
$Tstr = ($Tplot | ForEach-Object { "{0:g}" -f $_ }) -join " "
$pctGlobal = 100.0 * ($bestRmse - $rmseRef) / [math]::Max($rmseRef, 1e-12)
$cLine = if ($modelCok) { "- **Model C:** ``alpha_res`` finite on all overlap rows." } else { "- **Model C:** skipped." }
$mdLines = New-Object System.Collections.Generic.List[string]
$mdLines.Add("# Aging hermetic closure (Agent 24I)")
$mdLines.Add("")
$mdLines.Add("**Computed by:** ``tools/compute_aging_hermetic_agent24i.ps1`` (leverage LOOCV, same as MATLAB ``localLoocvOls``).")
$mdLines.Add("")
$mdLines.Add("## 1. Question")
$mdLines.Add("Does a **single minimal** extension to ``R ~ spread90_50 + kappa1 + alpha`` close LOOCV error globally and in **22-24 K**?")
$mdLines.Add("")
$mdLines.Add("## 2. Data (same merge as Agents 24B / 24G)")
$mdLines.Add("- **R(T):** ``R_T_interp``; clock lineage: ``$clkPos``")
$mdLines.Add("- **PT:** ``$barPos``")
$mdLines.Add("- **Energy join:** ``$enPos``")
$mdLines.Add("- **State / gates:** ``$alPos``, ``$dePos``")
$mdLines.Add("- **Overlap:** n = **$n** (finite R, spread90_50, kappa1, kappa2, alpha).")
$mdLines.Add($cLine)
$mdLines.Add("- **T grid:** ``$Tstr``")
$mdLines.Add("")
$mdLines.Add("## 3. Models (LOOCV OLS, intercept)")
$mdLines.Add('| model | n | LOOCV RMSE | Pearson | mean abs res 22-24 K | mean abs res outside | pct RMSE vs ref | pct transition vs ref |')
$mdLines.Add('|---|---:|---:|---:|---:|---:|---:|---:|')
foreach ($r in $results) {
    $mdLines.Add("| $($r.model) | $($r.n) | $($r.loocv_rmse) | $($r.pearson_y_yhat) | $($r.mean_abs_res_22_24K) | $($r.mean_abs_res_outside_22_24K) | $($r.pct_loocv_rmse_vs_reference) | $($r.pct_transition_mean_abs_res_vs_reference) |")
}
$mdLines.Add("")
$mdLines.Add('**Model B:** ``g(T) = exp(-(T-23)^2/(2*1.5^2))`` K; sigma = 1.5 K fixed (not fitted).')
$mdLines.Add("")
$mdLines.Add("## 4. Global vs transition")
$mdLines.Add("- **Reference LOOCV RMSE:** $rmseRef")
$mdLines.Add("- **Best LOOCV model (lowest RMSE):** ``$bestId`` (LOOCV RMSE = $bestRmse)")
$pctBestRmse = 100.0 * ($rmseRef - $bestRmse) / [math]::Max($rmseRef, 1e-12)
$mdLines.Add("- **RMSE_IMPROVED_OVER_BASELINE (best LOOCV vs ref):** $([math]::Round($pctBestRmse, 3)) % reduction")
$mdLines.Add("- **Mean abs residual 22-24 K (for best LOOCV model):** reference = $m22Ref; best = $m22Best (reduction $([math]::Round($transDrop, 3)) % of reference)")
$rowC = $results | Where-Object { $_.model -like '*abs(alpha_res)*' } | Select-Object -First 1
if ($rowC) {
    $pctRmseC = 100.0 * ($rmseRef - $rowC.loocv_rmse) / [math]::Max($rmseRef, 1e-12)
    $pctTrC = 100.0 * ($m22Ref - $rowC.mean_abs_res_22_24K) / [math]::Max($m22Ref, 1e-12)
    $mdLines.Add("- **Model C (|alpha_res|):** LOOCV RMSE $($rowC.loocv_rmse); mean abs res 22-24 K $($rowC.mean_abs_res_22_24K) => **$([math]::Round($pctRmseC,3)) %** RMSE gain vs ref, **$([math]::Round($pctTrC,3)) %** transition residual reduction vs ref.")
}
$mdLines.Add("")
$mdLines.Add("## 5. Answers (brief)")
$mdLines.Add("1. Minimal correction: see best model row vs reference (LOOCV RMSE and 22-24 K mean abs residual).")
$mdLines.Add("2. 22-24 K mechanism: compare extension A (interaction), B (fixed Gaussian in T), C (|alpha_res|) using transition columns.")
$mdLines.Add("3. Remaining error: inspect residual vs T (baseline vs best); systematic banding implies structure.")
$mdLines.Add("")
$mdLines.Add("## 6. Verdicts")
$mdLines.Add("- **INTERACTION_TERM_SUPPORTED:** **$vInt**")
$mdLines.Add("- **LOCAL_TRANSITION_TERM_SUPPORTED:** **$vLoc**")
$mdLines.Add("- **RESIDUAL_DEFORMATION_TERM_SUPPORTED:** **$vRes**")
$mdLines.Add("- **HERMETIC_CLOSURE_ACHIEVED:** **$vHerm**")
$mdLines.Add("")
$mdLines.Add("Support rule (per term A/B/C): YES if LOOCV RMSE improves by >=3% *and* mean abs res in 22-24 K drops by >=10% vs reference; PARTIAL if only one holds.")
$mdLines.Add("HERMETIC_CLOSURE_ACHIEVED = YES if *any* extension satisfies both thresholds simultaneously (not necessarily the lowest LOOCV model overall).")
$mdLines.Add("")
$mdLines.Add("## Figures")
$mdLines.Add("- ``$((Join-Path $figs 'aging_hermetic_predictions.png').Replace('\','/'))`` (observed R vs LOOCV best)")
$mdLines.Add("- ``$((Join-Path $figs 'aging_hermetic_residuals_vs_T.png').Replace('\','/'))`` (baseline vs best LOOCV residual vs T; shaded 22-24 K)")
$mdLines.Add("MATLAB twin: ``analysis/run_aging_hermetic_closure_agent24i.m`` writes the same names under a run directory and mirrors to ``figures/``.")
$mdLines.ToArray() | Set-Content -Path (Join-Path $reps "aging_hermetic_closure_report.md") -Encoding utf8

# PNG figures (System.Drawing)
try {
    Add-Type -AssemblyName System.Drawing
    $penBlk = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), 2
    $penRef = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(80, 80, 180)), 2
    $penBest = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 90, 40)), 2
    $brDot = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 100, 160))

    function Map-X([double]$t, [double]$tmin, [double]$tmax, [int]$pw, [int]$pad) {
        if ($tmax -le $tmin) { return $pad }
        return [int]($pad + ($t - $tmin) / ($tmax - $tmin) * ($pw - 2 * $pad))
    }
    function Map-Y([double]$v, [double]$vmin, [double]$vmax, [int]$ph, [int]$pad) {
        if ($vmax -le $vmin) { return $ph - $pad }
        return [int]($ph - $pad - ($v - $vmin) / ($vmax - $vmin) * ($ph - 2 * $pad))
    }

    $pw = 720; $ph = 560; $pad = 70
    $tmin = ($Tplot | Measure-Object -Minimum).Minimum
    $tmax = ($Tplot | Measure-Object -Maximum).Maximum
    $resRefArr = [Array]::CreateInstance([System.Double], [int32]$n)
    $resBestArr = [Array]::CreateInstance([System.Double], [int32]$n)
    for ($i = 0; $i -lt $n; $i++) {
        $resRefArr[$i] = $y[$i] - $yhatRef[$i]
        $resBestArr[$i] = $y[$i] - $yhatBest[$i]
    }
    $vmin = [math]::Min(($resRefArr | Measure-Object -Minimum).Minimum, ($resBestArr | Measure-Object -Minimum).Minimum)
    $vmax = [math]::Max(($resRefArr | Measure-Object -Maximum).Maximum, ($resBestArr | Measure-Object -Maximum).Maximum)
    if ($vmax -le $vmin) { $vmin -= 1; $vmax += 1 }

    $bmp2 = New-Object System.Drawing.Bitmap $pw, $ph
    $g2 = [System.Drawing.Graphics]::FromImage($bmp2)
    $g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g2.Clear([System.Drawing.Color]::White)
    $g2.DrawRectangle($penBlk, $pad, $pad, $pw - 2 * $pad, $ph - 2 * $pad)
    $x22 = Map-X 22 $tmin $tmax $pw $pad
    $x24 = Map-X 24 $tmin $tmax $pw $pad
    $brushBand = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(60, 255, 200, 200))
    $g2.FillRectangle($brushBand, $x22, $pad, [math]::Max(1, $x24 - $x22), $ph - 2 * $pad)
    $brushBand.Dispose()
    $g2.DrawRectangle($penBlk, $pad, $pad, $pw - 2 * $pad, $ph - 2 * $pad)
    for ($i = 0; $i -lt $n; $i++) {
        $xi = Map-X $Tplot[$i] $tmin $tmax $pw $pad
        $yr = Map-Y $resRefArr[$i] $vmin $vmax $ph $pad
        $g2.FillEllipse($brDot, $xi - 3, $yr - 3, 6, 6)
    }
    for ($i = 0; $i -lt ($n - 1); $i++) {
        $x1 = Map-X $Tplot[$i] $tmin $tmax $pw $pad
        $x2 = Map-X $Tplot[$i + 1] $tmin $tmax $pw $pad
        $y1 = Map-Y $resRefArr[$i] $vmin $vmax $ph $pad
        $y2 = Map-Y $resRefArr[$i + 1] $vmin $vmax $ph $pad
        $g2.DrawLine($penRef, $x1, $y1, $x2, $y2)
        $y1b = Map-Y $resBestArr[$i] $vmin $vmax $ph $pad
        $y2b = Map-Y $resBestArr[$i + 1] $vmin $vmax $ph $pad
        $g2.DrawLine($penBest, $x1, $y1b, $x2, $y2b)
    }
    $y0 = Map-Y 0 $vmin $vmax $ph $pad
    $g2.DrawLine((New-Object System.Drawing.Pen ([System.Drawing.Color]::Gray), 1), $pad, $y0, $pw - $pad, $y0)
    $bmp2.Save((Join-Path $figs "aging_hermetic_residuals_vs_T.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $g2.Dispose(); $bmp2.Dispose()

    $pw2 = 560; $ph2 = 520
    $bmp3 = New-Object System.Drawing.Bitmap $pw2, $ph2
    $g3 = [System.Drawing.Graphics]::FromImage($bmp3)
    $g3.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g3.Clear([System.Drawing.Color]::White)
    $umin = [math]::Min(($y | Measure-Object -Minimum).Minimum, ($yhatBest | Measure-Object -Minimum).Minimum)
    $umax = [math]::Max(($y | Measure-Object -Maximum).Maximum, ($yhatBest | Measure-Object -Maximum).Maximum)
    if ($umax -le $umin) { $umin -= 1; $umax += 1 }
    $g3.DrawRectangle($penBlk, $pad, $pad, $pw2 - 2 * $pad, $ph2 - 2 * $pad)
    for ($i = 0; $i -lt $n; $i++) {
        $xu = Map-X $y[$i] $umin $umax $pw2 $pad
        $xv = Map-Y $yhatBest[$i] $umin $umax $ph2 $pad
        $g3.FillEllipse($brDot, $xu - 4, $xv - 4, 8, 8)
    }
    $d1 = Map-X $umin $umin $umax $pw2 $pad
    $d2 = Map-X $umax $umin $umax $pw2 $pad
    $e1 = Map-Y $umin $umin $umax $ph2 $pad
    $e2 = Map-Y $umax $umin $umax $ph2 $pad
    $g3.DrawLine($penBlk, $d1, $e2, $d2, $e1)
    $bmp3.Save((Join-Path $figs "aging_hermetic_predictions.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $g3.Dispose(); $bmp3.Dispose()

    $penBlk.Dispose(); $penRef.Dispose(); $penBest.Dispose(); $brDot.Dispose()
}
catch {
    Write-Host "Figure export skipped: $($_.Exception.Message)"
}

Write-Host "Wrote tables, report, and figures (if System.Drawing available)."
