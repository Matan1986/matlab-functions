# Run validity classification layer (detection only)

## What classification detects

The layer writes `run_validity.txt` in each Switching `run_dir` produced by `Switching/analysis/run_switching_canonical.m`. It records one of:

- **CANONICAL** — `createRunContext` resolves to `Aging/utils/createRunContext.m` for the active repo, `run_dir` is under `results/switching/runs`, `execution_status.csv` is present, `enforcement_checked` is true, and multi-module cases are consistent with that flag.
- **NON_CANONICAL** — `execution_status.csv` exists and the run directory is usable, but at least one of the above canonical signals fails (for example unexpected `createRunContext` resolution, run folder not under the switching runs tree, or enforcement not fully evaluated).
- **INVALID** — `run_validity.txt` is written only when the run directory exists but `execution_status.csv` is missing (for example a partial or broken signaling path). If there is no writable `run_dir`, no file is produced.

Signals are evaluated locally at write time; they do not change analysis results or status writers.

## What it does NOT enforce

- It does **not** block MATLAB, alter the wrapper, or change `execution_status.csv`, `createRunContext`, `createSwitchingRunContext`, `assertModulesCanonical`, or validators.
- It does **not** throw errors or stop the script; failures to classify or write are swallowed so runs always behave as before aside from the optional text file.

## Why this preserves a non-blocking design

Classification is a **read-only annotation**: it observes path resolution, directory layout, and flags already computed in the script, then writes a small text artifact. Execution outcomes and science outputs are unchanged; the file exists for machines and humans to audit drift without gating runs.

## Examples of canonical vs non-canonical runs

- **Canonical** — Full successful `run_switching_canonical` run: `createRunContext` matches the repo copy, outputs land under `results/switching/runs/...`, checkpoints and final `execution_status.csv` exist, and module enforcement has been evaluated (`enforcement_checked` true). `RUN_VALIDITY=CANONICAL`, `REASON=All canonical conditions satisfied`.
- **Non-canonical** — Run completes and writes status, but `run_dir` is not under `results/switching/runs` (for example a relocated or manually pointed output tree), or `createRunContext` resolves to a different file than this repository’s `Aging/utils` copy. `RUN_VALIDITY=NON_CANONICAL` with a short semicolon-separated reason line.
- **Invalid signaling** — A directory exists for the run but `execution_status.csv` was never written. `RUN_VALIDITY=INVALID`, `REASON=Missing execution_status.csv`.
