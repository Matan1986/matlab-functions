# Analysis contamination risk audit

**Date:** 2026-04-04  
**Scope:** All `Switching/analysis/**/*.m` files (103 files).  
**Method:** Read-only static inspection (pattern scan + spot checks). No MATLAB execution, no code edits.

**References:** `docs/repo_execution_rules.md`, `docs/switching_dependency_boundary.md`, `tables/module_canonical_status.csv`, `Switching/utils/assertModulesCanonical.m`.

---

## Summary verdict

| Field | Value |
|-------|--------|
| **CONTAMINATION_RISK** | **HIGH** |
| **ANALYSIS_LAYER_SAFE** | **NO** |

Rationale: broad `addpath(genpath(Aging))` usage conflicts with the documented Switching boundary (Aging restricted to `Aging/utils` for canonical-style wiring). Many analyses read shared `tables/*.csv`, legacy `Switching ver12`, hard-coded absolute paths, and Relaxation/Aging `results/` trees without any `modules_used` declaration and without `assertModulesCanonical` (except a single script, and it only asserts `Switching`). The module registry marks **Relaxation** and **Aging** as **NON_CANONICAL**, so even ideal enforcement via `assertModulesCanonical` cannot certify those modules as canonical today.

---

## 1. DATA IMPORT SOURCES (cross-module)

**CROSS_MODULE_DATA_USAGE**

- **Relaxation data:** Scripts that reference `results/relaxation` (e.g. `switching_ridge_curvature_analysis.m` loads `temperature_observables.csv` from a Relaxation run dir); dedicated Relaxation tooling under `Switching/analysis` (`run_relaxation_*.m`, `run_PT_*_relaxation_mapping.m`, `find_relaxation_time_series.m`, `locate_relaxation_raw_runs.m`, `inspect_relaxation_data_structure.m`, `run_extract_tau_from_relaxation.m`, `run_build_relaxation_dataset*.m`, etc.); `run_kappa2_kww_shape_test.m` reads `tables/relaxation_full_dataset.csv`; hard-coded legacy Relaxation run IDs/paths under `results/relaxation/runs/run_legacy_*` in several scripts.
- **Aging data:** `run_alpha_physical_validity_test.m` reads `results/aging/runs/.../table_clock_ratio.csv`; `inspect_relaxation_data_structure.m` documents scanning `results/aging` (and switching); multiple `run_aging_*.m` and trajectory tests consume shared `tables/` rows tied to aging analyses (e.g. `R_vs_state.csv`, `alpha_structure.csv`).
- **Shared tables:** 57/103 files reference `fullfile(..., 'tables', ...)` (repo-root `tables/` CSV SSOT), including closure, O2, phi, kappa, width, and decomposition outputs.
- **Legacy outputs / non-canonical backend:** `run_switching_canonical.m`, `switching_alignment_audit.m`, and `experimental/run_switching_physical_baseline_model.m` add `Switching ver12`; `analyze_phi_kappa_canonical_space.m` adds `General ver2` and `Tools ver1`; numerous scripts depend on prior Switching canonical run artifacts via `switchingCanonicalRunRoot`.

If no cross-module inputs were used, this section would be **NONE** — it is **not** NONE.

---

## 2. IMPLICIT DEPENDENCIES

**IMPLICIT_CROSS_MODULE_LINKS**

- **Shared `tables/`:** Repo-root CSVs used as inputs/outputs for multiple experiments (closure metrics, O2 pipeline, alpha/kappa tables, etc.).
- **Shared utils / infra:** `Aging/utils/createRunContext` (and `Switching/utils/createSwitchingRunContext`); `Switching/utils/switchingCanonicalRunRoot` and related guards; `tools/` (`resolve_results_input_dir`, `getLatestRun`, figure helpers).
- **Shared paths:** `results/switching`, `results/relaxation`, `results/aging`, `results/cross_experiment`; hard-coded `C:/Dev/matlab-functions/...` strings in 27 files (machine and clone path coupling).
- **Path pollution:** `addpath(genpath(fullfile(repoRoot,'Aging')))` in 49 files — pulls non-utils Aging code onto the path (explicitly discouraged for Switching in `docs/switching_dependency_boundary.md`).

---

## 3. UNDECLARED MODULE USAGE

**UNDECLARED_MODULE_USAGE**

- **ALL analysis and runner scripts:** There are **zero** assignments to `modules_used` anywhere under `Switching/analysis` (repository-wide, only the comment example inside `assertModulesCanonical.m` references `modules_used`).
- Therefore any script that consumes Relaxation, Aging, shared `tables/`, or legacy backends does so **without** an explicit module list in code.

---

## 4. ENFORCEMENT GAPS

**ANALYSIS_ENFORCEMENT_GAPS**

- Only **`Switching/analysis/analyze_phi_kappa_canonical_space.m`** calls `assertModulesCanonical({'Switching'})`.
- **102/103** files do **not** call `assertModulesCanonical`.
- **Registry constraint:** `tables/module_canonical_status.csv` lists **Relaxation** and **Aging** as **NON_CANONICAL**, so scripts that genuinely require those modules cannot pass `assertModulesCanonical` including them until the registry (or module status) changes — even if declarations were added.

Scripts that especially warrant review (non-exhaustive): any file with `genpath(Aging)`, `Switching ver12`, `results/relaxation` or `results/aging`, `cross_experiment`, or repo `tables/` inputs — see `tables/analysis_contamination_audit.csv` per-file flags.

---

## 5. CONTAMINATION RISK LEVEL

**CONTAMINATION_RISK = HIGH**

Drivers: widespread non-canonical path setup (`genpath(Aging)`), legacy backend and extra version trees on the path, shared mutable `tables/` inputs, absolute-path coupling, and cross-experiment `results/` reads — combined with **no** `modules_used` and **almost no** `assertModulesCanonical` enforcement.

---

## Artifacts

| Artifact | Purpose |
|----------|---------|
| `tables/analysis_contamination_audit.csv` | Per-file flags: `FILE_ROLE`, `RISK_TIER`, path/import patterns (0/1). |
| `tables/analysis_contamination_status.csv` | Aggregated metrics and verdict fields. |

**Pattern notes:** Automated regex tagging can misclassify edge cases (e.g. `relaxation` in a run ID string vs Relaxation module data). Treat per-file rows as screening indicators, not proof of runtime behavior.

---

## STATUS

**ANALYSIS_LAYER_SAFE = NO**

The analysis layer can still be influenced by non-canonical modules (Aging beyond utils, Relaxation and Aging pipelines via `results/` and `tables/`, legacy Switching, and path shadowing from `genpath`).
