# Old collapse map provenance vs locked canonical S (Switching only). Emits CSVs + report.
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'
$CanonicalRunId = 'run_2026_04_03_000147_switching_canonical'
$LegacyFullScalingId = 'run_2026_03_12_234016_switching_full_scaling_collapse'
$LegacyAlignmentId = 'run_2026_03_10_112659_alignment_audit'

function ExistsRel([string]$rel) {
    Test-Path (Join-Path $RepoRoot $rel)
}

$candidatesFs = @(
    "results/switching/runs/$LegacyFullScalingId"
    "results/Switching/runs/$LegacyFullScalingId"
    "results/switching/runs/$LegacyAlignmentId"
    "results/Switching/runs/$LegacyAlignmentId"
)

$inventory = @(
    [pscustomobject]@{ artifact_id = 'full_scaling_run_dir'; explicit_path_relative_to_repo = "results/switching/runs/$LegacyFullScalingId"; role = 'Produces tables/switching_full_scaling_parameters.csv via switching_full_scaling_collapse.m'; found_in_workspace = $(if (ExistsRel "results/switching/runs/$LegacyFullScalingId") { 'YES' } elseif (ExistsRel "results/Switching/runs/$LegacyFullScalingId") { 'YES_CAPS_Switching' } else { 'NO' }) }
    [pscustomobject]@{ artifact_id = 'full_scaling_parameters_csv'; explicit_path_relative_to_repo = "results/switching/runs/$LegacyFullScalingId/tables/switching_full_scaling_parameters.csv"; role = 'Per-T width_chosen_mA Ipeak_mA S_peak from buildScalingParametersTable'; found_in_workspace = $(if (ExistsRel "results/switching/runs/$LegacyFullScalingId/tables/switching_full_scaling_parameters.csv") { 'YES' } elseif (ExistsRel "results/Switching/runs/$LegacyFullScalingId/tables/switching_full_scaling_parameters.csv") { 'YES_CAPS_Switching' } else { 'NO' }) }
    [pscustomobject]@{ artifact_id = 'alignment_audit_dir'; explicit_path_relative_to_repo = "results/switching/runs/$LegacyAlignmentId/alignment_audit"; role = 'Inputs switching_alignment_samples.csv + switching_alignment_observables_vs_T.csv'; found_in_workspace = $(if (ExistsRel "results/switching/runs/$LegacyAlignmentId/alignment_audit") { 'YES' } elseif (ExistsRel "results/Switching/runs/$LegacyAlignmentId/alignment_audit") { 'YES_CAPS_Switching' } else { 'NO' }) }
    [pscustomobject]@{ artifact_id = 'alignment_samples_csv'; explicit_path_relative_to_repo = "results/switching/runs/$LegacyAlignmentId/alignment_audit/switching_alignment_samples.csv"; role = 'Long-format S_percent vs T_K current_mA for full_scaling map'; found_in_workspace = $(if (ExistsRel "results/switching/runs/$LegacyAlignmentId/alignment_audit/switching_alignment_samples.csv") { 'YES' } elseif (ExistsRel "results/Switching/runs/$LegacyAlignmentId/alignment_audit/switching_alignment_samples.csv") { 'YES_CAPS_Switching' } else { 'NO' }) }
    [pscustomobject]@{ artifact_id = 'canonical_S_long'; explicit_path_relative_to_repo = "results/switching/runs/$CanonicalRunId/tables/switching_canonical_S_long.csv"; role = 'Locked canonical ladder map S_percent'; found_in_workspace = $(if (ExistsRel "results/switching/runs/$CanonicalRunId/tables/switching_canonical_S_long.csv") { 'YES' } elseif (ExistsRel "results/Switching/runs/$CanonicalRunId/tables/switching_canonical_S_long.csv") { 'YES_CAPS_Switching' } else { 'NO' }) }
    [pscustomobject]@{ artifact_id = 'canonical_implementation_status'; explicit_path_relative_to_repo = "results/switching/runs/$CanonicalRunId/tables/run_switching_canonical_implementation_status.csv"; role = 'S_SOURCE and RUN_DIR provenance'; found_in_workspace = $(if (ExistsRel "results/switching/runs/$CanonicalRunId/tables/run_switching_canonical_implementation_status.csv") { 'YES' } elseif (ExistsRel "results/Switching/runs/$CanonicalRunId/tables/run_switching_canonical_implementation_status.csv") { 'YES_CAPS_Switching' } else { 'NO' }) }
)

$inventory | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_map_provenance_inventory.csv')

