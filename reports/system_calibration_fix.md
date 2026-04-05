# System calibration fix report

## 1. Goal

Reduce **too-permissive** pre-execution behavior, clarify **failure classification**, improve **observability** when MATLAB never starts, fix **validator signal inconsistency**, and keep **soft failures non-blocking** — with minimal infrastructure changes (no scientific logic).

## 2. Input audit contradiction

Prior state: missing script could still launch MATLAB; validator could emit WARN then a PASS-style continuation; `SYSTEM_READY_FOR_ANALYSIS_CONFIRMED=YES` was inconsistent with weak pre-exec observability.

## 3. Minimal fixes applied

| ID | Change |
| --- | --- |
| CHG-01 | `tools/pre_execution_guard.ps1` — exit **2** if path empty, not a file, or not `.m`; append `tables/pre_execution_failure_log.csv`. |
| CHG-02 | `tools/run_matlab_safe.bat` — invoke guard **before** MATLAB; **exit 2** on failure; `temp_runner_%RANDOM%_%RANDOM%.m` to reduce collision. |
| CHG-03 | `tools/validate_matlab_runnable.ps1` — `FailValidation` now **`exit 0`** after emitting lines; adds **`RESULT = NOT_PASS`** so stdout is not mistaken for success. |
| CHG-04 | `docs/execution_failure_classification.md` — calibration contract table. |
| CHG-05 | `docs/repo_execution_rules.md`, `docs/repo_context_minimal.md` — document guard + log. |

See `tables/system_calibration_fix_changes.csv`.

## 4. Failure classification contract

See `tables/system_calibration_fix_failure_contract.csv` and `docs/execution_failure_classification.md`.

## 5. Pre-execution guard behavior

- **Blocks:** Missing file, non-`.m`, unresolvable path (MATLAB **not** started, batch exit **2**).
- **Log:** `tables/pre_execution_failure_log.csv` receives a row with `PRE_EXECUTION_INVALID_SCRIPT`.
- **Evidence:** `cmd.exe /v:on /c "(…run_matlab_safe.bat …nope… ) & echo ERRORLEVEL=!ERRORLEVEL!"` → `ERRORLEVEL=2`; log row appended (see `tables/pre_execution_failure_log.csv`).

## 6. Observability under failure

- **Pre-exec:** Guaranteed row in `pre_execution_failure_log.csv` + stderr line + `PRE_EXECUTION_GUARD=FAIL` echo.
- **Validator:** No contradictory PASS after WARN for the same failing condition (`RESULT = NOT_PASS` then process exit; no `OK:` line on that path).
- **Residual:** If MATLAB starts and the script aborts before `createRunContext`, there may still be **no** `run_dir` — not addressed here (would require script changes).

## 7. Hard-block boundary

| Stage | Behavior |
| --- | --- |
| Before MATLAB | Guard: **hard** exit 2, no MATLAB. |
| Validator (standalone) | **Non-blocking** exit 0 with WARN / NOT_PASS. |
| After script entry | Existing `catch` / `execution_status` behavior unchanged. |

## 8. Parallel isolation check

See `tables/system_calibration_fix_parallel_safety.csv`. Unique temp runner name; append-only log may interleave under concurrent writes — documented as acceptable for diagnostics.

## 9. Focused re-verification tests

See `tables/system_calibration_fix_recheck.csv`.

- **R1:** Invalid path — **PASS** (exit 2, log row, no MATLAB).
- **R2:** Validator missing file — **PASS** (NOT_PASS, no spurious OK).
- **R3:** Validator on `run_minimal_canonical.m` — **PASS** (PASS + OK).
- **R4 / R5:** Not run (no MATLAB batch in this fix session).

## 10. Final verdict

Calibration is **improved** for the pre-execution and validator-signaling gaps. The system is **not** fully “well-calibrated” for all runtime/post-entry opaque failures without additional work.

## 11. Remaining risks

- MATLAB launch with valid `.m` that errors before any disk output: observability still depends on console/MATLAB.
- Shared append to `pre_execution_failure_log.csv` under heavy parallel automation (low severity).

## 12. Minimal next step

Optional: one manual `run_matlab_safe.bat` success run to populate end-to-end evidence when convenient.

---

**Status fields:** `tables/system_calibration_fix_status.csv`
