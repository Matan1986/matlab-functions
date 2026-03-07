# Repository Structure

This repository separates code, run entry points, tests, and generated artifacts.

## Top-level directories

- `Aging/` - Aging analysis module (pipeline, models, diagnostics, utils, verification).
- `Relaxation ver3/` - Relaxation analysis module.
- `Switching ver12/` - Switching analysis module.
- `runs/` - launch scripts and local path adapters for running pipelines.
- `tests/` - test code and test harnesses (not generated outputs).
- `results/` - all generated outputs (figures, tables, diagnostics, logs).

## Repository philosophy

- Modules contain analysis code.
- `runs/` contains execution entry points and local environment wrappers.
- `tests/` contains testing code only.
- `results/` contains runtime outputs only.

## Results structure

When a run context is active (initialized in `Aging/pipeline/stage0_setupPaths.m`), outputs are isolated per run:

- `results/<experiment>/runs/run_<timestamp>_<label>/<analysis>/...`

Run naming:

- Preferred: `run_<timestamp>_<label>` (for example `run_2026_03_07_184500_MG119_AF_decomp_test`)
- Fallback: `run_<timestamp>` when no label is provided

Label sources (first non-empty, sanitized):

- `cfg.runLabel`
- `cfg.analysisLabel`
- `cfg.dataset`
- `cfg.datasetName`

Run reproducibility files are created at the run root:

- `run_manifest.json` (includes `run_id`, `timestamp`, `experiment`, `label`, `git_commit`, `matlab_version`, `host`, `user`)
- `config_snapshot.m` (configuration snapshot at run start)
- `log.txt`
- `run_notes.txt` (researcher notes template; created empty if missing)

Without an active run context, legacy output behavior is preserved:

- `results/<experiment>/<analysis>/...`

## Aging outputs (analysis folders)

- `decomposition/`
- `svd_pca/`
- `baseline_tests/`
- `separability/`
- `diagnostics_misc/`
- `debug_runs/`

## Diagnostics placement

Diagnostics scripts live inside each module, for example:

- `Aging/diagnostics/`

They should write outputs under `results/` via module utilities (for Aging: `Aging/utils/getResultsDir.m`).

## Current template status

Aging is currently the first fully organized module and serves as the template for refactoring other modules to the same structure.

## Developer tools

- `tools/list_runs.m` - Read-only utility to list runs and manifest metadata from `results/<experiment>/runs/`.
- `tools/load_run_manifest.m` - Helper to read a run's `run_manifest.json` by path.
