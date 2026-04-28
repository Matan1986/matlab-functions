# Build prioritized canonical validation matrix from deep Switching inventory (no new runs).
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'

$paths = @{
    result_inventory = Join-Path $RepoRoot 'tables/switching_old_analysis_result_inventory.csv'
    artifact_inventory = Join-Path $RepoRoot 'tables/switching_old_analysis_artifact_inventory.csv'
    run_inventory      = Join-Path $RepoRoot 'tables/switching_old_analysis_run_inventory.csv'
}
foreach ($kv in $paths.GetEnumerator()) {
    if (-not (Test-Path $kv.Value)) { throw "Missing inventory file $($kv.Key): $($kv.Value) - run run_switching_old_analysis_deep_inventory.ps1 first" }
}

$results = @(Import-Csv $paths.result_inventory)
$artifacts = @(Import-Csv $paths.artifact_inventory)
$runs = @(Import-Csv $paths.run_inventory)

function Map-TopicToValidationLayer([string]$tag) {
    switch ($tag) {
        'map_level_collapse_master_curve' { return '01_map_level_collapse_master_curve' }
        'collapse_defect_vs_T' { return '01_map_level_collapse_master_curve' }
        'effective_observables_WI_X_gauge' { return '02_effective_observables_I_peak_W_I_S_peak_X' }
        'asymmetry_half_width' { return '03_asymmetry_half_width_LR' }
        'T22_crossover_reorganization' { return '04_T22_crossover_reorganization' }
        'above_transition_regime_tag' { return '05_above_31p5_K_transition_regime' }
        'phi_kappa_residual_modes' { return '06_phi_kappa_residual_sector' }
        'PT_CDF_barrier' { return '07_PT_CDF_barrier_sector' }
        'cross_module_hook_tag' { return '08_cross_module_hooks' }
        'unclassified_topic' { return '09_unclassified_or_inventory_gap' }
        Default { return '09_unclassified_or_inventory_gap' }
    }
}

function Layer-ClassificationAndPriority([string]$layerKey) {
    switch ($layerKey) {
        '01_map_level_collapse_master_curve' {
            @{ class = 'ALREADY_CANONICALLY_REPRODUCED'; priority = 'P0'; rationale = 'Primary-domain W_I replay matches legacy full_scaling_chosen defect; canonical S equals legacy map on overlap per S-equivalence audit.' }
        }
        '02_effective_observables_I_peak_W_I_S_peak_X' {
            @{ class = 'ADOPTABLE_NOW_BY_S_EQUIVALENCE'; priority = 'P0'; rationale = 'Recipes on same S_percent vs I,T; treat X/W_I as gauge - validate metric parity vs old recipe on canonical ladder.' }
        }
        '03_asymmetry_half_width_LR' {
            @{ class = 'NEEDS_NARROW_REPLAY'; priority = 'P1'; rationale = 'Left/right width observables require scripted replay on canonical alignment - not validated in this batch.' }
        }
        '04_T22_crossover_reorganization' {
            @{ class = 'DIAGNOSTIC_ONLY'; priority = 'P2'; rationale = 'Crossover narratives - keep diagnostic; primary collapse excludes above-transition misuse already flagged elsewhere.' }
        }
        '05_above_31p5_K_transition_regime' {
            @{ class = 'DIAGNOSTIC_ONLY'; priority = 'P2'; rationale = '>31.5 K behavior is above primary collapse domain per physics cutoff framing.' }
        }
        '06_phi_kappa_residual_sector' {
            @{ class = 'CLAIM_BOUNDARY_ONLY'; priority = 'P3'; rationale = 'Residual/Phi/kappa sector explicitly out of scope for this validation matrix cycle.' }
        }
        '07_PT_CDF_barrier_sector' {
            @{ class = 'NEEDS_NARROW_REPLAY'; priority = 'P1'; rationale = 'CDF/PT-derived quantities need recipe checks on canonical S_long where applicable.' }
        }
        '08_cross_module_hooks' {
            @{ class = 'DEFER_CROSS_MODULE'; priority = 'P3'; rationale = 'Relaxation/Aging/other modules - defer.' }
        }
        '09_unclassified_or_inventory_gap' {
            @{ class = 'NEEDS_ARTIFACT_RECOVERY'; priority = 'P3'; rationale = 'Heuristic inventory missed topic tag or artifact path ambiguous - review or restore paths.' }
        }
        '10_paper_facing_figures_results' {
            @{ class = 'NEEDS_NARROW_REPLAY'; priority = 'P2'; rationale = 'Figures/table packaging for publications - regenerate from validated recipes when narrative frozen.' }
        }
        Default {
            @{ class = 'UNKNOWN_NEEDS_REVIEW'; priority = 'P3'; rationale = '' }
        }
    }
}

