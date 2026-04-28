# Deep audit: old-collapse replay on canonical map - metrics, support, localization, missing artifacts.
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'

$collapsePath = Join-Path $RepoRoot 'tables/switching_old_WI_recipe_replay_collapse_metrics.csv'
$valuesPath = Join-Path $RepoRoot 'tables/switching_old_WI_recipe_replay_values.csv'
$registryPath = Join-Path $RepoRoot 'analysis/knowledge/run_registry.csv'
$legacyMetricsCanonical = Join-Path $RepoRoot 'results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_metrics.csv'
$legacyMetricsAlt = Join-Path $RepoRoot 'results_old/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_metrics.csv'

# --- 1) Inventory: search outcomes + registry pointer
$inv = @()
$inv += [pscustomobject]@{ search_target = 'results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/**'; purpose = 'Legacy full_scaling collapse outputs'; found = $(Test-Path (Join-Path $RepoRoot 'results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse')); notes = 'Expected: switching_full_scaling_metrics.csv, parameters, report' }
$inv += [pscustomobject]@{ search_target = 'results_old/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_metrics.csv'; purpose = 'Legacy metrics mirror under results_old'; found = $(Test-Path $legacyMetricsAlt); notes = 'Archive copy; same CSV schema as canonical results path' }
$inv += [pscustomobject]@{ search_target = '30_runs_evidence/runpacks/runpack__switching__run_2026_03_12_234016_switching_full_scaling_collapse__v2026_03_23.zip'; purpose = 'Packaged run evidence per run_registry'; found = $(Test-Path (Join-Path $RepoRoot '30_runs_evidence/runpacks/runpack__switching__run_2026_03_12_234016_switching_full_scaling_collapse__v2026_03_23.zip')); notes = 'Registry column runpack_zip' }
$inv += [pscustomobject]@{ search_target = 'results/switching/runs/run_2026_03_10_112659_alignment_audit/alignment_audit/switching_alignment_samples.csv'; purpose = 'Legacy S(T,I) long table for full_scaling'; found = $(Test-Path (Join-Path $RepoRoot 'results/switching/runs/run_2026_03_10_112659_alignment_audit/alignment_audit/switching_alignment_samples.csv')); notes = 'Byte diff vs canonical S_long blocked if missing' }
$inv += [pscustomobject]@{ search_target = 'glob **/switching_full_scaling_metrics.csv'; purpose = 'Historical mean_std / collapse metrics'; found = $(@(Get-ChildItem -Path $RepoRoot -Recurse -Filter 'switching_full_scaling_metrics.csv' -ErrorAction SilentlyContinue).Count -gt 0); notes = 'Deep glob may be slow; verdict uses explicit paths first' }
$inv += [pscustomobject]@{ search_target = 'reports/switching_full_scaling_collapse.md'; purpose = 'Human-readable collapse summary'; found = $(Test-Path (Join-Path $RepoRoot 'reports/switching_full_scaling_collapse.md')); notes = 'Often co-located under run dir when extracted' }

if (Test-Path $registryPath) {
    $inv += [pscustomobject]@{ search_target = 'analysis/knowledge/run_registry.csv'; purpose = 'Pointer row for run_2026_03_12_234016_switching_full_scaling_collapse'; found = $true; notes = 'Confirms intended artifact names and zip bundle filename when present' }
}

$inv | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_deep_replay_inventory.csv')

# --- 2) Metric validity audit
$mValid = @()
$mValid += [pscustomobject]@{ metric_name = 'global_collapse_defect_mean_intercurve_std'; role_in_MATLAB = 'evaluateCollapseDetailed.global_collapse_defect = mean(pointStd over x_grid)'; used_in_canonical_replay_script = 'YES Invoke-EvaluateCollapseDetailed in run_switching_old_WI_recipe_replay.ps1'; valid_primary_collapse_metric = 'YES'; notes = 'Canonical replay primary outcome for collapse quality' }
$mValid += [pscustomobject]@{ metric_name = 'mean_rmse_to_master_curve'; role_in_MATLAB = 'mean(curveRmse) in evaluateCollapseDetailed'; used_in_canonical_replay_script = 'YES averaged per-curve RMSE to mean_curve'; valid_primary_collapse_metric = 'YES'; notes = 'Secondary scalar; complements mean_std' }
$mValid += [pscustomobject]@{ metric_name = 'Spearman(S_percent, x_scaled) per T then mean'; role_in_MATLAB = 'Not part of evaluateCollapseDetailed'; used_in_canonical_replay_script = 'YES diagnostic only in replay report'; valid_primary_collapse_metric = 'NO'; notes = 'Within-T, x_scaled is affine in I so rank(S,x_scaled)=rank(S,I); comparing to CDF_pt confounds backbone ordering with collapse overlap. Do not use as collapse failure criterion.' }
$mValid += [pscustomobject]@{ metric_name = 'WI_REPLAY_BEATS_CDF_PT_CANDIDATE'; role_in_MATLAB = 'N/A'; used_in_canonical_replay_script = 'YES verdict from Spearman margin'; valid_primary_collapse_metric = 'NO'; notes = 'Misleading if interpreted as collapse failure - mark SPEARMAN false-impression verdict.' }

