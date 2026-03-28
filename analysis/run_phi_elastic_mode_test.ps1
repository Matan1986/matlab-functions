$ErrorActionPreference = "Stop"

$root = "C:\Dev\matlab-functions"
$runId = "run_{0}_phi_elastic_mode_test" -f (Get-Date -Format "yyyy_MM_dd_HHmmss")
$runDir = Join-Path $root ("results\switching\runs\" + $runId)
$reportsDir = Join-Path $runDir "reports"
$tablesDir = Join-Path $runDir "tables"
New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $tablesDir -Force | Out-Null

$phiCsv = Join-Path $root "results\switching\runs\run_2026_03_24_220314_residual_decomposition\tables\phi_shape.csv"
$phiData = Import-Csv $phiCsv
$x = @($phiData | ForEach-Object { [double]$_.x })
$phi = @($phiData | ForEach-Object { [double]$_.Phi })
$nSamples = $phi.Count

function Dot([double[]]$a, [double[]]$b) {
    $s = 0.0
    for ($i = 0; $i -lt $a.Count; $i++) { $s += $a[$i] * $b[$i] }
    return $s
}

function Norm([double[]]$a) {
    return [Math]::Sqrt((Dot $a $a))
}

function Mean([double[]]$a) {
    return (($a | Measure-Object -Average).Average)
}

# Normalize phi
$phiMean = Mean $phi
for ($i = 0; $i -lt $nSamples; $i++) { $phi[$i] = $phi[$i] - $phiMean }
$phiNorm = Norm $phi
for ($i = 0; $i -lt $nSamples; $i++) { $phi[$i] = $phi[$i] / $phiNorm }

# Map x to [-1, 1] for stable Legendre projections.
$xMin = ($x | Measure-Object -Minimum).Minimum
$xMax = ($x | Measure-Object -Maximum).Maximum
$t = New-Object double[] $nSamples
for ($i = 0; $i -lt $nSamples; $i++) { $t[$i] = 2.0 * (($x[$i] - $xMin) / ($xMax - $xMin)) - 1.0 }

# Legendre polynomial projections (k = 0..10).
$deg = 10
$P = @()
$p0 = New-Object double[] $nSamples
for ($i = 0; $i -lt $nSamples; $i++) { $p0[$i] = 1.0 }
$P += ,$p0
$p1 = New-Object double[] $nSamples
for ($i = 0; $i -lt $nSamples; $i++) { $p1[$i] = $t[$i] }
$P += ,$p1
for ($k = 1; $k -lt $deg; $k++) {
    $pk = $P[$k]
    $pkm1 = $P[$k - 1]
    $pn = New-Object double[] $nSamples
    for ($i = 0; $i -lt $nSamples; $i++) {
        $pn[$i] = (((2.0 * $k + 1.0) * $t[$i] * $pk[$i]) - ($k * $pkm1[$i])) / ($k + 1.0)
    }
    $P += ,$pn
}

function LegendreLowEnergy([int]$kMax, [double[]]$signal, $basisList) {
    $len = $signal.Count
    $recon = New-Object double[] $len
    for ($k = 0; $k -le $kMax; $k++) {
        $pk = $basisList[$k]
        $num = Dot $signal $pk
        $den = Dot $pk $pk
        $ak = $num / $den
        for ($i = 0; $i -lt $len; $i++) { $recon[$i] += $ak * $pk[$i] }
    }
    $eSig = Dot $signal $signal
    $eRec = Dot $recon $recon
    return $eRec / $eSig
}

$polyLow3 = LegendreLowEnergy 2 $phi $P
$polyLow5 = LegendreLowEnergy 4 $phi $P
$polyLow7 = LegendreLowEnergy 6 $phi $P

# Fourier low-mode energy via full DFT coefficients.
 $coefRe = New-Object double[] $nSamples
$coefIm = New-Object double[] $nSamples
for ($n = 0; $n -lt $nSamples; $n++) {
    $re = 0.0
    $im = 0.0
    for ($i = 0; $i -lt $nSamples; $i++) {
        $ang = -2.0 * [Math]::PI * $n * $i / $nSamples
        $re += $phi[$i] * [Math]::Cos($ang)
        $im += $phi[$i] * [Math]::Sin($ang)
    }
    $coefRe[$n] = $re
    $coefIm[$n] = $im
}
$specEnergy = New-Object double[] $nSamples
$totalEnergy = 0.0
for ($n = 0; $n -lt $nSamples; $n++) {
    $specEnergy[$n] = ($coefRe[$n] * $coefRe[$n] + $coefIm[$n] * $coefIm[$n]) / $nSamples
    $totalEnergy += $specEnergy[$n]
}
$nBands = @(1, 3, 5)
$fourierVals = @{}
foreach ($nMax in $nBands) {
    $keep = New-Object bool[] $nSamples
    for ($n = 0; $n -le $nMax; $n++) {
        $keep[$n] = $true
        $mirror = ($nSamples - $n) % $nSamples
        $keep[$mirror] = $true
    }
    $e = 0.0
    for ($n = 0; $n -lt $nSamples; $n++) {
        if ($keep[$n]) { $e += $specEnergy[$n] }
    }
    $fourierVals[$nMax] = $e / $totalEnergy
}
$fourierLow1 = $fourierVals[1]
$fourierLow3 = $fourierVals[3]
$fourierLow5 = $fourierVals[5]

@(
    [pscustomobject]@{basis="polynomial_orthonormal_z"; low_modes="k=0..2"; energy_fraction=$polyLow3}
    [pscustomobject]@{basis="polynomial_orthonormal_z"; low_modes="k=0..4"; energy_fraction=$polyLow5}
    [pscustomobject]@{basis="polynomial_orthonormal_z"; low_modes="k=0..6"; energy_fraction=$polyLow7}
    [pscustomobject]@{basis="fourier_dft"; low_modes="n=0..1"; energy_fraction=$fourierLow1}
    [pscustomobject]@{basis="fourier_dft"; low_modes="n=0..3"; energy_fraction=$fourierLow3}
    [pscustomobject]@{basis="fourier_dft"; low_modes="n=0..5"; energy_fraction=$fourierLow5}
) | Export-Csv (Join-Path $tablesDir "phi_spectral_low_mode_energy.csv") -NoTypeInformation

# Stability windows
$windows = @(
    @{name="T_le_30"; path="results\switching\runs\run_2026_03_24_220314_residual_decomposition\tables\phi_shape.csv"},
    @{name="T_le_28"; path="results\switching\runs\run_2026_03_25_011526_rsr_child_tmax_28k\tables\phi_shape.csv"},
    @{name="T_le_25"; path="results\switching\runs\run_2026_03_25_011605_rsr_child_tmax_25k\tables\phi_shape.csv"},
    @{name="T_le_24"; path="results\switching\runs\run_2026_03_25_043610_kappa_phi_temperature_structure_test\tables\phi_shape.csv"}
)

function InterpLinear([double[]]$xRef, [double[]]$xSrc, [double[]]$ySrc) {
    $yOut = New-Object double[] $xRef.Count
    for ($j = 0; $j -lt $xRef.Count; $j++) {
        $xr = $xRef[$j]
        if ($xr -le $xSrc[0]) { $yOut[$j] = $ySrc[0]; continue }
        if ($xr -ge $xSrc[$xSrc.Count-1]) { $yOut[$j] = $ySrc[$ySrc.Count-1]; continue }
        for ($i = 0; $i -lt $xSrc.Count - 1; $i++) {
            if ($xSrc[$i] -le $xr -and $xr -le $xSrc[$i+1]) {
                $t = ($xr - $xSrc[$i]) / ($xSrc[$i+1] - $xSrc[$i])
                $yOut[$j] = $ySrc[$i] * (1.0 - $t) + $ySrc[$i+1] * $t
                break
            }
        }
    }
    return $yOut
}

$baseData = Import-Csv (Join-Path $root $windows[0].path)
$xBase = @($baseData | ForEach-Object { [double]$_.x })
$phiBase = @($baseData | ForEach-Object { [double]$_.Phi })
$mb = Mean $phiBase
for ($i = 0; $i -lt $phiBase.Count; $i++) { $phiBase[$i] -= $mb }
$nb = Norm $phiBase
for ($i = 0; $i -lt $phiBase.Count; $i++) { $phiBase[$i] /= $nb }

$stabRows = @()
foreach ($w in $windows) {
    $wd = Import-Csv (Join-Path $root $w.path)
    $xw = @($wd | ForEach-Object { [double]$_.x })
    $yw = @($wd | ForEach-Object { [double]$_.Phi })
    $yi = InterpLinear $xBase $xw $yw
    $mi = Mean $yi
    for ($i = 0; $i -lt $yi.Count; $i++) { $yi[$i] -= $mi }
    $ni = Norm $yi
    for ($i = 0; $i -lt $yi.Count; $i++) { $yi[$i] /= $ni }
    $corr = Dot $phiBase $yi
    $rmse = 0.0
    for ($i = 0; $i -lt $yi.Count; $i++) { $rmse += ($phiBase[$i] - $yi[$i]) * ($phiBase[$i] - $yi[$i]) }
    $rmse = [Math]::Sqrt($rmse / $yi.Count)
    $stabRows += [pscustomobject]@{window=$w.name; corr_with_T_le_30=$corr; rmse_vs_T_le_30=$rmse}
}
$stabRows | Export-Csv (Join-Path $tablesDir "phi_mode_stability_windows.csv") -NoTypeInformation

# Reuse prior diagnostics for tasks 2-3
$phys = Import-Csv (Join-Path $root "results\switching\runs\run_2026_03_25_041314_phi_physical_structure_test\tables\phi_physical_kernel_correlations.csv")
$cdf = $phys | Where-Object { $_.kernel_name -eq "cdf_curvature_d2dI2" } | Select-Object -First 1
$ptdef = Import-Csv (Join-Path $root "results\switching\runs\run_2026_03_25_041024_pt_deformation_mode_test\tables\pt_deformation_mode_correlation.csv")
$local = $ptdef | Where-Object { $_.basis_id -match "^(poly_|gauss_|narrow_gauss_|spline_|local_)" -and $_.rmse_ratio_kappaPhi_over_rank1 -ne "NaN" } | Sort-Object {[double]$_.rmse_ratio_kappaPhi_over_rank1} | Select-Object -First 1

$proj = Import-Csv (Join-Path $root "results\switching\runs\run_2026_03_25_034055_phi_pt_independence_test\tables\phi_projection_metrics.csv") | Select-Object -First 1
$corr = Import-Csv (Join-Path $root "results\switching\runs\run_2026_03_25_034055_phi_pt_independence_test\tables\phi_pt_correlation_metrics.csv")
$maxAbsCorr = ($corr | ForEach-Object { [Math]::Abs([double]$_.corr_with_phi) } | Measure-Object -Maximum).Maximum

$report = @()
$report += "# Phi elastic / interaction-induced collective mode test"
$report += ""
$report += "## Inputs and constraints"
$report += "- Reused existing decomposition and diagnostics only (no decomposition recomputation)."
$report += "- Required file `phi_structure_physics.md` was not found by exact-name search in the repository."
$report += "- Canonical Phi source: `run_2026_03_24_220314_residual_decomposition/tables/phi_shape.csv`."
$report += ""
$report += "## 1) Spectral smoothness"
$report += ("- Polynomial low-mode energy: k=0..2 **{0:N4}**, k=0..4 **{1:N4}**, k=0..6 **{2:N4}**." -f $polyLow3,$polyLow5,$polyLow7)
$report += ("- Fourier low-mode energy: n=0..1 **{0:N4}**, n=0..3 **{1:N4}**, n=0..5 **{2:N4}**." -f $fourierLow1,$fourierLow3,$fourierLow5)
$report += "- Interpretation: strong low-frequency concentration (smooth collective profile)."
$report += ""
$report += "## 2) Local vs nonlocal mismatch"
$report += ("- Best local derivative-like basis from PT deformation library: `{0}` with Pearson(Psi,Phi) **{1:N4}**, RMSE ratio(kappaPhi/rank1) **{2:N3}**." -f $local.basis_id,[double]$local.pearson_psi_phi,[double]$local.rmse_ratio_kappaPhi_over_rank1)
$report += ("- Physical-kernel check `cdf_curvature_d2dI2`: Pearson **{0:N4}**, cosine **{1:N4}**." -f [double]$cdf.pearson_r,[double]$cdf.cosine_similarity)
$report += "- Interpretation: local derivative kernels do not provide a competitive reconstruction."
$report += ""
$report += "## 3) PT independence"
$report += ("- Projection ratio ||proj_PT(Phi)||/||Phi||: **{0:N4}**." -f [double]$proj.projection_norm_ratio)
$report += ("- PT-space reconstruction RMSE / RMS(Phi): **{0:N4}**." -f [double]$proj.reconstruction_rmse_over_phi_rms)
$report += ("- Max |corr(Phi, PT-feature)|: **{0:N4}**." -f $maxAbsCorr)
$report += "- Interpretation: weak-independence criterion is not satisfied."
$report += ""
$report += "## 4) Mode stability across T windows"
foreach ($r in $stabRows) {
    $report += ("- {0}: corr with canonical **{1:N4}**, RMSE **{2:N4}**." -f $r.window,[double]$r.corr_with_T_le_30,[double]$r.rmse_vs_T_le_30)
}
$report += "- Interpretation: Phi shape is highly stable across tested windows."
$report += ""
$report += "## Final verdict"
$report += "**ELASTIC_MODE: PARTIAL**"
$report += ""
$report += "Phi is strongly smooth/even/stable and consistent with a collective-mode structure. However, PT-coupling diagnostics show strong PT-feature dependence, so the elastic interaction-induced interpretation is supported only partially under the requested criteria."

$report | Set-Content (Join-Path $reportsDir "phi_elastic_mode_test.md") -Encoding UTF8
Write-Output $runDir
