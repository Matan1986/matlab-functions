# Runtime truth classification (Switching canonical)

This document describes the **runtime marker** layer and the **post-run classifier** used to label canonical Switching runs as `SUCCESS`, `PARTIAL`, or `FAIL` without changing scientific logic or pipeline outputs.

## Marker design

- **Path:** `run_switching_canonical.m` adds `repoRoot/tools` after `restoredefaultpath` so `write_execution_marker` remains on the MATLAB path (the entry script calls `restoredefaultpath`, which clears earlier `addpath` entries).
- **Where:** Markers append to `runtime_execution_markers.txt` under the active `run_dir` when `createRunContext` has published run context to MATLAB appdata. If no `run_dir` is available yet, markers append to `tables/runtime_execution_markers_fallback.txt` at the repo root (non-blocking).
- **Format:** Each line is `timestamp marker_name` (UTC-agnostic local clock; deterministic ordering per run).
- **Names:** `ENTRY`, `STAGE_START_PIPELINE`, `STAGE_AFTER_PROCESSING`, `STAGE_BEFORE_OUTPUTS`, `STAGE_AFTER_OUTPUTS`, `COMPLETED`, `FAILED`.
- **ENTRY:** Written at script start (may hit fallback only). After `createRunContext` creates `run_dir`, `ENTRY` is written again so classification tied to `run_dir` always sees an `ENTRY` line in `runtime_execution_markers.txt`.

## Classification logic (`tools/classify_run_status.m`)

Let `entry` / `completed` / `failed` mean the corresponding marker name appears at least once in `run_dir/runtime_execution_markers.txt`. Let artifact checks be:

- `execution_status.csv` exists under `run_dir`
- At least one `*.csv` exists under `run_dir/tables/`
- At least one `*.md` exists under `run_dir/reports/`

Then:

| Condition | Status |
|-----------|--------|
| No `ENTRY` | `FAIL` |
| `ENTRY` and no `COMPLETED` | `PARTIAL` |
| `COMPLETED` but artifact checks not all pass | `PARTIAL` |
| `COMPLETED` and all artifact checks pass | `SUCCESS` |

The classifier writes one row per call to repo `tables/runtime_classification.csv` with columns: `run_id`, `status`, `entry`, `completed`, `failed`, `artifact_ok` (YES/NO).

## Example scenarios

1. **Crash before entry:** No script-side markers; no `run_dir` from this run. Classifying a non-existent or wrong path yields `FAIL` (no `ENTRY` in that `run_dir`).
2. **Crash mid-run:** `ENTRY` present, no `COMPLETED` -> `PARTIAL`. `FAILED` may appear if the catch path resolved a `run_dir` and wrote the failure marker.
3. **Missing outputs:** `COMPLETED` written only after main outputs and status; if artifacts are incomplete while still classifying an old folder, `artifact_ok` is NO -> `PARTIAL`.
4. **Full success:** `ENTRY` and `COMPLETED` in `runtime_execution_markers.txt`, plus `execution_status.csv`, at least one CSV under `tables/`, at least one MD under `reports/` -> `SUCCESS`.

## Relation to execution signaling

Markers are **additional** observability. Existing contracts (`execution_probe_top.txt`, `execution_status.csv`, `run_dir`) are unchanged in meaning; the classifier uses markers plus minimal artifact checks for runtime truth.
