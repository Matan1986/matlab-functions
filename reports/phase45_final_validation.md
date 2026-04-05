# Phase 4.5 final validation (isolation enforcement + non-regression)

**Mode:** read-only validation; no repository code changes. **Runtime:** one full baseline via `tools/run_matlab_safe.bat`; additional MATLAB snippets for workspace behavior; static inspection of `run_switching_canonical.m`, `assertModulesCanonical.m`, and `modules_used` usage.

## 1. Switching-only run (baseline)

**Command:** `tools/run_matlab_safe.bat` with absolute path `C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m`.

**Outcome:** MATLAB batch completed with exit code **0**.

**Artifacts (run directory):** `results/switching/runs/run_2026_04_04_230034_switching_canonical`

| Check | Result |
|--------|--------|
| `enforcement_status.txt` present | Yes |
| `ENFORCEMENT_CHECKED=YES` | Yes |
| `MODULES_USED=Switching` | Yes |
| `execution_status.csv` | `EXECUTION_STATUS=SUCCESS` |
| Core outputs | `tables/switching_canonical_*.csv`, `reports/run_switching_canonical_report.md`, implementation status/report |

**`SWITCHING_ONLY_OK`:** **YES**

---

## 2. Cross-module (non-canonical) — must fail

**Required simulation:** `modules_used_input = {'Switching','Aging'}` then canonical entrypoint.

**Finding:** `run_switching_canonical.m` starts with `clear; clc;` (lines 1–2). The assignment to `modules_used` that consults `modules_used_input` runs later (lines 51–53). In MATLAB, `clear` removes `modules_used_input` from the base workspace before `exist('modules_used_input','var')` can succeed.

**Runtime check:** `matlab -batch` with `modules_used_input = {'Switching','Aging'}; clear; clc;` then `exist('modules_used_input','var')` reported **0**.

Therefore the canonical run **does not** receive a two-module list via the documented mechanism; it stays on the default `modules_used = {'Switching'}` and does **not** reach `assertModulesCanonical` for a non-canonical second module.

**`NON_CANONICAL_BLOCKED`:** **NO** (integration test for “fail early at entrypoint with two modules” is **not** satisfied by runtime; the failure mode is **not** `assertModulesCanonical` from a two-module list).

---

## 3. Cross-module (canonical) — must pass

**Required simulation:** temporarily set Aging to CANONICAL in the registry and run with `{'Switching','Aging'}`.

**Finding:** The same `clear` ordering prevents supplying `modules_used_input`, so the “both canonical, multi-module success” path cannot be demonstrated at the canonical entrypoint without changing how inputs are preserved. Registry-only experiments would still not activate multi-module `modules_used` without fixing input preservation.

**`CANONICAL_ALLOWED`:** **NO** (not demonstrated at canonical entrypoint under the stated simulation).

---

## 4. Enforcement only when needed

**Static inspection of** `Switching/analysis/run_switching_canonical.m` (lines 51–60):

- If `length(modules_used) > 1`, `assertModulesCanonical(modules_used)` is called.
- Otherwise it is not called.

**Default path after `clear`:** `modules_used` is always the single-element cell `{'Switching'}` (unless some other in-script mechanism sets `modules_used_input`, which none does). So **`assertModulesCanonical` is never called** from this entrypoint in normal or simulated multi-module use.

| Sub-check | Verdict |
|-----------|---------|
| Switching-only → no `assertModulesCanonical` | **YES** (matches intent) |
| Multi-module → `assertModulesCanonical` called | **NO** (unreachable with current `clear` + input pattern) |

**`ENFORCEMENT_CONDITIONAL_CORRECT`:** **NO**

---

## 5. No over-regulation

- Switching-only baseline **succeeds**; no user-facing requirement to pass `modules_used_input` for that path.
- `modules_used` is local to `run_switching_canonical.m` and written to `enforcement_status.txt`; repository search shows no propagation of `modules_used` into other modules’ run context APIs.

**`NO_OVERREGULATION`:** **YES**

---

## 6. False positives / false negatives

- **False positive (incorrect failure when all canonical):** Not observed for Switching-only baseline.
- **False negative (incorrect success when a module is non-canonical in a declared multi-module run):** The intended multi-module declaration **cannot** be applied at the entrypoint because `modules_used_input` is cleared; a user intending `{'Switching','Aging'}` with Aging non-canonical would **not** be stopped by `assertModulesCanonical` in this script, because enforcement never sees two modules.

**`NO_FALSE_DECISIONS`:** **NO**

---

## 7. Final verdict

**`PHASE45_VALIDATED`:** **NO**

**Failing case (exact):** Cross-module canonical policy cannot be enforced or validated at `run_switching_canonical.m` via `modules_used_input`, because the opening `clear; clc;` removes `modules_used_input` before it is read, so `length(modules_used)` never exceeds 1 and `assertModulesCanonical` is never invoked on a multi-module list from this entrypoint.

**Minimal fix (conceptual, not applied here):**

1. **Preserve cross-module intent across `clear`:** e.g. read `modules_used_input` from the base workspace into a temporary variable **before** `clear`, then `clearvars` with an `-except` list for that carrier, or replace leading `clear` with a narrower cleanup that does not drop `modules_used_input`; or use a supported side channel (environment variable / small manifest file) that the script reads after path setup.
2. **Optional:** Ensure registry reads used by `assertModulesCanonical` resolve to a working `readtable` implementation on this installation (repo root shadows toolbox `readtable`; the wrapper calls `builtin('readtable', ...)`, which failed in isolated `loadModuleCanonicalStatus` tests in this environment—worth reconciling with successful end-to-end runs if enforcement paths are enabled).

---

## Output index

| File | Purpose |
|------|---------|
| `tables/phase45_final_validation.csv` | Row-per-check results and evidence |
| `tables/phase45_final_validation_status.csv` | Key=value summary flags |
| `reports/phase45_final_validation.md` | This report |

**`PHASE45_FINAL_VALIDATION_COMPLETE`:** **YES**
