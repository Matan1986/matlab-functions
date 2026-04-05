# Switching post-validation cleanup report

## Changes made to helpers

- Updated `tools/save_run_figure.m` so it resolves the nearest ancestor `run_*` directory before saving, then always writes figure outputs into `<run_root>/figures/`.
- Updated `tools/save_run_table.m` so it resolves the nearest ancestor `run_*` directory before saving, then always writes table outputs into `<run_root>/tables/`.
- Updated `tools/save_run_report.m` so it resolves the nearest ancestor `run_*` directory before saving, then always writes report outputs into `<run_root>/reports/`.
- The helpers now create those canonical subfolders automatically if they are missing.

## Analysis scripts modified

Minimal script changes were applied only to the three requested files:

- `Switching/analysis/switching_mode23_analysis.m`
- `Switching/analysis/switching_XI_Xshape_analysis.m`
- `Switching/analysis/switching_alignment_audit.m`

Change made:

- each script now creates `<run_root>/review/` at startup when an active switching run directory is available

No other analysis scripts were modified.
No files under `Switching ver12` were modified.

## Canonical artifact layout enforcement

Confirmed by MATLAB helper smoke test using a nested analysis output path:

- input nested path: `results/repository_audit/runs/run_2026_03_09_999999_helper_layout_smoke/nested_analysis_dir`
- saved figure output landed in: `.../run_2026_03_09_999999_helper_layout_smoke/figures/`
- saved table output landed in: `.../run_2026_03_09_999999_helper_layout_smoke/tables/`
- saved report output landed in: `.../run_2026_03_09_999999_helper_layout_smoke/reports/`

This means scripts that already call:

- `save_run_figure`
- `save_run_table`
- `save_run_report`

will now write to canonical run subfolders even if they pass an analysis-specific subdirectory instead of the run root.

## Repository rule update

Updated `docs/AGENT_RULES.md` with the new rule:

- analysis scripts must not manage artifact paths directly
- all artifact generation must use `save_run_figure`, `save_run_table`, and `save_run_report`

## Observable export status

Standardized observable export is already present for Switching runs, but only through `switching_alignment_audit`.

Where it happens:

- script: `Switching/analysis/switching_alignment_audit.m`
- helper: `tools/export_observables.m`

Current behavior:

- `switching_alignment_audit.m` builds the long-format observable table via `buildSwitchingObservableLongTable(...)`
- it then calls `export_observables('switching', switchingRunDir, obsLongTbl)`
- `tools/export_observables.m` writes `observables.csv`

Observed schema in the recent run `results/switching/runs/run_2026_03_09_222702_alignment_audit/observables.csv`:

- `experiment`
- `sample`
- `temperature`
- `observable`
- `value`
- `units`
- `role`
- `source_run`

So the observable-layer schema is already standardized and includes the expected fields.

Important current inconsistency:

- recent Switching observable export writes `observables.csv` at the run root
- older Switching runs also exist with `tables/observables.csv`
- `tools/export_observables.m` currently writes to `<run_root>/observables.csv`, not `<run_root>/tables/observables.csv`

This was documented only; no new observable export system was introduced in this cleanup pass.

## Remaining inconsistencies discovered

- `switching_alignment_audit.m` still manages many artifact paths directly with `fullfile(outDir, ...)` and `saveas(...)`, so its figures/tables are not yet routed through the canonical save helpers.
- Several other Switching analysis scripts still write review ZIPs or other artifacts directly under their analysis subdirectory rather than consistently using canonical helper-managed subfolders.
- `tools/export_observables.m` currently targets the run root for `observables.csv`, which does not fully match the `tables/` convention documented in `docs/results_system.md`.
- The helper enforcement added here improves all scripts already using `save_run_figure`, `save_run_table`, and `save_run_report`, but it does not retroactively fix scripts that still bypass those helpers.