# Run System

This document is the authoritative reference for the repository run-tracking system.

## Architecture

Run initialization is centralized in module `stage0_setupPaths`.

- Run context is created by `createRunContext`.
- Active run context is stored in MATLAB root appdata:
  - `setappdata(0, 'runContext', runCtx)`
- Output paths are resolved through `getResultsDir(experiment, analysis, ...)`.

This architecture ensures reproducible, run-scoped outputs and avoids accidental overwrites.

## Run directory structure

Each run is created under:

`results/<experiment>/runs/run_<timestamp>_<label>/`

Example:

`results/aging/runs/run_2026_03_07_184500_MG119_AF_decomp_test/`

Run folder contents:

- `run_manifest.json`
- `config_snapshot.m`
- `log.txt`
- `run_notes.txt`
- analysis output folders (for example `decomposition/`, `svd_pca/`, `baseline_tests/`)

## Run manifest

`run_manifest.json` stores metadata such as:

- `run_id`
- `timestamp`
- `experiment`
- `label`
- `git_commit`
- `matlab_version`
- `host`
- `user`
- `dataset` (when available)

## Config snapshot

`config_snapshot.m` stores the run configuration captured at run start.

- Preferred path: MATLAB script snapshot of `cfg`.
- Fallback path: JSON snapshot reconstructed into `cfg`.

Goal: allow reconstruction of run configuration for reproducibility.

## Run index

Each experiment has:

`results/<experiment>/run_index.csv`

Columns:

- `run_id`
- `timestamp`
- `label`
- `experiment`
- `dataset`
- `git_commit`

The index is updated only when a **new run** is created.

## Latest run pointer

Each experiment has:

`results/<experiment>/latest_run.txt`

This file contains only the latest `run_id` and is updated when a **new run** is created.

## Developer tools

Tools are located under `tools/`:

- `tools/list_runs.m` - list runs and key manifest metadata.
- `tools/load_run_manifest.m` - load and parse a run manifest by path.
- `tools/getLatestRun.m` - read `latest_run.txt` and return latest `run_id`.
- `tools/openLatestRun.m` - open the latest run folder for an experiment (Windows) or print its path (non-Windows).

## Protection rules

The following rules must be preserved:

- Run initialization remains in `stage0_setupPaths`.
- Run context is created by `createRunContext`.
- Active run context is stored in root appdata.
- Outputs are routed via `getResultsDir`.
- New direct writes to `results/<experiment>` should not be introduced.
