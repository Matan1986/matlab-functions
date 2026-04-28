# Emit canonical P0 old W_I collapse freeze tables and report (documentation only; no analysis runs).
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'

function Export-Status([hashtable]$verdicts, [string]$path) {
    $verdicts.GetEnumerator() | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{ verdict_key = $_.Key; verdict_value = $_.Value }
    } | Export-Csv -NoTypeInformation -Encoding UTF8 $path
}

$tables = Join-Path $RepoRoot 'tables'
$reports = Join-Path $RepoRoot 'reports'
if (-not (Test-Path $tables)) { New-Item -ItemType Directory -Path $tables -Force | Out-Null }
if (-not (Test-Path $reports)) { New-Item -ItemType Directory -Path $reports -Force | Out-Null }

# --- Definition (frozen recipe + geometry)
$defRows = @(
    [pscustomobject]@{ field_key = 'horizontal_scaled_coordinate'; field_symbol = 'x_scaled'; field_value = '(I - I_peak) / W_I'; notes = 'Legacy collapse-plane horizontal axis; gauge tied to W_I width.' }
    [pscustomobject]@{ field_key = 'vertical_scaled_coordinate'; field_symbol = 'y_scaled'; field_value = 'S / S_peak'; notes = 'Normalized switching observable on ridgeline peak.' }
    [pscustomobject]@{ field_key = 'W_I_width_recipe'; field_symbol = 'W_I'; field_value = 'Interpolated FWHM at 0.5 * S_peak on I-axis; sigma fallback only if ridge unresolved'; notes = 'Same prescription as recovered old effective width; not a uniqueness claim.' }
    [pscustomobject]@{ field_key = 'collapse_quality_metric'; field_symbol = ''; field_value = 'evaluateCollapseDetailed (old-style intercurve consistency)'; notes = 'Spearman correlation is not used as the collapse acceptance gate.' }
    [pscustomobject]@{ field_key = 'spearman_role'; field_symbol = ''; field_value = 'NOT_COLLAPSE_GATE'; notes = 'Spearman may exist for diagnostics; primary collapse acceptance uses old-style collapse metric.' }
    [pscustomobject]@{ field_key = 'reference_audit_old_S_equivalence'; field_symbol = ''; field_value = 'scripts/run_switching_old_S_object_equivalence_audit.ps1'; notes = 'reports/switching_old_S_object_equivalence_audit.md; tables/switching_old_S_equivalence_status.csv' }
    [pscustomobject]@{ field_key = 'reference_old_W_I_recipe_replay'; field_symbol = ''; field_value = 'scripts/run_switching_old_WI_recipe_replay.ps1'; notes = 'Old W_I recipe replay on canonical ladder; outputs per run dirs.' }
    [pscustomobject]@{ field_key = 'reference_apples_to_apples_primary_domain'; field_symbol = ''; field_value = 'scripts/run_switching_old_collapse_apples_to_apples.ps1'; notes = 'reports/switching_old_collapse_apples_to_apples_replay.md; tables/switching_old_collapse_apples_to_apples_status.csv' }
    [pscustomobject]@{ field_key = 'reference_canonical_adoption_plan'; field_symbol = ''; field_value = 'reports/switching_old_analysis_canonical_adoption_plan.md'; notes = 'tables/switching_old_analysis_canonical_adoption_plan.csv; tables/switching_old_analysis_execution_order.csv' }
)
$defRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $tables 'switching_P0_old_collapse_freeze_definition.csv')

# --- Domain
$domRows = @(
    [pscustomobject]@{ domain_name = 'PRIMARY_COLLAPSE'; temperature_rule_K = 'T_K < 31.5'; inclusion_note = 'Includes T = 22 K as an in-domain point (internal crossover/outlier candidate allowed).'; collapse_role = 'PRIMARY_NARRATIVE_AND_FREEZE' }
    [pscustomobject]@{ domain_name = 'ABOVE_TRANSITION_DIAGNOSTIC'; temperature_rule_K = 'T_K >= 31.5 (e.g. 32 K, 34 K reference points)'; inclusion_note = 'Excluded from primary collapse framing; diagnostic / sensitivity only.'; collapse_role = 'DIAGNOSTIC_ONLY' }
)
$domRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $tables 'switching_P0_old_collapse_freeze_domain.csv')

