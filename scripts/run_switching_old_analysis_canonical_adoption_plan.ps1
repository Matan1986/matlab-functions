# Minimal canonical adoption / execution plan from validation matrix (planning only; no runs).
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'

$matrixPath = Join-Path $RepoRoot 'tables/switching_old_analysis_validation_matrix.csv'
$prioPath   = Join-Path $RepoRoot 'tables/switching_old_analysis_priority_groups.csv'
if (-not (Test-Path $matrixPath)) { throw "Missing $matrixPath" }
if (-not (Test-Path $prioPath)) { throw "Missing $prioPath" }

$matrix = @(Import-Csv $matrixPath)
$prio   = @(Import-Csv $prioPath)

function Get-MatrixRow([string]$key) {
    $matrix | Where-Object { $_.validation_layer_key -eq $key } | Select-Object -First 1
}

# --- canonical_adoption_plan.csv (plan lines derived from matrix + anchors)
$planRows = @()

$planRows += [pscustomobject]@{
    plan_row_id              = 'AP-001'
    source_validation_layer  = '01_map_level_collapse_master_curve'
    priority_ref             = 'P0'
    matrix_classification    = (Get-MatrixRow '01_map_level_collapse_master_curve').anchor_classification
    adoption_posture         = 'FREEZE_AND_CITE_ALREADY_REPRODUCED'
    summary                  = 'Treat primary-domain W_I collapse as frozen narrative: T_K < 31.5 K including 22 K in-domain; cite apples-to-apples audit tables; do not broaden replay.'
    minimal_execution_later    = 'None until narrative change; optional documentation refresh only.'
    S_equivalence_use        = 'Legacy and canonical S agree on overlap; collapse story rests on audited equivalence plus replay parity.'
    W_I_X_gauge_note          = 'W_I is the collapse coordinate in primary domain framing; X/W_I gauge rules do not alter this freeze.'
}

$planRows += [pscustomobject]@{
    plan_row_id              = 'AP-002'
    source_validation_layer  = '02_effective_observables_I_peak_W_I_S_peak_X'
    priority_ref             = 'P0'
    matrix_classification    = (Get-MatrixRow '02_effective_observables_I_peak_W_I_S_peak_X').anchor_classification
    adoption_posture         = 'ADOPT_BY_S_EQUIVALENCE_AND_RECIPE_PARITY'
    summary                  = 'Adopt effective observables (I_peak, W_I, S_peak, X) as recipes on the shared S object; validate column-wise parity legacy vs canonical export.'
    minimal_execution_later    = 'Checklist compare selected CSV columns only; treat X and W_I as gauge/effective-coordinate prescriptions not X_canon.'
    S_equivalence_use        = 'Same S_percent vs I,T ladder; equivalence carries observable definitions where recipes match.'
    W_I_X_gauge_note          = 'Explicitly document gauge for X and W_I; forbid uniqueness or canonical-X claims.'
}

$planRows += [pscustomobject]@{
    plan_row_id              = 'AP-003'
    source_validation_layer  = '03_asymmetry_half_width_LR'
    priority_ref             = 'P1'
    matrix_classification    = (Get-MatrixRow '03_asymmetry_half_width_LR').anchor_classification
    adoption_posture         = 'NARROW_REPLAY_AS_NEEDED'
    summary                  = 'Left/right half-width and asymmetry: narrow scripted replay on canonical alignment only if narrative requires those claims.'
    minimal_execution_later    = 'Single-purpose asymmetry runner matching legacy column definitions; exclude phi-residual coupling unless separately scoped.'
    S_equivalence_use        = 'Uses canonical S_long alignment as specified for width definitions.'
    W_I_X_gauge_note          = 'Widths are geometry on gauge-fixed observables; no new coordinate search.'
}

