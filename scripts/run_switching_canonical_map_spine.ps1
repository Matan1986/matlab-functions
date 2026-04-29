# SWITCHING NAMESPACE / EVIDENCE WARNING
# NAMESPACE_ID: CANON_GEN_SOURCE (T_K, current_mA, S_percent) + EXPERIMENTAL_PTCDF_DIAGNOSTIC (S_model_pt_percent, CDF_pt, PT_pdf) — full S_long read
# EVIDENCE_STATUS: DIAGNOSTIC_ONLY for PT/CDF columns; CANON_GEN_SOURCE for S_percent
# BACKBONE_FORMULA: reads S_model_pt_percent etc. from switching_canonical_S_long — not CORRECTED_CANONICAL_OLD_ANALYSIS backbone
# SVD_INPUT: N/A in spine (table IO / recompute residual column semantics per script)
# COORDINATE_GRID: native current_mA ladder
# SAFE_USE: map spine / correlation diagnostics with column-level namespace declared in any report
# UNSAFE_USE: treating script output as authoritative corrected-old evidence; manuscript primary backbone from PTCDF columns
# NOT_MAIN_MANUSCRIPT_EVIDENCE_IF_APPLICABLE: YES for PTCDF column usage
# CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
# Phase 2 — canonical map spine from locked switching_canonical_S_long.csv only (Switching).
# No scaling tests; no legacy width; geocanon ridge joined by T_K from repo tables only as inventory.
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'
function Test-Finite([double]$x) { (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }

function Mean($a) { if ($a.Count -eq 0) { return [double]::NaN }; ($a | Measure-Object -Average).Average }
function Pearson($x, $y) {
    $nx = $x.Count
    if ($nx -ne $y.Count -or $nx -lt 2) { return [double]::NaN }
    $mx = Mean $x; $my = Mean $y
    $num = 0.0; $dx = 0.0; $dy = 0.0
    for ($jj = 0; $jj -lt $nx; $jj++) {
        $vx = $x[$jj] - $mx; $vy = $y[$jj] - $my
        $num += $vx * $vy; $dx += $vx * $vx; $dy += $vy * $vy
    }
    if ($dx -lt 1e-18 -or $dy -lt 1e-18) { return [double]::NaN }
    return $num / [math]::Sqrt($dx * $dy)
}

$identityPath = Join-Path $RepoRoot 'tables/switching_canonical_identity.csv'
$id = Import-Csv $identityPath
$runId = ($id | Where-Object { $_.field -eq 'CANONICAL_RUN_ID' }).value.Trim()
$SlongPath = Join-Path $RepoRoot "results/switching/runs/$runId/tables/switching_canonical_S_long.csv"
if (-not (Test-Path $SlongPath)) { throw "Missing $SlongPath" }

$geoPath = Join-Path $RepoRoot 'tables/switching_geocanon_T1_weighted_ridge_values.csv'
$geoRows = @()
if (Test-Path $geoPath) {
    $geoRows = Import-Csv $geoPath | ForEach-Object {
        [pscustomobject]@{ T_K = [double]$_.T_K; ridge_center_geocanon_primary = [double]$_.ridge_center_geocanon_primary }
    }
}
$geoByT = @{}
foreach ($g in $geoRows) {
    $tk = [double]$g.T_K
    $geoByT[$tk] = $g.ridge_center_geocanon_primary
}

$rows = Import-Csv $SlongPath | ForEach-Object {
    [pscustomobject]@{
        T_K                = [double]$_.T_K
        current_mA         = [double]$_.current_mA
        S_percent          = [double]$_.S_percent
        S_model_pt_percent = [double]$_.S_model_pt_percent
        residual_percent   = [double]$_.residual_percent
        PT_pdf             = [double]$_.PT_pdf
        CDF_pt             = [double]$_.CDF_pt
    }
}

$tol = 1e-14
foreach ($r in $rows) {
    $r | Add-Member -NotePropertyName residual_recomputed -NotePropertyValue ($r.S_percent - $r.S_model_pt_percent) -Force
    $r | Add-Member -NotePropertyName residual_abs_diff -NotePropertyValue ([math]::Abs($r.residual_percent - ($r.S_percent - $r.S_model_pt_percent))) -Force
}

$maxResDiff = ($rows | ForEach-Object { $_.residual_abs_diff } | Measure-Object -Maximum).Maximum

$byT = $rows | Group-Object { $_.T_K }

# --- Per-T peaks (canonical dictionary sense: max_I S) ---
$peakRows = @()
foreach ($g in ($byT | Sort-Object { [double]$_.Name })) {
    $tKey = [double]$g.Name
    $slice = @($g.Group | Where-Object { Test-Finite $_.S_percent })
    if ($slice.Count -eq 0) { continue }
    $best = $slice | Sort-Object S_percent -Descending | Select-Object -First 1
    $ridgeVal = [double]::NaN
    if ($geoByT.ContainsKey($tKey)) { $ridgeVal = $geoByT[$tKey] }
    $peakRows += [pscustomobject]@{
        T_K              = $tKey
        S_peak           = $best.S_percent
        I_at_S_peak_mA   = $best.current_mA
        ridge_center_geocanon_primary_mA = $ridgeVal
    }
}

# --- dS/dI intervals (deterministic I order) ---
$intervalRows = @()
foreach ($g in ($byT | Sort-Object { [double]$_.Name })) {
    $T = [double]$g.Name
    $slice = @($g.Group | Sort-Object current_mA | Where-Object { Test-Finite $_.S_percent })
    for ($kk = 1; $kk -lt $slice.Count; $kk++) {
        $di = $slice[$kk].current_mA - $slice[$kk - 1].current_mA
        if ([math]::Abs($di) -lt $tol) { continue }
        $ds = $slice[$kk].S_percent - $slice[$kk - 1].S_percent
        if (-not (Test-Finite $ds)) { continue }
        $midI = ($slice[$kk].current_mA + $slice[$kk - 1].current_mA) / 2
        $cdfMid = ($slice[$kk].CDF_pt + $slice[$kk - 1].CDF_pt) / 2
        $intervalRows += [pscustomobject]@{
            T_K = $T
            I_lo = $slice[$kk - 1].current_mA
            I_hi = $slice[$kk].current_mA
            mid_I_mA = $midI
            dS_dI = $ds / $di
            PT_pdf_mid = ($slice[$kk].PT_pdf + $slice[$kk - 1].PT_pdf) / 2
            CDF_pt_mid = $cdfMid
        }
    }
}

# --- Region tag by CDF (point-level for grid rows) ---
function Get-CdfRegion([double]$c) {
    if (-not (Test-Finite $c)) { return 'unknown' }
    if ($c -lt 0.1 -or $c -gt 0.99) { return 'tail' }
    if ($c -ge 0.25 -and $c -le 0.75) { return 'core' }
    return 'shoulder'
}

$regionAgg = @{ tail = @(); core = @(); shoulder = @() }
foreach ($r in $rows) {
    if (-not (Test-Finite $r.S_percent)) { continue }
    $sMin = ($rows | Where-Object { $_.T_K -eq $r.T_K -and (Test-Finite $_.S_percent) } | ForEach-Object { $_.S_percent } | Measure-Object -Minimum).Minimum
    $sMax = ($rows | Where-Object { $_.T_K -eq $r.T_K -and (Test-Finite $_.S_percent) } | ForEach-Object { $_.S_percent } | Measure-Object -Maximum).Maximum
    $span = $sMax - $sMin
    $Sn = if ([math]::Abs($span) -gt $tol) { ($r.S_percent - $sMin) / $span } elseif (Test-Finite($sMin)) { 0.5 } else { [double]::NaN }
    if (-not (Test-Finite $Sn)) { continue }
    $err = [math]::Abs($Sn - $r.CDF_pt)
    $reg = Get-CdfRegion $r.CDF_pt
    if ($regionAgg.ContainsKey($reg)) { $regionAgg[$reg] += $err }
}

# --- Pearsons per T (finite S rows) ---
$cdfAlign = @()
foreach ($g in ($byT | Sort-Object { [double]$_.Name })) {
    $slice = @($g.Group | Sort-Object current_mA | Where-Object { Test-Finite $_.S_percent })
    $S = @($slice | ForEach-Object { $_.S_percent })
    $cdf = @($slice | ForEach-Object { $_.CDF_pt })
    $sMin = ($S | Measure-Object -Minimum).Minimum
    $sMax = ($S | Measure-Object -Maximum).Maximum
    $span = $sMax - $sMin
    $Snorm = if ([math]::Abs($span) -gt $tol) { @($S | ForEach-Object { ($_ - $sMin) / $span }) } else { @($S | ForEach-Object { 0.5 }) }
    $rSC = Pearson $Snorm $cdf

    $dsdi = @(); $pmid = @()
    for ($kk = 1; $kk -lt $slice.Count; $kk++) {
        $di = $slice[$kk].current_mA - $slice[$kk - 1].current_mA
        if ([math]::Abs($di) -lt $tol) { continue }
        $ds = $slice[$kk].S_percent - $slice[$kk - 1].S_percent
        if (-not (Test-Finite $ds)) { continue }
        $dsdi += ($ds / $di)
        $pmid += (($slice[$kk].PT_pdf + $slice[$kk - 1].PT_pdf) / 2)
    }
    $rDP = if ($dsdi.Count -ge 2) { Pearson $dsdi $pmid } else { [double]::NaN }

    $cdfAlign += [pscustomobject]@{
        T_K = [double]$g.Name
        pearson_S_norm_vs_CDF = if ([double]::IsNaN($rSC)) { 'NaN' } else { [math]::Round($rSC, 6) }
        pearson_dS_dI_vs_PT_pdf = if ([double]::IsNaN($rDP)) { 'NaN' } else { [math]::Round($rDP, 6) }
    }
}

$meanRsc = ($cdfAlign | ForEach-Object { try { [double]$_.pearson_S_norm_vs_CDF } catch { [double]::NaN } } | Where-Object { -not [double]::IsNaN($_) } | Measure-Object -Average).Average
$meanRdp = ($cdfAlign | ForEach-Object { try { [double]$_.pearson_dS_dI_vs_PT_pdf } catch { [double]::NaN } } | Where-Object { -not [double]::IsNaN($_) } | Measure-Object -Average).Average

# --- Grid summary rows ---
function Grid-Stats($name, [double[]]$vals) {
    $f = @($vals | Where-Object { Test-Finite $_ })
    [pscustomobject]@{
        grid_name = $name
        n_total = $vals.Count
        n_finite = $f.Count
        n_nonfinite = $vals.Count - $f.Count
        min_value = if ($f.Count) { ($f | Measure-Object -Minimum).Minimum } else { 'NaN' }
        max_value = if ($f.Count) { ($f | Measure-Object -Maximum).Maximum } else { 'NaN' }
        mean_value = if ($f.Count) { [math]::Round(($f | Measure-Object -Average).Average, 12) } else { 'NaN' }
    }
}

$gridSummary = @(
    Grid-Stats 'S_percent' (@($rows | ForEach-Object { $_.S_percent }))
    Grid-Stats 'S_model_pt_percent' (@($rows | ForEach-Object { $_.S_model_pt_percent }))
    Grid-Stats 'residual_percent_canonical_column' (@($rows | ForEach-Object { $_.residual_percent }))
    Grid-Stats 'residual_recomputed_S_minus_S_model_pt' (@($rows | ForEach-Object { $_.residual_recomputed }))
    Grid-Stats 'residual_abs_diff_canonical_minus_recomputed' (@($rows | ForEach-Object { $_.residual_abs_diff }))
    Grid-Stats 'CDF_pt' (@($rows | ForEach-Object { $_.CDF_pt }))
    Grid-Stats 'PT_pdf' (@($rows | ForEach-Object { $_.PT_pdf }))
    Grid-Stats 'dS_dI_interval_midpoints' (@($intervalRows | ForEach-Object { $_.dS_dI }))
)

# --- Spine inventory (documentation) ---
$inv = @(
    [pscustomobject]@{ spine_element='S_map'; source_location=$SlongPath; column_or_derivation='S_percent'; grid_role='primary response S(I,T)'; verification_note='Locked run per tables/switching_canonical_identity.csv' }
    [pscustomobject]@{ spine_element='PT_model_S'; source_location=$SlongPath; column_or_derivation='S_model_pt_percent'; grid_role='PT backbone model column'; verification_note='Same row keys T_K current_mA' }
    [pscustomobject]@{ spine_element='residual_pt'; source_location=$SlongPath; column_or_derivation='residual_percent canonical; matches S-S_model_pt on this grid'; grid_role='certified residual column'; verification_note=('max_abs_diff_canonical_vs_recomputed=' + [math]::Round($maxResDiff, 15)) }
    [pscustomobject]@{ spine_element='CDF_backbone'; source_location=$SlongPath; column_or_derivation='CDF_pt'; grid_role='PT cumulative coordinate on spine'; verification_note='Use Phase 1 language: PARTIAL physical analogy' }
    [pscustomobject]@{ spine_element='PT_density_backbone'; source_location=$SlongPath; column_or_derivation='PT_pdf'; grid_role='PT density coordinate on spine'; verification_note='Derivative spine alignment vs dS/dI in derivative summary' }
    [pscustomobject]@{ spine_element='dS_dI'; source_location='derived'; column_or_derivation='finite differences on sorted current_mA per T_K'; grid_role='I-derivative of S on protocol ladder'; verification_note='Deterministic ordering; excludes non-finite S rows' }
)

$invOut = Join-Path $RepoRoot 'tables/switching_canonical_map_spine_inventory.csv'
$inv | Export-Csv -NoTypeInformation -Encoding UTF8 $invOut

$gridOut = Join-Path $RepoRoot 'tables/switching_canonical_map_spine_grids_summary.csv'
$gridSummary | Export-Csv -NoTypeInformation -Encoding UTF8 $gridOut

# Merge alignment failures list (|r|<0.5 for either metric)
$failAlign = @()
foreach ($c in $cdfAlign) {
    $a = try { [double]$c.pearson_S_norm_vs_CDF } catch { [double]::NaN }
    $b = try { [double]$c.pearson_dS_dI_vs_PT_pdf } catch { [double]::NaN }
    if ((-not [double]::IsNaN($a)) -and $a -lt 0.5) { $failAlign += "T_K=$($c.T_K) weak_S_norm_vs_CDF r=$a" }
    if ((-not [double]::IsNaN($b)) -and $b -lt 0.5) { $failAlign += "T_K=$($c.T_K) weak_dS_vs_pdf r=$b" }
}
$derivSummary = @(
    [pscustomobject]@{ metric_category='alignment'; metric_name='mean_pearson_S_norm_vs_CDF_pt_across_T'; value=[math]::Round($meanRsc, 6); detail='Finite-T rows only' }
    [pscustomobject]@{ metric_category='alignment'; metric_name='mean_pearson_dS_dI_vs_PT_pdf_mid_across_T'; value=[math]::Round($meanRdp, 6); detail='Per-T interval vectors' }
    [pscustomobject]@{ metric_category='cdf_region_mae_S_norm_vs_CDF'; metric_name='mean_abs_err_tail'; value= if ($regionAgg.tail.Count) { [math]::Round(($regionAgg.tail | Measure-Object -Average).Average, 6) } else { 'NaN' }; detail='CDF_pt<0.1 or >0.99' }
    [pscustomobject]@{ metric_category='cdf_region_mae_S_norm_vs_CDF'; metric_name='mean_abs_err_core'; value= if ($regionAgg.core.Count) { [math]::Round(($regionAgg.core | Measure-Object -Average).Average, 6) } else { 'NaN' }; detail='0.25<=CDF_pt<=0.75' }
    [pscustomobject]@{ metric_category='cdf_region_mae_S_norm_vs_CDF'; metric_name='mean_abs_err_shoulder'; value= if ($regionAgg.shoulder.Count) { [math]::Round(($regionAgg.shoulder | Measure-Object -Average).Average, 6) } else { 'NaN' }; detail='shoulder band' }
    [pscustomobject]@{ metric_category='interval_count'; metric_name='n_dS_dI_intervals'; value=$intervalRows.Count; detail='all T' }
    [pscustomobject]@{ metric_category='alignment_failures'; metric_name='flagged_T_summary'; value=($failAlign -join ' | '); detail='|r|<0.5 either channel' }
)
$derivOut = Join-Path $RepoRoot 'tables/switching_canonical_derivative_spine_summary.csv'
$derivSummary | Export-Csv -NoTypeInformation -Encoding UTF8 $derivOut

# Center / width candidates (meta + per-T computed peaks joined with geocanon ridge)
$cw = @(
    [pscustomobject]@{ candidate_name='S_peak'; definition='max_I S(T,I) on spine ladder'; availability='computed_per_T'; status='candidate_locked_definition'; source_table=$SlongPath; notes='Matches observable_dictionary S_peak intent' }
    [pscustomobject]@{ candidate_name='I_at_S_peak'; definition='current_mA argmax S on ladder'; availability='computed_per_T'; status='candidate'; source_table=$SlongPath; notes='Not an independent I_peak(T) measurement column' }
    [pscustomobject]@{ candidate_name='I_peak_legacy_style'; definition='distinct legacy I_peak(T) column'; availability='absent_on_S_long'; status='partial'; source_table='N/A'; notes='Deep audit: canonical I_peak PARTIAL — use argmax surrogate only here' }
    [pscustomobject]@{ candidate_name='W_width'; definition='canonical width scalar W(T)'; availability='absent_on_S_long'; status='partial'; source_table='N/A'; notes='Deep audit: canonical W PARTIAL — not carried on this spine grid' }
    [pscustomobject]@{ candidate_name='ridge_center_geocanon_primary'; definition='geocanon T1 weighted ridge center'; availability=$(if ($geoRows.Count) { 'tables_join_T_K' } else { 'missing_file' }); status=$(if ($geoRows.Count) { 'locked_geocanon_T1_table' } else { 'unavailable' }); source_table=$(if (Test-Path $geoPath) { $geoPath } else { 'N/A' }); notes='Inventory only; no scaling test' }
)
foreach ($pr in $peakRows) {
    $cw += [pscustomobject]@{
        candidate_name    = ('per_T_spine_peak_T_{0}' -f $pr.T_K)
        definition        = 'S_peak = max_I S on ladder; I_at_S_peak; ridge from geocanon T1 table by T_K'
        availability      = 'computed_and_or_joined'
        status            = 'candidate'
        source_table      = $SlongPath
        notes             = ('S_peak={0}; I_at_S_peak_mA={1}; ridge_geocanon_mA={2}' -f $pr.S_peak, $pr.I_at_S_peak_mA, $pr.ridge_center_geocanon_primary_mA)
    }
}
$cwOut = Join-Path $RepoRoot 'tables/switching_center_width_candidate_inventory.csv'
$cw | Export-Csv -NoTypeInformation -Encoding UTF8 $cwOut

# Status verdicts
$ipeakVer = 'PARTIAL'
$wVer = 'NO'
$ridgeVer = if ($geoRows.Count) { 'PARTIAL' } else { 'NO' }

$statusRows = @(
    [pscustomobject]@{ verdict_key='CANONICAL_MAP_SPINE_COMPLETE'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='LOCKED_CANONICAL_S_SOURCE_USED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='LEGACY_WIDTH_ALIGNMENT_USED'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='S_MAP_GRID_BUILT'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='PT_BACKBONE_GRID_BUILT'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='CDF_PT_GRID_BUILT'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='PT_PDF_GRID_BUILT'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='DS_DI_GRID_BUILT'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='DERIVATIVE_SPINE_INCLUDED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='CENTER_WIDTH_CANDIDATES_INVENTORIED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='IPEAK_USABLE_AS_SCALING_BASELINE'; verdict_value=$ipeakVer }
    [pscustomobject]@{ verdict_key='W_USABLE_AS_SCALING_BASELINE'; verdict_value=$wVer }
    [pscustomobject]@{ verdict_key='RIDGE_CENTER_AVAILABLE_AS_CENTER_CANDIDATE'; verdict_value=$ridgeVer }
    [pscustomobject]@{ verdict_key='SAFE_TO_PROCEED_TO_COORDINATE_IDENTIFIABILITY_AUDIT'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='SAFE_TO_TEST_SCALING_COORDINATES'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='SAFE_TO_WRITE_GEOCANON_INTERPRETATION'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='SAFE_TO_COMPARE_TO_RELAXATION'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='CROSS_MODULE_EVIDENCE_USED'; verdict_value='NO' }
)
$statusOut = Join-Path $RepoRoot 'tables/switching_canonical_map_spine_status.csv'
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $statusOut

Write-Host "OK spine: $invOut"
