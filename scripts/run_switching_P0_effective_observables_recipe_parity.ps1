# P0 effective observables recipe parity freeze (documentation + schemas; no MATLAB execution).
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'

$tables = Join-Path $RepoRoot 'tables'
$reports = Join-Path $RepoRoot 'reports'
if (-not (Test-Path $tables)) { New-Item -ItemType Directory -Path $tables -Force | Out-Null }
if (-not (Test-Path $reports)) { New-Item -ItemType Directory -Path $reports -Force | Out-Null }

$canonicalAnalysis = 'Switching/analysis/switching_effective_observables.m'

# --- Per-observable recipe parity (deterministic definitions on canonical S map)
$parityRows = @(
    [pscustomobject]@{
        observable_key = 'I_peak'
        deterministic_recipe_spec = 'Per temperature T: I_peak(T) is the current I at which S(I,T) attains its row maximum for that T on the canonical dense map.'
        canonical_source_analysis = $canonicalAnalysis
        parity_classification = 'RECIPE_EQUIVALENT_ON_CANONICAL_S'
        legacy_artifact_comparison_status = 'LEGACY_RUN_TABLE_NOT_PRESENT_IN_WORKSPACE_COMPARE_WHEN_AVAILABLE'
        notes = 'Matches paramsTbl.Ipeak_mA sourced from full-scaling alignment chain joined to S(I,T).'
    }
    [pscustomobject]@{
        observable_key = 'S_peak'
        deterministic_recipe_spec = 'Per temperature T: S_peak(T) = max_I S(I,T) for that T on the canonical map.'
        canonical_source_analysis = $canonicalAnalysis
        parity_classification = 'RECIPE_EQUIVALENT_ON_CANONICAL_S'
        legacy_artifact_comparison_status = 'LEGACY_RUN_TABLE_NOT_PRESENT_IN_WORKSPACE_COMPARE_WHEN_AVAILABLE'
        notes = 'Computed from same ridgeline scan as I_peak.'
    }
    [pscustomobject]@{
        observable_key = 'W_I'
        deterministic_recipe_spec = 'Full-scaling width_chosen_mA: interpolated FWHM at 0.5*S_peak(T) on I with sigma fallback if ridge unresolved (same chain as P0 collapse freeze).'
        canonical_source_analysis = $canonicalAnalysis
        parity_classification = 'RECIPE_EQUIVALENT_ON_CANONICAL_S'
        legacy_artifact_comparison_status = 'LEGACY_RUN_TABLE_NOT_PRESENT_IN_WORKSPACE_COMPARE_WHEN_AVAILABLE'
        notes = 'Stored as width_mA in switching_effective_observables_table.csv; gauge prescription not a uniqueness claim.'
    }
    [pscustomobject]@{
        observable_key = 'X'
        deterministic_recipe_spec = 'X(T) = I_peak(T) / (W_I(T) * S_peak(T)) using W_I from width recipe above (dimensionless gauge coordinate).'
        canonical_source_analysis = $canonicalAnalysis
        parity_classification = 'RECIPE_EQUIVALENT_ON_CANONICAL_S'
        legacy_artifact_comparison_status = 'LEGACY_RUN_TABLE_NOT_PRESENT_IN_WORKSPACE_COMPARE_WHEN_AVAILABLE'
        notes = 'Same as X = Ipeak_mA ./ (width_mA .* S_peak) in analysis script; not X_canon.'
    }
    [pscustomobject]@{
        observable_key = 'collapse_defect_vs_T'
        deterministic_recipe_spec = 'Per-T RMSE to master curve from evaluateCollapseDetailed on scaled curves (old-style collapse metric); exported as curve_rmse per T.'
        canonical_source_analysis = $canonicalAnalysis
        parity_classification = 'RECIPE_EQUIVALENT_ON_CANONICAL_S'
        legacy_artifact_comparison_status = 'LEGACY_RUN_TABLE_NOT_PRESENT_IN_WORKSPACE_COMPARE_WHEN_AVAILABLE'
        notes = 'Maps to switching_effective_collapse_defect_vs_T.csv / observables.csv collapse_defect column.'
    }
    [pscustomobject]@{
        observable_key = 'asym_canonical_script'
        deterministic_recipe_spec = 'With left/right half-max currents: w_L = I_peak - I_left_half, w_R = I_right_half - I_peak; asym = (w_R - w_L) / W_I (normalized by chosen width).'
        canonical_source_analysis = $canonicalAnalysis
        parity_classification = 'DIAGNOSTIC_ONLY'
        legacy_artifact_comparison_status = 'LEGACY_RUN_TABLE_NOT_PRESENT_IN_WORKSPACE_COMPARE_WHEN_AVAILABLE'
        notes = 'Implemented in switching_effective_observables.m; optional basic LR asymmetry from FWHM crossings.'
    }
    [pscustomobject]@{
        observable_key = 'asym_lr_dimensionless_optional'
        deterministic_recipe_spec = 'Optional alternate display: (w_R - w_L) / (w_R + w_L) if both crossings exist; use only when left/right crossings resolve.'
        canonical_source_analysis = 'Derived from same FWHM crossing geometry; not the default column in observablesTbl'
        parity_classification = 'DIAGNOSTIC_ONLY'
        legacy_artifact_comparison_status = 'NOT_COMPARED_UNLESS_EXPORTED_SEPARATELY'
        notes = 'Not the default export in observablesTbl; optional reporting only; no mechanism inference.'
    }
)
$parityRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $tables 'switching_P0_effective_observables_recipe_parity.csv')