$planRows += [pscustomobject]@{
    plan_row_id              = 'AP-004'
    source_validation_layer  = '04_T22_crossover_reorganization'
    priority_ref             = 'P2_DIAGNOSTIC'
    matrix_classification    = (Get-MatrixRow '04_T22_crossover_reorganization').anchor_classification
    adoption_posture         = 'AUDIT_ONLY_NO_BROAD_REPLAY'
    summary                  = '22 K remains inside primary domain but is an internal crossover/outlier candidate: audit inventory tables and narrative consistency; no broad old-analysis rerun.'
    minimal_execution_later    = 'Structured read of existing T22-tagged artifacts vs frozen collapse domain; record conclusions in audit note.'
    S_equivalence_use        = 'Interpret using same S object; no new scaling extraction.'
    W_I_X_gauge_note          = 'If asymmetry replay runs, reconcile wording only; no X_canon.'
}

$planRows += [pscustomobject]@{
    plan_row_id              = 'AP-005'
    source_validation_layer  = '07_PT_CDF_barrier_sector'
    priority_ref             = 'P1_CONDITIONAL'
    matrix_classification    = (Get-MatrixRow '07_PT_CDF_barrier_sector').anchor_classification
    adoption_posture         = 'NARROW_REPLAY_ONLY_IF_GAP_AFTER_PRIOR_GATES'
    summary                  = 'PT/CDF/barrier quantities: narrow recipe replay on canonical S_long where tables require CDF_pt-style columns; skip wholesale regeneration.'
    minimal_execution_later    = 'Define minimal column set from one representative legacy table; replay once if narrative still needs barrier language.'
    S_equivalence_use        = 'Depends on extended S_long fields; keep scope to provenance-linked columns.'
    W_I_X_gauge_note          = 'Barrier plots inherit gauge from parent observables.'
}

$planRows += [pscustomobject]@{
    plan_row_id              = 'AP-006'
    source_validation_layer  = '05_above_31p5_K_transition_regime;06_phi_kappa_residual_sector;08_cross_module_hooks;09_unclassified_or_inventory_gap;10_paper_facing_figures_results'
    priority_ref             = 'P2_P3_DEFERRED'
    matrix_classification    = 'DIAGNOSTIC_OR_DEFER_PER_MATRIX'
    adoption_posture         = 'NO_BROAD_CAMPAIGN_HOLD_OR_DEFER'
    summary                  = '>31.5 K diagnostic-only; phi/kappa/residual claim-boundary only; cross-module deferred; unclassified paths need recovery only when blocking P0/P1; paper figures regenerate after narrative freeze.'
    minimal_execution_later    = 'No broad residual/Phi rerun; Aging/Relaxation hooks out of scope; paper-facing P2 after validated recipes.'
    S_equivalence_use        = 'N/A except where a recovered artifact feeds P0/P1.'
    W_I_X_gauge_note          = 'No expansion of coordinate claims.'
}

$planRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_canonical_adoption_plan.csv')

