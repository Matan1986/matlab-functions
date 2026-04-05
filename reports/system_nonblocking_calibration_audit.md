# System non-blocking calibration audit

**Date:** 2026-04-03  
**Method:** Code inspection, policy cross-check, one controlled wrapper invocation with a missing script (MATLAB present), one validator invocation on a missing script. No scientific analysis. Scope: canonical execution infrastructure; Switching only as the canonical runner path.

---

## 1. Audit goal

Challenge the post-micro-polish claim (`MICRO_POLISH_APPLIED=YES`, etc.) and decide whether the execution stack is **well-calibrated** (soft vs hard boundaries, observability under failure, parallel safety, token efficiency) or **mis-calibrated** / **not yet proven**.

---

## 2. Scope and exclusions

- **In scope:** `tools/run_matlab_safe.bat`, `tools/validate_matlab_runnable.ps1` (behavior when run standalone), `Aging/utils/createRunContext.m`, canonical Switching runner `Switching/analysis/run_switching_canonical.m`, relevant docs (`docs/repo_execution_rules.md`, `docs/repo_context_minimal.md`, micro-polish artifacts).
- **Out of scope:** Physics, Aging, Relaxation pipelines, refactors, new features.

---

## 3. Current claimed system state

Prior claim: consistent, parallel-ready, observability and token efficiency improved, system ready for analysis. **This audit treats that as a hypothesis**, not proof.

---

## 4. Failure taxonomy

See **`tables/system_nonblocking_failure_taxonomy.csv`**.

**Summary:** Failure modes span wrapper (no pre-block for missing script; shared `temp_runner.m`), validator (non-blocking WARN; ambiguous output in observed run), run context (hard errors on mkdir; **silent skip** if `run_status.csv` cannot be opened), canonical script (strong PARTIAL/FAILED/`execution_status` behavior in `catch`), and parallel (unique `run_dir` vs shared temp file).

---

## 5. Controlled failure injection design

**Executed:**

| Test | Condition | Result |
| --- | --- | --- |
| T-C-01 | `run_matlab_safe.bat` with nonexistent `.m` | Batch printed `SCRIPT_EXISTS=NO`, still called MATLAB; MATLAB error: `RUN cannot execute the file`; process exit 1. **No `run_dir` from script.** Evidence: `terminals/829497.txt` (wrapper log). |

**Executed (validator only, no MATLAB script run):**

| Test | Condition | Result |
| --- | --- | --- |
| T-A-01 | `validate_matlab_runnable.ps1` on missing path | WARN + `FILE_NOT_FOUND`; also emitted contradictory `RESULT = PASS` for same path in the same run. Exit code 0. |

**Not executed (documented):** Mid-pipeline partial fault (T-B-01), destructive misconfiguration of `Switching ver12` (T-C-02) — **NOT_EXECUTED**; behavior inferred from `catch` in `run_switching_canonical.m`.

Full rows: **`tables/system_nonblocking_injection_results.csv`**.

---

## 6. Observability findings

| Path | Observability |
| --- | --- |
| **Canonical script enters and hits `createRunContext`** | **Strong:** `execution_status.csv` (PARTIAL then SUCCESS or FAILED), `execution_probe_top.txt`, probes, failure implementation CSV/MD, `run_manifest.json` from `createRunContext`. |
| **Wrapper + missing/invalid script** | **Weak for run-scoped artifacts:** MATLAB may error with no script-created `run_dir` or `execution_status`. Distinction relies on console/MATLAB message, not a unified repo log. |
| **Validator** | **Ambiguous:** WARN messaging coexists with PASS line in observed output (see T-A-01). |

**Verdict:** Observability is **good** once the canonical runner path is entered; **incomplete** for failures that prevent script entry or any `createRunContext`.

---

## 7. Blocking boundary findings

See **`tables/system_nonblocking_boundary_audit.csv`**.

