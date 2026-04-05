# Output Artifact Audit Report

Date: 2026-03-09
Repository: `matlab-functions`
Scope: `results/aging`, `results/relaxation`, `results/switching`, plus top-level `results/` legacy outputs relevant to run-based organization.

## Summary

The experiment result roots are structurally clean at the top level: `results/aging`, `results/relaxation`, and `results/switching` each contain only `runs/`.

However, the contents of the run directories do not yet follow the newly documented artifact layout in `docs/output_artifacts.md`.

Current standard expected inside each run:

- `figures/`
- `tables/`
- `reports/`
- `review/`

Observed repository state:

- 34 audited runs are missing one or more of the required artifact directories.
- 1250 figure files were found outside `figures/`.
- 188 CSV tables were found outside `tables/`.
- 30 ZIP review bundles were found outside `review/`.
- Multiple non-standard artifact directories are still present inside runs.
- Several legacy outputs still exist at the top level of `results/` outside experiment run directories.

## Problems Found

### 1. Required artifact directories are missing from all audited runs

Problem:

No audited run fully matches the required `figures/`, `tables/`, `reports/`, `review/` layout.

Representative affected directories:

- `results/aging/runs/run_2026_03_09_124648_geometry_visualization`
- `results/aging/runs/run_legacy_decomposition`
- `results/relaxation/runs/run_legacy_geometry_maps_relaxband`
- `results/relaxation/runs/run_legacy_log_model`
- `results/switching/runs/run_2026_03_09_132236_switching_alignment_audit`
- `results/switching/runs/run_legacy_alignment_audit`

Recommended correction:

Create the standard artifact directories in every run and migrate existing artifacts into the correct locations.

### 2. Non-standard artifact directories are still used inside runs

Problem:

Runs still contain analysis-specific or legacy directories instead of the standard artifact directories.

Representative unexpected directories:

- `geometry_visualization/`
- `debug_runs/`
- `baseline_subtracted_FM/`
- `diagnostics/`
- `archives/`
- `stability_survey/`
- timestamp-named debug folders such as `20260223_093325/`

Representative affected directories:

- `results/aging/runs/run_2026_03_09_141328_geometry_visualization/geometry_visualization`
- `results/aging/runs/run_legacy_debug_runs/20260223_093325`
- `results/relaxation/runs/run_legacy_kww_model/diagnostics`
- `results/switching/runs/run_legacy_alignment_audit/archives`

Recommended correction:

Flatten or remap these directories into the allowed top-level artifact layout and stop generating new non-standard subdirectories.

### 3. Figures are stored outside `figures/`

Problem:

Figure files (`.png`, `.pdf`, `.fig`) are frequently stored under analysis-specific folders rather than `figures/`.

Representative examples:

- `results/aging/runs/run_2026_03_09_014130_MG119_3sec/geometry_visualization/aging_map_heatmap.png`
- `results/aging/runs/run_2026_03_09_124648_geometry_visualization/geometry_visualization/aging_centered_temperature_slices.png`
- `results/relaxation/runs/run_legacy_derivative_smoothing/relaxation_derivative_map.png`
- `results/switching/runs/run_legacy_alignment_audit/alignment_audit_overview.png`

Recommended correction:

Move all figure outputs into `figures/` and keep both `.png` and `.fig` there.

### 4. Tables are stored outside `tables/`

Problem:

CSV outputs are stored directly in run roots or inside legacy analysis folders instead of `tables/`.

Representative examples:

- `results/aging/runs/run_legacy_baseline_tests/FM_baseline_test.csv`
- `results/aging/runs/run_legacy_debug_runs/20260223_093325/debug_metrics.csv`
- `results/switching/runs/run_legacy_observable_summary/switching_observables_long.csv`
- `results/switching/runs/run_legacy_XI_Xshape_analysis/XI_Xshape_regression_metrics.csv`

Recommended correction:

Move all numeric outputs into `tables/` and standardize machine-readable filenames where possible.

### 5. ZIP review bundles are stored outside `review/`

Problem:

ZIP files prepared for human review are still stored in legacy folders such as `archives/` or inside analysis-specific directories.

Representative examples:

- `results/aging/runs/run_2026_03_09_124648_geometry_visualization/geometry_visualization/aging_geometry_review.zip`
- `results/relaxation/runs/run_legacy_derivative_smoothing/relaxation_derivative_smoothing_analysis.zip`
- `results/switching/runs/run_legacy_alignment_audit/archives/alignment_audit.zip`
- `results/switching/runs/run_legacy_mechanism_followup/switching_mechanism_followup_review.zip`

Recommended correction:

Move all human-review ZIP bundles into `review/` and stop using `archives/` for new review packages.

### 6. Legacy outputs still exist outside experiment run directories

Problem:

Top-level `results/` still contains legacy outputs and non-run result trees.

Affected directories and files:

- `results/cross_analysis/`
- `results/cross_experiment/`
- `results/phaseC/`
- `results/baseline_resultsLOO.mat`
- `results/C2_dipWindowSweep.csv`
- `results/C2_dipWindowSweep.mat`

Recommended correction:

Decide whether these locations are still valid under current policy. If not, migrate them into run directories or document them explicitly as sanctioned exceptions.

### 7. Documentation currently describes two different run-internal layouts

Problem:

`docs/output_artifacts.md` defines `figures/`, `tables/`, `reports/`, `review/`, while `docs/results_system.md` still describes `figures/`, `csv/`, `reports/`, `archives/`, `artifacts/`.

Affected files:

- `docs/output_artifacts.md`
- `docs/results_system.md`

Recommended correction:

Choose one authoritative run-internal artifact layout before applying a large migration, otherwise agents and scripts will continue to diverge.

## Recommended Corrections

1. Reconcile the documentation so only one run-internal artifact layout is authoritative.
2. Add the required `figures/`, `tables/`, `reports/`, and `review/` directories to every active and legacy run.
3. Move figure files into `figures/`.
4. Move CSV and other numeric outputs into `tables/`.
5. Move review ZIP files into `review/`.
6. Retire non-standard directories such as `plots/`, `figs/`, `archives/`, `diagnostics/`, and analysis-specific folders inside runs.
7. Audit top-level `results/` exceptions such as `cross_analysis`, `cross_experiment`, `phaseC`, and loose `.csv` or `.mat` files, then either migrate them or explicitly document them as exceptions.

## Audit Conclusion

The repository passes the top-level experiment-root structure check, but it does not yet comply with the new artifact-organization rules inside run directories.

A migration is needed before the run contents can be considered fully standardized.
