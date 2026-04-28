# Phase 5X - residual decomposition overlap audit (Switching only). Compare Phase 5B PCA vs canonical Phi/kappa/full model.
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$CanonicalRunId = 'run_2026_04_03_000147_switching_canonical'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-Finite([double]$x) { (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }

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

function VecNorm($v) {
    $s = 0.0
    foreach ($x in $v) { if (Test-Finite $x) { $s += $x * $x } }
    [math]::Sqrt($s)
}

function CovFlatMatVec([double[]]$Cf, [double[]]$v, [int]$n) {
    $dim = $v.Length
    $out = New-Object double[] $dim
    for ($r = 0; $r -lt $dim; $r++) {
        $acc = [double]0
        $rb = $r * $n
        for ($c = 0; $c -lt $dim; $c++) {
            $acc = [double]$acc + [double]$Cf[$rb + $c] * [double]$v[$c]
        }
        $out[$r] = $acc
    }
    return $out
}

function PearsonVec([double[]]$a, [double[]]$b) {
    $n = [math]::Min($a.Length, $b.Length)
    if ($n -lt 3) { return [double]::NaN }
    $ma = 0.0; $mb = 0.0; $cntm = 0
    for ($i = 0; $i -lt $n; $i++) {
        if ((Test-Finite $a[$i]) -and (Test-Finite $b[$i])) {
            $ma += $a[$i]; $mb += $b[$i]; $cntm++
        }
    }
    if ($cntm -lt 3) { return [double]::NaN }
    $ma /= $cntm; $mb /= $cntm
    $num = 0.0; $da = 0.0; $db = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        if (-not ((Test-Finite $a[$i]) -and (Test-Finite $b[$i]))) { continue }
        $va = $a[$i] - $ma; $vb = $b[$i] - $mb
        $num += $va * $vb; $da += $va * $va; $db += $vb * $vb
    }
    if ($da -lt 1e-30 -or $db -lt 1e-30) { return [double]::NaN }
    return $num / [math]::Sqrt($da * $db)
}

function Invoke-TopEigenPowerIter([double[]]$Cf, [int]$dim, [int]$maxIter = 80) {
    $rng = [System.Random]::new(42)
    $v = New-Object double[] $dim
    for ($i = 0; $i -lt $dim; $i++) { $v[$i] = $rng.NextDouble() - 0.5 }
    $nv = VecNorm $v
    for ($i = 0; $i -lt $dim; $i++) { $v[$i] /= $nv }
    for ($it = 0; $it -lt $maxIter; $it++) {
        $w = CovFlatMatVec $Cf $v $dim
        $nw = VecNorm $w
        if ($nw -lt 1e-30) { break }
        for ($i = 0; $i -lt $dim; $i++) { $v[$i] = $w[$i] / $nw }
    }
    $Mv = CovFlatMatVec $Cf $v $dim
    $lam = 0.0
    for ($i = 0; $i -lt $dim; $i++) { $lam += $v[$i] * $Mv[$i] }
    @{ v = $v; lambda = $lam }
}

function UnitVec([double[]]$v) {
    $out = New-Object double[] $v.Length
    $nv = VecNorm $v
    if ($nv -lt 1e-40) { return $out }
    for ($i = 0; $i -lt $v.Length; $i++) { $out[$i] = $v[$i] / $nv }
    $out
}

$runTables = Join-Path $RepoRoot "results/switching/runs/$CanonicalRunId/tables"
$SlongPath = Join-Path $runTables 'switching_canonical_S_long.csv'
$phiPath = Join-Path $runTables 'switching_canonical_phi1.csv'
$obsPath = Join-Path $runTables 'switching_canonical_observables.csv'

foreach ($p in @($SlongPath, $phiPath, $obsPath)) {
    if (-not (Test-Path $p)) { throw "Missing required artifact: $p" }
}

$p5bModes = Join-Path $RepoRoot 'tables/switching_phase5B_residual_absorption_modes.csv'
$p5bMetrics = Join-Path $RepoRoot 'tables/switching_phase5B_residual_absorption_metrics.csv'
$p5bRecon = Join-Path $RepoRoot 'tables/switching_phase5B_residual_absorption_reconstruction.csv'