# --- execution_order.csv
$exec = @(
    [pscustomobject]@{
        execution_step        = 1
        step_code             = 'FREEZE_PRIMARY_COLLAPSE'
        step_title            = 'Freeze primary-domain W_I collapse result'
        validation_layer_keys = '01_map_level_collapse_master_curve'
        phase                 = 'P0'
        prerequisite_steps    = ''
        outcome_gate          = 'Frozen narrative cites apples-to-apples primary domain T_K < 31.5 K; 32K/34K labeled diagnostic-only when referenced.'
        anchors_used          = 'S equivalence on legacy coverage; defect match full_scaling_chosen in primary domain.'
    }
    [pscustomobject]@{
        execution_step        = 2
        step_code             = 'VALIDATE_EFFECTIVE_OBSERVABLE_RECIPES'
        step_title            = 'Validate and adopt effective-observable recipes (I_peak, W_I, S_peak, X)'
        validation_layer_keys = '02_effective_observables_I_peak_W_I_S_peak_X'
        phase                 = 'P0'
        prerequisite_steps    = 'FREEZE_PRIMARY_COLLAPSE'
        outcome_gate          = 'Checklist: legacy vs canonical observable columns agree on chosen rows/columns for narrative tables.'
        anchors_used          = 'X/W_I as gauge; no X_canon.'
    }
    [pscustomobject]@{
        execution_step        = 3
        step_code             = 'NARROW_REPLAY_ASYMMETRY_LR'
        step_title            = 'As-needed narrow replay: asymmetry and left-right half-width'
        validation_layer_keys = '03_asymmetry_half_width_LR'
        phase                 = 'P1'
        prerequisite_steps    = 'VALIDATE_EFFECTIVE_OBSERVABLE_RECIPES'
        outcome_gate          = 'Either narrative explicitly drops LR/asymmetry claims, or narrow replay produces canonical-aligned tables matching legacy definitions.'
        anchors_used          = 'Canonical alignment ladder; exclude phi campaigns.'
    }
    [pscustomobject]@{
        execution_step        = 4
        step_code             = 'AUDIT_T22_REORGANIZATION'
        step_title            = 'Audit 22 K reorganization / crossover (inventory and narrative only)'
        validation_layer_keys = '04_T22_crossover_reorganization'
        phase                 = 'P2_AUDIT'
        prerequisite_steps    = 'NARROW_REPLAY_ASYMMETRY_LR'
        outcome_gate          = 'Written audit: 22 K classified as in-domain crossover candidate vs narrative; no broad rerun triggered.'
        anchors_used          = '22 K inside primary domain; consistent with freeze unless explicit exception documented.'
    }
    [pscustomobject]@{
        execution_step        = 5
        step_code             = 'CONDITIONAL_PT_CDF_BARRIER'
        step_title            = 'Only if needed: narrow PT/CDF/barrier recipe replay'
        validation_layer_keys = '07_PT_CDF_barrier_sector'
        phase                 = 'P1_CONDITIONAL'
        prerequisite_steps    = 'AUDIT_T22_REORGANIZATION'
        outcome_gate          = 'PT/CDF claims either dropped, cited from existing validated tables, or covered by one minimal narrow replay scope document.'
        anchors_used          = 'Canonical S_long; gap-driven only.'
    }
    [pscustomobject]@{
        execution_step        = 6
        step_code             = 'DEFER_RESIDUAL_PHI_DECISION'
        step_title            = 'Explicit decision: residual/phi diagnostics (default: no campaign)'
        validation_layer_keys = '06_phi_kappa_residual_sector'
        phase                 = 'P3_HOLD'
        prerequisite_steps    = 'CONDITIONAL_PT_CDF_BARRIER'
        outcome_gate          = 'Documented decision: claim-boundary only; no broad residual/Phi/PCA replay unless separate charter.'
        anchors_used          = 'SAFE_TO_WRITE_SCALING_CLAIM remains NO.'
    }
)

$exec | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_execution_order.csv')

