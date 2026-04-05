# Switching Pipeline Stability (Post-Enforcement Canonical Phi1)

## Scope
- Task type: validation-only consolidation after canonical Phi1 enforcement.
- Policy applied: prefer existing valid artifacts; rerun only affected checks.
- Code logic changes: none.

## Enforcement Gate (Affected Domain)
- Source: reports/phi1_enforcement.md (2026-03-30 10:28:00)
- Source: tables/phi1_enforcement_status.csv
- Verified outcomes:
  - CANONICAL_PHI1_ONLY_IN_PIPELINE = YES
  - NON_CANONICAL_PHI1_ISOLATED = YES
  - PHI1_MIXING_BLOCKED = YES
  - Enforced phi1-using pipelines resolve to a single canonical source run id.

## Reconstruction Recheck (Affected Domain)
- Source: reports/canonical_reconstruction.md (2026-03-30 01:50:03)
- Source: tables/canonical_reconstruction_status.csv
- Verified outcomes:
  - Strict LOTO protocol still active (no leakage).
  - PHI1_IMPROVES_RECONSTRUCTION = YES.
  - mean_RMSE_PT = 0.0695742780954322.
  - mean_RMSE_FULL = 0.0193655063005014.
  - improvement_count = 14/14.

Non-canonical contradiction handling:
- Source: reports/reconstruction_v1.md is explicitly non-canonical/local and remains archived as isolated evidence.
- Because non-canonical phi1 usage is isolated and blocked from enforced pipeline paths, it is not an active contradiction to canonical pipeline reconstruction status.

## Reused Unaffected Stability Evidence
- Source: results/switching/runs/run_2026_03_29_014529_switching_physics_output_robustness_fast/robustness_verdicts.csv
  - MAP_STABLE = YES
  - COLLAPSE_STABLE = YES
- Source: tables/parameter_robustness_stage1b_verdicts.csv
  - KAPPA1_SENSITIVE_TO_WIDTH = YES
  - KAPPA1_SENSITIVE_TO_IPEAK = YES
  - KAPPA1_FAILURE_INDEPENDENT = YES

## Validation Outputs
- MAP_STABLE = YES
- PHI1_STABLE = YES
- RECONSTRUCTION_CONSISTENT = YES
- COLLAPSE_STABLE = YES
- KAPPA1_SENSITIVE = YES
- KAPPA1_SENSITIVITY_LEVEL = HIGH

## Final Verdict
- PIPELINE_STABLE = YES

Blocking reason: none.