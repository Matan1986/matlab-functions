# Phase 4.2 — Failure path contract (Switching)

## Summary

Failure handling for the **canonical Switching runner** `Switching/analysis/run_switching_canonical.m` is aligned with the Phase 4.2 contract: a canonical `run_dir`, a single authoritative final row in `execution_status.csv` (column `EXECUTION_STATUS`, values `SUCCESS` or `FAILED` for terminal outcomes; `FINAL_STATUS=FAILED` in task language means that column set to `FAILED`), and no silent fallback when allocating a failure run.

## Code changes (Switching only)

1. **`Switching/utils/writeSwitchingExecutionStatus.m`**  
   - Writes `execution_status.csv` using the fixed five-column schema.  
   - **Final** outcomes (`isFinal=true`): write `execution_status.tmp.csv`, then replace `execution_status.csv` so the final file is not left half-written.  
   - **Checkpoints** (`isFinal=false`): ordinary overwrite for `PARTIAL` rows.

2. **`Switching/utils/allocateSwitchingFailureRunContext.m`**  
   - Thin wrapper around `createSwitchingRunContext` for failure-only allocation (full manifest + fingerprints).  
   - No alternate directory creation.

3. **`Switching/analysis/run_switching_canonical.m`**  
   - Success and checkpoint status lines use `writeSwitchingExecutionStatus` (final flag `false` for `PARTIAL`, `true` for `SUCCESS`).  
   - Catch path: if no `run_dir` yet, allocates via `allocateSwitchingFailureRunContext` with explicit `fingerprint_script_path` and `dataset`; **removed** the previous silent `catch` that created `run_failure_*` without `createRunContext`.  
   - If failure allocation throws, raises `run_switching_canonical:FailureRunAllocation` including the original error message (not a silent exit).  
   - Failure terminal status: `writeSwitchingExecutionStatus(..., {'FAILED'}, ..., isFinal=true)` before `rethrow(ME)`.

## Status flags

See `tables/failure_path_status.csv`. `FAILURE_PATH_ENFORCED=YES` when all component flags are `YES` for this scope.

## Scope

Enforcement is implemented for **`run_switching_canonical.m`** and the two helpers under **`Switching/utils`**. Other Switching analysis scripts are unchanged in this phase (minimal diff; no science edits).

## Artifacts

- `tables/failure_path_contract.csv` — requirement-to-implementation map  
- `tables/failure_path_status.csv` — consolidated flags  
- `reports/failure_path_contract.md` — this file  