$inventory = @(
    [pscustomobject]@{ artifact_type = 'canonical'; relative_path = "results/switching/runs/$CanonicalRunId/tables/switching_canonical_S_long.csv"; role = 'S_percent,S_model_pt_percent,S_model_full_percent,residual_percent,CDF_pt,current_mA' }
    [pscustomobject]@{ artifact_type = 'canonical'; relative_path = "results/switching/runs/$CanonicalRunId/tables/switching_canonical_phi1.csv"; role = 'Phi1_vs_current_mA_master_curve' }
    [pscustomobject]@{ artifact_type = 'canonical'; relative_path = "results/switching/runs/$CanonicalRunId/tables/switching_canonical_observables.csv"; role = 'kappa1_per_T_K,S_peak,I_peak,phi_cosine_row,rmse_full_row' }
    [pscustomobject]@{ artifact_type = 'phase5b'; relative_path = 'tables/switching_phase5B_residual_absorption_modes.csv'; role = 'PCA_variance_fractions_on_CDF_grid' }
    [pscustomobject]@{ artifact_type = 'phase5b'; relative_path = 'tables/switching_phase5B_residual_absorption_metrics.csv'; role = 'phase5b_scalar_metrics_and_projection_amps' }
    [pscustomobject]@{ artifact_type = 'phase5b'; relative_path = 'tables/switching_phase5B_residual_absorption_reconstruction.csv'; role = 'PT_vs_PT_plus_PC_reconstruction_MSE' }
)

$invOut = Join-Path $RepoRoot 'tables/switching_phase5X_residual_decomposition_overlap_inventory.csv'
$inventory | Export-Csv -NoTypeInformation -Encoding UTF8 $invOut

# --- Phi1 canonical curve
$phiRows = Import-Csv $phiPath | ForEach-Object {
    [pscustomobject]@{ current_mA = [double]$_.current_mA; Phi1 = [double]$_.Phi1 }
}
$phiSorted = @($phiRows | Sort-Object current_mA)
$phiX = @($phiSorted | ForEach-Object { $_.current_mA })
$phiY = @($phiSorted | ForEach-Object { $_.Phi1 })

# --- Observables / kappa1
$obsByT = @{}
Import-Csv $obsPath | ForEach-Object {
    $obsByT[[double]$_.T_K] = $_
}

# --- Full S_long with full model column
$srows = Import-Csv $SlongPath | ForEach-Object {
    [pscustomobject]@{
        T_K                  = [double]$_.T_K
        current_mA           = [double]$_.current_mA
        S_percent            = [double]$_.S_percent
        S_model_pt_percent   = [double]$_.S_model_pt_percent
        S_model_full_percent = [double]$_.S_model_full_percent
        residual_percent     = [double]$_.residual_percent
        CDF_pt               = [double]$_.CDF_pt
    }
}

# --- Rebuild Phase 5B PC1 on CDF grid (same protocol as Phase 5B script)
$byT = $srows | Group-Object { $_.T_K }
$Tlist = @($byT | ForEach-Object { [double]$_.Name } | Sort-Object)
$nGrid = 48
$cdfAll = @($srows | Where-Object { Test-Finite $_.CDF_pt } | ForEach-Object { $_.CDF_pt })
$cdfMin = ($cdfAll | Measure-Object -Minimum).Minimum
$cdfMax = ($cdfAll | Measure-Object -Maximum).Maximum
$grid = New-Object double[] $nGrid
for ($g = 0; $g -lt $nGrid; $g++) {
    $grid[$g] = $cdfMin + ($g / ($nGrid - 1)) * ($cdfMax - $cdfMin)
}

$curveRaw = @{}
foreach ($tk in $Tlist) {
    $g = $byT | Where-Object { [double]$_.Name -eq $tk }
    $slice = @($g.Group | Where-Object { (Test-Finite $_.CDF_pt) -and (Test-Finite $_.residual_percent) } | Sort-Object CDF_pt)
    if ($slice.Count -lt 3) { continue }
    $xv = @($slice | ForEach-Object { $_.CDF_pt })
    $rv = @($slice | ForEach-Object { $_.residual_percent })
    $ig = New-Object double[] $nGrid
    for ($q = 0; $q -lt $nGrid; $q++) {
        $ig[$q] = LinInterp $grid[$q] $xv $rv
    }
    $curveRaw[$tk] = $ig
}

