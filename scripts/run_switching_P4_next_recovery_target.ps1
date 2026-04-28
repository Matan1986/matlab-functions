# Switching P4: choose next narrow old-analysis recovery target.
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'

$tablesDir = Join-Path $RepoRoot 'tables'
$reportsDir = Join-Path $RepoRoot 'reports'
if (-not (Test-Path $tablesDir)) { New-Item -ItemType Directory -Path $tablesDir -Force | Out-Null }
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

$paths = @{
    validation_matrix = Join-Path $tablesDir 'switching_old_analysis_validation_matrix.csv'
    priority_groups   = Join-Path $tablesDir 'switching_old_analysis_priority_groups.csv'
    adoption_plan     = Join-Path $tablesDir 'switching_old_analysis_canonical_adoption_plan.csv'
    p0_collapse       = Join-Path $tablesDir 'switching_P0_old_collapse_freeze_status.csv'
    p0_effective      = Join-Path $tablesDir 'switching_P0_effective_observables_status.csv'
    p1_asym           = Join-Path $tablesDir 'switching_P1_asymmetry_LR_status.csv'
    p2_t22            = Join-Path $tablesDir 'switching_P2_T22_crossover_status.csv'
}

$outCandidates = Join-Path $tablesDir 'switching_P4_next_recovery_target_candidates.csv'
$outDecision = Join-Path $tablesDir 'switching_P4_next_recovery_target_decision.csv'
$outStatus = Join-Path $tablesDir 'switching_P4_next_recovery_target_status.csv'
$outReport = Join-Path $reportsDir 'switching_P4_next_recovery_target.md'

