# results/aging README

## Purpose
- `results/aging/` is the Aging run-lineage layer.
- It stores run-scoped execution evidence, not final governance conclusions.

## Run container contract
- Canonical run root: `results/aging/runs/run_<timestamp>_<label>/`
- Each run container is expected to carry lineage artifacts such as:
  - `run_manifest.json`
  - `execution_status.csv` (or equivalent status artifact)
  - `log.txt` (or equivalent runtime log)
  - config/entrypoint snapshot (for reproducibility)
  - run-scoped `tables/`, `reports/`, `figures/` subfolders when emitted
- Run folders are lineage containers and must not be treated as cleanup staging.

## debug_runs semantics
- `results/aging/debug_runs/` is for debugging/probe outputs and intermediate diagnostics.
- `debug_runs` outputs are non-canonical by default.
- Nothing in `debug_runs` is auto-promoted; explicit promotion rules apply.

## Current vs legacy separation
- Current run lineage: `results/aging/runs/`
- Debug/probe lineage: `results/aging/debug_runs/`
- Legacy lineage: `results_old/aging/` (write-closed, historical reference only)

## Promotion rules
- Promote to durable layers only with verified lineage and scope-safe evidence:
  - `tables/aging/`
  - `reports/aging/`
  - `figures/aging/`
- Required promotion metadata:
  - source run path or source script
  - canonicality/diagnostic/replay status
  - Aging-only scope confirmation

## Safety rule
- No movement or deletion from `results/aging/` without lineage checks and consumer checks.