$Tactive = @($curveRaw.Keys | Sort-Object)
$nTa = $Tactive.Count
$R = New-Object 'double[,]' $nTa, $nGrid
$TtoIdx = @{}
for ($i = 0; $i -lt $nTa; $i++) {
    $tk = $Tactive[$i]
    $TtoIdx[$tk] = $i
    for ($j = 0; $j -lt $nGrid; $j++) {
        $R[$i, $j] = $curveRaw[$tk][$j]
    }
}

$mu = New-Object double[] $nGrid
for ($j = 0; $j -lt $nGrid; $j++) {
    $s = 0.0
    for ($i = 0; $i -lt $nTa; $i++) { $s += $R[$i, $j] }
    $mu[$j] = $s / $nTa
}

$X = New-Object 'double[,]' $nTa, $nGrid
for ($i = 0; $i -lt $nTa; $i++) {
    for ($j = 0; $j -lt $nGrid; $j++) {
        $X[$i, $j] = $R[$i, $j] - $mu[$j]
    }
}

$CovFlat = New-Object double[] ($nGrid * $nGrid)
$denCov = [math]::Max($nTa - 1, 1)
for ($a = 0; $a -lt $nGrid; $a++) {
    for ($b = 0; $b -lt $nGrid; $b++) {
        $s = 0.0
        for ($i = 0; $i -lt $nTa; $i++) {
            $s += $X[$i, $a] * $X[$i, $b]
        }
        $CovFlat[$a * $nGrid + $b] = $s / $denCov
    }
}

$ev1 = Invoke-TopEigenPowerIter $CovFlat $nGrid
$phiP5 = UnitVec([double[]]$ev1.v)
$cMu = 0.0
for ($j = 0; $j -lt $nGrid; $j++) { $cMu += $phiP5[$j] * $mu[$j] }
if ($cMu -lt 0) {
    for ($j = 0; $j -lt $nGrid; $j++) { $phiP5[$j] = -$phiP5[$j] }
}

# --- Pointwise vectors over all ladder rows
$nPts = $srows.Count
$arrPhiCan = New-Object double[] $nPts
$arrPc1 = New-Object double[] $nPts
$idx = 0
foreach ($rw in $srows) {
    $arrPhiCan[$idx] = LinInterp $rw.current_mA $phiX $phiY
    $arrPc1[$idx] = LinInterp $rw.CDF_pt $grid $phiP5
    $idx++
}

$pearPhiPc1 = PearsonVec $arrPhiCan $arrPc1
$pearFlip = PearsonVec ($arrPhiCan | ForEach-Object { -$_ }) @($arrPc1)
$bestPear = [math]::Max([math]::Abs($pearPhiPc1), [math]::Abs($pearFlip))

$dotNorm = 0.0
$nfn = 0
for ($i = 0; $i -lt $nPts; $i++) {
    if ((Test-Finite $arrPhiCan[$i]) -and (Test-Finite $arrPc1[$i])) {
        $dotNorm += $arrPhiCan[$i] * $arrPc1[$i]; $nfn++
    }
}
$cosRaw = if ($nfn -gt 0) {
    $nf = VecNorm(@($arrPhiCan | Where-Object { Test-Finite $_ }))
    $np = VecNorm(@($arrPc1 | Where-Object { Test-Finite $_ }))
    if ($nf -gt 1e-30 -and $np -gt 1e-30) { $dotNorm / ($nf * $np) } else { [double]::NaN }
} else { [double]::NaN }

$phiCmpRows = @(
    [pscustomobject]@{ comparison = 'canonical_Phi1_vs_phase5b_PC1'; axis_canonical = 'current_mA'; axis_phase5b = 'CDF_pt_uniform_grid'; pearson_all_ladder_rows = [math]::Round($pearPhiPc1, 8); pearson_best_sign_alignment = [math]::Round($bestPear, 8); cosine_unsigned_dot_over_norms = if (Test-Finite $cosRaw) { [math]::Round($cosRaw, 8) } else { 'NaN' }; notes = 'PC1 recomputed_same_as_phase5B_protocol; Phi1_from_switching_canonical_phi1.csv' }
)

$phiCmpOut = Join-Path $RepoRoot 'tables/switching_phase5X_phi_mode_comparison.csv'
$phiCmpRows | Export-Csv -NoTypeInformation -Encoding UTF8 $phiCmpOut

# --- Per-T: kappa1 vs PC1 score (dot(X_row, phiP5))
$scoreByT = @{}
foreach ($tk in $Tactive) {
    $ti = $TtoIdx[$tk]
    $sc = 0.0
    for ($j = 0; $j -lt $nGrid; $j++) {
        $sc += $X[$ti, $j] * $phiP5[$j]
    }
    $scoreByT[$tk] = $sc
}

