# Repository organization follow-up

## 1. Observables location policy confirmation

Current intended policy:

- `observables.csv` is a run-level summary/index
- it belongs at the run root
- artifact helpers should not move it into `tables/`

Observed Switching run survey:

- historical transition runs still exist with `tables/observables.csv`
  - `run_2026_03_09_132236_switching_alignment_audit`
  - `run_2026_03_09_141041_switching_alignment_audit`
  - `run_2026_03_09_145524_switching_alignment_audit`
- the current validated Switching run uses run-root placement
  - `run_2026_03_09_222702_alignment_audit/observables.csv`

Conclusion:

- the current policy is run-root placement
- older `tables/observables.csv` files are historical transition artifacts, not the target layout
- this policy is now documented explicitly in `docs/results_system.md`

Where observable export currently happens:

- `Switching/analysis/switching_alignment_audit.m`
- `tools/export_observables.m`

Observed standardized schema includes:

- `experiment`
- `sample`
- `temperature`
- `observable`
- `value`
- `units`
- `role`
- `source_run`

## 2. Relaxation structure findings

High-level status:

- `Relaxation ver3` already uses the run-based results system for the main diagnostics surveyed
- new diagnostics typically call `init_run_output_dir(...)`
- however, many of those scripts still write artifacts directly to `outDir` with `writetable`, `writematrix`, `saveas`, or explicit ZIP creation rather than using `save_run_figure`, `save_run_table`, and `save_run_report`

Small duplication patterns found:

- shared curve preprocessing duplicated between:
  - `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m`
  - `Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m`
  - repeated helpers: `cleanAligned`, `detectRelaxStart`, `findRuns`, `parseNominalTemp`, `safeDiv`, `setDef`
- geometry map setup duplicated between:
  - `Relaxation ver3/diagnostics/visualize_relaxation_geometry.m`
  - `Relaxation ver3/diagnostics/visualize_relaxation_band_maps.m`
  - repeated logic: dataset loading, MuB/Co conversion, nominal temperature parsing, common log-grid interpolation, per-curve summary table creation
- derivative visualization / rendering overlap between:
  - `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m`
  - `Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m`
  - repeated concerns: map plotting, cut plotting, color scaling, bundle/report packaging

Minimal extraction candidates only:

- `Relaxation/utils/relaxation_curve_prep.m` or a small set of helpers for:
  - `cleanAligned`
  - `detectRelaxStart`
  - `findRuns`
  - `parseNominalTemp`
- `Relaxation/utils/build_relaxation_geometry_grid.m` for common-grid interpolation and summary preparation shared by the geometry map scripts
- `Relaxation/utils/relaxation_map_plotting.m` for repeated heatmap / cut plotting used by the derivative and geometry diagnostics

Results-system verification for Relaxation:

- run-scoped outputs exist under `results/relaxation/runs/`
- legacy runs were previously migrated into `run_legacy_*` folders
- the recent non-legacy run `run_2026_03_09_205312_derivative_smoothing` is run-based, but still carries extra subfolders such as `archives/`, `artifacts/`, `csv/`, and `derivative_smoothing/`

Interpretation:

- Relaxation is on the run system already
- the next cleanup there should be helper adoption and small utility extraction, not a module rewrite

## 3. Legacy results directories survey

### `results/cross_analysis`

- Producer: Aging diagnostics using `getResultsDir('cross_analysis', ...)`
- Current status: already migrated into `results/cross_analysis/runs/run_legacy_cross_analysis/`
- Recommendation: keep for now as a historical namespace; later decide whether to consolidate with `cross_experiment`

### `results/phaseC`

- Producer: Aging Phase C outputs, notably `Aging/pipeline/runPhaseC_leaveOneOut.m`
- Current status: already migrated into `results/phaseC/runs/run_legacy_phaseC/`
- Recommendation: keep as a legacy namespace for provenance; no automatic move now

### `results/legacy_root`

- Producer: historical loose files that had been written directly under `results/`
- Current status: already migrated into `results/legacy_root/runs/run_legacy_results_root/`
- Recommendation: keep as a cleanup holding namespace; no further move needed unless there is a future global namespace simplification

### `results/repository_audit`

- Producer: repository-audit and follow-up organization work
- Current status: mixed namespace with canonical `runs/` plus flat reports and ZIPs at the top level
- Recommendation: keep as a special documentation/audit namespace, but prefer future generated outputs under `results/repository_audit/runs/` and reserve top-level files for intentional summary documents only

### `results/repository_cleanup`

- Producer: historical cleanup migration summary
- Current status: flat `cleanup_report.md` only
- Recommendation: candidate for later migration into a pseudo-run such as `results/repository_audit/runs/run_legacy_repository_cleanup/` or equivalent archival location, but do not move automatically now

### `results/cross_experiment`

- Status: canonical shared-analysis namespace per current docs
- Recommendation: keep as-is

## 4. Recommended small cleanups

- Relaxation:
  - adopt `save_run_figure`, `save_run_table`, and `save_run_report` gradually in diagnostics that already use `init_run_output_dir(...)`
  - extract only the repeated preprocessing/grid helpers listed above
- Results documentation:
  - keep `observables.csv` at run root and treat older `tables/observables.csv` as historical
- Namespace cleanup:
  - leave `cross_analysis`, `phaseC`, and `legacy_root` in place for now because they already preserve legacy outputs safely inside pseudo-runs
  - consider moving `results/repository_cleanup/cleanup_report.md` into an audit pseudo-run later

## Remaining inconsistencies discovered

- `results/README.md` still documents older run subfolders such as `csv/`, `archives/`, and `artifacts/`, which no longer match the canonical layout in `docs/results_system.md`
- `results/repository_audit/` is partly canonical and partly flat
- Relaxation diagnostics are run-based but still mostly bypass the artifact helpers
- `cross_analysis` and `cross_experiment` remain split namespaces, which is historically understandable but still conceptually redundant