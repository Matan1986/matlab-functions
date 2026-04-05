# Switching Pipeline Stability (Canonical Consolidation)

## Scope
- Task type: consolidation + minimal completion.
- Policy applied: prefer existing validated outputs; do not recompute when results already exist.
- Additional MATLAB execution performed: NO.

## Canonical Evidence Used
- `tables/parameter_robustness_stage1_canonical_verdicts.csv`
- `reports/parameter_robustness_stage1_canonical_report.md`
- `tables/parameter_robustness_stage1b_verdicts.csv`
- `reports/parameter_robustness_stage1b_width_kappa_report.md`
- `results/switching/runs/run_2026_03_29_014529_switching_physics_output_robustness_fast/robustness_verdicts.csv`
- `reports/reconstruction_v1.md`
- `tables/reconstruction_metrics_v1.csv`
- `reports/canonical_reconstruction.md`
- `tables/canonical_reconstruction_summary.csv`
- `results/switching/runs/run_2026_03_26_152733_phi1_observable_phi2_driver_test/tables/phi1_phi2_driver_verdicts.csv`

## Consistency Validation
- Canonical lock evidence present for parameter robustness artifacts (`CANONICAL_SOURCE_LOCKED=YES`).
- No conflicts for map/collapse/kappa1-sensitivity conclusions.
- Conflict detected in reconstruction/phi1-related outcomes:
  - `reports/canonical_reconstruction.md`: `PHI1_IMPROVES_RECONSTRUCTION=YES`.
  - `reports/reconstruction_v1.md`: `LOCAL_IMPROVES_OVER_PT=NO`, `FINAL_RECONSTRUCTION_MODEL=PT_ONLY`.
- Per rule, conflicting outcomes force final field value to `NO`.

## Unified Verdict
- MAP_STABLE = YES
- PHI1_STABLE = NO
- RECONSTRUCTION_CONSISTENT = NO
- COLLAPSE_STABLE = YES
- KAPPA1_SENSITIVE = YES

## Final
- PIPELINE_STABLE = NO

Reason: pipeline requires all of {MAP_STABLE, PHI1_STABLE, RECONSTRUCTION_CONSISTENT, COLLAPSE_STABLE} to be YES; phi1 stability and reconstruction consistency are not both satisfied under conflict-aware canonical consolidation.