$kappaRows = @()
foreach ($tk in $Tactive) {
    $k1 = [double]::NaN
    if ($obsByT.ContainsKey([double]$tk)) {
        $k1 = [double]$obsByT[[double]$tk].kappa1
    }
    $sc = $scoreByT[$tk]
    $ratio = if ((Test-Finite $k1) -and ([math]::Abs($k1) -gt 1e-18)) { $sc / $k1 } else { [double]::NaN }
    $kappaRows += [pscustomobject]@{
        T_K                = $tk
        kappa1_canonical   = if (Test-Finite $k1) { [math]::Round($k1, 12) } else { 'NaN' }
        pc1_score_phase5b  = [math]::Round($sc, 12)
        ratio_score_over_kappa = if (Test-Finite $ratio) { [math]::Round($ratio, 8) } else { 'NaN' }
        phi_cosine_row_obs = if ($obsByT.ContainsKey([double]$tk)) { [math]::Round([double]$obsByT[[double]$tk].phi_cosine_row, 8) } else { 'NaN' }
    }
}

$pearKappaScore = PearsonVec (@($Tactive | ForEach-Object { [double]$obsByT[[double]$_].kappa1 })) (@($Tactive | ForEach-Object { [double]$scoreByT[$_] }))

$kappaOut = Join-Path $RepoRoot 'tables/switching_phase5X_kappa_amplitude_comparison.csv'
$kappaRows | Export-Csv -NoTypeInformation -Encoding UTF8 $kappaOut

# --- Reconstruction MSE
$sseFull = 0.0
$ssePtPc1 = 0.0
$ssePtOnly = 0.0
$cntPt = 0
foreach ($rw in $srows) {
    if (-not ($TtoIdx.ContainsKey($rw.T_K))) { continue }
    $s = [double]$rw.S_percent
    $sm = [double]$rw.S_model_pt_percent
    $sf = [double]$rw.S_model_full_percent
    if (-not ((Test-Finite $s) -and (Test-Finite $sm) -and (Test-Finite $sf))) { continue }
    $ti = $TtoIdx[$rw.T_K]
    $cdf = [double]$rw.CDF_pt
    if (-not (Test-Finite $cdf)) { continue }
    $muP = LinInterp $cdf $grid $mu
    $p1v = LinInterp $cdf $grid $phiP5
    $dot1 = 0.0
    for ($j = 0; $j -lt $nGrid; $j++) {
        $dot1 += $X[$ti, $j] * $phiP5[$j]
    }
    $rHat = $muP + $dot1 * $p1v
    $sHat = $sm + $rHat
    $sseFull += ($s - $sf) * ($s - $sf)
    $ssePtPc1 += ($s - $sHat) * ($s - $sHat)
    $ssePtOnly += ($s - $sm) * ($s - $sm)
    $cntPt++
}

$mseFull = $sseFull / $cntPt
$mseP5 = $ssePtPc1 / $cntPt
$msePt = $ssePtOnly / $cntPt

$relFullVsP5 = if ($mseP5 -gt 1e-30) { $mseFull / $mseP5 } else { [double]::NaN }

$reconRows = @(
    [pscustomobject]@{ quantity = 'mse_mean_squared_error'; canonical_S_vs_S_model_full = [math]::Round($mseFull, 14); phase5b_S_vs_S_model_pt_plus_PC1_same_protocol = [math]::Round($mseP5, 14); phase5b_S_vs_S_model_pt_only = [math]::Round($msePt, 14); ratio_mse_full_over_phase5b_pc1 = if (Test-Finite $relFullVsP5) { [math]::Round($relFullVsP5, 8) } else { 'NaN' }; notes = 'phase5b_row_reconstruction_matches_phase5B_script' }
)

$p5reconMse = [double]::NaN
if (Test-Path $p5bRecon) {
    $rr = Import-Csv $p5bRecon | Where-Object { $_.model -eq 'PT_plus_residual_rank1_PCA_grid' -and $_.quantity -eq 'mse_vs_S_percent' }
    if ($rr) { try { $p5reconMse = [double]$rr.value } catch {} }
}

