# Infrastructure overview (Phase 5A.3)

This document summarizes **discovered** infrastructure components by filename and path patterns only (no internal logic review). Types used: `EXECUTION`, `VALIDATION`, `IO`, `UTILITY`, `UNKNOWN`.

## Discovery scope

Patterns and locations searched:

- Wrappers: `run_*.bat`, `run_*.m`, especially `*_wrapper.m` at repository root
- Validators: paths/names containing `validator`, `validate`
- Guards: paths/names containing `guard`, and `assert*` helpers under `Switching/utils`
- Run context: `createRunContext`, `*RunContext*`, `switchingCanonicalRunRoot`, `allocateSwitchingFailureRunContext`, `writeSwitchingExecutionStatus`
- Execution scripts: `scripts/`, root and subtree `run_*.m` aggregates
- `tools/` tree (scripts, MATLAB helpers, subfolders)
- Infra-like helpers: repo-level `repo_state_validator.m`, `tests/infrastructure/`, `Aging/pipeline/stage0_setupPaths.m`, `docs/templates/matlab_run_template.m`

## High-level counts

| Pattern | Approximate count | Notes |
|--------|-------------------|--------|
| `run_*.m` (entire repo) | 161 | See `tables/infrastructure_components_map.csv` for directory aggregates |
| `run_*.bat` | 1 | `tools/run_matlab_safe.bat` |
| `tools/` files (excluding `figure_repair/_validation_tmp`) | 80+ | Mix of PS1/Python/MATLAB/JSON/txt |
| Root `*_wrapper.m` | 17 | Thin wrappers delegating to `analysis/` |

## Primary buckets

1. **EXECUTION** — Batch/shell entry (`run_matlab_safe.bat`), orchestration PS1/Python under `tools/`, root `*_wrapper.m`, and `run_*.m` entry scripts under `Switching/analysis/`, `analysis/`, `Relaxation ver3/`, and repo root.
2. **VALIDATION** — `repo_state_validator.m`, `tools/validate_matlab_runnable.ps1`, `tools/pre_execution_guard.ps1`, `Switching/utils/assertModulesCanonical.m`, `Switching/utils/assertSwitchingRunDirCanonical.m`, figure repair validation suite, `tests/infrastructure/*` probes.
3. **IO** — Load/save/export helpers (`load_observables.m`, `save_run_*.m`, `export_observables.m`, `resolve_results_input_dir.m`, `write_execution_marker.m`, `writeSwitchingExecutionStatus.m`, manifests).
4. **UTILITY** — Run context constructors (`createRunContext.m`, `createSwitchingRunContext.m`), path/root helpers (`switchingCanonicalRunRoot.m`, `getResultsDir.m`, `init_run_output_dir.m`, `run_artifact_path.m`), directory helpers (`ensure_dir.m`), pipeline path bootstrap (`stage0_setupPaths.m`).
5. **UNKNOWN** — Legacy or ad-hoc locations (e.g. `junk/`, `tmp/`) and artifacts mixed into `tools/` (probe logs, cached JSON).

The `scripts/` folder has a single `run_*.m` entry in this map (`scripts/run_adversarial_observable_search.m`); it is excluded from the “miscellaneous locations” aggregate row so directory totals stay consistent.

## Machine-readable map

Detailed rows: `tables/infrastructure_components_map.csv` (100 rows: directory aggregates, explicit infra helpers, full `tools/` inventory, guard/validator-named items, and selected `validate*` paths).  
Status flag: `tables/infrastructure_map_status.csv` (`INFRASTRUCTURE_DISCOVERED=YES`).
