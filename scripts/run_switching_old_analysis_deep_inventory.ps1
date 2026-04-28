# Deep inventory: old Switching analysis runs, artifacts, and result-topic survey (no adoption plan).
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Parse-RunMeta([string]$runId) {
    $dateStr = ''
    $label = $runId
    if ($runId -match '^run_(\d{4}_\d{2}_\d{2}_\d{6})_(.+)$') {
        $ds = $Matches[1] -replace '_', '-'
        # 2026-03-12-234016 -> approximate ISO date part only
        $dateStr = ($Matches[1] -replace '^(\d{4})_(\d{2})_(\d{2})_', '$1-$2-$3 ')
        $label = $Matches[2]
    }
    [pscustomobject]@{ run_label_suffix = $label; date_prefix_from_id = $dateStr.Trim() }
}

function Guess-ProducerScript([string]$label, [string]$registryAnalysis) {
    if ($registryAnalysis -and $registryAnalysis.Trim()) { return $registryAnalysis.Trim() }
    $l = $label.ToLowerInvariant()
    $map = @{
        'switching_full_scaling_collapse'              = 'switching_full_scaling_collapse.m'
        'switching_effective_observables'              = 'switching_effective_observables.m'
        'switching_alignment_audit'                    = 'switching_alignment_audit.m'
        'switching_canonical'                          = 'run_switching_canonical.m / switching_canonical pipeline'
        'alignment_audit'                              = 'switching_alignment_audit.m'
        'switching_energy_scale_collapse_filtered'     = 'switching_energy_scale_collapse_filtered.m'
        'switching_ridge'                              = 'switching_ridge_susceptibility_analysis.m / switching_ridge_curvature_analysis.m'
        'switching_phi'                                = 'run_switching_phi1_deep_audit.m / phi scripts'
        'switching_physics_output_robustness'          = 'physics robustness bundle'
        'switching_barrier'                            = 'switching_barrier_distribution_from_map.m'
    }
    foreach ($k in $map.Keys) {
        if ($l -like "*$k*") { return $map[$k] }
    }
    if ($l -match 'phi|kappa|residual|decomposition') { return 'Switching/analysis phi-kappa-residual runners (see artifact names)' }
    if ($l -match 'collapse') { return 'collapse-related Switching/analysis scripts' }
    'UNKNOWN_REVIEW_SWITCHING_ANALYSIS_FOLDER'
}

function Classify-ResultTopic([string]$fullLower) {
    $topics = @()
    if ($fullLower -match 'collapse|master_curve|scaling_collapse') { $topics += 'map_level_collapse_master_curve' }
    if ($fullLower -match 'defect_vs_t|collapse_defect|collapse_metrics|per_temperature_collapse') { $topics += 'collapse_defect_vs_T' }
    if ($fullLower -match 'effective_observables|i_?peak|width_chosen|s_?peak|\bx\b|x_scaled|coordinate') { $topics += 'effective_observables_WI_X_gauge' }
    if ($fullLower -match 'asymmetry|half[-_]?width|left.right|lr_') { $topics += 'asymmetry_half_width' }
    if ($fullLower -match '22|reorganization|crossover') { $topics += 'T22_crossover_reorganization' }
    if ($fullLower -match '31|transition|above.transition|post.transition') { $topics += 'above_transition_regime_tag' }
    if ($fullLower -match 'phi|kappa|residual.mode|svd.mode|mode_geometry') { $topics += 'phi_kappa_residual_modes' }
    if ($fullLower -match 'barrier|cdf|pt_matrix|pt_summary|pt_|pdf') { $topics += 'PT_CDF_barrier' }
    if ($fullLower -match 'relaxation|aging|cross_experiment') { $topics += 'cross_module_hook_tag' }
    if ($topics.Count -eq 0) { $topics += 'unclassified_topic' }
    return ($topics | Select-Object -Unique)
}

function Classify-NarrativeBucket([string]$topicsJoined) {
    $t = $topicsJoined.ToLowerInvariant()
    if ($t -match 'cross_module_hook') { return 'CROSS_MODULE_DEFERRED' }
    if ($t -match 'phi_kappa|residual') { return 'SUPPORTING_OBSERVABLE' }
    if ($t -match 'collapse|master_curve|defect') { return 'CORE_OLD_NARRATIVE' }
    if ($t -match 'effective_observables|asymmetry') { return 'SUPPORTING_OBSERVABLE' }
    if ($t -match 'barrier|pt_cdf') { return 'SUPPORTING_OBSERVABLE' }
    if ($t -match 'above_transition|t22') { return 'DIAGNOSTIC_ONLY' }
    'UNKNOWN_NEEDS_REVIEW'
}