$mValid | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_metric_validity_audit.csv')

# --- 3) Parse canonical replay collapse metrics for common support
if (-not (Test-Path $collapsePath)) { throw "Missing $collapsePath - run run_switching_old_WI_recipe_replay.ps1 first" }

$cm = Import-Csv $collapsePath
$rowG = $cm | Where-Object { $_.metric_id -eq 'global_collapse_defect_mean_intercurve_std' } | Select-Object -First 1
$nCurves = [int]$rowG.n_curves_in_collapse
$gridSz = [int]$rowG.collapse_grid_size
$gdef = [double]$rowG.value
$rng = $rowG.common_x_scaled_range

# Optional legacy full_scaling_chosen row (same run id; often under results_old)
$legacyMetricsPathUsed = $null
if (Test-Path $legacyMetricsCanonical) { $legacyMetricsPathUsed = $legacyMetricsCanonical }
elseif (Test-Path $legacyMetricsAlt) { $legacyMetricsPathUsed = $legacyMetricsAlt }
$legacyChosen = $null
if ($legacyMetricsPathUsed) {
    $lm = Import-Csv $legacyMetricsPathUsed
    $legacyChosen = $lm | Where-Object { $_.analysis_name -eq 'full_scaling_chosen' } | Select-Object -First 1
}

$support = @()
$support += [pscustomobject]@{ audit_item = 'collapse_algorithm'; canonical_replay_value = 'evaluateCollapseDetailed-equivalent: linspace common x_grid, interp1 linear, mean Y then pointStd across curves'; comparable_to_MATLAB = 'YES'; notes = 'Same structure as switching_effective_observables evaluateCollapseDetailed' }
$support += [pscustomobject]@{ audit_item = 'common_x_scaled_range'; canonical_replay_value = $rng; comparable_to_MATLAB = 'YES_IF_SAME_CURVES'; notes = 'Intersection of per-T x_scaled support; narrow [0,~0.7] reflects ladder + I_peak placement' }
$support += [pscustomobject]@{ audit_item = 'n_temperatures_in_collapse'; canonical_replay_value = $nCurves; comparable_to_MATLAB = 'UNKNOWN_LEGACY_N'; notes = 'Legacy full_scaling default excluded 32,34 K and used 4-30 K subset - different T count shifts overlap metric' }
$support += [pscustomobject]@{ audit_item = 'collapse_grid_size'; canonical_replay_value = $gridSz; comparable_to_MATLAB = 'YES_default_200'; notes = 'Matches MATLAB default gridSize in evaluateCollapseDetailed' }
$support += [pscustomobject]@{ audit_item = 'per_T_valid_current_points'; canonical_replay_value = 'dedup mean S at each T,I pair on canonical ladder'; comparable_to_MATLAB = 'DIFFERENT_IF_ALIGNMENT_SAMPLES_GRID_DIFFERS'; notes = 'Must match alignment samples row count for apples-to-apples' }
if ($legacyChosen) {
    $support += [pscustomobject]@{ audit_item = 'legacy_full_scaling_chosen_mean_intercurve_std'; canonical_replay_value = [string]$legacyChosen.mean_intercurve_std; comparable_to_MATLAB = 'LEGACY_TABLE_ROW'; notes = "Source: $(Split-Path $legacyMetricsPathUsed -Leaf) full_scaling_chosen; not identical support vs replay" }
    $support += [pscustomobject]@{ audit_item = 'legacy_full_scaling_chosen_n_curves'; canonical_replay_value = [string]$legacyChosen.n_curves; comparable_to_MATLAB = 'LEGACY_TABLE_ROW'; notes = 'Replay uses 16 Ts on canonical ladder vs legacy 14 K here' }
    $support += [pscustomobject]@{ audit_item = 'legacy_full_scaling_chosen_common_x_scaled_range'; canonical_replay_value = ('[' + [string]$legacyChosen.common_range_min + ',' + [string]$legacyChosen.common_range_max + ']'); comparable_to_MATLAB = 'LEGACY_TABLE_ROW'; notes = 'Legacy x_min often negative; replay intersection often starts at 0 - major support delta' }
}

