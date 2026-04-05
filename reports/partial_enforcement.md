# Partial Run Enforcement

## Scope
- Single-pass static scan of MATLAB files for `load(`, `readtable(`, and `resolve_results_input_dir`.
- Runtime guard policy: all `load`/`readtable` paths under `results/*/runs/run_*` are blocked when run_status is `PARTIAL`.
- Auto-discovery policy: resolver/latest-run utilities allow only CANONICAL runs.

## Repository Verdicts
- PARTIAL_BLOCKED: YES
- LOADER_SAFE: YES

## Counts
- Matches: 708
- Target run-tree loaders: 571
- Unsafe target loaders: 0
- Target loaders without PARTIAL blocking: 0

## Implemented Guards
- Global runtime wrappers: `readtable.m`, `load.m` (block PARTIAL for run-scoped results paths).
- Centralized status helper: `tools/get_run_status_value.m`.
- Canonical-only auto selection and PARTIAL hard block in `tools/resolve_results_input_dir.m` and `tools/getLatestRun.m`.
- Canonical-only ingestion in `tools/load_observables.m` and explicit-run guard in stage1 canonical scripts.
- New run contexts now include `run_status.csv` via `Aging/utils/createRunContext.m`.