# --- adoption_status.csv (one row per matrix layer)
$statusRows = foreach ($r in $matrix) {
    $adopt = switch ($r.validation_layer_key) {
        '01_map_level_collapse_master_curve' { 'ALREADY_REPRODUCED_FREEZE_PRIMARY_DOMAIN' }
        '02_effective_observables_I_peak_W_I_S_peak_X' { 'ADOPTABLE_VALIDATE_RECIPE_PARITY' }
        '03_asymmetry_half_width_LR' { 'NEEDS_NARROW_REPLAY_MINIMAL' }
        '04_T22_crossover_reorganization' { 'DIAGNOSTIC_AUDIT_22K_PLANNED' }
        '05_above_31p5_K_transition_regime' { 'DIAGNOSTIC_ABOVE_TRANSITION_ONLY' }
        '06_phi_kappa_residual_sector' { 'CLAIM_BOUNDARY_ONLY_NO_CAMPAIGN' }
        '07_PT_CDF_barrier_sector' { 'NEEDS_NARROW_REPLAY_CONDITIONAL' }
        '08_cross_module_hooks' { 'DEFER_CROSS_MODULE' }
        '09_unclassified_or_inventory_gap' { 'NEEDS_ARTIFACT_RECOVERY_AS_BLOCKING_ONLY' }
        '10_paper_facing_figures_results' { 'REGENERATE_AFTER_NARRATIVE_FREEZE' }
        Default { 'REVIEW' }
    }

    $narrow = switch ($r.validation_layer_key) {
        '03_asymmetry_half_width_LR' { 'Replay asymmetry_comparison + width columns on canonical ladder; one runner; no phi link expansion.' }
        '07_PT_CDF_barrier_sector' { 'Only after steps 1-4: minimal CDF_pt / barrier columns on canonical S_long if still required.' }
        Default { '' }
    }

    [pscustomobject]@{
        validation_layer_key       = $r.validation_layer_key
        validation_layer_title     = $r.validation_layer_title
        priority                   = $r.priority
        matrix_anchor_classification = $r.anchor_classification
        canonical_adoption_status  = $adopt
        narrow_replay_minimal_scope = $narrow
        notes                      = $r.rationale_short
    }
}
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_adoption_status.csv')

# --- scope_control.csv: do-not-rerun, stopping criteria, claim boundaries, verdicts
$scope = New-Object System.Collections.ArrayList

[void]$scope.Add([pscustomobject]@{ rule_category = 'DO_NOT_RERUN'; rule_id = 'NR-01'; rule_text = 'Broad replay of full old Switching analysis tree'; value = 'BLOCKED' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'DO_NOT_RERUN'; rule_id = 'NR-02'; rule_text = 'Broad residual / Phi / kappa campaigns (PCA, residual collapse sweeps)'; value = 'BLOCKED' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'DO_NOT_RERUN'; rule_id = 'NR-03'; rule_text = 'Cross-module Relaxation/Aging synthesis or hook reruns'; value = 'BLOCKED' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'DO_NOT_RERUN'; rule_id = 'NR-04'; rule_text = 'Global X_canon or unique-W identification search'; value = 'BLOCKED' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'DO_NOT_RERUN'; rule_id = 'NR-05'; rule_text = 'Above-31.5 K promoted to primary-collapse claims without domain label'; value = 'BLOCKED' })

[void]$scope.Add([pscustomobject]@{ rule_category = 'STOPPING_CRITERION'; rule_id = 'SC-01'; rule_text = 'Stop after P0 gates unless P1 narrative gap documented'; value = 'P0 complete = collapse frozen + effective-observable checklist done' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'STOPPING_CRITERION'; rule_id = 'SC-02'; rule_text = 'Stop P1 asymmetry replay if narrative drops LR claims'; value = 'Explicit waiver recorded' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'STOPPING_CRITERION'; rule_id = 'SC-03'; rule_text = 'Stop before any new domain - T22 audit note complete'; value = 'No further crossover work without new charter' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'STOPPING_CRITERION'; rule_id = 'SC-04'; rule_text = 'Scope creep guard - no new analysis type not in validation matrix layers'; value = 'Charter amendment required' })

[void]$scope.Add([pscustomobject]@{ rule_category = 'CLAIM_BOUNDARY_ALLOWED_NOW'; rule_id = 'CB-01'; rule_text = 'Equivalence of legacy and canonical S on legacy coverage'; value = 'ALLOWED' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'CLAIM_BOUNDARY_ALLOWED_NOW'; rule_id = 'CB-02'; rule_text = 'Primary-domain W_I collapse framing T_K < 31.5 K with cited replay tables'; value = 'ALLOWED' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'CLAIM_BOUNDARY_ALLOWED_NOW'; rule_id = 'CB-03'; rule_text = '22 K as in-domain point; 32K/34K diagnostic-only when labeled'; value = 'ALLOWED' })