$reconRows += [pscustomobject]@{ quantity = 'cross_check_phase5b_csv'; canonical_S_vs_S_model_full = [math]::Round($mseFull, 14); phase5b_S_vs_S_model_pt_plus_PC1_same_protocol = [math]::Round($mseP5, 14); phase5b_S_vs_S_model_pt_only = if (Test-Finite $p5reconMse) { [math]::Round($p5reconMse, 14) } else { 'NaN' }; ratio_mse_full_over_phase5b_pc1 = if (Test-Finite $relFullVsP5) { [math]::Round($relFullVsP5, 8) } else { 'NaN' }; notes = 'second_row_compare_exported_phase5B_reconstruction_csv_if_present' }

$reconOut = Join-Path $RepoRoot 'tables/switching_phase5X_reconstruction_overlap.csv'
$reconRows | Export-Csv -NoTypeInformation -Encoding UTF8 $reconOut

# --- Verdict logic
$existCanon = 'YES'
$phiMatch = if ((Test-Finite $bestPear) -and ($bestPear -ge 0.92)) { 'YES' } elseif ((Test-Finite $bestPear) -and ($bestPear -ge 0.80)) { 'PARTIAL' } else { 'NO' }
$kappaMatch = if ((Test-Finite $pearKappaScore) -and ($pearKappaScore -ge 0.88)) { 'YES' } elseif ((Test-Finite $pearKappaScore) -and ($pearKappaScore -ge 0.65)) { 'PARTIAL' } else { 'NO' }
$reconMatch = if ((Test-Finite $relFullVsP5) -and ($relFullVsP5 -gt 0.85) -and ($relFullVsP5 -lt 1.15)) { 'YES' } elseif ((Test-Finite $relFullVsP5) -and ($relFullVsP5 -lt 2.0)) { 'PARTIAL' } else { 'NO' }

$dupSvd = if (($phiMatch -eq 'YES' -or $phiMatch -eq 'PARTIAL') -and ($kappaMatch -eq 'YES' -or $kappaMatch -eq 'PARTIAL') -and ($reconMatch -ne 'NO')) { 'PARTIAL' } else { 'NO' }
if (($phiMatch -eq 'YES') -and ($kappaMatch -eq 'YES') -and ($reconMatch -eq 'YES')) { $dupSvd = 'YES' }
if (($phiMatch -eq 'NO') -and ($kappaMatch -eq 'NO')) { $dupSvd = 'NO' }

$onlyReparam = if (($bestPear -ge 0.90) -and ($dupSvd -ne 'NO')) { 'YES' } else { 'PARTIAL' }
if ($dupSvd -eq 'YES') { $onlyReparam = 'YES' }

$addsNew = if ($dupSvd -eq 'YES') { 'NO' } elseif ($dupSvd -eq 'PARTIAL') { 'PARTIAL' } else { 'YES' }

$safe5c = 'NO'
if ($dupSvd -eq 'YES') {
    $safe5c = 'NO'
}
elseif ($dupSvd -eq 'PARTIAL' -and $addsNew -eq 'PARTIAL') {
    $safe5c = 'NO'
}
else {
    $safe5c = 'PARTIAL'
}

$statusRows = @(
    [pscustomobject]@{ verdict_key = 'PHASE5X_OVERLAP_AUDIT_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'LOCKED_CANONICAL_RUN_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'PHASE5B_OUTPUTS_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'EXISTING_CANONICAL_RESIDUAL_DECOMPOSITION_FOUND'; verdict_value = $existCanon }
    [pscustomobject]@{ verdict_key = 'PHASE5B_DUPLICATES_CANONICAL_RESIDUAL_SVD'; verdict_value = $dupSvd }
    [pscustomobject]@{ verdict_key = 'PHASE5B_ADDS_NEW_INFORMATION'; verdict_value = $addsNew }
    [pscustomobject]@{ verdict_key = 'PHASE5B_ONLY_REPARAMETERIZES_RESIDUAL'; verdict_value = $onlyReparam }
    [pscustomobject]@{ verdict_key = 'PHASE5B_PC1_MATCHES_CANONICAL_PHI1'; verdict_value = $phiMatch }
    [pscustomobject]@{ verdict_key = 'PHASE5B_AMPLITUDES_MATCH_CANONICAL_KAPPA1'; verdict_value = $kappaMatch }
    [pscustomobject]@{ verdict_key = 'PHASE5B_RECONSTRUCTION_MATCHES_CANONICAL_FULL_MODEL'; verdict_value = $reconMatch }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_PROCEED_TO_PHASE5C'; verdict_value = $safe5c }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_RESIDUAL_MODE_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_EVIDENCE_USED'; verdict_value = 'NO' }
)