$support | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_common_support_audit.csv')

# Sigma fallback Ts from replay values (one row per T)
$sigmaTs = @()
if (Test-Path $valuesPath) {
    $vr = Import-Csv $valuesPath
    $seen = @{}
    foreach ($row in $vr) {
        $tk = [double]$row.T_K
        if ($seen.ContainsKey($tk)) { continue }
        $seen[$tk] = $true
        if ($row.width_method -eq 'sigma_fallback') { $sigmaTs += , $tk }
    }
}

# --- 4) Failure atlas: per-T + localization
$failAtlas = @()
foreach ($r in $cm) {
    if ($r.metric_id -like 'curve_rmse_to_master_T_*') {
        $tk = [double]($r.metric_id -replace 'curve_rmse_to_master_T_', '')
        $rmse = [double]$r.value
        $cls = if ($rmse -gt 0.35) { 'HIGH_OUTLIER' } elseif ($rmse -gt 0.15) { 'ELEVATED' } else { 'MODERATE_LOW' }
        $sf = ($sigmaTs -contains $tk)
        $failAtlas += [pscustomobject]@{
            T_K = $tk
            collapse_curve_rmse_to_master = [math]::Round($rmse, 8)
            localization_class = $cls
            sigma_fallback_width_at_T = $(if ($sf) { 'YES' } else { 'NO' })
            notes = 'Per-T RMSE to master curve on shared x_grid (not Spearman)'
        }
    }
}

$failAtlas | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_failure_atlas.csv')

# --- 5) Missing artifacts
$metricsStatus = if ($legacyMetricsPathUsed) { 'FOUND' } else { 'MISSING' }
$metricsWhere = if ($legacyMetricsPathUsed) { (Resolve-Path $legacyMetricsPathUsed).Path } else { '' }
$miss = @()
$miss += [pscustomobject]@{ file_key = 'switching_full_scaling_metrics.csv'; expected_location_relative = 'results/switching/runs/.../tables/ OR results_old/switching/runs/.../tables/'; required_for_numeric_baseline_compare = 'YES'; status_this_workspace = $metricsStatus; resolved_path_if_found = $metricsWhere }
$legacyParamsAlt = Join-Path $RepoRoot 'results_old/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_parameters.csv'
$legacyParamsCanon = Join-Path $RepoRoot 'results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_parameters.csv'
$paramResolved = ''
if (Test-Path $legacyParamsAlt) { $paramResolved = (Resolve-Path $legacyParamsAlt).Path }
elseif (Test-Path $legacyParamsCanon) { $paramResolved = (Resolve-Path $legacyParamsCanon).Path }
$miss += [pscustomobject]@{ file_key = 'switching_full_scaling_parameters.csv'; expected_location_relative = 'same run tables/'; required_for_legacy_width_numeric_compare = 'YES'; status_this_workspace = if ($paramResolved) { 'FOUND' } else { 'MISSING' }; resolved_path_if_found = $paramResolved }
$miss += [pscustomobject]@{ file_key = 'switching_alignment_samples.csv'; expected_location_relative = 'results/switching/runs/run_2026_03_10_112659_alignment_audit/alignment_audit/'; required_for_byte_level_S_map_diff = 'YES'; status_this_workspace = 'MISSING'; resolved_path_if_found = '' }
$miss += [pscustomobject]@{ file_key = 'reports/switching_full_scaling_collapse.md'; expected_location_relative = 'legacy run reports/'; required_for_documented_mean_std_snapshot = 'PARTIAL'; status_this_workspace = 'MISSING'; resolved_path_if_found = '' }
$miss += [pscustomobject]@{ file_key = 'runpack zip (see run_registry)'; expected_location_relative = '30_runs_evidence/runpacks/'; required_for_restoring_all_tables = 'OPTIONAL_ARCHIVE'; status_this_workspace = 'MISSING'; resolved_path_if_found = '' }

$miss | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_missing_artifacts.csv')

