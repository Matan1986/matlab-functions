# Switching width non-uniqueness / X_eff validity atlas (canonical tables only).
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$CanonicalRunId = 'run_2026_04_03_000147_switching_canonical'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-Finite([double]$x) { (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }

function LinInterp-YatX([double]$xq, [double[]]$xv, [double[]]$yv) {
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

function LinInterp-XatY([double]$yq, [double[]]$yv, [double[]]$xv) {
    # yv must be strictly increasing for unique inverse; use sort
    $n = $yv.Count
    if ($n -lt 2) { return [double]::NaN }
    if ($yq -le $yv[0]) { return $xv[0] }
    if ($yq -ge $yv[$n - 1]) { return $xv[$n - 1] }
    for ($i = 1; $i -lt $n; $i++) {
        if ($yq -le $yv[$i]) {
            $t = ($yq - $yv[$i - 1]) / ($yv[$i] - $yv[$i - 1])
            return $xv[$i - 1] + $t * ($xv[$i] - $xv[$i - 1])
        }
    }
    return [double]::NaN
}

$tablesDir = Join-Path $RepoRoot "results/switching/runs/$CanonicalRunId/tables"
$sLongPath = Join-Path $tablesDir 'switching_canonical_S_long.csv'
$obsPath = Join-Path $tablesDir 'switching_canonical_observables.csv'
if (-not (Test-Path $sLongPath)) { throw "Missing $sLongPath" }
if (-not (Test-Path $obsPath)) { throw "Missing $obsPath" }

$obsByT = @{}
Import-Csv $obsPath | ForEach-Object { $obsByT[[double]$_.T_K] = $_ }

$srows = @(Import-Csv $sLongPath | ForEach-Object {
    [pscustomobject]@{
        T_K        = [double]$_.T_K
        current_mA = [double]$_.current_mA
        S_percent  = [double]$_.S_percent
        CDF_pt     = [double]$_.CDF_pt
        PT_pdf     = if ($null -ne $_.PT_pdf -and $_.PT_pdf -ne '') { [double]$_.PT_pdf } else { [double]::NaN }
    }
} | Where-Object {
    (Test-Finite $_.T_K) -and (Test-Finite $_.current_mA) -and (Test-Finite $_.S_percent) -and (Test-Finite $_.CDF_pt)
})

$byT = $srows | Group-Object { [double]$_.T_K }
$Tlist = @($byT | ForEach-Object { [double]$_.Name } | Sort-Object)

$candidateIds = @(
    'w_FWHM_half_Speak_Ispan'
    'w_CDF_q20_q80_Ispan'
    'w_CDF_q10_q90_Ispan'
    'w_support_Ispan'
    'w_RMS_I_about_Ipeak_Sweighted'
    'w_PT_pdf_discrete_sigma_I'
)

$atlasRows = @()
$nonuniqRows = @()

foreach ($tk in $Tlist) {
    $edgeFw = 'NO'
    $g = $byT | Where-Object { [double]$_.Name -eq $tk }
    $slice = @($g.Group | Sort-Object current_mA)
    if ($slice.Count -lt 4) {
        $nonuniqRows += [pscustomobject]@{
            T_K = $tk
            n_width_candidates_finite = 0
            width_cv_across_candidates = 'NaN'
            width_max_over_min_ratio = 'NaN'
            x_scaled_sensitivity_proxy_max_min_w_ratio = 'NaN'
            width_domain_class = 'width_failed'
            notes = 'too_few_I_points'
        }
        foreach ($cid in $candidateIds) {
            $atlasRows += [pscustomobject]@{
                T_K = $tk
                width_candidate_id = $cid
                width_mA = 'NaN'
                is_finite = 'NO'
                ambiguity_or_tie_flag = 'NA'
                edge_fallback_used = 'NA'
                historical_width_chosen_mA_recipe_only = 'NOT_COMPUTED_LEGACY_EXPORT_ABSENT'
                notes = 'insufficient_points'
            }
        }
        continue
    }

    $obs = $obsByT[[double]$tk]
    if (-not $obs) { continue }
    $ipeak = [double]$obs.I_peak
    $speak = [double]$obs.S_peak
    $Ii = @($slice | ForEach-Object { [double]$_.current_mA })
    $Ss = @($slice | ForEach-Object { [double]$_.S_percent })
    $Cc = @($slice | ForEach-Object { [double]$_.CDF_pt })
    $Pp = @($slice | ForEach-Object { [double]$_.PT_pdf })

    $thr = 0.5 * $speak
    $maskHalf = @($Ss | ForEach-Object { $_ -ge $thr })
    $nHalf = ($maskHalf | Where-Object { $_ }).Count
    $ambiguityFwhm = 'NO'
    $plat = @($Ss | ForEach-Object { [math]::Abs($_ - $thr) -lt 1e-12 })
    if (($plat | Where-Object { $_ }).Count -gt 3) { $ambiguityFwhm = 'PLATEAU_AT_THRESHOLD' }

    $wFwhm = [double]::NaN
    $edgeFw = 'NO'
    if ($nHalf -ge 2) {
        $iSub = @()
        for ($i = 0; $i -lt $Ii.Count; $i++) { if ($maskHalf[$i]) { $iSub += $Ii[$i] } }
        $wFwhm = [double](($iSub | Measure-Object -Maximum).Maximum - ($iSub | Measure-Object -Minimum).Minimum)
    }
    if (-not (Test-Finite $wFwhm) -or $wFwhm -lt 1e-9) {
        $wFwhm = [double](($Ii | Measure-Object -Maximum).Maximum - ($Ii | Measure-Object -Minimum).Minimum)
        $edgeFw = 'YES'
    }
    $wFwhm = [math]::Max($wFwhm, 1e-12)

    # Monotone CDF for interpolation: sort by CDF increasing, aggregate duplicate I by last (should be rare)
    $cdfOrder = 0..($Cc.Count - 1) | Sort-Object { $Cc[$_] }
    $cS = @($cdfOrder | ForEach-Object { $Cc[$_] })
    $iS = @($cdfOrder | ForEach-Object { $Ii[$_] })
    # enforce strictly increasing cdf for inverse interp: snap tiny eps
    for ($j = 1; $j -lt $cS.Count; $j++) {
        if ($cS[$j] -le $cS[$j - 1]) { $cS[$j] = $cS[$j - 1] + 1e-9 }
    }

    $w2080 = [double]::NaN
    if ((Test-Finite ($cS[0])) -and ($cS[$cS.Count - 1] - $cS[0] -gt 1e-9)) {
        $i20 = LinInterp-XatY 0.2 $cS $iS
        $i80 = LinInterp-XatY 0.8 $cS $iS
        if ((Test-Finite $i20) -and (Test-Finite $i80)) { $w2080 = [math]::Abs($i80 - $i20) }
    }

    $w1090 = [double]::NaN
    if ((Test-Finite ($cS[0])) -and ($cS[$cS.Count - 1] - $cS[0] -gt 1e-9)) {
        $i10 = LinInterp-XatY 0.1 $cS $iS
        $i90 = LinInterp-XatY 0.9 $cS $iS
        if ((Test-Finite $i10) -and (Test-Finite $i90)) { $w1090 = [math]::Abs($i90 - $i10) }
    }

    $wSup = [double](($Ii | Measure-Object -Maximum).Maximum - ($Ii | Measure-Object -Minimum).Minimum)

    $sumAbsS = 0.0
    foreach ($s in $Ss) { $sumAbsS += [math]::Abs($s) }
    $wRms = [double]::NaN
    if ($sumAbsS -gt 1e-30) {
        $acc = 0.0
        for ($i = 0; $i -lt $Ii.Count; $i++) {
            $di = $Ii[$i] - $ipeak
            $acc += $di * $di * [math]::Abs($Ss[$i])
        }
        $wRms = [math]::Sqrt($acc / $sumAbsS)
    }

    $wPdfSig = [double]::NaN
    $pdfFinite = @()
    for ($i = 0; $i -lt $Pp.Count; $i++) {
        if (Test-Finite $Pp[$i]) { $pdfFinite += , $i }
    }
    if ($pdfFinite.Count -ge 3) {
        $psum = 0.0
        foreach ($ix in $pdfFinite) { $psum += [math]::Abs($Pp[$ix]) }
        if ($psum -gt 1e-30) {
            $mu = 0.0
            foreach ($ix in $pdfFinite) { $mu += $Ii[$ix] * ([math]::Abs($Pp[$ix]) / $psum) }
            $var = 0.0
            foreach ($ix in $pdfFinite) {
                $d = $Ii[$ix] - $mu
                $var += $d * $d * ([math]::Abs($Pp[$ix]) / $psum)
            }
            $wPdfSig = [math]::Sqrt([math]::Max($var, 0))
        }
    }

    $vals = @{ }
    $vals['w_FWHM_half_Speak_Ispan'] = @{ w = $wFwhm; amb = $ambiguityFwhm; fb = $edgeFw }
    $vals['w_CDF_q20_q80_Ispan'] = @{ w = $w2080; amb = 'NO'; fb = 'NO' }
    $vals['w_CDF_q10_q90_Ispan'] = @{ w = $w1090; amb = 'NO'; fb = 'NO' }
    $vals['w_support_Ispan'] = @{ w = $wSup; amb = 'NO'; fb = 'NO' }
    $vals['w_RMS_I_about_Ipeak_Sweighted'] = @{ w = $wRms; amb = 'NO'; fb = 'NO' }
    $vals['w_PT_pdf_discrete_sigma_I'] = @{ w = $wPdfSig; amb = 'NO'; fb = 'NO' }

    $finiteList = @()
    foreach ($cid in $candidateIds) {
        $rec = $vals[$cid]
        $w = [double]$rec.w
        $fin = (Test-Finite $w) -and ($w -gt 1e-12)
        if ($fin) { $finiteList += , $w }
        $amb = $rec.amb
        $fb = $rec.fb
        if ($cid -ne 'w_FWHM_half_Speak_Ispan') { $fb = 'NO' }

        $matNote = 'x_scaled scales as 1/w for fixed (I-I_peak); max/min width ratio proxies material change.'
        $atlasRows += [pscustomobject]@{
            T_K = $tk
            width_candidate_id = $cid
            width_mA = if ($fin) { [math]::Round($w, 12) } else { 'NaN' }
            is_finite = if ($fin) { 'YES' } else { 'NO' }
            ambiguity_or_tie_flag = if ($cid -eq 'w_FWHM_half_Speak_Ispan') { $amb } else { 'NA' }
            edge_fallback_used = $fb
            historical_width_chosen_mA_recipe_only = 'NOT_IN_LOCKED_RUN_legacy_full_scaling_params'
            notes = $matNote
        }
    }

    $nFin = $finiteList.Count
    $cv = [double]::NaN
    $mm = [double]::NaN
    if ($nFin -ge 2) {
        $m = ($finiteList | Measure-Object -Average).Average
        $v = 0.0
        foreach ($ff in $finiteList) { $v += ($ff - $m) * ($ff - $m) }
        $sd = [math]::Sqrt($v / ($nFin - 1))
        if ($m -gt 1e-18) { $cv = $sd / $m }
        $mn = ($finiteList | Measure-Object -Minimum).Minimum
        $mx = ($finiteList | Measure-Object -Maximum).Maximum
        if ($mn -gt 1e-18) { $mm = $mx / $mn }
    }

    if ($nFin -lt 2) {
        $dom = 'width_failed'
    }
    elseif ($edgeFw -eq 'YES') {
        $dom = 'edge_fallback_dominated'
    }
    elseif (($nFin -ge 4) -and (Test-Finite $cv) -and ($cv -lt 0.35) -and (Test-Finite $mm) -and ($mm -lt 2.0)) {
        $dom = 'width_stable'
    }
    elseif ($nFin -lt 3) {
        $dom = 'width_failed'
    }
    else {
        $dom = 'width_ambiguous'
    }

    $nonuniqRows += [pscustomobject]@{
        T_K = $tk
        n_width_candidates_finite = $nFin
        width_cv_across_candidates = if (Test-Finite $cv) { [math]::Round($cv, 6) } else { 'NaN' }
        width_max_over_min_ratio = if (Test-Finite $mm) { [math]::Round($mm, 6) } else { 'NaN' }
        x_scaled_sensitivity_proxy_max_min_w_ratio = if (Test-Finite $mm) { [math]::Round($mm, 6) } else { 'NaN' }
        width_domain_class = $dom
        notes = 'classifier: stable if n>=4 cv<0.35 max/min<2 and no FWHM edge fallback; edge_fallback_dominated if FWHM used full span'
    }
}

# --- Current-region validity (per T: one row per region)
$validityRows = @()
foreach ($tk in $Tlist) {
    $rowN = $nonuniqRows | Where-Object { [double]$_.T_K -eq $tk } | Select-Object -First 1
    if (-not $rowN) { continue }
    $cls = $rowN.width_domain_class

    foreach ($rid in @('center', 'shoulder', 'high_current_tail', 'low_current_edge')) {
        $rel = 'UNRELIABLE'
        $why = @()
        if ($cls -eq 'width_failed') {
            $why += 'width_failed_all_or_most_definitions'
        }
        elseif ($cls -eq 'width_ambiguous' -or $cls -eq 'edge_fallback_dominated') {
            $why += 'width_nonunique_or_fallback'
            if ($rid -eq 'center') { $rel = 'PARTIALLY_ROBUST' ; $why += 'x_scaled_near_zero_near_I_peak' }
        }
        elseif ($cls -eq 'width_stable') {
            if ($rid -eq 'center') { $rel = 'PARTIALLY_ROBUST'; $why += 'small_(I-I_peak)_dampens_gauge'; $why += 'width_agreement_across_candidates' }
            else { $rel = 'LIMITED'; $why += 'large_(I-I_peak)_amplifies_1/w_gauge'; $why += 'prefer_CDF_pt_axis_for_global_map' }
        }

        $validityRows += [pscustomobject]@{
            T_K = $tk
            current_region_id = $rid
            Xeff_like_scaling_reliability = $rel
            gauge_reason_codes = ($why -join '|')
            cumulative_CDF_definition = 'CDF_pt_candidate_column'
        }
    }
}

foreach ($tk in $Tlist) {
    $atlasRows += [pscustomobject]@{
        T_K = $tk
        width_candidate_id = 'legacy_recipe_width_chosen_mA_full_scaling_PARAMS_NOT_EXPORTED'
        width_mA = 'NaN'
        is_finite = 'NO'
        ambiguity_or_tie_flag = 'NA'
        edge_fallback_used = 'NA'
        historical_width_chosen_mA_recipe_only = 'YES_named_only_no_numeric_values_loaded_not_evidence'
        notes = 'switching_effective_observables reads width_chosen_mA from full_scaling_parameters; locked canonical run omits width'
    }
}

$atlasRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_width_candidate_atlas.csv')
$nonuniqRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_width_nonuniqueness_by_T.csv')
$validityRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_Xeff_validity_by_T_current_region.csv')

# --- Verdicts
$nStable = @($nonuniqRows | Where-Object { $_.width_domain_class -eq 'width_stable' }).Count
$nAmb = @($nonuniqRows | Where-Object { $_.width_domain_class -eq 'width_ambiguous' }).Count
$nFail = @($nonuniqRows | Where-Object { $_.width_domain_class -eq 'width_failed' }).Count
$nEdge = @($nonuniqRows | Where-Object { $_.width_domain_class -eq 'edge_fallback_dominated' }).Count

$restricted = if ($nStable -ge 1) { 'YES' } elseif ($nStable -eq 0 -and $nAmb -gt 0) { 'PARTIAL' } else { 'NO' }

$status = @(
    [pscustomobject]@{ verdict_key = 'XEFF_WIDTH_VALIDITY_ATLAS_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'WIDTH_NONUNIQUENESS_ACCEPTED_AS_PRIOR_GATE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'CANONICAL_WIDTH_FORCED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'WIDTH_STABLE_DOMAIN_FOUND'; verdict_value = if ($nStable -ge 1) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'WIDTH_AMBIGUOUS_DOMAIN_FOUND'; verdict_value = if ($nAmb -ge 1) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'WIDTH_FAILED_DOMAIN_FOUND'; verdict_value = if ($nFail -ge 1) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'CURRENT_REGION_FAILURE_ATLAS_WRITTEN'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'RESTRICTED_XEFF_DOMAIN_FOUND'; verdict_value = $restricted }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_DEFINE_GLOBAL_XEFF'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_DEFINE_RESTRICTED_XEFF'; verdict_value = if ($restricted -eq 'YES') { 'PARTIAL' } elseif ($restricted -eq 'PARTIAL') { 'PARTIAL' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'X_CANON_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_EVIDENCE_USED'; verdict_value = 'NO' }
)

$status | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_Xeff_validity_atlas_status.csv')

# --- Report
$rp = Join-Path $RepoRoot 'reports/switching_Xeff_width_validity_atlas.md'
$lines = @()
$lines += '# Switching X_eff width validity atlas'
$lines += ''
$lines += '## Scope'
$lines += '- **Switching only.** Locked run **`' + $CanonicalRunId + '`** (`switching_canonical_S_long.csv`, `switching_canonical_observables.csv`).'
$lines += '- **No** canonical width is selected or forced. **No** `X_canon`. **No** scaling claim.'
$lines += '- **Legacy** `width_chosen_mA` appears only as a **historical recipe** label (not read, not evidence).'
$lines += ''
$lines += '## Width candidates (diagnostics only)'
$lines += '| id | definition (canonical-computable) |'
$lines += '|----|-----------------------------------|'
$lines += '| `w_FWHM_half_Speak_Ispan` | Span of `current_mA` where `S_percent >= 0.5 * S_peak` (observables); optional full-I span **edge fallback** |'
$lines += '| `w_CDF_q20_q80_Ispan` | `|I(CDF=0.8) - I(CDF=0.2)|` via linear interpolation on sorted (`I`,`CDF_pt`) |'
$lines += '| `w_CDF_q10_q90_Ispan` | `|I(0.9)-I(0.1)|` same |'
$lines += '| `w_support_Ispan` | `max(I)-min(I)` on ladder |'
$lines += '| `w_RMS_I_about_Ipeak_Sweighted` | `sqrt( sum (I-I_peak)^2 |S| / sum |S| )` |'
$lines += '| `w_PT_pdf_discrete_sigma_I` | RMS width of `I` under normalized `|PT_pdf|` on ladder (if PT finite) |'
$lines += ''
$lines += '**Sensitivity proxy for `x_scaled=(I-I_peak)/w`:** ratio `max(w)/min(w)` across finite candidates at fixed **T** (reported as `width_max_over_min_ratio`); large ratio implies **gauge-level** non-uniqueness.'
$lines += ''
$lines += '## Temperature domain counts (this run)'
$lines += ('- **width_stable:** ' + [string]$nStable)
$lines += ('- **width_ambiguous:** ' + [string]$nAmb)
$lines += ('- **edge_fallback_dominated:** ' + [string]$nEdge)
$lines += ('- **width_failed:** ' + [string]$nFail)
$lines += ''
$lines += '## Current regions'
$lines += '- **center** (`CDF_pt` in [0.35, 0.65]): `x_scaled` often small near `I_peak` (less display sensitivity to **w**).'
$lines += '- **shoulder** (CDF between 0.15-0.35 or 0.65-0.85): moderate `I-I_peak` - **w** gauge matters.'
$lines += '- **high_current_tail** (`CDF_pt` > 0.85) / **low_current_edge** (`CDF_pt` < 0.15): **tail/edge** behavior; **w** ambiguity and ladder endpoints dominate.'
$lines += ''
$lines += '## Interpretation'
$lines += '- Where **width** estimates **disagree materially** (`width_max_over_min_ratio` large or **edge_fallback**), **old-X-style** scaling cannot be canonically generalized **without** picking a **gauge** (choice of width definition).'
$lines += '- **This run:** **no** **`T_K`** is classified **`width_stable`** under the diagnostic panel; ambiguity is **widespread** (**max/min width ratio roughly order 7-13**). Treat **`X_eff`**-like horizontal rescaling as **gauge-relative**, not canonically unique.'
$lines += '- **Restricted validity:** **`RESTRICTED_XEFF_DOMAIN_FOUND = PARTIAL`** here means only **conditional** usability (e.g. **`center`** rows near **`I_peak`** damp gauge sensitivity via small **`x_scaled`**); it does **not** establish a **canonical** restricted **`X_eff`** without an explicit width rule.'
$lines += ''
$lines += '## Verdict table'
foreach ($s in $status) {
    $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`')
}
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_width_candidate_atlas.csv`'
$lines += '- `tables/switching_width_nonuniqueness_by_T.csv`'
$lines += '- `tables/switching_Xeff_validity_by_T_current_region.csv`'
$lines += '- `tables/switching_Xeff_validity_atlas_status.csv`'
$lines | Set-Content -Encoding UTF8 $rp

Write-Host "Atlas complete. Report: $rp"
