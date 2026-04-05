# System-Wide Risk and Failure Mode Audit (Cross-Module Enforcement)

**Mode:** Read-only. No code or policy fixes applied.  
**Normative inputs:** `docs/repo_execution_rules.md`, `docs/switching_dependency_boundary.md`, `docs/execution_status_schema.md`, `tables/module_canonical_status.csv`, `tables/module_enforcement_status.csv`, `tables/switching_entrypoint_lock_status.csv`.  
**Date:** 2026-04-04.

---

## Purpose

Assess **unintended consequences** of cross-module enforcement: false blocking, partial enforcement, state desync, and scalability as the number of modules grows.

---

## Mechanisms reviewed

| Mechanism | Role |
|-----------|------|
| `Switching/utils/assertModulesCanonical.m` | Runtime gate: listed modules must have `STATUS=CANONICAL` in `tables/module_canonical_status.csv`. |
| `Switching/utils/createSwitchingRunContext.m` | Wraps `Aging/utils/createRunContext` with `repoRoot` consistency check and `assertSwitchingRunDirCanonical` before manifest write. |
| `tools/pre_execution_guard.ps1` | Pre-MATLAB filesystem gate for the wrapper (`docs/repo_execution_rules.md`). |
| `tables/module_enforcement_status.csv` | Declares `CROSS_MODULE_PROTECTION_ACTIVE=YES`. |
| `tables/switching_entrypoint_lock_status.csv` | Declarative lock snapshot for Switching entrypoint policy. |

---

## 1. False blocking (`FALSE_BLOCKING_RISK`)

**Verdict: YES**

**Why**

1. **Strict repository root match** — `createSwitchingRunContext` requires `repoRoot` to match the repository inferred from `which('createRunContext')` (string equality after normalization). Legitimate executions that resolve the same tree through different path forms (junction, symlink, separate clone path, or tooling-specific absolute forms) can **error** even when the scientific configuration is valid. That is a classic second-order effect: the failure presents as “canonical violation” rather than “path identity.”

2. **Opt-in module gate vs. sibling scripts** — `assertModulesCanonical` is invoked from **one** analysis script (`Switching/analysis/analyze_phi_kappa_canonical_space.m`). A mistake in `module_canonical_status.csv` (missing file, wrong `STATUS`, or missing `MODULE` row) blocks that script **only**, while other Switching analysis scripts proceed. Operators may interpret this as intermittent or “buggy” blocking.

3. **Pre-execution guard** — Invalid or mis-resolved script paths exit **before** MATLAB; this is intentional, but mis-invocation of `run_matlab_safe.bat` still produces **false negatives** for “did MATLAB run?” in logs (`PRE_EXECUTION_INVALID_SCRIPT`), which can be confused with in-script failures.

**What is *not* a primary false-blocking concern for the registered canonical entrypoint**

- `Switching/analysis/run_switching_canonical.m` does **not** call `assertModulesCanonical`. Valid canonical Switching runs are not gated by the module status table on that path. Blocking there is driven by other checks (legacy root, `createRunContext` resolution, `createSwitchingRunContext`, pipeline errors).

---

## 2. Partial enforcement (`PARTIAL_ENFORCEMENT_RISK`)

**Verdict: YES**

**Why**

1. **Registry claims active protection** — `tables/module_enforcement_status.csv` sets `CROSS_MODULE_PROTECTION_ACTIVE=YES`, but runtime enforcement of cross-module canonical policy exists only where `assertModulesCanonical` is called (effectively **one** callsite in this repository snapshot).

2. **Canonical entrypoint not module-gated** — The registered Switching entrypoint uses `createSwitchingRunContext` but not `assertModulesCanonical`, so “Switching canonical execution” and “module registry check” are **orthogonal** unless authors add calls.

3. **Data path** — `tools/load_observables.m` uses per-run canonical status via `get_run_status_value`, not `module_canonical_status.csv`. Aggregated views can look “clean” while cross-module scientific coupling remains ungated at load time.

4. **Optional validator** — `validate_matlab_runnable.ps1` is not on the wrapper’s live path (`docs/repo_execution_rules.md`), so structured checks do not compose with the single-call wrapper model.

**Second-order effect:** The system can **appear** policy-complete (tables + helper exist) while behavior remains **policy-selective** by file.

---

## 3. State desync (`STATE_DESYNC_RISK`)

**Verdict: YES**

**Why**

1. **Module table vs. execution artifacts** — `module_canonical_status.csv` is not written into `execution_status.csv` or run manifests by `writeSwitchingExecutionStatus`. A run can record `SUCCESS` while the registry still lists other modules as `NON_CANONICAL`, with no single artifact tying them together.

2. **Lock status vs. runtime** — `tables/switching_entrypoint_lock_status.csv` documents policy closure; MATLAB does not read it to allow or deny execution. Agents could still invoke non-canonical scripts unless human/process discipline holds.

3. **Registry vs. script surface** — `Relaxation` and `Aging` are `NON_CANONICAL` in the registry, yet many scripts under `Switching/analysis` may still add broad paths or consume cross-experiment inputs (documented in existing surveys). The **table** says one thing; the **code surface** says another unless each script opts in to `assertModulesCanonical` with an accurate module list.

---

## 4. Future scalability (`SCALABILITY_RISK`)

**Verdict: MEDIUM**

**Rationale**

- **Linear manual maintenance** — Each new module requires updates to `module_canonical_status.csv` and discipline at every callsite that should declare `modules_used`. There is no automated linkage from “new script” to “registry row.”

- **Helper proliferation** — `createSwitchingRunContext` is Switching-specific. Scaling to many experiments implies either duplicated `create*RunContext` wrappers or a generalized hook; either way, merge conflict and review load grow with module count.

- **Not HIGH by default** — Current registry is tiny (three modules), and `assertModulesCanonical` is O(rows) per call. Computational cost is not the bottleneck; **process and consistency** are.

---

## Required return values

| Field | Value |
|--------|--------|
| `FALSE_BLOCKING_RISK` | YES |
| `PARTIAL_ENFORCEMENT_RISK` | YES |
| `STATE_DESYNC_RISK` | YES |
| `SCALABILITY_RISK` | MEDIUM |
| `SYSTEM_SAFE` | NO |

`SYSTEM_SAFE=NO` reflects that **cross-module enforcement**, as declared in tables, is **not uniformly applied**, and **status artifacts** do not fully mirror **runtime behavior**; combined with **path-identity** sensitivity in `createSwitchingRunContext`, a “safe system” claim would overstate operational guarantees.

---

## Artifacts

| File | Description |
|------|-------------|
| `tables/system_risk_status.csv` | Machine-readable key/value summary (includes fields above). |
| `tables/system_risk_audit.csv` | Row-level risk register with second-order notes. |

---

## Related internal references (read-only)

- `reports/infra_consistency_audit.md` — enforcement vs. execution paths.  
- `reports/system_realign_survey.md` — registry and callsite coverage.  
- `reports/overblocking_audit.md` — wrapper vs. validator behavior.
