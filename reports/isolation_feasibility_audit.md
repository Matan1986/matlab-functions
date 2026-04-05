# Canonical isolation feasibility audit

**Mode:** Read-only feasibility audit (no code changes, no fixes).  
**Scope:** Canonical Switching subsystem behavior, `tables/module_canonical_status.csv`, `Switching/utils/assertModulesCanonical.m`, and the registered canonical entrypoint per `docs/repo_execution_rules.md`.

---

## 1. Policy implementability

**Policy:** Cross-module analysis is allowed only if all participating modules are canonical.

**POLICY_IMPLEMENTABLE = NO**

**Why:** Enforcement in code is limited to `assertModulesCanonical`, which checks that each name in a **caller-provided** cell array has `STATUS=CANONICAL` in `tables/module_canonical_status.csv`. The current system does not define an authoritative, automatic mapping from “this analysis run” to “participating modules.” Scripts are not required to declare `modules_used`; omitting the call, passing only `Switching` while other modules are involved indirectly, or listing an incomplete set cannot be caught by the helper alone.

**Structural blockers:**

- **Opt-in coverage:** Only `Switching/analysis/analyze_phi_kappa_canonical_space.m` calls `assertModulesCanonical` (with `{'Switching'}`). The rest of `Switching/analysis` and the registered canonical script do not.
- **Primary entry gap:** `Switching/analysis/run_switching_canonical.m` does not call `assertModulesCanonical`, so the canonical Switching execution path is not module-gated by the registry.
- **No global choke point:** MATLAB analysis can run without going through a single hook that always validates modules before cross-module I/O.

So the policy is **not enforceable as a repository-wide invariant** with the present wiring; it could only be approximated by additional process or future infrastructure (mandatory declarations, static inventory, wrapper-level checks), which are out of scope here.

---

## 2. Registry reliability

**REGISTRY_RELIABLE = NO**

| Criterion | Assessment |
|-----------|------------|
| Used on canonical execution path? | **No** for the registry-listed canonical Switching script: `run_switching_canonical.m` does not read `module_canonical_status.csv`. The registry is used only when `assertModulesCanonical` runs (currently one analysis script). |
| Can drift from reality? | **Yes.** The CSV is hand-maintained; module sets in code are not generated from it. |
| Complete? | **Partial.** Only `Switching`, `Relaxation`, and `Aging` are listed. New conceptual modules or workflows would require explicit rows; absence blocks only if a script asserts a missing module name. |

---

## 3. Enforcement coverage

**ENFORCEMENT_COVERAGE_SUFFICIENT = NO**

**`assertModulesCanonical` cannot realistically cover all cross-module entry points today** because it is invoked from a single callsite. Surfaces that are **not** covered by that gate include, at minimum:

- **`Switching/analysis/run_switching_canonical.m`** — canonical Switching runner (no `assertModulesCanonical`).
- **Other `Switching/analysis/*.m` scripts** — vast majority do not call the assert (evidence: single repository callsite outside the utility).
- **Failure / allocation helpers** — e.g. paths using `allocateSwitchingFailureRunContext` / `createSwitchingRunContext` without `assertModulesCanonical` (see `reports/infra_consistency_audit.md` and `reports/canonical_switching_isolation_audit.md`).
- **Data loading** — e.g. `tools/load_observables.m` uses per-run canonical flags, not `module_canonical_status.csv`.
- **Any execution** that bypasses scripts that call `assertModulesCanonical` (direct MATLAB, other folders).

---

## 4. False safety root cause (72110)

**FALSE_SAFETY_ROOT_CAUSE:** The combination of (a) a **module canonical registry** and **assertModulesCanonical** as the stated cross-module guard, (b) **`tables/module_enforcement_status.csv`** asserting `CROSS_MODULE_PROTECTION_ACTIVE=YES`, and (c) **success signaling** (`writeSwitchingExecutionStatus` / `execution_status.csv`) that **does not record whether a module gate ran**, produces an appearance of system-wide protection. In reality, the **registered canonical Switching entrypoint does not use the registry**, and the assert is **optional and singular**. An operator can interpret “canonical Switching run succeeded” or “registry says Switching is CANONICAL” as evidence that **cross-module canonical policy was enforced**, when most paths never consult `module_canonical_status.csv`.

---

## 5. Minimal requirement for real isolation

**MINIMAL_ISOLATION_REQUIREMENT:** Every execution path that can perform **cross-module analysis** must **declare the full set of participating modules** and **invoke `assertModulesCanonical` (or a single agreed choke-point equivalent) before any cross-module data or path access**, and that check must be **reflected in authoritative run artifacts** (so success implies the gate ran). If the policy is claimed for **canonical Switching**, the **canonical Switching entrypoint** must be included in that gated set **or** the policy must **explicitly exclude** that entry and any other ungated scripts. Without that alignment, **CANONICAL_SYSTEM_ISOLATED = YES** is not satisfied.

---

## 6. Final verdict

| Flag | Value |
|------|--------|
| **POLICY_IMPLEMENTABLE** | **NO** |
| **SYSTEM_READY_FOR_ISOLATION_ENFORCEMENT** | **NO** |

**Rationale:** The enforcement primitive exists but is not coextensive with canonical execution, is not bound to an authoritative participation list, conflicts with the “protection active” status narrative, and cannot guarantee the stated policy across the current MATLAB surface without broader mechanical coverage (per prior realign notes: plan/module-model work still required).

---

## Output files

| File | Role |
|------|------|
| `tables/isolation_feasibility_audit.csv` | Row-level audit dimensions |
| `tables/isolation_feasibility_status.csv` | Machine-readable verdicts |
| `reports/isolation_feasibility_audit.md` | This report |

**ISOLATION_FEASIBILITY_AUDIT_COMPLETE = YES**
