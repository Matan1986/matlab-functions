# Figure Repair Report

Date: March 10, 2026

## Export helper upgrade

- Updated `tools/save_run_figure.m` to remain backward compatible with the existing `(figure_handle, figure_name, run_output_dir)` calling convention.
- The helper now exports three formats with one shared base name:
  - vector PDF via `exportgraphics(..., 'ContentType', 'vector')`
  - PNG via `exportgraphics(..., 'Resolution', 600)`
  - editable FIG via `savefig`
- The helper still resolves any analysis subdirectory back to the active run root and writes figure artifacts into `results/<experiment>/runs/<run_id>/figures/`.
- Existing callers that use `paths.png` and `paths.fig` remain compatible; `paths.pdf` was added as an extra field.

## Switching repair

- Modified only `Switching/analysis/switching_alignment_audit.m`.
- Replaced `64` direct figure export calls that previously used `saveas` into `outDir`.
- Added one local wrapper, `export_alignment_figure(...)`, that delegates export to `save_run_figure(...)` and returns the PNG path expected by the script's existing reporting/copy logic.
- The plotting blocks, calculations, decomposition logic, and run initialization flow were left unchanged.

## Analysis behavior

- Analysis logic was unchanged.
- No experiment pipeline files were modified.
- No legacy utilities from `General ver2/` were reused.

## Verification

- Confirmed `Switching/analysis/switching_alignment_audit.m` now contains `0` direct `saveas`, `exportgraphics`, or `savefig` calls.
- Confirmed the Switching script now routes figure exports through `save_run_figure(...)`.
- MATLAB execution was not run in this repair session, so runtime export validation is still pending.

## Relaxation and Aging follow-up

- Reviewed `Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m` and confirmed it already routes all figure exports through `save_run_figure(...)` at `4` call sites.
- Reviewed `Aging/analysis/aging_geometry_visualization.m` and confirmed it already routes all figure exports through `save_run_figure(...)` at `6` call sites.
- No script edits were required for these two priority files because they were already aligned with the canonical export helper.
- Both scripts now inherit the upgraded `PDF + 600 dpi PNG + FIG` export behavior and canonical run-root `figures/` output location through `tools/save_run_figure.m`.

## Visualization infrastructure completion

- Added `tools/figures/create_figure.m` for publication-oriented figure creation with centimeter sizing and repository typography defaults.
- Added `tools/figures/apply_publication_style.m` to enforce publication styling across all axes, legends, and colorbars in a figure.
- Added `tools/figures/figure_quality_check.m` to warn about common figure issues such as small line widths, small fonts, forbidden colormaps, and missing axis labels.
- Updated `tools/save_run_figure.m` so exports automatically attempt publication styling and run warning-only figure quality checks before writing `PDF + PNG + FIG`.
- Updated `docs/AGENT_RULES.md` with a `Visualization Helpers` section that centralizes figure helper usage under `tools/figures/`.