# --- Metrics (frozen numbers as authorized by P0 recovery; approximate where noted)
$metRows = @(
    [pscustomobject]@{
        metric_id = 'PRIMARY_MEAN_INTERCURVE_STD_LT_31P5'
        metric_name = 'mean_intercurve_std (PRIMARY_T_LT_31P5)'
        numeric_value_text = '0.076034'
        classification = 'PRIMARY_FROZEN_RESULT'
        legacy_reference = ''
        sensitivity_note = 'Canonical apples-to-apples primary domain aggregate.'
    }
    [pscustomobject]@{
        metric_id = 'LEGACY_FULL_SCALING_CHOSEN_DEFECT'
        metric_name = 'Legacy full_scaling_chosen defect (reference)'
        numeric_value_text = '~0.076'
        classification = 'LEGACY_REFERENCE_MATCH'
        legacy_reference = 'full_scaling_chosen'
        sensitivity_note = 'Apples-to-apples comparison target; not an independent measurement.'
    }
    [pscustomobject]@{
        metric_id = 'T22_EXCLUSION_SENSITIVITY_DEFECT_OPTIONAL'
        metric_name = 'Optional defect when 22 K excluded (sensitivity variant)'
        numeric_value_text = '~0.065'
        classification = 'SENSITIVITY_ONLY'
        legacy_reference = ''
        sensitivity_note = 'Optional narrative sensitivity only; 22 K remains in primary domain unless charter explicitly excludes it.'
    }
)
$metRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $tables 'switching_P0_old_collapse_freeze_metrics.csv')

# --- Claim boundary
$cbRows = @(
    [pscustomobject]@{ boundary_category = 'ALLOWED'; statement = 'Canonical recovery of old gauge-based W_I collapse in the primary domain T_K < 31.5 with cited replay tables.' }
    [pscustomobject]@{ boundary_category = 'ALLOWED'; statement = 'Equivalence of legacy and canonical S maps on legacy coverage used as input to observables and collapse replay.' }
    [pscustomobject]@{ boundary_category = 'FORBIDDEN'; statement = 'Claiming a unique canonical width W or global coordinate outside the stated gauge recipe.' }
    [pscustomobject]@{ boundary_category = 'FORBIDDEN'; statement = 'Claiming X_canon or a globally identified unique effective coordinate.' }
    [pscustomobject]@{ boundary_category = 'FORBIDDEN'; statement = 'Universal all-temperature scaling-law or exponent claims (SAFE_TO_WRITE_SCALING_CLAIM remains NO).' }
    [pscustomobject]@{ boundary_category = 'FORBIDDEN'; statement = 'Mechanism-level physical explanation as a proved output of this freeze.' }
    [pscustomobject]@{ boundary_category = 'FORBIDDEN'; statement = 'Cross-module (Relaxation/Aging) synthesis tied to this collapse freeze.' }
)
$cbRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $tables 'switching_P0_old_collapse_freeze_claim_boundary.csv')

# --- Source artifacts (point-in-time repo references)
# --- Status verdicts (required keys)
$verdict = @{
    'P0_OLD_COLLAPSE_FREEZE_COMPLETE'              = 'YES'
    'OLD_AND_CANONICAL_S_EQUIVALENCE_USED'         = 'YES'
    'OLD_WI_RECIPE_USED'                           = 'YES'
    'PRIMARY_DOMAIN_T_LT_31P5_USED'                = 'YES'
    'T22_INCLUDED_IN_PRIMARY_DOMAIN'               = 'YES'
    'ABOVE_31P5_DIAGNOSTIC_ONLY'                   = 'YES'
    'OLD_STYLE_COLLAPSE_METRIC_USED'               = 'YES'
    'PRIMARY_COLLAPSE_MATCHES_LEGACY_DEFECT'       = 'YES'
    'X_CANON_CLAIMED'                              = 'NO'
    'UNIQUE_W_CLAIMED'                             = 'NO'
    'GLOBAL_ALL_T_SCALING_CLAIMED'                = 'NO'
    'SAFE_TO_WRITE_SCALING_CLAIM'                  = 'NO'
    'CROSS_MODULE_SYNTHESIS_PERFORMED'             = 'NO'
}
Export-Status $verdict (Join-Path $tables 'switching_P0_old_collapse_freeze_status.csv')

