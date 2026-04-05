# System Reality Blind Spot Audit — Switching canonical (Phase 3)

Read-only inspection. No code changes. Scope: Switching canonical execution chain, artifacts, and closely shared infrastructure used by that chain.

## Status flags

| Flag | Value |
|------|--------|
| BLIND_SPOTS_FOUND | YES |
| CRITICAL_ISSUES_FOUND | NO |
| SYSTEM_FULLY_CANONICAL | NO |

**Rationale:** Several **MEDIUM**-risk mismatches remain between actual behavior and a strict “everything scoped, single path, no silent skips” ideal. None were classified **HIGH** with a mandatory contract breach in this pass.

## Execution chain (actual)

1. `tools/run_matlab_safe.bat` resolves script path (PowerShell), echoes diagnostics, runs `pre_execution_guard.ps1`, then **one** `matlab -batch "run('<ABS_PATH>.m');"`.
2. Guard: nonempty path, resolve full path, file must exist as leaf, extension `.m`; else exit 2 and optional `tables/pre_execution_failure_log.csv` row.
3. MATLAB: `Switching/analysis/run_switching_canonical.m` — path setup, `createRunContext('Switching', cfg)`, writes under `results/Switching/runs/<run_id>/`.

**Blind spot:** Infra logs (`pre_execution_failure_log.csv`) are not run-scoped.

## Artifact generation

- **Authoritative (documented in script):** `execution_status.csv` column `EXECUTION_STATUS` for final SUCCESS / FAILED / PARTIAL.
- **Auxiliary:** `execution_probe*.csv`, `execution_probe_top.txt`, `runtime_execution_markers.txt`, implementation/report tables under `run_dir`.

**Blind spot:** `execution_status.csv` is **overwritten** during the run; mid-run copies are not final.

## Path resolution

- Wrapper passes absolute path into `-batch`; guard validates resolved leaf `.m`.
- Manifest paths use canonical normalization (may differ in casing from `fullfile` strings).
- Raw data `parentDir` comes from **legacy file** `Switching_main.m` string — often **outside** the repo.

## Working directory

- `disp(pwd)` shows current folder (typically script directory under `run()`), not necessarily repository root.

## Run directory allocation

- Normal path: `createRunContext` → `results/<experiment>/runs/run_<timestamp>_<label>/` with manifest.
- Failure path: optional second `createRunContext` with `switching_canonical_failure`, else `run_failure_<timestamp>` folder **without** the same manifest lifecycle.

## Manifest + fingerprint

- `script_hash` matches file content; `git_commit` from `git rev-parse`; host/user/version are **environment**, not science.

## Helper functions (Switching-relevant)

- `resolve_preset` / `select_preset` (General ver2 on path): order-dependent `which`.
- `resolveNegP2P` (Switching ver12): path-string logic; deterministic given same path.

## Writes outside `run_dir`

- `tools/write_execution_marker.m` → `tables/runtime_execution_markers_fallback.txt` if no `run_dir` in appdata.
- Guard → `tables/pre_execution_failure_log.csv` on failure.

## Duplicate or conflicting sources of truth

- Final outcome: **`execution_status.csv`** (declared in script comments).
- **Risk:** `implementation_status` verdict columns vs `EXECUTION_STATUS` if read as competing “pass/fail.”

## Hidden fallback or silent behavior

- **Catch block:** alternate run directory allocation if primary context missing.
- **Loops:** `continue` when `fileList` empty or `Tvec` empty — folders can be skipped without prominent signaling in `execution_status.csv`.

## Machine-readable findings

Full table: `tables/system_blind_spot_audit.csv`.

---

*Audit method: static read of Switching canonical script, wrapper, guard, createRunContext fingerprint/manifest paths, write_execution_marker, registry CSV, and repo `load.m` interaction.*
