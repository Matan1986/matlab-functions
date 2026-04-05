# Phase 5F — Validation (no regression check)

**Date:** 2026-04-05  
**Entrypoint:** `Switching/analysis/run_switching_canonical.m`  
**Command:** `tools/run_matlab_safe.bat Switching\analysis\run_switching_canonical.m` (from repo root `C:\Dev\matlab-functions`)

**Constraint:** No code changes; validation and reporting only.

---

## 1. Smoke run

- **Exit code:** 0 (`AFTER_MATLAB_CALL`, batch completed successfully).
- **run_dir:** `C:\Dev\matlab-functions\results\switching\runs\run_2026_04_05_013535_switching_canonical`
- **Console (excerpt):** `SCRIPT_ENTERED`, `=== START SCRIPT ===`, `=== RUN CONTEXT ===` with path above, `=== WRITE TEST ===` with `execution_probe.csv` path. Runtime ~9.5 minutes.

---

## 2. Execution success

| Check | Result |
|--------|--------|
| `execution_status.csv` exists | Yes |
| Final `EXECUTION_STATUS` | `SUCCESS` |
| `N_T` | 16 |
| `MAIN_RESULT_SUMMARY` | `switching_canonical completed` |

**MATLAB:** One **Warning** about a function named `load` shadowing the built-in (from `run` cleanup path). No error reported; execution completed with exit code 0.

---

## 3. Marker behavior (critical)

### A. Inside run_dir

- **File:** `runtime_execution_markers.txt`
- **Exists:** Yes  
- **Non-empty:** Yes — lines include `ENTRY`, `STAGE_START_PIPELINE`, `STAGE_AFTER_PROCESSING`, `STAGE_BEFORE_OUTPUTS`, `STAGE_AFTER_OUTPUTS`, `COMPLETED`.

### B. Outside run_dir — fallback

- **Target:** `tables/runtime_execution_markers_fallback.txt`
- **Before run:** `Length = 240`, `LastWriteTimeUtc = 2026-04-04 11:37:44 UTC`
- **After run:** **Same** `Length` and `LastWriteTimeUtc` (file not created anew and not modified)

**Conclusion:** Markers are written only under `run_dir`; the repo-root fallback was not used.

---

## 4. Run-scoped isolation (light)

- New canonical outputs for this execution live under `run_2026_04_05_013535_switching_canonical/`.
- The Phase 5F concern — **writes to `tables/runtime_execution_markers_fallback.txt`** — was checked explicitly; **no change** detected.

---

## 5. Failure path (optional)

**Not run.** The validation task disallows modifying the script for a temporary early error, and no separate no-code failure trigger was used. Status column `FAILURE_PATH_VALID` is **NO** (not validated).

---

## 6. Light comparison vs previous canonical run

**Baseline:** `run_2026_04_04_235812_switching_canonical` (prior SUCCESS, same `N_T=16` in `execution_status.csv`).

| Artifact | Old lines | New lines |
|----------|-----------|-----------|
| `tables/switching_canonical_S_long.csv` | 113 | 113 |
| `tables/switching_canonical_observables.csv` | 17 | 17 |

- **`run_manifest.json`:** Present in the new run with expected fields (`run_id`, `run_dir`, `script_hash`, etc.).

No structural or unexpected size differences observed for these checks.

---

## Summary

| Criterion | Met |
|-----------|-----|
| Canonical run completes successfully | Yes |
| Markers only inside `run_dir` | Yes |
| No writes to `tables/runtime_execution_markers_fallback.txt` | Yes (verified unchanged) |
| No unexpected regression in sampled outputs | Yes (line counts + manifest) |

**PHASE_5F_VALIDATED = YES**

*(Failure-path behavior was not exercised in this pass.)*