# --- Report
$rp = Join-Path $reports 'switching_P0_old_collapse_freeze.md'
$md = @'
# Switching P0 old W_I collapse freeze

This document freezes the recovered **old W_I-based collapse** as the canonical **Switching P0** collapse result. **No new exploratory analysis** was executed to produce this freeze; it records definitions, domain, metrics, claim boundaries, and pointers to existing audits and scripts.

## Frozen collapse definition

| Field | Value |
|-------|-------|
| x_scaled | **(I - I_peak) / W_I** |
| y_scaled | **S / S_peak** |
| W_I | Interpolated **FWHM at 0.5 * S_peak** on I; **sigma fallback** only if ridge unresolved |
| Metric | **evaluateCollapseDetailed** (old-style intercurve consistency) |
| Spearman | **Not** the collapse acceptance gate |

CSV: **tables/switching_P0_old_collapse_freeze_definition.csv**

## Frozen domain

| Domain | Rule | Role |
|--------|------|------|
| Primary collapse | **T_K < 31.5 K** | Narrative + freeze |

**22 K** is **included** in the primary domain (internal crossover/outlier candidate allowed).

**32 K / 34 K** (and similarly **T_K >= 31.5 K**) are **above-transition** points and **diagnostic-only** when referenced - not primary collapse claims.

CSV: **tables/switching_P0_old_collapse_freeze_domain.csv**

## Frozen numerical results

| Metric | Approx. value | Classification |
|--------|----------------|----------------|
| PRIMARY mean intercurve std (primary T_K < 31.5 K) | **~0.076034** | Primary frozen aggregate |
| Legacy **full_scaling_chosen** defect | **~0.076** | Legacy reference match |
| Optional sensitivity (22 K exclusion variant) | **~0.065** | **Sensitivity only** |

CSV: **tables/switching_P0_old_collapse_freeze_metrics.csv**

## Claim boundaries

- **Allowed:** Canonical recovery of **gauge-based** old W_I collapse in the primary domain; citation of equivalence of **S** maps on legacy coverage.
- **Forbidden:** **X_canon**, unique **W**, global all-temperature scaling claims, mechanism claims proved by this artifact, cross-module synthesis.

CSV: **tables/switching_P0_old_collapse_freeze_claim_boundary.csv**

## Source artifacts

| Role | Entry point |
|------|-------------|
| Old vs canonical **S** equivalence | `scripts/run_switching_old_S_object_equivalence_audit.ps1` |
| Old **W_I** recipe replay | `scripts/run_switching_old_WI_recipe_replay.ps1` |
| Apples-to-apples primary domain replay | `scripts/run_switching_old_collapse_apples_to_apples.ps1` |
| Canonical adoption plan (P0 freeze step) | `reports/switching_old_analysis_canonical_adoption_plan.md` |

## Outputs

- tables/switching_P0_old_collapse_freeze_definition.csv
- tables/switching_P0_old_collapse_freeze_metrics.csv
- tables/switching_P0_old_collapse_freeze_domain.csv
- tables/switching_P0_old_collapse_freeze_claim_boundary.csv
- tables/switching_P0_old_collapse_freeze_status.csv

## Verdict table

| Verdict | Value |
|---------|-------|
| P0_OLD_COLLAPSE_FREEZE_COMPLETE | YES |
| OLD_AND_CANONICAL_S_EQUIVALENCE_USED | YES |
| OLD_WI_RECIPE_USED | YES |
| PRIMARY_DOMAIN_T_LT_31P5_USED | YES |
| T22_INCLUDED_IN_PRIMARY_DOMAIN | YES |
| ABOVE_31P5_DIAGNOSTIC_ONLY | YES |
| OLD_STYLE_COLLAPSE_METRIC_USED | YES |
| PRIMARY_COLLAPSE_MATCHES_LEGACY_DEFECT | YES |
| X_CANON_CLAIMED | NO |
| UNIQUE_W_CLAIMED | NO |
| GLOBAL_ALL_T_SCALING_CLAIMED | NO |
| SAFE_TO_WRITE_SCALING_CLAIM | NO |
| CROSS_MODULE_SYNTHESIS_PERFORMED | NO |
'@
Set-Content -Encoding UTF8 -Path $rp -Value $md

Write-Host "P0 collapse freeze written: $rp"