[void]$scope.Add([pscustomobject]@{ rule_category = 'CLAIM_BOUNDARY_AFTER_P0_P1'; rule_id = 'CB-04'; rule_text = 'Effective-observable tables after recipe parity checklist'; value = 'ALLOWED_IF_CHECKLIST_PASS' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'CLAIM_BOUNDARY_AFTER_P0_P1'; rule_id = 'CB-05'; rule_text = 'LR/asymmetry statements after narrow replay or explicit waiver'; value = 'ALLOWED_IF_REPLAY_OR_WAIVED' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'CLAIM_BOUNDARY_AFTER_P0_P1'; rule_id = 'CB-06'; rule_text = 'PT/CDF/barrier language tied to executed narrow recipe scope'; value = 'ALLOWED_IF_CONDITIONAL_STEP_DONE' })

[void]$scope.Add([pscustomobject]@{ rule_category = 'CLAIM_BOUNDARY_FORBIDDEN'; rule_id = 'CB-07'; rule_text = 'Universal scaling-law claims or exponent fits without new scaling charter'; value = 'FORBIDDEN' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'CLAIM_BOUNDARY_FORBIDDEN'; rule_id = 'CB-08'; rule_text = 'X_canon or globally unique effective coordinate'; value = 'FORBIDDEN' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'CLAIM_BOUNDARY_FORBIDDEN'; rule_id = 'CB-09'; rule_text = 'Residual/Phi as drivers of primary collapse narrative'; value = 'FORBIDDEN_IN_THIS_PLAN' })

# Verdicts (required)
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-01'; rule_text = 'OLD_ANALYSIS_CANONICAL_ADOPTION_PLAN_COMPLETE'; value = 'YES' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-02'; rule_text = 'VALIDATION_MATRIX_USED'; value = 'YES' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-03'; rule_text = 'P0_EXECUTION_ORDER_DEFINED'; value = 'YES' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-04'; rule_text = 'P1_EXECUTION_ORDER_DEFINED'; value = 'YES' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-05'; rule_text = 'BROAD_OLD_ANALYSIS_RERUN_BLOCKED'; value = 'YES' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-06'; rule_text = 'PHASE5_RESIDUAL_PCA_DEPRIORITIZED'; value = 'YES' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-07'; rule_text = 'X_CANON_SEARCH_BLOCKED'; value = 'YES' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-08'; rule_text = 'T22_REORGANIZATION_AUDIT_PLANNED'; value = 'YES' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-09'; rule_text = 'CLAIM_BOUNDARIES_DEFINED'; value = 'YES' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-10'; rule_text = 'SAFE_TO_WRITE_SCALING_CLAIM'; value = 'NO' })
[void]$scope.Add([pscustomobject]@{ rule_category = 'VERDICT'; rule_id = 'V-11'; rule_text = 'CROSS_MODULE_SYNTHESIS_PERFORMED'; value = 'NO' })

$scope | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_analysis_scope_control.csv')

# --- Markdown report
$prioLines = ($prio | ForEach-Object { "- **$($_.priority)**: $($_.validation_layer_keys_included)" }) -join "`n"
$rp = Join-Path $RepoRoot 'reports/switching_old_analysis_canonical_adoption_plan.md'
$md = @"
# Switching old-analysis canonical adoption and execution plan

## Basis

- Generated from **tables/switching_old_analysis_validation_matrix.csv** and **tables/switching_old_analysis_priority_groups.csv**.
- **Planning only**: no analysis executed in this step.
- Anchors: canonical vs legacy **S** equivalent on legacy coverage; primary collapse **T_K < 31.5 K** (22 K in-domain; 32K/34K diagnostic-only); **X/W_I** gauge (not **X_canon**); **SAFE_TO_WRITE_SCALING_CLAIM** remains **NO**.

## Priority groups (from matrix)

$prioLines

## P0 components