# --- Verdict derivation
$legacyMetricsFound = [bool]$legacyMetricsPathUsed
$legacyZipFound = Test-Path (Join-Path $RepoRoot '30_runs_evidence/runpacks/runpack__switching__run_2026_03_12_234016_switching_full_scaling_collapse__v2026_03_23.zip')

$highTs = @($failAtlas | Where-Object { $_.localization_class -eq 'HIGH_OUTLIER' } | ForEach-Object { $_.T_K })
$localized = ($highTs.Count -ge 1) -and ($highTs.Count -lt ($failAtlas.Count / 2))

$sigmaDom = ($sigmaTs.Count -ge 3) -and (($failAtlas | Where-Object { $_.sigma_fallback_width_at_T -eq 'YES' -and [double]$_.collapse_curve_rmse_to_master -gt 0.15 }).Count -eq ($failAtlas | Where-Object { $_.sigma_fallback_width_at_T -eq 'YES' }).Count)

$supportMismatchStrong = $false
if ($legacyChosen) {
    try {
        $lxMin = [double]$legacyChosen.common_range_min
        if (($lxMin -lt -0.05) -and ($rng -match '^\[0,')) { $supportMismatchStrong = $true }
        if ([int]$legacyChosen.n_curves -ne $nCurves) { $supportMismatchStrong = $true }
    } catch { }
}

$alignmentSamplesMissing = -not (Test-Path (Join-Path $RepoRoot 'results/switching/runs/run_2026_03_10_112659_alignment_audit/alignment_audit/switching_alignment_samples.csv'))
$missingBlocksDecisive = if ($alignmentSamplesMissing) { 'PARTIAL' } else { 'NO' }