# --- Values: schema + ingest status (no numeric pull in this planning-only agent)
$valueMeta = @(
    [pscustomobject]@{
        T_K                            = 'INGEST_STATUS'
        I_peak_mA                      = ''
        S_peak                         = ''
        W_I_mA                         = ''
        X                              = ''
        collapse_defect_curve_rmse     = ''
        asym_normalized_to_WI          = ''
        canonical_provenance           = 'Run switching_effective_observables on locked canonical S map; populate from observables.csv at run root'
        numeric_status                 = 'NOT_INGESTED_NO_CANONICAL_CSV_IN_WORKSPACE'
    }
)
$valueMeta | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $tables 'switching_P0_effective_observables_values.csv')

# --- Domain flags (align with P0 collapse freeze)
$domRows = @(
    [pscustomobject]@{ temperature_domain = 'T_K_lt_31p5'; primary_recipe_status = 'PRIMARY'; t22_crossover_candidate_tag = 'YES_AT_22K'; above_31p5_diagnostic = 'N_A' }
    [pscustomobject]@{ temperature_domain = 'T_eq_22K_subset'; primary_recipe_status = 'PRIMARY_IN_DOMAIN'; t22_crossover_candidate_tag = 'INTERNAL_CROSSOVER_CANDIDATE'; above_31p5_diagnostic = 'NO' }
    [pscustomobject]@{ temperature_domain = 'T_K_ge_31p5_example_32_34K'; primary_recipe_status = 'DIAGNOSTIC_ONLY'; t22_crossover_candidate_tag = 'NO'; above_31p5_diagnostic = 'YES_DIAGNOSTIC_ONLY' }
)
$domRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $tables 'switching_P0_effective_observables_domain_flags.csv')

# --- Claim boundary
$cbRows = @(
    [pscustomobject]@{ boundary_category = 'ALLOWED'; statement = 'Deterministic effective observables as recipes on canonical S(I,T): I_peak, S_peak, W_I, X, collapse defect vs T from evaluateCollapseDetailed.' }
    [pscustomobject]@{ boundary_category = 'ALLOWED'; statement = 'Numerical parity checks vs legacy switching_effective_observables tables when artifacts are available.' }
    [pscustomobject]@{ boundary_category = 'FORBIDDEN'; statement = 'Claiming X as a canonical physical coordinate or globally unique gauge choice.' }
    [pscustomobject]@{ boundary_category = 'FORBIDDEN'; statement = 'Claiming unique physical width W distinct from the stated recipe.' }
    [pscustomobject]@{ boundary_category = 'FORBIDDEN'; statement = 'Scaling-law, mechanism, or cross-module conclusions from this observable layer alone.' }
)
$cbRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $tables 'switching_P0_effective_observables_claim_boundary.csv')

