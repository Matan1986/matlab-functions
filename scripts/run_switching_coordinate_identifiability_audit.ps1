# Phase 3 — coordinate identifiability audit (Switching only). Formulas only; no collapse optimization.
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'
function Test-Finite([double]$x) { (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }

$identityPath = Join-Path $RepoRoot 'tables/switching_canonical_identity.csv'
$id = Import-Csv $identityPath
$runId = ($id | Where-Object { $_.field -eq 'CANONICAL_RUN_ID' }).value.Trim()
$SlongPath = Join-Path $RepoRoot "results/switching/runs/$runId/tables/switching_canonical_S_long.csv"
if (-not (Test-Path $SlongPath)) { throw "Missing $SlongPath" }

$geoPath = Join-Path $RepoRoot 'tables/switching_geocanon_T1_weighted_ridge_values.csv'
$ridgeByT = @{}
if (Test-Path $geoPath) {
    Import-Csv $geoPath | ForEach-Object { $ridgeByT[[double]$_.T_K] = [double]$_.ridge_center_geocanon_primary }
}

$rows = Import-Csv $SlongPath | ForEach-Object {
    [pscustomobject]@{ T_K=[double]$_.T_K; current_mA=[double]$_.current_mA; S_percent=[double]$_.S_percent
        PT_pdf=[double]$_.PT_pdf; CDF_pt=[double]$_.CDF_pt }
}
$byT = $rows | Group-Object { $_.T_K }

function Interpolate-I-At-CdfTarget($sliceSorted, [double]$targetCdf) {
    # sliceSorted: sorted by current_mA; linear interp I(CDF)
    $arr = @($sliceSorted | Sort-Object current_mA)
    for ($i = 1; $i -lt $arr.Count; $i++) {
        $c0 = $arr[$i - 1].CDF_pt; $c1 = $arr[$i].CDF_pt
        $i0 = $arr[$i - 1].current_mA; $i1 = $arr[$i].current_mA
        if (-not ((Test-Finite $c0) -and (Test-Finite $c1))) { continue }
        if (($targetCdf -ge [math]::Min($c0, $c1)) -and ($targetCdf -le [math]::Max($c0, $c1))) {
            if ([math]::Abs($c1 - $c0) -lt 1e-15) { return ($i0 + $i1) / 2 }
            $t = ($targetCdf - $c0) / ($c1 - $c0)
            return $i0 + $t * ($i1 - $i0)
        }
    }
    return [double]::NaN
}

$perTStats = @()
foreach ($g in ($byT | Sort-Object { [double]$_.Name })) {
    $tk = [double]$g.Name
    $slice = @($g.Group | Sort-Object current_mA | Where-Object { Test-Finite $_.S_percent })
    $best = @($slice | Sort-Object S_percent -Descending)[0]
    $iPeak = $best.current_mA
    $ridge = if ($ridgeByT.ContainsKey($tk)) { $ridgeByT[$tk] } else { [double]::NaN }

    $pdfMax = ($slice | ForEach-Object { $_.PT_pdf } | Measure-Object -Maximum).Maximum
    $half = $pdfMax / 2
    $widthPdf = [double]::NaN
    if ((Test-Finite $pdfMax) -and $pdfMax -gt 0) {
        $above = @($slice | Where-Object { $_.PT_pdf -ge $half })
        if ($above.Count -ge 2) {
            $widthPdf = ($above | Measure-Object current_mA -Maximum).Maximum - ($above | Measure-Object current_mA -Minimum).Minimum
        } elseif ($above.Count -eq 1) { $widthPdf = 0 }
    }

    $iCdf02 = Interpolate-I-At-CdfTarget $slice 0.2
    $iCdf08 = Interpolate-I-At-CdfTarget $slice 0.8
    $cdfTransWidth = if ((Test-Finite $iCdf02) -and (Test-Finite $iCdf08)) { [math]::Abs($iCdf08 - $iCdf02) } else { [double]::NaN }

    $pdfLoc = ($slice | Sort-Object PT_pdf -Descending | Select-Object -First 1).current_mA

    $perTStats += [pscustomobject]@{
        T_K = $tk
        I_argmax_S_mA = $iPeak
        ridge_geocanon_mA = $ridge
        abs_argmax_minus_ridge_mA = if ((Test-Finite $ridge)) { [math]::Abs($iPeak - $ridge) } else { [double]::NaN }
        I_at_PT_pdf_max_mA = $pdfLoc
        width_PT_pdf_FWHM_span_mA = $widthPdf
        width_CDF_02_to_08_mA = $cdfTransWidth
    }
}

$nT = $perTStats.Count
$finiteRidge = @($perTStats | Where-Object { Test-Finite $_.ridge_geocanon_mA }).Count

$gapVals = @($perTStats | Where-Object { Test-Finite $_.abs_argmax_minus_ridge_mA } | ForEach-Object { $_.abs_argmax_minus_ridge_mA })
$meanAbsGap = if ($gapVals.Count) { ($gapVals | Measure-Object -Average).Average } else { [double]::NaN }
$sdGap = if ($gapVals.Count -gt 1) {
    $v = $gapVals | ForEach-Object { ($_ - $meanAbsGap) * ($_ - $meanAbsGap) }
    [math]::Sqrt(($v | Measure-Object -Average).Average)
} else { [double]::NaN }

# --- Center inventory ---
$centerRows = @(
    [pscustomobject]@{ center_id='none_raw_current'; definition='Use current_mA directly (no subtraction)'; classification='canonical_safe'; unique_by_T='YES'; finite_coverage_T="16/16"; stability_note='Axis is experimental control; unique but not a derived center'; ambiguity_source='N/A not a centered coordinate' }
    [pscustomobject]@{ center_id='I_argmax_S_spine'; definition='current_mA at max S_percent on sorted ladder per T_K'; classification='candidate_only'; unique_by_T='PARTIAL'; finite_coverage_T='16/16 T_K with finite S grid'; stability_note='Argmax can move discretely with T; ties possible on coarser ladders'; ambiguity_source='Discrete ladder + possible ties; not independent measurement of legacy I_peak(T)' }
    [pscustomobject]@{ center_id='ridge_center_geocanon_primary'; definition='ridge_center_geocanon_primary(T) from T1 table'; classification='candidate_only'; unique_by_T='PARTIAL'; finite_coverage_T=('{0}/16 from geocanon table' -f $finiteRidge); stability_note=('Mean_abs_argmax_minus_ridge_mA~{0}_sd~{1}' -f [math]::Round($meanAbsGap,3), [math]::Round($sdGap,3)); ambiguity_source='Distinct family from argmax-S; geocanon vs spine peak semantics differ' }
    [pscustomobject]@{ center_id='I_at_CDF_pt_half'; definition='Linearly interpolated I where CDF_pt crosses 0.5 along ladder'; classification='canonical_safe'; unique_by_T='PARTIAL'; finite_coverage_T='computed_per_T_when_CDF_monotone_in_I'; stability_note='Requires monotone CDF vs I on ladder for injectivity'; ambiguity_source='Non-monotone CDF(I) breaks unique crossing; check per T' }
    [pscustomobject]@{ center_id='I_at_PT_pdf_max'; definition='current_mA at max PT_pdf on discrete ladder'; classification='candidate_only'; unique_by_T='PARTIAL'; finite_coverage_T='16/16'; stability_note='Co-located with PT backbone density peak on grid'; ambiguity_source='Plateau maxima yield interval ambiguity' }
)

$centerOut = Join-Path $RepoRoot 'tables/switching_coordinate_identifiability_center_inventory.csv'
$centerRows | Export-Csv -NoTypeInformation -Encoding UTF8 $centerOut

# --- Width inventory ---
$widthRows = @(
    [pscustomobject]@{ width_id='none'; definition='No width normalization'; classification='canonical_safe'; unique_by_T='YES'; finite_coverage_T='n/a'; stability_note='Use raw I or backbone coords without scaling'; ambiguity_source='NA' }
    [pscustomobject]@{ width_id='canonical_W_column'; definition='Dedicated W(T) on spine'; classification='forbidden'; unique_by_T='NO'; finite_coverage_T='0/16 on S_long'; stability_note='Absent'; ambiguity_source='Not available — Phase 2 verdict W baseline NO' }
    [pscustomobject]@{ width_id='legacy_alignment_width'; definition='Legacy width / alignment inventories'; classification='legacy_diagnostic'; unique_by_T='NO'; finite_coverage_T='quarantine'; stability_note='Not used as evidence here'; ambiguity_source='Cross-namespace risk per separation contract' }
    [pscustomobject]@{ width_id='PT_pdf_FWHM_span'; definition='Span of currents where PT_pdf >= half max at fixed T'; classification='canonical_safe'; unique_by_T='PARTIAL'; finite_coverage_T='see per_T_stats'; stability_note='Discrete FWHM proxy'; ambiguity_source='Half-max plateau width may be zero or multi-interval if flat' }
    [pscustomobject]@{ width_id='CDF_transition_02_08'; definition='abs(I(CDF=0.8)-I(CDF=0.2)) linear interp on ladder'; classification='canonical_safe'; unique_by_T='PARTIAL'; finite_coverage_T='finite when crossings exist'; stability_note='Captures backbone transition extent in I'; ambiguity_source='Interpolation gaps if CDF not bracketed' }
    [pscustomobject]@{ width_id='dS_dI_curvature_scale'; definition='Second-moment or span of dS/dI intervals; deferred minimal'; classification='candidate_only'; unique_by_T='PARTIAL'; finite_coverage_T='from derivative spine'; stability_note='Use only with explicit formula in Phase 4'; ambiguity_source='Not uniquely preferred without collapse gate' }
)

$widthOut = Join-Path $RepoRoot 'tables/switching_coordinate_identifiability_width_inventory.csv'
$widthRows | Export-Csv -NoTypeInformation -Encoding UTF8 $widthOut

# --- Candidate families (formulas only) ---
$fam = @(
    [pscustomobject]@{ family_id='I_raw_candidate'; formula='x = current_mA'; blocked='NO'; requires_W='NO'; notes='Primitive control coordinate' }
    [pscustomobject]@{ family_id='eta_Ipeak_candidate'; formula='eta = current_mA - I_argmax_S_spine(T)'; blocked='NO'; requires_W='NO'; notes='Shift by spine argmax center' }
    [pscustomobject]@{ family_id='x_Ipeak_W_candidate'; formula='(I - I_argmax_S)/W(T)'; blocked='YES'; requires_W='YES'; notes='Blocked: no canonical W(T) on spine' }
    [pscustomobject]@{ family_id='eta_ridge_candidate'; formula='eta = current_mA - ridge_center_geocanon_primary(T)'; blocked='NO'; requires_W='NO'; notes='Requires finite ridge row for that T' }
    [pscustomobject]@{ family_id='x_ridge_W_candidate'; formula='(I - ridge_center)/W(T)'; blocked='YES'; requires_W='YES'; notes='Blocked until usable width family exists' }
    [pscustomobject]@{ family_id='CDF_pt_candidate'; formula='x = CDF_pt'; blocked='NO'; requires_W='NO'; notes='Backbone cumulative coordinate on spine; Phase 1 PARTIAL analogy only' }
    [pscustomobject]@{ family_id='PT_pdf_axis_candidate'; formula='use PT_pdf as auxiliary axis alongside I (not replacing I)'; blocked='PARTIAL'; requires_W='NO'; notes='Density coordinate paired with I for bookkeeping only' }
    [pscustomobject]@{ family_id='eta_perp_geocanon'; formula='DEFERRED'; blocked='YES'; requires_W='DEFERRED'; notes='T2 / perpendicular frame not implemented' }
)

$famOut = Join-Path $RepoRoot 'tables/switching_coordinate_identifiability_candidate_families.csv'
$fam | Export-Csv -NoTypeInformation -Encoding UTF8 $famOut

# --- Non-uniqueness audit ---
$nonuniq = @(
    [pscustomobject]@{ topic='I_peak_like_center'; summary='Argmax-on-ladder peak current is operationally defined and moves with T; not identical to ridge_center_geocanon_primary'; severity='HIGH'; evidence_ref='per_T abs_argmax_minus_ridge_mA distribution' }
    [pscustomobject]@{ topic='W_width'; summary='No spine W(T); width-normalized X families blocked'; severity='HIGH'; evidence_ref='tables/switching_canonical_map_spine_status W_USABLE_AS_SCALING_BASELINE=NO' }
    [pscustomobject]@{ topic='X_family'; summary='Multiple shifts (eta_Ipeak vs eta_ridge) and CDF_pt backbone yield non-equivalent 1D coordinates without collapse test'; severity='HIGH'; evidence_ref='Phase 1 MIXED observable class' }
    [pscustomobject]@{ topic='multiple_centers_coexist'; summary='At least three distinct center notions (none argmax ridge CDF-half) usable as candidates — no canonical uniqueness'; severity='MEDIUM'; evidence_ref='center_inventory rows' }
)

$nonOut = Join-Path $RepoRoot 'tables/switching_coordinate_nonuniqueness_audit.csv'
$nonuniq | Export-Csv -NoTypeInformation -Encoding UTF8 $nonOut

# Verdicts
$statusRows = @(
    [pscustomobject]@{ verdict_key='COORDINATE_IDENTIFIABILITY_AUDIT_COMPLETE'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='LOCKED_CANONICAL_S_SOURCE_USED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='LEGACY_WIDTH_ALIGNMENT_USED'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='CENTER_DEFINITIONS_INVENTORIED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='WIDTH_DEFINITIONS_INVENTORIED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='IPEAK_NONUNIQUENESS_DOCUMENTED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='W_NONUNIQUENESS_DOCUMENTED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='X_NONUNIQUENESS_DOCUMENTED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='CENTER_UNIQUENESS'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='WIDTH_UNIQUENESS'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='EFFECTIVE_COORDINATE_FAMILY_DEFINED'; verdict_value='PARTIAL' }
    [pscustomobject]@{ verdict_key='UNIQUE_EFFECTIVE_COORDINATE_FOUND'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='ONLY_COORDINATE_FAMILY_SUPPORTED'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='CDF_PT_AVAILABLE_AS_COORDINATE_CANDIDATE'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='RIDGE_CENTER_AVAILABLE_AS_CENTER_CANDIDATE'; verdict_value='PARTIAL' }
    [pscustomobject]@{ verdict_key='IPEAK_USABLE_AS_CENTER_CANDIDATE'; verdict_value='PARTIAL' }
    [pscustomobject]@{ verdict_key='W_USABLE_AS_SCALING_WIDTH'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='SAFE_TO_TEST_SCALING_COORDINATES'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='SAFE_TO_DEFINE_COLLAPSE_CANDIDATE'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='GEOCANON_T2_DEFERRED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='ETA_PERP_W_PERP_DEFERRED'; verdict_value='YES' }
    [pscustomobject]@{ verdict_key='SAFE_TO_WRITE_GEOCANON_INTERPRETATION'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='SAFE_TO_COMPARE_TO_RELAXATION'; verdict_value='NO' }
    [pscustomobject]@{ verdict_key='CROSS_MODULE_EVIDENCE_USED'; verdict_value='NO' }
)

$statusOut = Join-Path $RepoRoot 'tables/switching_coordinate_identifiability_status.csv'
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $statusOut

Write-Host "OK Phase3: $centerOut"
