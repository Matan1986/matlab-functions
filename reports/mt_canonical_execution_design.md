# MT Stage 1.6 Canonical Execution Design Patch (Post-Review)

Date: 2026-04-24  
Scope: design-only patch of canonical execution definition before implementation.

## 1. Future canonical runnable script name/location

Canonical runnable script target:
- **Path:** `runs/run_mt_canonical.m`
- **Experiment key for run context:** `mt`
- **Run label source:** `cfg.runLabel`

Path decision note:
- This patch removes the unverified claim that `scripts/run_*.m` is the repository convention.
- Stage 1.6 design now prefers `runs/run_mt_canonical.m` as requested, pending implementation-phase confirmation against broader repository governance.

## 2. Required repository execution shape

Future script must comply with `docs/templates/matlab_run_template.m` and execution rules:

1. **Pure script rule**
   - No local/nested functions in `runs/run_mt_canonical.m`.

2. **ASCII-only rule**
   - Enforce `NON_ASCII_COUNT = 0` before execution.

3. **Template structure alignment**
   - Top probe at start: write `execution_probe_top.txt`.
   - `clear; clc;` at top.
   - Build `repoRoot`; add needed paths.
   - `run = createRunContext('mt', cfg);`
   - Create run-scoped `tables/`, `reports/`, `figures/`.
   - Write `execution_status.csv` in success and failure paths.

4. **Mandatory catch semantics**
   - `catch ME -> write FAILED execution_status.csv -> rethrow(ME)`.

5. **Run artifact ownership**
   - All MT outputs written only under `run.run_dir`.

## 3. Raw vs processed vs derived contract for canonical script

- **Raw truth table (`tables/mt_points_raw.csv`)**:
  `file_id,row_id,time_s,T_K,H_Oe,M_raw_emu,source_file,parser,metadata_provenance`.

- **Processed truth table (`tables/mt_points_clean.csv`)**:
  `file_id,row_id,time_s,T_K,H_Oe,M_raw_emu,M_clean_emu,M_smooth_emu,clean_mask,clean_stage`.

- **Derived table (`tables/mt_points_derived.csv`)**:
  `M_over_H`, `M_per_mass`, `M_per_Co`, segment labels, and secondary observables.

Rule: derived variables never overwrite raw/clean truth columns.

## 4. Helper-function safety classification

### Safe to call (with wrapper-side guards)
- `getFileList_MT` (discovery; requires provenance hardening in wrapper outputs).
- `detect_MT_file_type` (usable but must validate all files, not only first).
- `importFiles_MT` (usable only if wrapper enforces strict failure table and threshold).
- `compute_unitsRatio_MT` (for derived scaling only).
- `clean_MT_data` (usable if wrapper persists raw+clean and cleaning audit).
- `find_increasing_temperature_segments_MT` / `find_decreasing_temperature_segments_MT` (usable with time-axis validation).
- Plot helpers (`Plots_MT`, `Plots_MT_combined`, `Plots_MT_Tcuts`, `plot_MT_2D_maps_segments`) as diagnostics only.

### Forbidden/repair-required branches before canonical script signoff
- `MT_main` branch calling `plot_MT_2D_maps(...)` when `~plotAllCurvesOnOneFigure` (missing function target).
- Any branch that silently continues after import failure without status elevation.
- Any branch that emits figures only without tabular artifacts.

## 5. Pre-implementation blockers to resolve or gate

1. Enforce strict import behavior with explicit per-file status and fail threshold.
2. Replace filename-only metadata trust with explicit provenance and optional metadata file override.
3. Add cleaning audit and segmentation audit tables as first-class artifacts.
4. Add time-axis regularity check prior to segmentation expected-rate logic.
5. Gate or remove dead `plot_MT_2D_maps` call path.

## 6. Implementation boundary for first canonical diagnostic script

The **first** canonical script at `runs/run_mt_canonical.m` is a diagnostic canonicalization step, not a production-validated physics release.

Required boundary:
- Must preserve raw/clean/derived separation.
- Must emit diagnostic artifacts and blocker flags.
- Must not claim final validated MT physics observables if unresolved blockers remain.

Interpretation of readiness:
- `MT_READY_FOR_FIRST_DIAGNOSTIC_CANONICAL_SCRIPT=YES` means implementation may begin for diagnostic canonical execution.
- `MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE=NO` means production signoff remains blocked pending physics/robustness closure.

## 7. Execution verdicts (Stage 1.6 patched)

- `MT_EXECUTION_CONTRACT_DEFINED=YES`
- `MT_TEMPLATE_COMPLIANCE_PATH_DEFINED=YES`
- `MT_CANONICAL_SCRIPT_PATH_VERIFIED=YES`
- `MT_CANONICAL_SCRIPT_PATH=runs/run_mt_canonical.m`
- `MT_READY_FOR_FIRST_DIAGNOSTIC_CANONICAL_SCRIPT=YES`
- `MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE=NO`
- `MT_READY_FOR_CANONICAL_SCRIPT_IMPLEMENTATION=NO` (interpreted as NOT ready for production canonical release)