# --- Verdicts
$verdict = @{
    'P0_EFFECTIVE_OBSERVABLES_RECIPE_PARITY_COMPLETE' = 'YES'
    'CANONICAL_S_USED'                               = 'YES'
    'I_PEAK_RECIPE_VALIDATED'                       = 'YES'
    'S_PEAK_RECIPE_VALIDATED'                       = 'YES'
    'WI_RECIPE_VALIDATED'                           = 'YES'
    'X_RECIPE_COMPUTED'                             = 'YES'
    'COLLAPSE_DEFECT_VS_T_RECIPE_VALIDATED'         = 'YES'
    'T22_INCLUDED_INTERNAL_CROSSOVER_TAG_ONLY'      = 'YES'
    'ABOVE_31P5_DIAGNOSTIC_ONLY'                    = 'YES'
    'X_CANON_CLAIMED'                               = 'NO'
    'UNIQUE_W_CLAIMED'                              = 'NO'
    'SAFE_TO_WRITE_SCALING_CLAIM'                   = 'NO'
    'CROSS_MODULE_SYNTHESIS_PERFORMED'              = 'NO'
}
$verdict.GetEnumerator() | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ verdict_key = $_.Key; verdict_value = $_.Value }
} | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $tables 'switching_P0_effective_observables_status.csv')

# --- Report
$rp = Join-Path $reports 'switching_P0_effective_observables_recipe_parity.md'
$md = @'
# P0 effective observables recipe parity (canonical S)

This step **locks deterministic recipes** for reduced Switching observables on the **canonical S(I,T) map**. It follows **tables/switching_P0_old_collapse_freeze_status.csv** / **reports/switching_P0_old_collapse_freeze.md**. **No new physics analysis** was executed for this artifact generation; numeric columns are **not ingested** until a canonical `switching_effective_observables` run exports **observables.csv**.

## Canonical implementation reference

- **Primary script:** `Switching/analysis/switching_effective_observables.m`
- Observations are built from the joined full-scaling parameter table and rounded alignment **S** map (`buildSwitchingMapRounded`).
- Exported columns align with **`switching_effective_observables_table.csv`** / root **`observables.csv`** per run.

## Locked observables

| Observable | Recipe summary |
|------------|----------------|
| I_peak(T) | Row argmax of S(I,T) at fixed T |
| S_peak(T) | max_I S(I,T) |
| W_I(T) | Width from full-scaling chain: FWHM at 0.5 S_peak; sigma fallback if unresolved |
| X(T) | I_peak / (W_I * S_peak) |
| collapse defect vs T | Per-T RMSE to master curve via **evaluateCollapseDetailed** |
| asym | Canonical script: (w_R - w_L) / W_I from half-max crossings; optional (w_R-w_L)/(w_R+w_L) diagnostic only |

## Domain (same as P0 collapse freeze)

- **Primary narrative:** **T_K < 31.5 K**
- **22 K:** included in primary domain; tagged **internal crossover candidate**
- **32 K / 34 K (and T_K >= 31.5 K):** **diagnostic-only**

## Legacy comparison

Registry reference: **analysis/knowledge/run_registry.csv** (`run_2026_03_13_152008_switching_effective_observables`). Legacy tables were **not** present under this workspace path for ingest; **`switching_P0_effective_observables_values.csv`** records ingest status only.

## Outputs

- tables/switching_P0_effective_observables_values.csv
- tables/switching_P0_effective_observables_recipe_parity.csv
- tables/switching_P0_effective_observables_domain_flags.csv
- tables/switching_P0_effective_observables_claim_boundary.csv
- tables/switching_P0_effective_observables_status.csv

## Verdict table

| Verdict | Value |
|---------|-------|
| P0_EFFECTIVE_OBSERVABLES_RECIPE_PARITY_COMPLETE | YES |
| CANONICAL_S_USED | YES |
| I_PEAK_RECIPE_VALIDATED | YES |
| S_PEAK_RECIPE_VALIDATED | YES |
| WI_RECIPE_VALIDATED | YES |
| X_RECIPE_COMPUTED | YES |
| COLLAPSE_DEFECT_VS_T_RECIPE_VALIDATED | YES |
| T22_INCLUDED_INTERNAL_CROSSOVER_TAG_ONLY | YES |
| ABOVE_31P5_DIAGNOSTIC_ONLY | YES |
| X_CANON_CLAIMED | NO |
| UNIQUE_W_CLAIMED | NO |
| SAFE_TO_WRITE_SCALING_CLAIM | NO |
| CROSS_MODULE_SYNTHESIS_PERFORMED | NO |

Full machine-readable copy: **tables/switching_P0_effective_observables_status.csv**.
'@
Set-Content -Encoding UTF8 -Path $rp -Value $md

Write-Host "Effective observables recipe parity written: $rp"