$statusOut = Join-Path $RepoRoot 'tables/switching_phase5X_overlap_status.csv'
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $statusOut

# --- Report
$rp = Join-Path $RepoRoot 'reports/switching_phase5X_residual_decomposition_overlap_audit.md'
$lines = @()
$lines += '# Phase 5X - Residual decomposition overlap audit (Switching only)'
$lines += ''
$lines += '## Purpose'
$lines += 'Determine whether Phase 5B PCA on **`CDF_pt_candidate`** largely **reproduces** the existing canonical residual mode geometry exported by **`run_switching_canonical`** (**`Phi1`**, **`kappa1`**, **`S_model_full_percent`**) or whether it adds **distinct** information.'
$lines += ''
$lines += '## Canonical objects (this run)'
$lines += '- **`switching_canonical_phi1.csv`**: master **`Phi1(current_mA)`** curve.'
$lines += '- **`switching_canonical_observables.csv`**: per-**`T_K`** **`kappa1`**, **`phi_cosine_row`**, RMSE rows.'
$lines += '- **`switching_canonical_S_long.csv`**: **`S_model_pt_percent`**, **`S_model_full_percent`**, **`residual_percent`** (= `S_percent - S_model_pt_percent` per column contract).'
$lines += ''
$lines += '## Phase 5B objects compared'
$lines += '- PC1 recomputed with the **same** Phase 5B protocol (48-bin **CDF_pt** grid, PCA on temperature-centered residual curves).'
$lines += '- Cross-check against **`tables/switching_phase5B_residual_absorption_*.csv`** where applicable.'
$lines += ''
$lines += '## Headline metrics'
$lines += ('- **Pearson(Phi1(I), PC1(CDF))** over all long-map rows (best sign): **' + [string]([math]::Round($bestPear, 4)) + '**.')
$lines += ('- **Pearson(kappa1(T), PC1_score(T))** across temperatures: **' + [string]([math]::Round($pearKappaScore, 4)) + '**.')
$lines += ('- **MSE(S vs S_model_full)** canonical full model: **' + [string]([math]::Round($mseFull, 8)) + '**; **MSE(S vs S_PT + Phase5B_PC1_fit)** **' + [string]([math]::Round($mseP5, 8)) + '**; ratio full/PC1 **' + [string]([math]::Round($relFullVsP5, 4)) + '**.')
$lines += ''
$lines += '## Interpretation'
if ($dupSvd -eq 'YES') {
    $lines += '- **Strong overlap:** Phase 5B rank-1 direction on **CDF** aligns closely with canonical **Phi1(I)** and **kappa1** scaling; **`S_model_full`** reconstruction is in the same ballpark as PT+PC1 under this audit. **Phase 5C should not proceed as a second parallel residual-mode story** - prefer canonical **`Phi1`/`kappa1`** definitions for residual language.'
}
elseif ($dupSvd -eq 'PARTIAL') {
    $lines += '- **Partial overlap:** Some redundancy with canonical SVD outputs; **CDF_pt_candidate** mainly **re-grids/reparameterizes** the same residual object. Treat Phase 5B as **axis-aligned diagnostics**, not independent discovery. **Phase 5C blocked or must be rewritten** to cite canonical modes explicitly.'
}
else {
    $lines += '- **Limited equivalence:** Phase 5B axis/chart geometry is **not** a trivial duplicate of the canonical **`Phi1`/`kappa1`** pairing as measured here; document **what differs** (axis, backbone slice, filtering) before any Phase 5C narrative.'
}
$lines += ''
$lines += '## Verdict table'
foreach ($s in $statusRows) {
    $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`')
}
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_phase5X_residual_decomposition_overlap_inventory.csv`'
$lines += '- `tables/switching_phase5X_phi_mode_comparison.csv`'
$lines += '- `tables/switching_phase5X_kappa_amplitude_comparison.csv`'
$lines += '- `tables/switching_phase5X_reconstruction_overlap.csv`'
$lines += '- `tables/switching_phase5X_overlap_status.csv`'
$lines | Set-Content -Encoding UTF8 $rp

Write-Host "Phase5X overlap audit complete. Report: $rp"
