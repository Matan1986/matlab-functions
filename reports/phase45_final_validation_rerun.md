# Phase 4.5 final validation (post-fix re-run)

**Scope:** Read-only validation with controlled execution only; no repository code changes. **Wrapper:** `tools/run_matlab_safe.bat` per `docs/repo_execution_rules.md`. **Fix under test:** `clearvars -except modules_used_input` at the top of `Switching/analysis/run_switching_canonical.m` so `modules_used_input` survives and cross-module enforcement is reachable.

---

## 1. Switching-only run (baseline)

**Command:** `tools/run_matlab_safe.bat` with `C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m` (no `modules_used_input`).

**Result:** MATLAB exit **0**. `execution_status.csv`: **SUCCESS**.

**Run directory:** `results/switching/runs/run_2026_04_04_234548_switching_canonical`

| Check | Result |
|--------|--------|
| `enforcement_status.txt` | Present |
| `ENFORCEMENT_CHECKED` | YES |
| `MODULES_USED` | Switching |
| Core artifacts | `tables/switching_canonical_*.csv`, `reports/run_switching_canonical_report.md`, implementation status/report |

**SWITCHING_ONLY_OK:** **YES**

---

## 2. Cross-module (non-canonical) — must fail

**Simulation:** External runner script (temp only, not in repo): `modules_used_input = {'Switching','Aging'};` then `run('.../run_switching_canonical.m')`.

**Result:** MATLAB exit **1**. Error: `assertModulesCanonical` — *Cross-module analysis blocked: module Aging has STATUS=NON_CANONICAL*.

**Failure run directory:** `results/switching/runs/run_2026_04_04_235147_switching_canonical_failure`

| Check | Result |
|--------|--------|
| Fails early (before main pipeline) | Yes |
| Failure at `assertModulesCanonical` | Yes (line 57) |
| `enforcement_status.txt` | Present |
| `MODULES_USED` | Switching,Aging |

**Note:** On this path, `enforcement_checked` is never set to true because the error throws before assignment; the file records **`ENFORCEMENT_CHECKED=NO`** even though the assertion ran. Behavior is consistent with current code ordering.

**NON_CANONICAL_BLOCKED:** **YES**

---

## 3. Cross-module (canonical) — must pass

**Simulation:** Registry file `tables/module_canonical_status.csv` backed up; **Aging** set to **CANONICAL** temporarily. Same temp runner as in section 2. Registry restored afterward (Aging **NON_CANONICAL** again).

**Result:** MATLAB exit **0**. `execution_status.csv`: **SUCCESS**.

**Run directory:** `results/switching/runs/run_2026_04_04_235812_switching_canonical`

| Check | Result |
|--------|--------|
| `enforcement_status.txt` | Present |
| `ENFORCEMENT_CHECKED` | YES |
| `MODULES_USED` | Switching,Aging |

**CANONICAL_ALLOWED:** **YES**

---

## 4. Enforcement conditional correctness

**Static inspection** (`run_switching_canonical.m`): `assertModulesCanonical(modules_used)` runs only when `length(modules_used) > 1`; otherwise only `enforcement_checked` is set for the single-module case.

**Runtime:** Baseline uses default `{'Switching'}` (length 1) — no call to `assertModulesCanonical`. Cross-module runs (sections 2–3) invoke `assertModulesCanonical`.

**ENFORCEMENT_CONDITIONAL_CORRECT:** **YES**

---

## 5. No over-regulation

- Normal switching-only run does not require `modules_used_input` and completed successfully.
- Repository search: `modules_used` / `modules_used_input` appear only under `Switching/analysis/run_switching_canonical.m` (plus comments in `assertModulesCanonical.m`); no propagation into `createRunContext` or other run APIs.

**NO_OVERREGULATION:** **YES**

---

## 6. No false decisions

- With Aging non-canonical and a two-module declaration, execution **failed** as required (no false success).
- With both modules canonical in the registry, execution **succeeded** (no false failure).
- Switching-only with default registry **succeeded**.

**NO_FALSE_DECISIONS:** **YES**

---

## Final verdict

**PHASE45_VALIDATED:** **YES**

**PHASE45_FINAL_VALIDATION_RERUN_COMPLETE:** **YES**

---

## Deliverables

| File | Role |
|------|------|
| `tables/phase45_final_validation_rerun.csv` | Metric-level results |
| `tables/phase45_final_validation_rerun_status.csv` | Completion and key paths |
| `reports/phase45_final_validation_rerun.md` | This report |