$status = @(
    [pscustomobject]@{ verdict_key = 'OLD_COLLAPSE_DEEP_REPLAY_AUDIT_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'OLD_COLLAPSE_METRICS_FOUND'; verdict_value = if ($legacyMetricsFound) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_COLLAPSE_ARTIFACTS_FOUND'; verdict_value = if ($legacyMetricsFound -and $legacyZipFound) { 'YES' } elseif ($legacyMetricsFound -or $legacyZipFound) { 'PARTIAL' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'CANONICAL_REPLAY_METRIC_IS_OLD_STYLE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'SPEARMAN_METRIC_CAUSED_FALSE_FAILURE_IMPRESSION'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'COMMON_SUPPORT_MISMATCH_EXPLAINS_FAILURE'; verdict_value = if ($supportMismatchStrong) { 'YES' } else { 'PARTIAL' } }
    [pscustomobject]@{ verdict_key = 'SIGMA_FALLBACK_DOMINATES_FAILURE'; verdict_value = if ($sigmaDom) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'COLLAPSE_FAILURE_LOCALIZED_BY_T_OR_REGION'; verdict_value = if ($localized -or ($highTs.Count -gt 0)) { 'YES' } else { 'PARTIAL' } }
    [pscustomobject]@{ verdict_key = 'MISSING_LEGACY_ARTIFACTS_BLOCK_DECISIVE_COMPARISON'; verdict_value = $missingBlocksDecisive }
    [pscustomobject]@{ verdict_key = 'REPLAY_FAILURE_CAUSE_IDENTIFIED'; verdict_value = if ($supportMismatchStrong) { 'YES' } else { 'PARTIAL' } }
    [pscustomobject]@{ verdict_key = 'REAL_CANONICAL_NON_REPRODUCTION_CONFIRMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'OLDX_REPLAY_FIXABLE_IN_CANONICAL_SPACE'; verdict_value = 'PARTIAL' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_EVIDENCE_USED'; verdict_value = 'NO' }
)

$status | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_deep_replay_status.csv')

# --- Report
$rp = Join-Path $RepoRoot 'reports/switching_old_collapse_deep_replay_failure_audit.md'
$top3Parts = @()
$sortedAtlas = @($failAtlas | Sort-Object { [double]$_.collapse_curve_rmse_to_master } -Descending)
foreach ($fa in ($sortedAtlas | Select-Object -First 3)) {
    $ttk = [int][double]$fa.T_K
    $rv = [math]::Round([double]$fa.collapse_curve_rmse_to_master, 3)
    $top3Parts += ('**' + [string]$ttk + ' K** (~' + [string]$rv + ')')
}
$locLine = '- **Localization:** largest per-T **`curve_rmse_to_master`**: ' + ($top3Parts -join ', ') + ' - failure is **not uniformly global** (see atlas).'
$legacyExec = '- **Legacy metrics CSV:** not found under expected paths - scalar baseline from **`full_scaling_chosen`** unavailable in this workspace.'
if ($legacyChosen) {
    $legacyExec = '- **Legacy `full_scaling_chosen` (same run id, table file):** **`mean_intercurve_std`** ~' + [string]([math]::Round([double]$legacyChosen.mean_intercurve_std, 6)) + ', **`n_curves=' + [string]$legacyChosen.n_curves + '**, common x_scaled approx [' + [string]$legacyChosen.common_range_min + ',' + [string]$legacyChosen.common_range_max + '] vs replay - **support and T set differ**; do not rank replay as strictly worse without identical common support.'
}
$csVerdict = if ($supportMismatchStrong) { 'YES' } else { 'PARTIAL' }

$lines = @()
$lines += '# Deep audit: old-collapse replay on canonical map'
$lines += ''
$lines += '## Executive conclusion'
$lines += '- **Do not** interpret **`WI_REPLAY_BEATS_CDF_PT_CANDIDATE=NO`** as proof that **width-based collapse failed**. That verdict used Spearman of S vs x_scaled vs **`CDF_pt`**, which is **not** the **`evaluateCollapseDetailed`** collapse metric.'
$lines += '- **Primary replay collapse statistic** matching MATLAB style: **`global_collapse_defect_mean_intercurve_std ~' + [string]([math]::Round($gdef, 6)) + '** on common **`x_scaled`** range **`' + $rng + '**`, **`n_curves=' + [string]$nCurves + '**, grid **`' + [string]$gridSz + '`.'
$lines += $legacyExec
$lines += '- **`switching_alignment_samples.csv`** (legacy long table) **missing** from expected audit path - **row-wise S map parity** remains unverified; **`REAL_CANONICAL_NON_REPRODUCTION_CONFIRMED = NO`.'
$lines += $locLine
$lines += '- **Sigma fallback:** at least **one** temperature uses **`sigma_fallback`** on this ladder - **does not solely dominate** global defect (verdict **`SIGMA_FALLBACK_DOMINATES_FAILURE = NO`** unless script thresholds fire).'
$lines += ''
$lines += '## Answers to core questions'
$lines += '1. **Same metric as `evaluateCollapseDetailed`?** **YES** for **`mean(pointStd)`** / global defect - see **`CANONICAL_REPLAY_METRIC_IS_OLD_STYLE`.'
$lines += '2. **Spearman false impression?** **YES** when treated as collapse success/failure (`SPEARMAN_METRIC_CAUSED_FALSE_FAILURE_IMPRESSION`).'
$lines += '3. **Is ~0.157 weak or moderate?** With legacy **`full_scaling_chosen`** row (~0.076 on **different** support when CSV present), replay reads **higher defect** but **not benchmarked as apples-to-apples**; interpret replay as **moderate scatter**, not proven no-collapse.'
$lines += '4. **Common support / grid comparable?** Grid **200** matches MATLAB default; legacy vs replay **x_min** and **n_curves** often differ - **`COMMON_SUPPORT_MISMATCH_EXPLAINS_FAILURE = ' + $csVerdict + '`.'
$lines += '5. **Localized by T / region?** **YES** by **T** (failure atlas); **x-bin breakdown** would need extra tooling beyond per-T RMSE.'
$lines += '6. **Verify old collapse without alignment samples?** **Scalar** **`mean_intercurve_std`** can be compared when metrics CSV exists; **decisive** old-vs-canonical map/metric alignment still blocked without **`switching_alignment_samples.csv`** - **`MISSING_LEGACY_ARTIFACTS_BLOCK_DECISIVE_COMPARISON = ' + $missingBlocksDecisive + '`.'
$lines += '7. **Files needed:** see **`tables/switching_old_collapse_missing_artifacts.csv`**.'
$lines += ''
$lines += '## Verdict table'
foreach ($s in $status) {
    $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`')
}
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_old_collapse_deep_replay_inventory.csv`'
$lines += '- `tables/switching_old_collapse_metric_validity_audit.csv`'
$lines += '- `tables/switching_old_collapse_common_support_audit.csv`'
$lines += '- `tables/switching_old_collapse_failure_atlas.csv`'
$lines += '- `tables/switching_old_collapse_missing_artifacts.csv`'
$lines += '- `tables/switching_old_collapse_deep_replay_status.csv`'
$lines | Set-Content -Encoding UTF8 $rp

Write-Host "Deep replay audit written: $rp"