- **Before MATLAB:** The batch wrapper does **not** block on missing file; it still launches MATLAB. Soft/non-blocking by design for automation; **permissive** relative to a strict “fail fast before MATLAB” policy.
- **After MATLAB launch:** Failures surface as MATLAB errors or script `catch` paths; canonical runner writes FAILED status when `catch` runs.
- **Policy vs code:** `docs/repo_execution_rules.md` ASCII **STOP** is **agent policy**, not wrapper-enforced — correct for “no blocking systems” but **permissive** if agents ignore policy.

---

## 8. Parallel failure safety findings

See **`tables/system_nonblocking_parallel_safety.csv`**.

- **Unique `run_dir`:** Preserved for normal and failure allocation paths in the canonical runner.
- **Residual risk:** Shared `tools/temp_runner.m` name — potential **cross-run contention** if multiple wrapper instances run concurrently.

---

## 9. Token-efficiency findings

See **`tables/system_nonblocking_token_efficiency.csv`**.

- Micro-polish **does** reduce default prompt surface (`docs/repo_context_minimal.md`, `docs/agent_prompt_exclude.md`, four short templates).
- **Residual load:** `docs/repo_execution_rules.md` remains long if attached in full; operational guidance is to use the minimal path + templates.

---

## 10. Final calibration verdict

**Primary verdict:** **`INCONSISTENT`** (see `tables/system_nonblocking_calibration_status.csv`, field `PRIMARY_VERDICT`).

Rationale:

- **Soft paths** are largely non-blocking (validator not wired to wrapper; optional WARN) — **aligned** with non-blocking goals.
- **Hard diagnosis** is **not uniform:** wrapper-level failures do not produce run-scoped `execution_status` by construction.
- **Observability under failure** is **partial** across all failure classes.
- **Parallel failure isolation** is **mostly** sound for `run_dir`; **not fully** proven for wrapper temp file.
- **Too permissive** in places (launch MATLAB even when `SCRIPT_EXISTS=NO`; silent `run_status` skip on fopen failure).

**`SYSTEM_WELL_CALIBRATED=NO`** per decision standard: not all criteria are fully supported by evidence.

---

## 11. Remaining risks

1. Missing-script / never-entered paths: little or no run-scoped artifact trail from the script.
2. `ensureRunStatusFile` silent failure: possible missing `run_status.csv` with no loud error.
3. `tools/temp_runner.m` concurrency under parallel wrapper use.
4. Validator output ambiguity (WARN vs PASS in one run).

---

## 12. Minimal required follow-up before analysis (if any)

- **Operational:** Prefer the **canonical Switching runner** path when traceability matters; treat wrapper-only failures as **MATLAB/console evidence**, not full run manifests.
- **Optional (not required to “start” analysis):** Harden observability for no-entry paths (e.g. append-only `agent_runs_log` rows manually), resolve validator contradictory lines, document parallel wrapper usage (serial or staggered).

---

## Status file (explicit fields)

| Field | Value |
| --- | --- |
| FAILURE_TAXONOMY_COMPLETE | YES |
| INJECTION_TESTS_COMPLETE | NO |
| OBSERVABILITY_UNDER_FAILURE | NO |
| HARD_BLOCK_BOUNDARY_CLEAR | NO |
| SOFT_FAILURES_NON_BLOCKING | YES |
| PARALLEL_FAILURE_ISOLATION | NO |
| TOKEN_EFFICIENCY_CONFIRMED | YES |
| SYSTEM_TOO_BLOCKING | NO |
| SYSTEM_TOO_PERMISSIVE | YES |
| SYSTEM_WELL_CALIBRATED | NO |
| SYSTEM_READY_FOR_ANALYSIS_CONFIRMED | YES |

**Evidence index:** `tables/system_nonblocking_*.csv`, wrapper terminal log `829497.txt` under Cursor terminals folder (user environment), PowerShell validator transcript from this session.