function Flag-DependencyRow([string]$topicsJoined, [string]$pathLower) {
    $depS = if ($topicsJoined -notmatch 'phi_kappa|residual.mode|svd') { 'LIKELY_YES' } else { 'PARTIAL' }
    $gauge = if ($topicsJoined -match 'effective_observables|WI|width|x_scaled|coordinate') { 'LIKELY_YES' } else { 'PARTIAL_OR_NO' }
    $phi = if ($topicsJoined -match 'phi_kappa|residual') { 'YES' } else { 'NO_OR_INDIRECT' }
    $legacy = if ($pathLower -match 'results_old|tables_old') { 'YES_PATH_IN_OLD_TREE' } else { 'NO' }
    $canon = if ($topicsJoined -match 'collapse|effective|asymmetry|barrier|cdf' -and $phi -eq 'NO_OR_INDIRECT') { 'LIKELY_YES_ON_S_OR_DERIVED' } elseif ($phi -eq 'YES') { 'NEEDS_PHI_KAPPA_LAYER' } else { 'REVIEW' }
    [pscustomobject]@{
        depends_only_on_S_map             = $depS
        uses_W_I_or_X_gauge             = $gauge
        uses_residual_phi_kappa           = $phi
        requires_legacy_only_artifacts    = $legacy
        canonical_S_equivalence_likely    = $canon
    }
}

$registryPath = Join-Path $RepoRoot 'analysis/knowledge/run_registry.csv'
$regRows = @()
if (Test-Path $registryPath) {
    $regRows = @(Import-Csv $registryPath | Where-Object { $_.experiment -eq 'switching' })
}
$regById = @{}
foreach ($r in $regRows) { if (-not $regById.ContainsKey($r.run_id)) { $regById[$r.run_id] = $r } }

$runRoots = @(
    @{ name = 'results_old_switching'; path = Join-Path $RepoRoot 'results_old/switching/runs' }
    @{ name = 'results_switching'; path = Join-Path $RepoRoot 'results/switching/runs' }
)

$runInventory = @()
$artifactRows = @()
$resultRows = @()
$depRows = @()