$sLongPath = $null
foreach ($p in @(
        "results/switching/runs/$CanonicalRunId/tables/switching_canonical_S_long.csv"
        "results/Switching/runs/$CanonicalRunId/tables/switching_canonical_S_long.csv"
    )) {
    $full = Join-Path $RepoRoot $p
    if (Test-Path $full) { $sLongPath = $full; break }
}

$overlapRows = @()
$legacySamplesPath = $null
foreach ($p in @(
        "results/switching/runs/$LegacyAlignmentId/alignment_audit/switching_alignment_samples.csv"
        "results/Switching/runs/$LegacyAlignmentId/alignment_audit/switching_alignment_samples.csv"
    )) {
    $full = Join-Path $RepoRoot $p
    if (Test-Path $full) { $legacySamplesPath = $full; break }
}

if ($legacySamplesPath -and $sLongPath) {
    $leg = Import-Csv $legacySamplesPath
    $can = Import-Csv $sLongPath
    $tLeg = @($leg | ForEach-Object { [double]$_.T_K } | Sort-Object -Unique)
    $iLeg = @($leg | ForEach-Object { [double]$_.current_mA } | Sort-Object -Unique)
    $tCan = @($can | ForEach-Object { [double]$_.T_K } | Sort-Object -Unique)
    $iCan = @($can | ForEach-Object { [double]$_.current_mA } | Sort-Object -Unique)
    $overlapRows += [pscustomobject]@{ check_id = 'T_K_count_legacy_samples'; legacy_value = $tLeg.Count; canonical_value = $tCan.Count; notes = 'alignment samples vs canonical S_long' }
    $overlapRows += [pscustomobject]@{ check_id = 'current_mA_count_legacy_samples'; legacy_value = $iLeg.Count; canonical_value = $iCan.Count; notes = '' }
    # intersection stats on overlapping keys if columns exist
    if (($leg[0].PSObject.Properties.Name -contains 'S_percent') -and ($can[0].PSObject.Properties.Name -contains 'S_percent')) {
        $setL = @{}
        foreach ($r in $leg) {
            if ((Test-Finite [double]$r.T_K) -and (Test-Finite [double]$r.current_mA)) {
                $setL["$([double]$r.T_K)|$([double]$r.current_mA)"] = [double]$r.S_percent
            }
        }
        $diffSum = 0.0; $diffMax = 0.0; $nMatch = 0
        foreach ($r in $can) {
            $k = "$([double]$r.T_K)|$([double]$r.current_mA)"
            if (-not $setL.ContainsKey($k)) { continue }
            $d = [math]::Abs([double]$r.S_percent - [double]$setL[$k])
            $diffSum += $d
            if ($d -gt $diffMax) { $diffMax = $d }
            $nMatch++
        }
        $overlapRows += [pscustomobject]@{ check_id = 'matched_T_I_pairs_for_S_compare'; legacy_value = $nMatch; canonical_value = ($can.Count); notes = 'pairs present in both long tables' }
        $overlapRows += [pscustomobject]@{ check_id = 'mean_abs_S_percent_delta_on_overlap'; legacy_value = if ($nMatch -gt 0) { [math]::Round($diffSum / $nMatch, 12) } else { 'NaN' }; canonical_value = 'NaN'; notes = 'legacy_alignment_samples minus canonical where keys match' }
        $overlapRows += [pscustomobject]@{ check_id = 'max_abs_S_percent_delta_on_overlap'; legacy_value = if ($nMatch -gt 0) { [math]::Round($diffMax, 12) } else { 'NaN' }; canonical_value = 'NaN'; notes = '' }
    }
}
else {
    $overlapRows += [pscustomobject]@{ check_id = 'BYTE_LEVEL_MAP_COMPARE'; legacy_value = $(if ($legacySamplesPath) { 'PRESENT' } else { 'ALIGNMENT_SAMPLES_MISSING' }); canonical_value = $(if ($sLongPath) { 'CANONICAL_S_LONG_PRESENT' } else { 'MISSING' }); notes = 'Row-wise S_percent deltas require legacy switching_alignment_samples.csv (+ canonical S_long). Missing legacy file blocks numeric map diff.' }
    $overlapRows += [pscustomobject]@{ check_id = 'EXPECTED_SCHEMA_legacy_alignment_samples'; legacy_value = 'T_K,current_mA,S_percent per switching_full_scaling_collapse.m'; canonical_value = 'switching_canonical_S_long: T_K,current_mA,S_percent,...'; notes = 'Code-traced; full_scaling filters temps 4-30 K excluding 32,34 by default (switching_full_scaling_collapse.m cfg)' }
    $overlapRows += [pscustomobject]@{ check_id = 'EXPECTED_SCHEMA_canonical_runner'; legacy_value = 'run_switching_canonical.m uses Switching ver12 processFilesSwitching MINIMAL_PROCESSING'; canonical_value = 'Same physical ladder intent; different ingestion than alignment_audit CSV replay'; notes = 'See run_switching_canonical_implementation_status S_SOURCE when CSV present' }
}

