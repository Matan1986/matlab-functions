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

- `results/aging/` - outputs from Aging analyses.
  - `decomposition/`
  - `svd_pca/`
  - `baseline_tests/`
  - `separability/`
  - `diagnostics_misc/`
  - `debug_runs/`
- `results/relaxation/` - outputs from Relaxation analyses.
- `results/switching/` - outputs from Switching analyses.
  - `test_logs/`
- `results/cross_analysis/` - cross-module outputs.
  - `aging_vs_switching/`
  - `aging_vs_relaxation/`

## Diagnostics placement

Diagnostics scripts live inside each module, for example:

- `Aging/diagnostics/`

They should write outputs under `results/` via module utilities (for Aging: `Aging/utils/getResultsDir.m`).

## Current template status

Aging is currently the first fully organized module and serves as the template for refactoring other modules to the same structure.