# Augment rows with validation layer
foreach ($row in $results) {
    $layer = Map-TopicToValidationLayer ([string]$row.result_topic_tag)
    Add-Member -InputObject $row -NotePropertyName validation_layer -NotePropertyValue $layer -Force
}

# Paper-facing: artifact rows that look like publication outputs
$paperArtifacts = @($artifacts | Where-Object {
    ($_.artifact_type -eq 'figure') -or ($_.relative_path.ToLowerInvariant() -match '\.(png|pdf|svg|eps)$') -or ($_.filename.ToLowerInvariant() -match '^figure|fig_|supplement')
})

# Group by validation_layer
$groups = @{}
foreach ($row in $results) {
    $vk = [string]$row.validation_layer
    if (-not $groups.ContainsKey($vk)) {
        $groups[$vk] = New-Object System.Collections.ArrayList
    }
    [void]$groups[$vk].Add($row)
}

# Explicit layers with zero tagged inventory rows still appear (no `cross_module_hook_tag` in heuristic topic map).
$syntheticEmptyLayers = @('08_cross_module_hooks')
foreach ($sel in $syntheticEmptyLayers) {
    if (-not $groups.ContainsKey($sel)) {
        $groups[$sel] = New-Object System.Collections.ArrayList
    }
}

$runById = @{}
foreach ($rn in $runs) { $runById[[string]$rn.run_id] = $rn }

