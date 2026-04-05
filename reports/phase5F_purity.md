# Phase 5F — Structural cleanup (purity only)

**Scope:** Switching canonical execution path and listed helpers (`run_switching_canonical.m`, `createRunContext.m`, `createSwitchingRunContext.m`, `writeSwitchingExecutionStatus.m`, `tools/write_execution_marker.m`).

## Violations detected

| # | Location | Description |
|---|----------|-------------|
| 1 | `tools/write_execution_marker.m` (removed block) | **GLOBAL_WRITE = YES:** When `run_dir` could not be resolved or did not exist as a directory, the function appended timestamped lines to **`tables/runtime_execution_markers_fallback.txt`** at the repo root (and could `mkdir` repo `tables/`). That file is shared across runs, not under `run_dir`, and is not part of the run manifest contract. |

### Classification (violation 1)

- **Purpose:** Observability only (execution timeline markers); non-authoritative vs `execution_status.csv`.
- **Required for execution correctness?** NO.
- **Part of execution contract?** NO (markers are auxiliary; contract is `writeSwitchingExecutionStatus` and manifest under `run_dir`).
- **Affects numerical / scientific results?** NO.

### Other files (static review)

- **`Switching/analysis/run_switching_canonical.m`:** All explicit IO targets `run_dir` (or failure `runDirForStatus` under `results/switching/runs/...`). No repo-root table writes.
- **`Aging/utils/createRunContext.m`:** Writes only under `run.run_dir` (manifest, snapshot, log, notes). `setappdata(0, ...)` is process state, not a filesystem global write.
- **`Switching/utils/createSwitchingRunContext.m`:** No direct writes; delegates to `createRunContext`.
- **`Switching/utils/writeSwitchingExecutionStatus.m`:** Requires an existing `run_dir`; writes `execution_status.csv` only there.

## Fix applied (purity only)

- **`tools/write_execution_marker.m`:** Removed the repository `tables/` fallback branch. If `run_dir` cannot be resolved or the directory is missing, the function now **does not write** (still wrapped in `try/catch`, still never throws). Markers when resolvable still append to `<run_dir>/runtime_execution_markers.txt` unchanged.

This is a **disable fallback path** change: no new tracking, no change to `execution_status.csv`, manifest, or analysis code paths.

## Confirmation — no intended behavior change (contract / outputs)

- **Same manifest / fingerprint / `execution_status` / result tables:** The Switching canonical script calls `write_execution_marker` only **after** `createSwitchingRunContext` (so appdata-based `run_dir` resolution applies for unqualified calls), or passes **`runDirForStatus`** on the failure marker. No change to `createRunContext`, `writeSwitchingExecutionStatus`, or pipeline computations.
- **Observability:** Successful canonical runs still populate `<run_dir>/runtime_execution_markers.txt` as before. The only removed behavior is appending to **`tables/runtime_execution_markers_fallback.txt`** when no `run_dir` write target exists (edge / non-canonical paths).

*Runtime MATLAB re-execution was not performed in this workspace session; conclusions follow from static analysis of call order and file paths.*

## Run-scoped isolation (after fix)

- **No unintended global filesystem writes** from `write_execution_marker` (no repo `tables/` marker fallback).
- **RUN_PURITY = ACHIEVED** for the reviewed Switching canonical stack and `write_execution_marker` helper as scoped.