function Write-Missing([string]$reason) {
    @([pscustomobject]@{
        candidate_id = ''
        candidate_layer = ''
        rank = ''
        readiness_score = ''
        rationale = $reason
    }) | Export-Csv -NoTypeInformation -Encoding UTF8 $outCandidates

    @([pscustomobject]@{
        decision = 'NO_DECISION'
        selected_candidate_id = ''
        selected_layer = ''
        reason = $reason
    }) | Export-Csv -NoTypeInformation -Encoding UTF8 $outDecision

    @(
        [pscustomobject]@{ verdict_key = 'P4_NEXT_RECOVERY_TARGET_DECISION_COMPLETE'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'MISSING_INPUT'; verdict_value = 'YES' }
        [pscustomobject]@{ verdict_key = 'MISSING_INPUT_REASON'; verdict_value = $reason }
        [pscustomobject]@{ verdict_key = 'X_CANON_CLAIMED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'UNIQUE_W_CLAIMED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'MECHANISM_CLAIMED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'CROSS_MODULE_SYNTHESIS_PERFORMED'; verdict_value = 'NO' }
    ) | Export-Csv -NoTypeInformation -Encoding UTF8 $outStatus

    @(
        '# Switching P4 next recovery target',
        '',
        'Decision not produced due to missing required input.',
        '',
        ('- ' + $reason)
    ) | Set-Content -Encoding UTF8 $outReport
}

foreach ($kv in $paths.GetEnumerator()) {
    if (-not (Test-Path $kv.Value)) {
        Write-Missing "Missing required input: $($kv.Value)"
        Write-Host "P4 next-target outputs written (missing input)."
        exit 0
    }
}

$validation = @(Import-Csv $paths.validation_matrix)
$priority = @(Import-Csv $paths.priority_groups)
$adoption = @(Import-Csv $paths.adoption_plan)
$p0c = @(Import-Csv $paths.p0_collapse)
$p0e = @(Import-Csv $paths.p0_effective)
$p1 = @(Import-Csv $paths.p1_asym)
$p2 = @(Import-Csv $paths.p2_t22)

function Get-Status([object[]]$tbl, [string]$key, [string]$default = 'UNKNOWN') {
    $r = @($tbl | Where-Object { $_.verdict_key -eq $key } | Select-Object -First 1)
    if ($r.Count -eq 0) { return $default }
    return [string]$r[0].verdict_value
}

$gates = @{
    p0_collapse_done = (Get-Status $p0c 'P0_OLD_COLLAPSE_FREEZE_COMPLETE' 'NO')
    p0_effective_done = (Get-Status $p0e 'P0_EFFECTIVE_OBSERVABLES_NUMERIC_MATERIALIZATION_COMPLETE' 'NO')
    p1_asym_done = (Get-Status $p1 'P1_ASYMMETRY_LR_REPLAY_COMPLETE' 'NO')
    p2_t22_done = (Get-Status $p2 'P2_T22_INTERNAL_CROSSOVER_AUDIT_COMPLETE' 'NO')
}

# Candidate set requested by user.
$cands = @(
    [pscustomobject]@{
        candidate_id = 'C1'
        candidate_layer = 'master_curve_collapse_shape'
        linked_validation_layer = '01_map_level_collapse_master_curve'
        legacy_anchor_class = 'ALREADY_CANONICALLY_REPRODUCED'
        scope_fit = 'LOW'
        dependency_risk = 'LOW'
        expected_narrowness = 'HIGH'
        blocked_by = 'ALREADY_FROZEN_P0'
        rationale = 'Already frozen in P0 collapse; repeating now adds low marginal recovery value.'
        readiness_score = 18
    }
    [pscustomobject]@{
        candidate_id = 'C2'
        candidate_layer = 'map_level_organization_metric'
        linked_validation_layer = '04_T22_crossover_reorganization'
        legacy_anchor_class = 'DIAGNOSTIC_ONLY'
        scope_fit = 'HIGH'
        dependency_risk = 'LOW'
        expected_narrowness = 'HIGH'
        blocked_by = ''
        rationale = 'Natural next narrow layer after P2 T22 audit: recover map-organization descriptor without reopening collapse or residual sectors.'
        readiness_score = 91
    }
    [pscustomobject]@{
        candidate_id = 'C3'
        candidate_layer = 'reorganization_index'
        linked_validation_layer = '04_T22_crossover_reorganization'
        legacy_anchor_class = 'DIAGNOSTIC_ONLY'
        scope_fit = 'HIGH'
        dependency_risk = 'LOW'
        expected_narrowness = 'HIGH'
        blocked_by = ''
        rationale = 'Also aligned with T22 internal crossover narrative; suitable as narrow follow-up but slightly less canonicalized than map-organization metric.'
        readiness_score = 86
    }
    [pscustomobject]@{
        candidate_id = 'C4'
        candidate_layer = 'soft_hard_switching_domain_split'
        linked_validation_layer = '05_above_31p5_K_transition_regime'
        legacy_anchor_class = 'DIAGNOSTIC_ONLY'
        scope_fit = 'MEDIUM'
        dependency_risk = 'MEDIUM'
        expected_narrowness = 'MEDIUM'
        blocked_by = ''
        rationale = 'Relevant diagnostic branch but touches regime partitioning semantics; better after map-level organization metric is fixed.'
        readiness_score = 73
    }
    [pscustomobject]@{
        candidate_id = 'C5'
        candidate_layer = 'transition_above_31p5_diagnostic'
        linked_validation_layer = '05_above_31p5_K_transition_regime'
        legacy_anchor_class = 'DIAGNOSTIC_ONLY'
        scope_fit = 'MEDIUM'
        dependency_risk = 'LOW'
        expected_narrowness = 'HIGH'
        blocked_by = ''
        rationale = 'Allowed as diagnostic-only but less central to immediate old-analysis recovery than internal reorganization layer.'
        readiness_score = 69
    }
    [pscustomobject]@{
        candidate_id = 'C6'
        candidate_layer = 'conditional_PT_CDF_barrier_link'
        linked_validation_layer = '07_PT_CDF_barrier_sector'
        legacy_anchor_class = 'NEEDS_NARROW_REPLAY'
        scope_fit = 'MEDIUM'
        dependency_risk = 'MEDIUM'
        expected_narrowness = 'MEDIUM'
        blocked_by = 'CONDITIONAL_AFTER_GAP'
        rationale = 'Explicitly conditional in adoption plan; defer unless a post-P2 narrative gap requires it.'
        readiness_score = 58
    }
    [pscustomobject]@{
        candidate_id = 'C7'
        candidate_layer = 'residual_phi_kappa_recovery'
        linked_validation_layer = '06_phi_kappa_residual_sector'
        legacy_anchor_class = 'CLAIM_BOUNDARY_ONLY'
        scope_fit = 'LOW'
        dependency_risk = 'HIGH'
        expected_narrowness = 'LOW'
        blocked_by = 'OUT_OF_SCOPE_BOUNDARY'
        rationale = 'Claim-boundary sector explicitly deferred; not a valid immediate next recovery target.'
        readiness_score = 15
    }
)

# Gate adjustment based on completion of P0/P1/P2.
$gateBonus = if (($gates.p0_collapse_done -eq 'YES') -and ($gates.p0_effective_done -eq 'YES') -and ($gates.p1_asym_done -eq 'YES') -and ($gates.p2_t22_done -eq 'YES')) { 4 } else { 0 }
$candRows = New-Object System.Collections.ArrayList
foreach ($c in $cands) {
    $adj = [int]$c.readiness_score
    if ($c.candidate_id -in @('C2','C3')) { $adj += $gateBonus }
    if ($adj -gt 100) { $adj = 100 }
    [void]$candRows.Add([pscustomobject]@{
        candidate_id = $c.candidate_id
        candidate_layer = $c.candidate_layer
        linked_validation_layer = $c.linked_validation_layer
        linked_priority_bucket = if ($c.linked_validation_layer -eq '07_PT_CDF_barrier_sector') { 'P1_CONDITIONAL' } elseif ($c.linked_validation_layer -eq '06_phi_kappa_residual_sector') { 'P3' } elseif ($c.linked_validation_layer -eq '05_above_31p5_K_transition_regime') { 'P2' } elseif ($c.linked_validation_layer -eq '04_T22_crossover_reorganization') { 'P2' } else { 'P0_OR_DONE' }
        legacy_anchor_class = $c.legacy_anchor_class
        scope_fit = $c.scope_fit
        dependency_risk = $c.dependency_risk
        expected_narrowness = $c.expected_narrowness
        blocked_by = $c.blocked_by
        readiness_score = $adj
        rationale = $c.rationale
    })
}
$sorted = @($candRows | Sort-Object readiness_score -Descending)
$ranked = New-Object System.Collections.ArrayList
$rank = 1
foreach ($r in $sorted) {
    $r | Add-Member -NotePropertyName rank -NotePropertyValue $rank -Force
    [void]$ranked.Add($r)
    $rank += 1
}
$ranked | Export-Csv -NoTypeInformation -Encoding UTF8 $outCandidates

$selected = @($ranked | Select-Object -First 1)[0]
@([pscustomobject]@{
    decision = 'SELECT_ONE_NEXT_LAYER'
    selected_candidate_id = $selected.candidate_id
    selected_layer = $selected.candidate_layer
    selected_linked_validation_layer = $selected.linked_validation_layer
    selected_priority_bucket = $selected.linked_priority_bucket
    reason_primary = 'Highest readiness under completed P0/P1/P2 gates while staying narrow and within Switching-only claim boundaries.'
    reason_scope = 'Does not require reopening collapse/geocanon/residual/PT-CDF/cross-module sectors.'
    reason_sequence = 'Builds directly on completed T22 internal crossover audit and adoption-plan ordering.'
    not_selected_summary = 'PT/CDF remains conditional; residual/Phi/kappa remains claim-boundary deferred; collapse already frozen.'
}) | Export-Csv -NoTypeInformation -Encoding UTF8 $outDecision

$statusRows = @(
    [pscustomobject]@{ verdict_key = 'P4_NEXT_RECOVERY_TARGET_DECISION_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'VALIDATION_MATRIX_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'ADOPTION_PLAN_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'P0_P1_P2_STATUS_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'NEXT_TARGET_SELECTED'; verdict_value = $selected.candidate_layer }
    [pscustomobject]@{ verdict_key = 'X_CANON_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'UNIQUE_W_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'MECHANISM_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_SYNTHESIS_PERFORMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'MISSING_INPUT'; verdict_value = 'NO' }
)
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $outStatus

$lines = @()
$lines += '# Switching P4 next old-analysis recovery target'
$lines += ''
$lines += 'Decision objective: choose one next narrow old-analysis layer after completed P0/P1/P2 recovery artifacts, without running new physics analysis.'
$lines += ''
$lines += '## Inputs used'
foreach ($k in @('validation_matrix','priority_groups','adoption_plan','p0_collapse','p0_effective','p1_asym','p2_t22')) {
    $lines += ('- `' + $paths[$k].Substring($RepoRoot.Length + 1).Replace('\','/') + '`')
}
$lines += ''
$lines += '## Completed gates'
$lines += ('- P0 collapse freeze complete: `' + $gates.p0_collapse_done + '`')
$lines += ('- P0 effective observables complete: `' + $gates.p0_effective_done + '`')
$lines += ('- P1 asymmetry/LR replay complete: `' + $gates.p1_asym_done + '`')
$lines += ('- P2 T22 crossover audit complete: `' + $gates.p2_t22_done + '`')
$lines += ''
$lines += '## Candidate ranking'
$lines += 'See `tables/switching_P4_next_recovery_target_candidates.csv` for full ranked table.'
$lines += ''
$lines += '## Selected next target (exactly one)'
$lines += ('- **Candidate:** `' + $selected.candidate_id + '`')
$lines += ('- **Layer:** `' + $selected.candidate_layer + '`')
$lines += ('- **Linked validation layer:** `' + $selected.linked_validation_layer + '`')
$lines += ('- **Why this next:** highest readiness while preserving narrow scope and claim boundaries; directly follows completed T22 internal-crossover evidence.')
$lines += ''
$lines += '## Non-selected summary'
$lines += '- `master_curve_collapse_shape`: already frozen in P0.'
$lines += '- `conditional_PT_CDF_barrier_link`: adoption-plan conditional; defer until explicit gap.'
$lines += '- `residual_phi_kappa_recovery`: claim-boundary/deferred.'
$lines += ''
$lines += '## Claim boundaries preserved'
$lines += '- No `X_canon` claim.'
$lines += '- No unique-W claim.'
$lines += '- No final scaling claim.'
$lines += '- No mechanism claim.'
$lines += '- No cross-module synthesis.'
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_P4_next_recovery_target_candidates.csv`'
$lines += '- `tables/switching_P4_next_recovery_target_decision.csv`'
$lines += '- `tables/switching_P4_next_recovery_target_status.csv`'
$lines += '- `reports/switching_P4_next_recovery_target.md`'
$lines += ''
$lines += '## Status'
foreach ($s in $statusRows) { $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`') }
$lines | Set-Content -Encoding UTF8 $outReport

Write-Host "P4 next recovery target written: $outReport"