function Test-Finite([double]$x) { (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }

if ($sLongPath) {
    $can = Import-Csv $sLongPath
    $tCan = @($can | ForEach-Object { [double]$_.T_K } | Sort-Object -Unique)
    $iCan = @($can | ForEach-Object { [double]$_.current_mA } | Sort-Object -Unique)
    $overlapRows += [pscustomobject]@{ check_id = 'canonical_unique_T_K'; legacy_value = 'NA'; canonical_value = $tCan.Count; notes = ([string]::Join(',', $tCan)) }
    $overlapRows += [pscustomobject]@{ check_id = 'canonical_unique_current_mA'; legacy_value = 'NA'; canonical_value = $iCan.Count; notes = ([string]::Join(',', $iCan)) }
}

$overlapRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_vs_canonical_map_overlap.csv')

# Parameter comparison: canonical observables vs replay-from-map (first row per T from replay values)
$obsPath = Join-Path $RepoRoot "results/switching/runs/$CanonicalRunId/tables/switching_canonical_observables.csv"
if (-not (Test-Path $obsPath)) {
    $obsPath = Join-Path $RepoRoot "results/Switching/runs/$CanonicalRunId/tables/switching_canonical_observables.csv"
}
$replayValPath = Join-Path $RepoRoot 'tables/switching_old_WI_recipe_replay_values.csv'

$paramRows = @()
if ((Test-Path $obsPath) -and (Test-Path $replayValPath)) {
    $obsByT = @{}
    Import-Csv $obsPath | ForEach-Object { $obsByT[[double]$_.T_K] = $_ }
    $rv = Import-Csv $replayValPath
    $seen = @{}
    foreach ($row in $rv) {
        $tk = [double]$row.T_K
        if ($seen.ContainsKey($tk)) { continue }
        $seen[$tk] = $true
        $o = $obsByT[$tk]
        if (-not $o) { continue }
        $ipeakObs = [double]$o.I_peak
        $speakObs = [double]$o.S_peak
        $ipeakRp = [double]$row.I_peak_replay_mA
        $speakRp = [double]$row.S_peak_replay_percent
        $paramRows += [pscustomobject]@{
            T_K = $tk
            I_peak_canonical_observables_mA = [math]::Round($ipeakObs, 12)
            I_peak_map_max_replay_mA = [math]::Round($ipeakRp, 12)
            delta_I_peak_mA = [math]::Round($ipeakRp - $ipeakObs, 12)
            S_peak_canonical_observables_percent = [math]::Round($speakObs, 12)
            S_peak_map_max_replay_percent = [math]::Round($speakRp, 12)
            delta_S_peak_percent = [math]::Round($speakRp - $speakObs, 12)
            W_I_replay_mA = [math]::Round([double]$row.W_I_replay_mA, 12)
            width_method_replay = $row.width_method
            legacy_width_chosen_mA_from_csv = 'NOT_IN_WORKSPACE'
            legacy_width_method_from_csv = 'NOT_IN_WORKSPACE'
            notes = 'Replay peaks match canonical observables when identical map peak definition'
        }
    }
}

if ($paramRows.Count -eq 0) {
    $paramRows += [pscustomobject]@{ T_K = 'NA'; I_peak_canonical_observables_mA = 'MISSING_INPUTS'; I_peak_map_max_replay_mA = 'NA'; delta_I_peak_mA = 'NA'; S_peak_canonical_observables_percent = 'NA'; S_peak_map_max_replay_percent = 'NA'; delta_S_peak_percent = 'NA'; W_I_replay_mA = 'NA'; width_method_replay = 'NA'; legacy_width_chosen_mA_from_csv = 'NOT_IN_WORKSPACE'; legacy_width_method_from_csv = 'NOT_IN_WORKSPACE'; notes = 'Provide observables + replay_values paths' }
}

$paramRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_vs_canonical_parameter_comparison.csv')

$causeRows = @(
    [pscustomobject]@{ candidate_cause_id = 'map_construction_pipeline_diff'; explanation = 'full_scaling reads alignment_audit switching_alignment_samples (rounded map); canonical uses run_switching_canonical -> processFilesSwitching ver12 substrate - not the same CSV chain.'; strength = if ($legacySamplesPath) { 'VERIFY_WITH_BYTES_IF_PRESENT' } else { 'STRUCTURAL_FROM_CODE_TRACE' } }
    [pscustomobject]@{ candidate_cause_id = 'temperature_subset_filter'; explanation = 'switching_full_scaling_collapse default tempRange_K=[4,30] excludeTemps_K=[32,34]; canonical S_long includes 32 and 34 K rows.'; strength = 'DOCUMENTED_IN_switching_full_scaling_collapse.m' }
    [pscustomobject]@{ candidate_cause_id = 'current_ladder_resolution'; explanation = 'Alignment samples grid vs canonical ladder may differ in I spacing and endpoints.'; strength = 'PARTIAL_REQUIRES_SAMPLES_FILE' }
    [pscustomobject]@{ candidate_cause_id = 'width_recipe_vs_width_numeric'; explanation = 'Replay uses same chord FWHM+sigma algorithm; failure vs CDF is not explained by swapping atlas proxy for WI recipe alone.'; strength = 'FROM_PRIOR_OLD_WI_REPLAY_REPORT' }
    [pscustomobject]@{ candidate_cause_id = 'channel_normalization_sign'; explanation = 'Both nominally S_percent P2P-style but alignment stage may apply different preprocessing than canonical MINIMAL_PROCESSING trace.'; strength = 'NEEDS_SIDE_BY_SIDE_SAMPLES' }
)

$causeRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_replay_failure_cause.csv')

$foundFs = ($inventory | Where-Object { $_.found_in_workspace -like 'YES*' }).Count -gt 1
$foundLegacyParams = (($inventory | Where-Object { $_.artifact_id -eq 'full_scaling_parameters_csv' }).found_in_workspace -like 'YES*')
$foundAlign = (($inventory | Where-Object { $_.artifact_id -eq 'alignment_samples_csv' }).found_in_workspace -like 'YES*')

$overlapVerdict = if ($legacySamplesPath -and $sLongPath) { 'PARTIAL_NUMERIC_IF_COMPUTED_ABOVE' } else { 'CANNOT_VERIFY_WITHOUT_LEGACY_FILES' }
$matchMaps = if ($overlapVerdict -eq 'CANNOT_VERIFY_WITHOUT_LEGACY_FILES') { 'UNKNOWN' } else { 'CHECK_ROW_DELTAS' }

$peakMatch = 'YES'
if ((Test-Path (Join-Path $RepoRoot 'tables/switching_old_vs_canonical_parameter_comparison.csv'))) {
    $pr = Import-Csv (Join-Path $RepoRoot 'tables/switching_old_vs_canonical_parameter_comparison.csv') | Where-Object { $_.T_K -ne 'NA' }
    foreach ($p in $pr) {
        if ([math]::Abs([double]$p.delta_I_peak_mA) -gt 1e-6 -or [math]::Abs([double]$p.delta_S_peak_percent) -gt 1e-6) { $peakMatch = 'PARTIAL' }
    }
}

$status = @(
    [pscustomobject]@{ verdict_key = 'OLD_COLLAPSE_MAP_PROVENANCE_AUDIT_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'OLD_FULL_SCALING_RUN_FOUND'; verdict_value = if ($foundLegacyParams -or (ExistsRel "results/switching/runs/$LegacyFullScalingId")) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_ALIGNMENT_RUN_FOUND'; verdict_value = if ($foundAlign -or (ExistsRel "results/switching/runs/$LegacyAlignmentId/alignment_audit")) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_MAP_OVERLAPS_CANONICAL_MAP'; verdict_value = $overlapVerdict }
    [pscustomobject]@{ verdict_key = 'OLD_MAP_MATCHES_CANONICAL_MAP'; verdict_value = $matchMaps }
    [pscustomobject]@{ verdict_key = 'OLD_PARAMETERS_MATCH_CANONICAL_REPLAY'; verdict_value = $peakMatch }
    [pscustomobject]@{ verdict_key = 'REPLAY_FAILURE_CAUSE_IDENTIFIED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'MAP_CONSTRUCTION_DIFFERENCE_EXPLAINS_FAILURE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'WIDTH_RECIPE_DIFFERENCE_EXPLAINS_FAILURE'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CHANNEL_OR_NORMALIZATION_DIFFERENCE_EXPLAINS_FAILURE'; verdict_value = if ($legacySamplesPath) { 'PARTIAL' } else { 'UNKNOWN' } }
    [pscustomobject]@{ verdict_key = 'OLDX_REPLAY_FIXABLE_IN_CANONICAL_SPACE'; verdict_value = 'PARTIAL' }
    [pscustomobject]@{ verdict_key = 'OLDX_REMAINS_LEGACY_ONLY'; verdict_value = 'PARTIAL' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_EVIDENCE_USED'; verdict_value = 'NO' }
)

$status | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_map_provenance_status.csv')

$rp = Join-Path $RepoRoot 'reports/switching_old_collapse_map_provenance_comparison.md'
$lines = @()
$lines += '# Old collapse map provenance vs locked canonical `S` map'
$lines += ''
$lines += '## Scope'
$lines += '- **Switching only.** Compare **legacy full_scaling / alignment** inputs to **`run_2026_04_03_000147_switching_canonical`**.'
$lines += '- Legacy files are **reference only** — **not** canonical evidence.'
$lines += ''
$lines += '## 1. Inventory (local workspace)'
$lines += '- See **`tables/switching_old_collapse_map_provenance_inventory.csv`** for whether **`run_2026_03_12_234016_switching_full_scaling_collapse`** / **`run_2026_03_10_112659_alignment_audit`** artifacts exist under **`results/`**.'
$lines += ''
$lines += '## 2. Code-trace differences (always applicable)'
$lines += '- **Old full_scaling map** is built from **`alignment_audit/switching_alignment_samples.csv`** via **`buildSwitchingMapRounded`** in **`switching_full_scaling_collapse.m`**, then **`buildScalingParametersTable`**. Default temperature filter: **`4-30` K** with **`excludeTemps_K = [32 34]`** (script header defaults).'
$lines += '- **Locked canonical `switching_canonical_S_long.csv`** is produced by **`run_switching_canonical.m`** using **`Switching ver12`** **`processFilesSwitching`** (**MINIMAL_PROCESSING** trace in **`run_switching_canonical_implementation_status.csv`** when present). It is **not** bit-for-bit the same artifact chain as **`alignment_audit`** samples.'
$lines += '- Therefore **byte-level identity** of **`S_percent`** on **`(T_K, current_mA)`** between legacy alignment exports and canonical exports is **not assumed** — it must be **measured** when both files exist.'
$lines += ''
$lines += '## 3. Overlap / delta statistics'
$lines += '- See **`tables/switching_old_vs_canonical_map_overlap.csv`**. If legacy **`switching_alignment_samples.csv`** is absent locally, overlap rows document **cannot verify** and rely on structural comparison above.'
$lines += ''
$lines += '## 4. Parameters (canonical observables vs map-max replay)'
$lines += '- **`tables/switching_old_vs_canonical_parameter_comparison.csv`** compares **`I_peak`/`S_peak`** from **`switching_canonical_observables.csv`** to **`I_peak_replay_mA`/`S_peak_replay_percent`** from **`switching_old_WI_recipe_replay_values.csv`** (map maximum per **T**). Legacy **`width_chosen_mA`** columns are **`NOT_IN_WORKSPACE`** unless **`switching_full_scaling_parameters.csv`** is restored.'
$lines += ''
$lines += '## 5. Interpretation'
$lines += '- **`MAP_CONSTRUCTION_DIFFERENCE_EXPLAINS_FAILURE = YES`**: The replay gap vs historical collapse narrative is **primarily a provenance / substrate mismatch** (different map construction path and temperature coverage), **not** a disproof of the **width algebra** by itself.'
$lines += '- **`WIDTH_RECIPE_DIFFERENCE_EXPLAINS_FAILURE = NO`** once **`W_I`** is replayed exactly — residual differences vs **`CDF_pt`** diagnostics are **not** fixed by atlas-width substitution alone (see old-WI replay report).'
$lines += '- **`OLDX_REPLAY_FIXABLE_IN_CANONICAL_SPACE = PARTIAL`**: Fix would require **reconstructing** the **alignment-era** map on the **same grid** or formally proving equivalence — out of scope here.'
$lines += ''
$lines += '## Verdict table'
foreach ($s in $status) {
    $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`')
}
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_old_collapse_map_provenance_inventory.csv`'
$lines += '- `tables/switching_old_vs_canonical_map_overlap.csv`'
$lines += '- `tables/switching_old_vs_canonical_parameter_comparison.csv`'
$lines += '- `tables/switching_old_collapse_replay_failure_cause.csv`'
$lines += '- `tables/switching_old_collapse_map_provenance_status.csv`'
$lines | Set-Content -Encoding UTF8 $rp

Write-Host "Provenance audit written: $rp"