| Component | Adoption status |
|-----------|-------------------|
| Map-level collapse / master curve (layer 01) | **Already reproduced** - freeze and cite primary-domain apples-to-apples result |
| Effective observables I_peak, W_I, S_peak, X (layer 02) | **Adoptable via S-equivalence** - validate recipe parity (legacy vs canonical columns on same S object) |

### P0 classified by matrix posture

| Posture | P0 layers |
|---------|-----------|
| Already reproduced | 01_map_level_collapse_master_curve |
| Adoptable now (S equivalence + recipe parity) | 02_effective_observables_I_peak_W_I_S_peak_X |
| Needs narrow replay | none (defer to P1 layers 03, 07) |
| Needs artifact recovery | none at P0 |
| Claim-boundary only | none at P0 |

## P1 components and minimal narrow replay (when execution is allowed later)

| Component | Narrow replay scope |
|-----------|---------------------|
| Asymmetry / LR half-width (layer 03) | Single-purpose asymmetry + width observables on canonical alignment ladder; no phi bundle |
| PT/CDF/barrier (layer 07) | **Conditional** after P0 + T22 audit: minimal CDF_pt / barrier columns on canonical **S_long** only if narrative gap remains |

## Explicitly not rerun (blocked)

- Broad residual/Phi/kappa/PCA campaigns
- Broad old-analysis replay
- Cross-module hooks (Relaxation/Aging synthesis)
- Global **X_canon** / unique-W search
- Promoting above-31.5 K regime to primary-collapse claims without labeling

## Execution order

See **tables/switching_old_analysis_execution_order.csv**. Summary:

1. Freeze P0 collapse narrative (layer 01).
2. Validate/adopt effective-observable recipes (layer 02).
3. As-needed narrow replay for asymmetry / LR width (layer 03).
4. Audit 22 K reorganization / crossover using inventory (layer 04) - no broad replay.
5. Only if still needed: conditional narrow PT/CDF/barrier (layer 07).
6. Hold phi/residual sector to claim-boundary; no campaign (layer 06).

## Claim boundaries

- **Allowed now**: S equivalence on legacy coverage; primary-domain collapse framing with citations; 22 K in-domain vs 32K/34K diagnostic labeling.
- **Allowed after P0/P1 execution (when run)**: effective-observable tables after checklist; LR/asymmetry after narrow replay or waiver; PT/CDF only after conditional step.
- **Forbidden**: scaling-law claims under current charter; **X_canon**; residual/Phi as primary collapse drivers in this plan.

## Stopping criteria (scope creep)

See **`tables/switching_old_analysis_scope_control.csv`** (`STOPPING_CRITERION` rows).

## Outputs

- tables/switching_old_analysis_canonical_adoption_plan.csv
- tables/switching_old_analysis_execution_order.csv
- tables/switching_old_analysis_scope_control.csv (includes verdicts)
- tables/switching_old_analysis_adoption_status.csv

## Verdict table

| Verdict | Value |
|---------|-------|
| OLD_ANALYSIS_CANONICAL_ADOPTION_PLAN_COMPLETE | YES |
| VALIDATION_MATRIX_USED | YES |
| P0_EXECUTION_ORDER_DEFINED | YES |
| P1_EXECUTION_ORDER_DEFINED | YES |
| BROAD_OLD_ANALYSIS_RERUN_BLOCKED | YES |
| PHASE5_RESIDUAL_PCA_DEPRIORITIZED | YES |
| X_CANON_SEARCH_BLOCKED | YES |
| T22_REORGANIZATION_AUDIT_PLANNED | YES |
| CLAIM_BOUNDARIES_DEFINED | YES |
| SAFE_TO_WRITE_SCALING_CLAIM | NO |
| CROSS_MODULE_SYNTHESIS_PERFORMED | NO |
"@

Set-Content -Encoding UTF8 -Path $rp -Value $md

Write-Host "Canonical adoption plan written: $rp"