foreach ($rr in $runRoots) {
    if (-not (Test-Path $rr.path)) { continue }
    foreach ($dir in @(Get-ChildItem -LiteralPath $rr.path -Directory -ErrorAction SilentlyContinue)) {
        $runId = $dir.Name
        $meta = Parse-RunMeta $runId
        $reg = $regById[$runId]
        $tblReg = if ($reg) { $reg.tables_csv } else { '' }
        $repReg = if ($reg) { $reg.reports_md } else { '' }
        $analysisIds = if ($reg) { $reg.snapshot_analysis_ids } else { '' }

        $tblFiles = @()
        $repFiles = @()
        $figFiles = @()
        $tp = Join-Path $dir.FullName 'tables'
        $rp = Join-Path $dir.FullName 'reports'
        $fp = Join-Path $dir.FullName 'figures'
        if (Test-Path $tp) { $tblFiles = @(Get-ChildItem -LiteralPath $tp -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
        if (Test-Path $rp) { $repFiles = @(Get-ChildItem -LiteralPath $rp -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
        if (Test-Path $fp) { $figFiles = @(Get-ChildItem -LiteralPath $fp -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }

        $tblJoin = ($tblFiles | ForEach-Object { $_.Replace($dir.FullName + '\', '').Replace($dir.FullName + '/', '') }) -join ';'
        $repJoin = ($repFiles | ForEach-Object { $_.Replace($dir.FullName + '\', '').Replace($dir.FullName + '/', '') }) -join ';'
        $figJoin = ($figFiles | ForEach-Object { $_.Replace($dir.FullName + '\', '').Replace($dir.FullName + '/', '') }) -join ';'
        if (-not $tblJoin -and $tblReg) { $tblJoin = [string]$tblReg }
        if (-not $repJoin -and $repReg) { $repJoin = [string]$repReg }

        $producer = Guess-ProducerScript $meta.run_label_suffix $analysisIds

        $runRelPath = ''
        try {
            $runRelPath = $dir.FullName.Replace($RepoRoot, '').TrimStart([char]92)
        } catch {
            $runRelPath = [string]$dir.FullName
        }

        $runInventory += [pscustomobject]@{
            run_id                      = $runId
            inventory_source_root     = $rr.name
            run_folder_relative       = $runRelPath
            date_prefix_from_run_id   = $meta.date_prefix_from_id
            run_label_suffix          = $meta.run_label_suffix
            producer_script_guess     = $producer
            run_registry_snapshot_row = if ($reg) { 'YES' } else { 'NO' }
            registry_tables_csv_field   = $tblReg
            registry_reports_md_field   = $repReg
            filesystem_tables_glob      = ($tblFiles.Count.ToString() + ' files')
            filesystem_reports_glob     = ($repFiles.Count.ToString() + ' files')
            filesystem_figures_glob     = ($figFiles.Count.ToString() + ' files')
            key_tables_preview          = if ($tblJoin.Length -gt 1800) { $tblJoin.Substring(0, 1800) + '...' } else { $tblJoin }
            key_reports_preview         = if ($repJoin.Length -gt 1800) { $repJoin.Substring(0, 1800) + '...' } else { $repJoin }
            key_figures_preview         = if ($figJoin.Length -gt 1200) { $figJoin.Substring(0, 1200) + '...' } else { $figJoin }
        }

        foreach ($f in ($tblFiles + $repFiles + $figFiles)) {
            $rel = $f.Replace($RepoRoot + '\', '').Replace($RepoRoot + '/', '')
            $ext = [System.IO.Path]::GetExtension($f).ToLowerInvariant()
            $atype = switch ($ext) { '.csv' { 'table' } '.md' { 'report' } '.png' { 'figure' } '.pdf' { 'figure' } '.json' { 'manifest' } '.txt' { 'log' } default { 'other' } }
            $artifactRows += [pscustomobject]@{
                run_id            = $runId
                inventory_root    = $rr.name
                artifact_type     = $atype
                relative_path     = $rel
                filename          = [System.IO.Path]::GetFileName($f)
            }

            $low = $rel.ToLowerInvariant()
            foreach ($topic in (Classify-ResultTopic $low)) {
                $tj = $topic
                $bucket = Classify-NarrativeBucket $tj
                $fd = Flag-DependencyRow $tj $low
                $resultRows += [pscustomobject]@{
                    run_id                              = $runId
                    result_topic_tag                    = $topic
                    narrative_classification            = $bucket
                    example_artifact_relative_path      = $rel
                    inferred_input_data_object          = 'switching maps / alignment samples / parameters (see run manifest if present)'
                    depends_only_on_S_map               = $fd.depends_only_on_S_map
                    uses_W_I_or_X_gauge                 = $fd.uses_W_I_or_X_gauge
                    uses_residual_phi_kappa             = $fd.uses_residual_phi_kappa
                    requires_legacy_only_artifacts      = $fd.requires_legacy_only_artifacts
                    canonical_S_equivalence_likely      = $fd.canonical_S_equivalence_likely
                }
            }
            $dff = Flag-DependencyRow ((Classify-ResultTopic $low) -join ';') $low
            $depRows += [pscustomobject]@{
                run_id                          = $runId
                artifact_relative_path          = $rel
                depends_only_on_S_map           = $dff.depends_only_on_S_map
                uses_W_I_or_X_gauge             = $dff.uses_W_I_or_X_gauge
                uses_residual_phi_kappa         = $dff.uses_residual_phi_kappa
                requires_legacy_only_artifacts  = $dff.requires_legacy_only_artifacts
                canonical_S_equivalence_likely  = $dff.canonical_S_equivalence_likely
            }
        }
    }
}

$knownIds = @($runInventory | ForEach-Object { $_.run_id }) | Sort-Object -Unique
foreach ($r in $regRows) {
    if ($knownIds -contains $r.run_id) { continue }
    $meta = Parse-RunMeta $r.run_id
    $producer = Guess-ProducerScript $meta.run_label_suffix $r.snapshot_analysis_ids
    $runInventory += [pscustomobject]@{
        run_id                      = $r.run_id
        inventory_source_root       = 'registry_only_no_matching_run_folder'
        run_folder_relative       = [string]$r.run_rel_path
        date_prefix_from_run_id     = $meta.date_prefix_from_id
        run_label_suffix            = $meta.run_label_suffix
        producer_script_guess       = $producer
        run_registry_snapshot_row = 'YES'
        registry_tables_csv_field   = $r.tables_csv
        registry_reports_md_field   = $r.reports_md
        filesystem_tables_glob      = 'N_A'
        filesystem_reports_glob     = 'N_A'
        filesystem_figures_glob     = 'N_A'
        key_tables_preview          = [string]$r.tables_csv
        key_reports_preview         = [string]$r.reports_md
        key_figures_preview         = ''
    }
}

# Loose switching reports under reports/
$repSwitch = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'reports') -Filter 'switching*' -File -ErrorAction SilentlyContinue)
foreach ($f in $repSwitch) {
    $rel = $f.FullName.Replace($RepoRoot, '').TrimStart('\')
    $artifactRows += [pscustomobject]@{ run_id = 'LOOSE_REPORTS_ROOT'; inventory_root = 'reports'; artifact_type = 'report'; relative_path = $rel; filename = $f.Name }
}

# tables_old switching-like
$toPath = Join-Path $RepoRoot 'tables_old'
if (Test-Path $toPath) {
    foreach ($f in @(Get-ChildItem -LiteralPath $toPath -Filter '*switching*' -File -ErrorAction SilentlyContinue)) {
        $rel = $f.FullName.Replace($RepoRoot, '').TrimStart('\')
        $artifactRows += [pscustomobject]@{ run_id = 'TABLES_OLD_ROOT'; inventory_root = 'tables_old'; artifact_type = 'table'; relative_path = $rel; filename = $f.Name }
    }
}

$analysisRoot = Join-Path $RepoRoot 'analysis'
if (Test-Path $analysisRoot) {
    foreach ($f in @(Get-ChildItem -LiteralPath $analysisRoot -Recurse -Filter '*.m' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'switching' })) {
        $rel = $f.FullName.Replace($RepoRoot, '').TrimStart('\')
        $artifactRows += [pscustomobject]@{ run_id = 'ANALYSIS_ROOT_SCRIPTS'; inventory_root = 'analysis'; artifact_type = 'matlab_script'; relative_path = $rel; filename = $f.Name }
    }
}

$snapDir = Join-Path $RepoRoot 'snapshot_scientific_v3'
if (Test-Path $snapDir) {
    foreach ($f in @(Get-ChildItem -LiteralPath $snapDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'switching' })) {
        $rel = $f.FullName.Replace($RepoRoot, '').TrimStart('\')
        $artifactRows += [pscustomobject]@{ run_id = 'SNAPSHOT_SCIENTIFIC_V3'; inventory_root = 'snapshot_scientific_v3'; artifact_type = 'snapshot_artifact'; relative_path = $rel; filename = $f.Name }
    }
}

# Switching/analysis producer catalog (filenames only)
$sanDir = Join-Path $RepoRoot 'Switching/analysis'
if (Test-Path $sanDir) {
    foreach ($mf in @(Get-ChildItem -LiteralPath $sanDir -Filter '*.m' -File -ErrorAction SilentlyContinue)) {
        $artifactRows += [pscustomobject]@{ run_id = 'SWITCHING_ANALYSIS_SCRIPTS'; inventory_root = 'Switching/analysis'; artifact_type = 'matlab_script'; relative_path = $mf.FullName.Replace($RepoRoot, '').TrimStart('\'); filename = $mf.Name }
    }
}

# Deduplicate resultRows by run_id + topic + path (keep first)
$seenR = @{}
$resultCompact = @()
foreach ($rrr in $resultRows) {
    $k = $rrr.run_id + '|' + $rrr.result_topic_tag + '|' + $rrr.example_artifact_relative_path
    if ($seenR.ContainsKey($k)) { continue }
    $seenR[$k] = $true
    $resultCompact += $rrr
}

$runInventory | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_run_inventory.csv')
$artifactRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_artifact_inventory.csv')
$resultCompact | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_result_inventory.csv')
$depRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_dependency_map.csv')

$nRuns = $runInventory.Count
$nArt = $artifactRows.Count
$nRes = $resultCompact.Count
$coreHits = (@($resultCompact | Where-Object { $_.narrative_classification -eq 'CORE_OLD_NARRATIVE' })).Count
$phiHits = @($artifactRows | Where-Object { $_.relative_path.ToLowerInvariant() -match 'phi|kappa|residual' }).Count -gt 0
$asyHits = @($artifactRows | Where-Object { $_.relative_path.ToLowerInvariant() -match 'asymmetry' }).Count -gt 0
$t22Hits = @($artifactRows | Where-Object { $_.relative_path.ToLowerInvariant() -match '22|reorganization|crossover' }).Count -gt 0
$ptHits = @($artifactRows | Where-Object { $_.relative_path.ToLowerInvariant() -match 'barrier|cdf|pt_' }).Count -gt 0
$crossHits = @($artifactRows | Where-Object { $_.relative_path.ToLowerInvariant() -match 'relaxation|aging|cross_experiment' }).Count -gt 0

$status = @(
    [pscustomobject]@{ verdict_key = 'OLD_SWITCHING_ANALYSIS_DEEP_INVENTORY_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'OLD_RUNS_INVENTORIED'; verdict_value = if ($nRuns -gt 0) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_RESULTS_INVENTORIED'; verdict_value = if ($nRes -gt 0) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'CORE_OLD_NARRATIVE_IDENTIFIED'; verdict_value = if ($coreHits -gt 0) { 'YES' } else { 'PARTIAL' } }
    [pscustomobject]@{ verdict_key = 'PHI_KAPPA_RESULTS_FOUND'; verdict_value = if ($phiHits) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'ASYMMETRY_RESULTS_FOUND'; verdict_value = if ($asyHits) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'T22_REORGANIZATION_RESULTS_FOUND'; verdict_value = if ($t22Hits) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'PT_CDF_BARRIER_RESULTS_FOUND'; verdict_value = if ($ptHits) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_HOOKS_FOUND'; verdict_value = if ($crossHits) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'CANONICAL_VALIDATION_NOT_PERFORMED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'ADOPTION_PLAN_NOT_WRITTEN'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'READY_FOR_CANONICAL_VALIDATION_PLANNING'; verdict_value = if ($nRuns -gt 0) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_SYNTHESIS_PERFORMED'; verdict_value = 'NO' }
)

$status | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_survey_status.csv')

$rp = Join-Path $RepoRoot 'reports/switching_old_analysis_deep_inventory.md'
$lines = @()
$lines += '# Deep inventory: old Switching analysis (survey only)'
$lines += ''
$lines += '## Summary'
$lines += ('- **Run folders scanned:** **' + [string]$nRuns + '** (`results_old/switching/runs`, `results/switching/runs`).')
$lines += ('- **Artifact rows (files + script catalog entries):** **' + [string]$nArt + '**.')
$lines += ('- **Result-topic rows (keyword/heuristic):** **' + [string]$nRes + '** (see `tables/switching_old_analysis_result_inventory.csv`).')
$lines += '- **No adoption plan** in this deliverable - inventory and classification tags only.'
$lines += ''
$lines += '## Search roots'
$lines += '- `results_old/switching/runs`, `results/switching/runs`'
$lines += '- `reports/switching*` loose markdown'
$lines += '- `tables_old/*switching*`'
$lines += '- `Switching/analysis/*.m` (producer filenames)'
$lines += '- `analysis/knowledge/run_registry.csv` rows with **experiment=switching** merged into run inventory when **run_id** matches.'
$lines += ''
$lines += '## Caveats'
$lines += '- **Producer script** column is **heuristic** when registry analysis id is empty.'
$lines += '- **Result topics** derive from **path/filename keywords**, not full text mining of reports.'
$lines += '- **Dependency / canonical coverage** columns are **screening flags**, not validated physics.'
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_old_analysis_run_inventory.csv`'
$lines += '- `tables/switching_old_analysis_artifact_inventory.csv`'
$lines += '- `tables/switching_old_analysis_result_inventory.csv`'
$lines += '- `tables/switching_old_analysis_dependency_map.csv`'
$lines += '- `tables/switching_old_analysis_survey_status.csv`'
$lines += ''
$lines += '## Verdict table'
foreach ($s in $status) {
    $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`')
}
$lines | Set-Content -Encoding UTF8 $rp

Write-Host "Deep inventory written: $rp (runs=$nRuns artifacts=$nArt)"