$validationMatrix = @()
foreach ($lk in ($groups.Keys | Sort-Object)) {
    $grp = @($groups[$lk])
    $caps = Layer-ClassificationAndPriority $lk
    $uniqRuns = @($grp | Select-Object -ExpandProperty run_id -Unique)
    $pathsSeen = New-Object System.Collections.Generic.HashSet[string]
    $examples = New-Object System.Collections.ArrayList
    foreach ($r in ($grp | Select-Object -First 400)) {
        $p = [string]$r.example_artifact_relative_path
        if (-not $pathsSeen.Contains($p)) {
            [void]$pathsSeen.Add($p)
            [void]$examples.Add($p)
            if ($examples.Count -ge 25) { break }
        }
    }

    $producers = New-Object System.Collections.ArrayList
    foreach ($rid in ($uniqRuns | Select-Object -First 80)) {
        if ($runById.ContainsKey($rid)) {
            [void]$producers.Add([string]$runById[$rid].producer_script_guess)
        }
    }
    $prodHint = ($producers | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
    if (-not $prodHint) { $prodHint = 'see_run_inventory_per_run' }

    $depS = 'YES_CANONICAL_S_EQUIVALENT_ON_LEGACY_COVERAGE'
    $depWI = if ($lk -eq '02_effective_observables_I_peak_W_I_S_peak_X') { 'YES_GAUGE_NOT_X_CANON' } elseif ($lk -match '01|03|07') { 'PARTIAL' } else { 'CASE_BY_CASE' }
    $depPhi = if ($lk -eq '06_phi_kappa_residual_sector') { 'YES_SECTOR_FOR_CLAIM_BOUNDARY' } else { 'NO_THIS_MATRIX_SCOPE' }
    $depLegacy = if (($grp | Where-Object { $_.requires_legacy_only_artifacts -eq 'YES_PATH_IN_OLD_TREE' }).Count -gt 0) { 'PARTIAL_LEGACY_TREE_PATHS' } else { 'LOW' }

    $validationMatrix += [pscustomobject]@{
        validation_layer_key                  = $lk
        validation_layer_title                = ($lk -replace '^.._', '' -replace '_', ' ')
        anchor_classification                 = $caps.class
        priority                              = $caps.priority
        rationale_short                       = $caps.rationale
        n_inventory_rows_in_layer             = $grp.Count
        n_distinct_source_runs                = $uniqRuns.Count
        representative_artifacts_sample       = ($examples -join '; ')
        producer_script_inferable_hint        = $prodHint
        dependency_canonical_S_object         = $depS
        dependency_W_I_X_gauge                = $depWI
        dependency_phi_kappa_residual         = $depPhi
        dependency_legacy_only_artifacts      = $depLegacy
        minimal_next_action                   = ''
    }
}

# Paper-facing synthetic group row (from artifacts, not result topics)
if ($paperArtifacts.Count -gt 0) {
    $pk = '10_paper_facing_figures_results'
    $caps = Layer-ClassificationAndPriority $pk
    $pex = @($paperArtifacts | Select-Object -First 20 | ForEach-Object { $_.relative_path })
    $validationMatrix += [pscustomobject]@{
        validation_layer_key                  = $pk
        validation_layer_title                = 'paper facing figures results'
        anchor_classification                 = $caps.class
        priority                              = $caps.priority
        rationale_short                       = $caps.rationale
        n_inventory_rows_in_layer             = $paperArtifacts.Count
        n_distinct_source_runs                = @($paperArtifacts | Select-Object -ExpandProperty run_id -Unique).Count
        representative_artifacts_sample       = ($pex -join '; ')
        producer_script_inferable_hint        = 'figure pipelines from source runs'
        dependency_canonical_S_object         = 'DERIVED_FROM_VALIDATED_RECIPES'
        dependency_W_I_X_gauge                = 'DERIVED'
        dependency_phi_kappa_residual         = 'NO_THIS_MATRIX_SCOPE'
        dependency_legacy_only_artifacts      = 'PATH_DEPENDENT'
        minimal_next_action                   = ''
    }
}

# Minimal next actions for P0 / P1 only
foreach ($vm in $validationMatrix) {
    if ($vm.priority -eq 'P0') {
        $vm.minimal_next_action = switch ($vm.validation_layer_key) {
            '01_map_level_collapse_master_curve' { 'Spot-check: keep using apples-to-apples primary domain T<31.5K; cite switching_old_collapse_apples_to_apples tables.' }
            '02_effective_observables_I_peak_W_I_S_peak_X' { 'Checklist: compare selected effective-observable CSV columns from legacy effective run vs canonical observables export on same S object (recipe parity).' }
            Default { 'Confirm narrative bindings for P0 layer against canonical run outputs.' }
        }
    }
    elseif ($vm.priority -eq 'P1') {
        $vm.minimal_next_action = switch ($vm.validation_layer_key) {
            '03_asymmetry_half_width_LR' { 'Schedule narrow asymmetry replay on canonical alignment ladder (no full old analysis).' }
            '07_PT_CDF_barrier_sector' { 'Schedule narrow PT/CDF/barrier recipe replay where tables reference CDF_pt columns on canonical S_long.' }
            Default { 'Narrow replay scope definition only - execution deferred.' }
        }
    }
    else {
        $vm.minimal_next_action = 'Deferred - see priority P2/P3.'
    }
}

$validationMatrix | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_validation_matrix.csv')

# Priority groups summary
$prioRows = @()
foreach ($p in @('P0', 'P1', 'P2', 'P3')) {
    $layersAt = @($validationMatrix | Where-Object { $_.priority -eq $p } | ForEach-Object { $_.validation_layer_key })
    $prioRows += [pscustomobject]@{
        priority = $p
        validation_layer_keys_included = ($layersAt -join '; ')
        n_layers = $layersAt.Count
        summary_intent = switch ($p) {
            'P0' { 'Restore main narrative: S-equivalent recipes + collapse primary domain' }
            'P1' { 'Important support: asymmetry, PT/CDF/barrier recipe checks' }
            'P2' { 'Diagnostics and paper-facing regeneration' }
            'P3' { 'Defer cross-module, phi/kappa claim boundary, unclassified gaps' }
        }
    }
}
$prioRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_priority_groups.csv')

# Dependencies wide table (one row per validation layer - detailed)
$validationMatrix | ForEach-Object {
    [pscustomobject]@{
        validation_layer_key             = $_.validation_layer_key
        anchor_classification            = $_.anchor_classification
        priority                         = $_.priority
        depends_canonical_S_equivalence  = $_.dependency_canonical_S_object
        depends_W_I_X_gauge              = $_.dependency_W_I_X_gauge
        depends_phi_kappa_residual       = $_.dependency_phi_kappa_residual
        depends_legacy_artifact_paths    = $_.dependency_legacy_only_artifacts
        inventory_heuristic_disclaimer   = 'Deep inventory is keyword-based; dependencies are planning flags not proof.'
    }
} | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_validation_dependencies.csv')

$p0c = @($validationMatrix | Where-Object { $_.priority -eq 'P0' }).Count
$p1c = @($validationMatrix | Where-Object { $_.priority -eq 'P1' }).Count
$recov = @($validationMatrix | Where-Object { $_.anchor_classification -eq 'NEEDS_ARTIFACT_RECOVERY' }).Count -gt 0
$narrow = @($validationMatrix | Where-Object { $_.anchor_classification -eq 'NEEDS_NARROW_REPLAY' }).Count -gt 0

$status = @(
    [pscustomobject]@{ verdict_key = 'OLD_ANALYSIS_VALIDATION_MATRIX_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'DEEP_INVENTORY_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'CORE_OLD_NARRATIVE_GROUPED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'P0_RESULTS_IDENTIFIED'; verdict_value = if ($p0c -gt 0) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'P1_RESULTS_IDENTIFIED'; verdict_value = if ($p1c -gt 0) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'ARTIFACT_RECOVERY_NEEDS_IDENTIFIED'; verdict_value = if ($recov) { 'YES' } else { 'PARTIAL' } }
    [pscustomobject]@{ verdict_key = 'NARROW_REPLAY_NEEDS_IDENTIFIED'; verdict_value = if ($narrow) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_DEFERRED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'ADOPTION_PLAN_NOT_WRITTEN'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'NO_NEW_ANALYSIS_RUN'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_SYNTHESIS_PERFORMED'; verdict_value = 'NO' }
)

$status | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_validation_matrix_status.csv')

$rp = Join-Path $RepoRoot 'reports/switching_old_analysis_validation_matrix.md'
$lines = @()
$lines += '# Switching old-analysis canonical validation matrix'
$lines += ''
$lines += '## Purpose'
$lines += '- Translate **deep inventory** CSVs into **prioritized validation layers** for Switching only.'
$lines += '- **No new analysis executed** in this step - matrix generation only.'
$lines += '- **Adoption plan** remains **out of scope** - use this file to sequence validation work.'
$lines += ''
$lines += '## Anchors (context, not re-run here)'
$lines += '- Canonical vs legacy **S** equivalent on legacy coverage (`OLD_AND_CANONICAL_S_EQUIVALENT=YES_ON_LEGACY_COVERAGE`).'
$lines += '- **Primary collapse** domain **`T_K < 31.5 K`**, **22 K included**, **32/34 K diagnostic**; defect matches legacy **`full_scaling_chosen`** on apples-to-apples replay.'
$lines += '- **X / W_I** are **gauge / effective-coordinate** - not **`X_canon`** or unique **W**.'
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_old_analysis_validation_matrix.csv`'
$lines += '- `tables/switching_old_analysis_priority_groups.csv`'
$lines += '- `tables/switching_old_analysis_validation_dependencies.csv`'
$lines += '- `tables/switching_old_analysis_validation_matrix_status.csv`'
$lines += ''
$lines += '## Verdict table'
foreach ($s in $status) {
    $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`')
}
$lines | Set-Content -Encoding UTF8 $rp

Write-Host "Validation matrix written: $rp"
