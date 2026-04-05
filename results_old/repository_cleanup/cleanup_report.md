# Cleanup Report

Date: 2026-03-09 20:26:47
Repository: `matlab-functions`

## Summary

- Files moved: 1629
- Runs modified: 35
- Legacy outputs migrated: 4

## Runs Modified

The migration updated 35 run directories across:

- `results/aging/runs/`
- `results/relaxation/runs/`
- `results/switching/runs/`
- `results/cross_analysis/runs/`
- `results/cross_experiment/runs/`
- `results/phaseC/runs/`
- `results/legacy_root/runs/`

Representative modified runs:

- `results/aging/runs/run_2026_03_09_141328_geometry_visualization`
- `results/aging/runs/run_legacy_debug_runs`
- `results/relaxation/runs/run_legacy_derivative_smoothing`
- `results/switching/runs/run_legacy_alignment_audit`
- `results/cross_analysis/runs/run_legacy_cross_analysis`
- `results/legacy_root/runs/run_legacy_results_root`

## Legacy Outputs Migrated

The following non-run result areas were migrated into pseudo-runs:

- `results/cross_analysis/` -> `results/cross_analysis/runs/run_legacy_cross_analysis/`
- `results/cross_experiment/` -> `results/cross_experiment/runs/run_legacy_cross_experiment/`
- `results/phaseC/` -> `results/phaseC/runs/run_legacy_phaseC/`
- loose files directly under `results/` -> `results/legacy_root/runs/run_legacy_results_root/`

## Unexpected Directory Structures Encountered

Representative pre-migration structures included:

- analysis-specific folders such as `geometry_visualization/`, `baseline_subtracted_FM/`, and `stability_survey/`
- legacy bundle folders such as `archives/`
- diagnostic folders such as `diagnostics/`
- timestamp-named debug folders such as `20260223_093325/`
- top-level legacy result trees such as `cross_analysis/`, `cross_experiment/`, and `phaseC/`

These structures were encountered during migration and their artifacts were reorganized into the canonical layout.

## Post-Migration Validation

Validation after migration:

- missing required `figures/`, `tables/`, `reports/`, `review/` directories: 0
- figure files outside `figures/`: 0
- table files outside `tables/`: 0
- report files outside `reports/` (excluding root `log.txt` and `run_notes.txt`): 0
- ZIP bundles outside `review/`: 0

## Notes

- Filenames were preserved.
- Run directories were not renamed.
- No experiment pipelines were modified.
- Required run-root metadata files were left at run root.
- Empty legacy directories were removed only after their files had been moved.
