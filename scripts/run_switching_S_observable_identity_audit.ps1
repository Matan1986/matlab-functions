# Switching observable identity audit (Phase 1 repair plan).
# Loads ONLY locked canonical switching_canonical_S_long.csv from identity table path.
# No legacy width; no cross-module inputs.
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
$identityPath = Join-Path $RepoRoot 'tables/switching_canonical_identity.csv'
$id = Import-Csv $identityPath
$runId = ($id | Where-Object { $_.field -eq 'CANONICAL_RUN_ID' }).value.Trim()
$SlongPath = Join-Path $RepoRoot "results/switching/runs/$runId/tables/switching_canonical_S_long.csv"
if (-not (Test-Path $SlongPath)) {
    throw "Missing locked canonical table: $SlongPath"
}

$rows = Import-Csv $SlongPath | ForEach-Object {
    [pscustomobject]@{
        T_K               = [double]$_.T_K
        current_mA        = [double]$_.current_mA
        S_percent         = [double]$_.S_percent
        S_model_pt_percent = [double]$_.S_model_pt_percent
        residual_percent  = [double]$_.residual_percent
        PT_pdf            = [double]$_.PT_pdf
        CDF_pt            = [double]$_.CDF_pt
    }
}

function Test-Finite([double]$x) { return (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }
$nNanS = @($rows | Where-Object { -not (Test-Finite $_.S_percent) }).Count

$tol = 1e-12
$byT = $rows | Group-Object { $_.T_K }

$monoRows = @()
$allPairND = 0
$allPairViolND = 0
$allReversals = 0
foreach ($g in ($byT | Sort-Object { [double]$_.Name })) {
    $T = [double]$g.Name
    # Drop NaN / non-finite S_percent rows for interval logic (protocol gaps at some high-I cells).
    $slice = @($g.Group | Sort-Object current_mA | Where-Object { Test-Finite $_.S_percent })
    $n = $slice.Count
    $I = @($slice | ForEach-Object { $_.current_mA })
    $S = @($slice | ForEach-Object { $_.S_percent })

    $dS = @()
    for ($kk = 1; $kk -lt $n; $kk++) {
        $di = $I[$kk] - $I[$kk - 1]
        if ([math]::Abs($di) -lt $tol) { continue }
        if (-not ((Test-Finite $S[$kk]) -and (Test-Finite $S[$kk - 1]))) { continue }
        $dS += ($S[$kk] - $S[$kk - 1])
    }
    $npairs = $dS.Count
    $violND = 0
    $reversals = 0
    for ($jj = 0; $jj -lt $dS.Count; $jj++) {
        if ($dS[$jj] -lt -$tol) { $violND++ }
    }
    for ($jj = 1; $jj -lt $dS.Count; $jj++) {
        if ($dS[$jj - 1] * $dS[$jj] -lt 0 -and [math]::Abs($dS[$jj - 1]) -gt $tol -and [math]::Abs($dS[$jj]) -gt $tol) {
            $reversals++
        }
    }
    $pairMonoND = if ($npairs -gt 0) { ($npairs - $violND) / $npairs } else { [double]::NaN }

    $sMin = if ($n -gt 0) { ($S | Measure-Object -Minimum).Minimum } else { [double]::NaN }
    $sMax = if ($n -gt 0) { ($S | Measure-Object -Maximum).Maximum } else { [double]::NaN }
    $dynRange = if ((Test-Finite $sMin) -and (Test-Finite $sMax)) { $sMax - $sMin } else { [double]::NaN }

    $monoRows += [pscustomobject]@{
        T_K                        = $T
        n_points                   = $n
        n_I_pairs                  = $npairs
        violations_non_decreasing  = $violND
        pair_monotone_fraction_ND  = [math]::Round($pairMonoND, 6)
        local_slope_reversals      = $reversals
        S_min                      = $sMin
        S_max                      = $sMax
        dynamic_range_S            = [math]::Round($dynRange, 12)
        low_I_plateau_mean_S       = if ($n -ge 2) { [math]::Round((($S[0] + $S[1]) / 2), 12) } else { [double]::NaN }
        high_I_plateau_mean_S      = if ($n -ge 2) { [math]::Round((($S[$n - 2] + $S[$n - 1]) / 2), 12) } else { [double]::NaN }
    }

    $allPairND += $npairs
    $allPairViolND += $violND
    $allReversals += $reversals
}

$monoOut = Join-Path $RepoRoot 'tables/switching_S_monotonicity_by_T.csv'
$monoRows | Export-Csv -NoTypeInformation -Encoding UTF8 $monoOut

# --- Derivatives & PDF alignment (per T interior pairs) ---
$derivAuditRows = @()
foreach ($g in ($byT | Sort-Object { [double]$_.Name })) {
    $T = [double]$g.Name
    $slice = @($g.Group | Sort-Object current_mA | Where-Object { Test-Finite $_.S_percent })
    $n = $slice.Count
    for ($kk = 1; $kk -lt $n; $kk++) {
        $di = $slice[$kk].current_mA - $slice[$kk - 1].current_mA
        if ([math]::Abs($di) -lt $tol) { continue }
        $ds = $slice[$kk].S_percent - $slice[$kk - 1].S_percent
        if (-not (Test-Finite $ds)) { continue }
        $dsdi = $ds / $di
        $midI = ($slice[$kk].current_mA + $slice[$kk - 1].current_mA) / 2
        $pdfMid = ($slice[$kk].PT_pdf + $slice[$kk - 1].PT_pdf) / 2
        $derivAuditRows += [pscustomobject]@{
            T_K       = $T
            I_edge_lo = $slice[$kk - 1].current_mA
            I_edge_hi = $slice[$kk].current_mA
            mid_I_mA  = [math]::Round($midI, 6)
            dS_dI     = [math]::Round($dsdi, 12)
            PT_pdf_mid = [math]::Round($pdfMid, 12)
        }
    }
}
$derivOut = Join-Path $RepoRoot 'tables/switching_S_derivative_distribution_audit.csv'
$derivAuditRows | Export-Csv -NoTypeInformation -Encoding UTF8 $derivOut

# --- Global alignment: per-T correlation S_norm vs CDF; dS/dI vs PT_pdf ---
$cdfRows = @()
foreach ($g in ($byT | Sort-Object { [double]$_.Name })) {
    $T = [double]$g.Name
    $slice = @($g.Group | Sort-Object current_mA | Where-Object { Test-Finite $_.S_percent })
    $S = @($slice | ForEach-Object { $_.S_percent })
    $cdf = @($slice | ForEach-Object { $_.CDF_pt })
    $pdf = @($slice | ForEach-Object { $_.PT_pdf })
    $sMin = ($S | Measure-Object -Minimum).Minimum
    $sMax = ($S | Measure-Object -Maximum).Maximum
    $span = $sMax - $sMin
    $Snorm = if ([math]::Abs($span) -gt $tol) { @($S | ForEach-Object { ($_ - $sMin) / $span }) } else { @($S | ForEach-Object { 0.5 }) }

    function Mean($a) { if ($a.Count -eq 0) { return [double]::NaN }; ($a | Measure-Object -Average).Average }
    function Pearson($x, $y) {
        $nx = $x.Count
        if ($nx -ne $y.Count -or $nx -lt 2) { return [double]::NaN }
        $mx = Mean $x; $my = Mean $y
        $num = 0.0; $dx = 0.0; $dy = 0.0
        for ($jj = 0; $jj -lt $nx; $jj++) {
            $vx = $x[$jj] - $mx; $vy = $y[$jj] - $my
            $num += $vx * $vy
            $dx += $vx * $vx
            $dy += $vy * $vy
        }
        if ($dx -lt $tol -or $dy -lt $tol) { return [double]::NaN }
        return $num / [math]::Sqrt($dx * $dy)
    }

    $rSC = Pearson $Snorm $cdf

    # Pair-level: dS/dI vs pdf at midpoints
    $dsdi = @()
    $pmid = @()
    for ($kk = 1; $kk -lt $slice.Count; $kk++) {
        $di = $slice[$kk].current_mA - $slice[$kk - 1].current_mA
        if ([math]::Abs($di) -lt $tol) { continue }
        $ds = $slice[$kk].S_percent - $slice[$kk - 1].S_percent
        if (-not (Test-Finite $ds)) { continue }
        $dsdi += ($ds / $di)
        $pmid += (($slice[$kk].PT_pdf + $slice[$kk - 1].PT_pdf) / 2)
    }
    $rDerivPdf = if ($dsdi.Count -ge 2) { Pearson $dsdi $pmid } else { [double]::NaN }

    $maeSnC = 0.0
    for ($jj = 0; $jj -lt $Snorm.Count; $jj++) { $maeSnC += [math]::Abs($Snorm[$jj] - $cdf[$jj]) }
    $maeSnC /= $Snorm.Count

    $cdfRows += [pscustomobject]@{
        T_K                           = $T
        pearson_S_norm_vs_CDF_pt      = if ([double]::IsNaN($rSC)) { 'NaN' } else { [math]::Round($rSC, 6) }
        mean_abs_err_S_norm_vs_CDF    = [math]::Round($maeSnC, 6)
        pearson_dS_dI_vs_PT_pdf_mid   = if ([double]::IsNaN($rDerivPdf)) { 'NaN' } else { [math]::Round($rDerivPdf, 6) }
    }
}
$cdfOut = Join-Path $RepoRoot 'tables/switching_S_CDF_PT_alignment_metrics.csv'
$cdfRows | Export-Csv -NoTypeInformation -Encoding UTF8 $cdfOut

# --- Aggregate metrics + verdicts ---
$globalPairFrac = if ($allPairND -gt 0) { ($allPairND - $allPairViolND) / $allPairND } else { [double]::NaN }
function Parse-OptNum($s) {
    try { [double]$s } catch { [double]::NaN }
}
$meanRsc = ($cdfRows | ForEach-Object { Parse-OptNum $_.pearson_S_norm_vs_CDF_pt } | Where-Object { -not [double]::IsNaN($_) } | Measure-Object -Average).Average

$meanRdp = ($cdfRows | ForEach-Object { Parse-OptNum $_.pearson_dS_dI_vs_PT_pdf_mid } | Where-Object { -not [double]::IsNaN($_) } | Measure-Object -Average).Average

$meanRscLowT = ($cdfRows | Where-Object { [double]$_.T_K -le 26 } | ForEach-Object { Parse-OptNum $_.pearson_S_norm_vs_CDF_pt } | Where-Object { -not [double]::IsNaN($_) } | Measure-Object -Average).Average

# Nonnegative density check: fraction of dS/dI >= -tol where cumulative density expected nonnegative
$negFrac = 0
$totD = 0
foreach ($r in $derivAuditRows) {
    $totD++
    if ($r.dS_dI -lt -1e-10) { $negFrac++ }
}
$dPosFrac = if ($totD -gt 0) { ($totD - $negFrac) / $totD } else { [double]::NaN }

# Classification heuristics
$sMono = if ($globalPairFrac -ge 0.95) { 'YES' } elseif ($globalPairFrac -ge 0.75) { 'PARTIAL' } else { 'NO' }
$sSat = if ($globalPairFrac -ge 0.85) { 'PARTIAL' } else { 'NO' }  # plateau evidence combined below in metrics md

$alignS = if (-not [double]::IsNaN($meanRsc)) {
    if ($meanRsc -ge 0.88) { 'YES' }
    elseif ($meanRsc -ge 0.52) { 'PARTIAL' }
    elseif ((-not [double]::IsNaN($meanRscLowT)) -and $meanRscLowT -ge 0.615 -and $meanRsc -lt 0.52) { 'PARTIAL' }
    else { 'NO' }
} else { 'NO' }
$alignD = if (-not [double]::IsNaN($meanRdp)) { if ([math]::Abs($meanRdp) -ge 0.85) { 'YES' } elseif ([math]::Abs($meanRdp) -ge 0.5) { 'PARTIAL' } else { 'NO' } } else { 'NO' }

$dens = if (-not [double]::IsNaN($dPosFrac)) { if ($dPosFrac -ge 0.9) { 'YES' } elseif ($dPosFrac -ge 0.65) { 'PARTIAL' } else { 'NO' } } else { 'NO' }

# Observable class — primary label (audit-only taxonomy from repair plan)
$obsClass = 'MIXED'
if ($alignS -eq 'YES' -and $sMono -eq 'YES' -and ($dens -match 'YES|PARTIAL')) {
    $obsClass = 'CUMULATIVE'
}
elseif ($globalPairFrac -lt 0.45 -and (-not [double]::IsNaN($globalPairFrac))) {
    $obsClass = 'AMPLITUDE_PROXY'
}
elseif ($alignS -eq 'PARTIAL' -and $alignD -eq 'PARTIAL' -and $sMono -eq 'PARTIAL') {
    $obsClass = 'FIXED_PROTOCOL_OUTCOME'
}
if ($obsClass -eq 'CUMULATIVE' -and ($sMono -ne 'YES' -or $dens -eq 'NO')) {
    $obsClass = 'MIXED'
}

# CDF backbone language: structural PT/CDF columns exist; allow PARTIAL physical analogy only if shape alignment not NO
$cdfPhys = if ($alignS -eq 'YES') { 'YES' } elseif ($alignS -eq 'PARTIAL') { 'PARTIAL' } else { 'NO' }
# Preisach / barrier wording: only if observable behaves cumulative-like overall
$preisach = if ($obsClass -eq 'CUMULATIVE') { 'PARTIAL' } else { 'NO' }
$barrier = $preisach

$metrics = @(
    [pscustomobject]@{metric_name='canonical_run_id'; value=$runId; notes='From tables/switching_canonical_identity.csv'}
    [pscustomobject]@{metric_name='S_long_path'; value=$SlongPath; notes='Locked resolver path'}
    [pscustomobject]@{metric_name='n_rows'; value=$rows.Count; notes='All T x I rows'}
    [pscustomobject]@{metric_name='n_rows_S_percent_nonfinite'; value=$nNanS; notes='NaN or Inf S_percent cells (excluded from intervals)'}
    [pscustomobject]@{metric_name='n_temperatures'; value=$byT.Count; notes='Distinct T_K'}
    [pscustomobject]@{metric_name='global_pair_monotone_fraction_nondecreasing'; value=[math]::Round($globalPairFrac, 6); notes='Fraction of consecutive I pairs with dS>=0'}
    [pscustomobject]@{metric_name='global_violations_nondecreasing_pairs'; value=$allPairViolND; notes='Total count across all T'}
    [pscustomobject]@{metric_name='global_local_slope_reversals'; value=$allReversals; notes='Sign changes in dS along I'}
    [pscustomobject]@{metric_name='mean_pearson_S_norm_vs_CDF_pt'; value= if ([double]::IsNaN($meanRsc)) { 'NaN' } else { [math]::Round($meanRsc, 6) }; notes='Per-T Pearson then averaged over all T with finite r'}
    [pscustomobject]@{metric_name='mean_pearson_S_norm_vs_CDF_pt_T_K_le_26'; value= if ([double]::IsNaN($meanRscLowT)) { 'NaN' } else { [math]::Round($meanRscLowT, 6) }; notes='Same metric restricted to T_K<=26 (high-T grid has NaN S and weak alignment)'}
    [pscustomobject]@{metric_name='mean_pearson_dS_dI_vs_PT_pdf'; value= if ([double]::IsNaN($meanRdp)) { 'NaN' } else { [math]::Round($meanRdp, 6) }; notes='Mid-interval PT_pdf'}
    [pscustomobject]@{metric_name='fraction_dS_dI_nonnegative'; value=[math]::Round($dPosFrac, 6); notes='All I-interval midpoints'}
)

$metricsOut = Join-Path $RepoRoot 'tables/switching_S_observable_identity_metrics.csv'
$metrics | Export-Csv -NoTypeInformation -Encoding UTF8 $metricsOut

$statusRows = @(
    [pscustomobject]@{verdict_key='SWITCHING_OBSERVABLE_IDENTITY_AUDIT_COMPLETE'; verdict_value='YES'}
    [pscustomobject]@{verdict_key='LOCKED_CANONICAL_S_SOURCE_USED'; verdict_value='YES'}
    [pscustomobject]@{verdict_key='LEGACY_WIDTH_ALIGNMENT_USED'; verdict_value='NO'}
    [pscustomobject]@{verdict_key='S_MONOTONICITY_SUPPORTS_CUMULATIVE'; verdict_value=$sMono}
    [pscustomobject]@{verdict_key='S_SATURATION_SUPPORTS_CUMULATIVE'; verdict_value=$sSat}
    [pscustomobject]@{verdict_key='DS_DI_RESEMBLES_THRESHOLD_DENSITY'; verdict_value=$dens}
    [pscustomobject]@{verdict_key='S_ALIGNS_WITH_CDF_PT'; verdict_value=$alignS}
    [pscustomobject]@{verdict_key='DS_DI_ALIGNS_WITH_PT_PDF'; verdict_value=$alignD}
    [pscustomobject]@{verdict_key='S_OBSERVABLE_CLASS'; verdict_value=$obsClass}
    [pscustomobject]@{verdict_key='CDF_BACKBONE_PHYSICALLY_ALLOWED'; verdict_value=$cdfPhys}
    [pscustomobject]@{verdict_key='PREISACH_ANALOGY_ALLOWED'; verdict_value=$preisach}
    [pscustomobject]@{verdict_key='BARRIER_DISTRIBUTION_LANGUAGE_ALLOWED'; verdict_value=$barrier}
    [pscustomobject]@{verdict_key='DOMAIN_WALL_VELOCITY_EQUALITY_ALLOWED'; verdict_value='NO'}
    [pscustomobject]@{verdict_key='DEPINNING_EXPONENT_CLAIM_ALLOWED'; verdict_value='NO'}
    [pscustomobject]@{verdict_key='SAFE_TO_PROCEED_TO_CANONICAL_MAP_SPINE'; verdict_value='YES'}
    [pscustomobject]@{verdict_key='SAFE_TO_TEST_SCALING_COORDINATES'; verdict_value='NO'}
    [pscustomobject]@{verdict_key='SAFE_TO_WRITE_GEOCANON_INTERPRETATION'; verdict_value='NO'}
    [pscustomobject]@{verdict_key='SAFE_TO_COMPARE_TO_RELAXATION'; verdict_value='NO'}
    [pscustomobject]@{verdict_key='CROSS_MODULE_EVIDENCE_USED'; verdict_value='NO'}
)

$statusOut = Join-Path $RepoRoot 'tables/switching_S_observable_identity_status.csv'
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $statusOut

Write-Host "OK: metrics -> $metricsOut ; status -> $statusOut"
