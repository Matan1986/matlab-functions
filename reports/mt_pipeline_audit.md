# MT Pipeline Design Audit (Design-Only)

Date: 2026-04-24  
Scope audited: `MT ver2/`  
Mode: static code/design audit only (no pipeline execution, no code-path modifications)

## 1) Entrypoint and full pipeline map

## Candidate entrypoint assessment
- Initial candidate `MT ver2/MT_main.m` is a real orchestration script and is currently the practical module entrypoint.
- It is **not canonical** under repository run-system law because it does not create `run_dir`, does not emit manifest/status/report artifacts, and uses hardcoded local paths.

## Pipeline stages (current implementation)
1. **Entrypoint orchestration**
   - `MT_main.m` sets runtime flags and numeric thresholds inline.
2. **File discovery + metadata parsing**
   - `getFileList_MT` finds `*.DAT`, parses field and sample mass from filenames (`...OE`, `...MG`).
3. **Instrument type detection**
   - `detect_MT_file_type` inspects first file header to choose MPMS vs PPMS parser.
4. **Import**
   - `importFiles_MT` loops files and dispatches:
     - `importOneFile_MT` (non-MPMS path)
     - `importOneFile_MT_MPMS` (MPMS path)
5. **Unit conversion setup**
   - `compute_unitsRatio_MT` resolves scaling (`raw`, `per_mass`, `per_co`).
6. **Cleaning and smoothing**
   - `clean_MT_data` applies high-field-only cleaning (jump detection, Hampel, interpolation, SG + moving average).
7. **Temperature segment detection**
   - `find_increasing_temperature_segments_MT`
   - `find_decreasing_temperature_segments_MT`
8. **Plotting / figure generation**
   - `Plots_MT` (per-field curves)
   - `Plots_MT_combined` (combined panel)
   - `Plots_MT_Tcuts` (temperature cuts)
   - `plot_MT_2D_maps_segments` (2D segment maps)
   - Debug helpers for visualized segment checks
9. **Analysis / fitting utility**
   - `analysisAndFitt_MT` exists but is not wired into `MT_main`; appears legacy/misaligned (uses `HC_table` naming).

## Notable dependency findings
- Missing callable implementation: `plot_MT_2D_maps(...)` is invoked in one branch but no definition exists.
- External non-MT dependencies are required (`close_all_except_ui_figures`, `extract_growth_FIB`, `chooseAutoScalePower`) from `General ver2/`.

---

## 2) Canonicalization blockers (explicit)

## Hard blockers
- Absolute hardcoded paths (`L:\...`) in `MT_main`.
- Script-embedded parameters with no external config contract or snapshot.
- Silent/partial import behavior (`importFiles_MT` catches per-file errors and continues).
- Metadata provenance depends on filename regex (field, mass), not explicit measured metadata contract.
- No run artifact contract: missing `run_dir`, `run_manifest.json`, `execution_status.csv`, required tables/reports.
- Output is figure-centric; no canonical intermediate/final machine-readable tables.
- No cleaning/segmentation audit tables.
- Missing function target `plot_MT_2D_maps` in active code path.

## Architecture misalignment blockers
- No manifest/fingerprint/validation behavior aligned with repository trust model.
- No strict failure semantics (`catch -> status -> rethrow`) at entrypoint level.
- No artifact-first output package.

---

## 3) Proposed canonical MT pipeline contract (design proposal)

## Raw inputs (required)
- `input_dir` (folder containing source `.DAT` files)
- `file_pattern` (default `*.DAT`)
- `instrument_mode` (`auto` | `MPMS` | `PPMS`)
- Optional explicit metadata file (`sample_metadata.csv/json`) for mass, sample ID, growth/FIB IDs

## Required config fields
- `run.label`
- `units.mode` (`raw`, `per_mass`, `per_co`)
- `plot.quantity` (`M`, `M_over_H`)
- Cleaning params (`tempJump_K`, `magJump_sigma`, Hampel window/sigma, interpolation gap, SG/moving average params, `field_threshold`)
- Segmentation params (`delta_T`, `min_temp_change`, `min_temp_time_window_change`, `temp_rate`, `temp_stabilization_window`, `min_segment_length_temp`)
- Failure policy (`strict_import=true`, `min_required_files`, `fail_on_missing_columns=true`)

## Canonical intermediate tables (minimum)
- `tables/mt_file_inventory.csv`
  - file, parser selected, field_Oe, mass_mg, parse provenance, import status
- `tables/mt_raw_summary.csv`
  - per-file lengths, min/max T/H/M, NaN counts
- `tables/mt_cleaning_audit.csv`
  - removed_by_temp_jump, removed_by_mag_spike, hampel_replaced_count, interpolated_count, long_gap_count
- `tables/mt_segments.csv`
  - file_id, segment_type (inc/dec), segment_id, start_idx, end_idx, t_start_s, t_end_s, T_start_K, T_end_K
- `tables/mt_curve_points.csv` (optional large table with schema lock)
  - file_id, idx, T_K, H_Oe, M_raw_emu, M_clean, M_scaled, segment_id, segment_type

## Canonical final observables
- `tables/mt_observables.csv`
  - per field and segment: slope metrics, mean M(T window), hysteresis delta (FCW-ZFC), coverage stats
- optional run-root `observables.csv` index if integrating into cross-module observable layer

## Diagnostic figures
- `figures/mt_combined_curves.png`
- `figures/mt_per_field_grid.png`
- `figures/mt_2d_zfc.png`, `figures/mt_2d_fcw.png`, `figures/mt_2d_diff.png`
- `figures/mt_temperature_cuts.png`
- `figures/mt_segmentation_debug.png`

## Status/report outputs
- `execution_status.csv` (run-root, strict schema)
- `reports/mt_pipeline_audit.md` / `reports/run_summary.md`
- `run_manifest.json` with script hash + git commit + environment fingerprint

## Strict failure behavior
- Preflight fail if no inputs, ambiguous parser, missing required columns, or unresolved mandatory dependency.
- Import stage must emit per-file status; if failed files exceed threshold -> fail run.
- No silent catch; enforce `catch ME -> write FAILED status -> rethrow(ME)`.

---

## 4) Comparison to repository architecture

Repository architecture requires run-based results (`results/<experiment>/runs/run_<timestamp>_<label>/`), mandatory manifest/status artifacts, and artifact-first outputs (figures/tables/reports/review). Current `MT ver2` module does not implement these contracts and remains pre-canonical script-style analysis. Therefore it is not currently aligned with the manifest/fingerprint/validation/trust model.

### Verdicts (explicit)
- **MT_ENTRYPOINT_FOUND:** YES (`MT ver2/MT_main.m`, non-canonical script entry)
- **MT_CANONICAL_READY:** NO
- **MT_REQUIRES_NEW_ENTRYPOINT:** YES
- **MT_IMPORT_STRICTNESS_OK:** NO
- **MT_METADATA_PROVENANCE_OK:** NO
- **MT_OUTPUT_CONTRACT_EXISTS:** NO
- **MT_SAFE_TO_IMPLEMENT_CANONICAL_WRAPPER:** YES (after contractization + dependency gap closure)

## Why wrapper implementation is safe next (design judgment)
Safe because the core transformation logic (import, cleaning, segmentation, plotting) is already modularized into callable helper functions. Main risks are operational contracts, not scientific algorithm absence. The only blocking functional defect to close first is missing `plot_MT_2D_maps` branch target or branch removal.

