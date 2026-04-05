# Infrastructure consistency audit (cross-module canonical enforcement)

**Mode:** Read-only review of repository code and docs (no fixes applied).  
**Scope:** Switching execution paths primary; system-wide implications noted.  
**References:** `docs/repo_execution_rules.md`, `Switching/utils/assertModulesCanonical.m`, `Aging/utils/createRunContext.m`, `Switching/utils/createSwitchingRunContext.m`, `tables/module_canonical_status.csv`.

---

## Required answers

| Token | Value |
|-------|-------|
| **ENFORCEMENT_ON_EXECUTION_PATH** | **PARTIAL** |
| **ENFORCEMENT_COMPATIBLE_WITH_RUN_CONTEXT** | **YES** |
| **FAILURE_PATH_ISOLATION_SAFE** | **NO** |
| **SIGNALING_CAN_HIDE_VIOLATION** | **YES** |
| **DATA_LAYER_BYPASS_POSSIBLE** | **YES** |
| **INVARIANT_TRUE** | **NO** |
| **INVARIANT_ENFORCED** | **NO** |
| **INFRA_CONSISTENT** | **NO** |

---

## 1. Enforcement vs execution path

**Mechanism:** `assertModulesCanonical` reads `tables/module_canonical_status.csv` and errors if any listed module is not `CANONICAL`.

**Evidence:** Repository-wide search shows **one** call site: `Switching/analysis/analyze_phi_kappa_canonical_space.m` (after path setup, before `createSwitchingRunContext`). The registered Switching canonical script `Switching/analysis/run_switching_canonical.m` does **not** call `assertModulesCanonical`. Neither do the other **102** analysis scripts under `Switching/analysis/` (excluding the single file above).

**BYPASS_PATHS (representative):**

- `Switching/analysis/run_switching_canonical.m` and every other `Switching/analysis/*.m` runner except `analyze_phi_kappa_canonical_space.m`
- Any workflow that uses `createRunContext` / `createSwitchingRunContext` without calling `assertModulesCanonical`
- Scripts outside `Switching` (e.g. Relaxation, Aging runners) that never reference the helper
- Direct MATLAB invocation or any path that never executes the single analysis script that calls the assert

**Conclusion:** **PARTIAL** coverage at best; the cross-module registry check is **not** a universal gate on Switching or repo execution.

---

## 2. Enforcement vs run context

**Interaction:**

- `createSwitchingRunContext` sets `cfg.beforeManifestWrite = @(run) assertSwitchingRunDirCanonical(run, repoRoot)` — this enforces **Switching run directory placement** under `results/switching/runs`, not module `CANONICAL` rows in `module_canonical_status.csv`.
- `assertModulesCanonical` is independent and optional at the caller; in the one consumer it runs **before** run allocation, which is order-compatible with manifest creation.

**Conclusion:** **YES** — no direct conflict with `createRunContext` / manifest identity; they address different contracts.

---

## 3. Enforcement vs failure path

**Failure allocation:** `allocateSwitchingFailureRunContext` → `createSwitchingRunContext` only. It does **not** call `assertModulesCanonical`.

**Catch path in `run_switching_canonical.m`:** On failure, if no `run_dir` exists yet, it adds `Aging/utils` and `Switching/utils`, then `allocateSwitchingFailureRunContext`. Canonical **run root** is still enforced via `assertSwitchingRunDirCanonical` inside `createSwitchingRunContext`, but **module registry enforcement is absent** on this path.

**Conclusion:** **NO** for a strict reading of “failure path must not bypass cross-module enforcement” — the registry assert is skipped. Run-folder isolation for Switching remains enforced separately.

---

## 4. Enforcement vs signaling

**Contract:** `writeSwitchingExecutionStatus` writes `execution_status.csv` with schema validation only (`EXECUTION_STATUS`, `INPUT_FOUND`, etc.). It does not read `module_canonical_status.csv` or call `assertModulesCanonical`.

**Conclusion:** **YES** — signaling can show **SUCCESS** (or **FAILED**) while cross-module canonical policy is **not** evaluated by the status writer. A script could violate intended cross-module rules only if those rules are not enforced earlier (and error), or if rules are not encoded as runtime checks.

---

## 5. Enforcement vs data contract

**Loading:** `tools/load_observables.m` filters runs using `get_run_status_value` → `run_status.csv` values (`CANONICAL` / `PARTIAL` / `INVALID`), **not** `module_canonical_status.csv`.

**Repo tables:** Analysis scripts commonly `readtable` under `tables/` (and outputs under `run_dir/tables/`) with no `assertModulesCanonical` unless the script author adds it.

**Conclusion:** **YES** — data from non-canonical modules (per registry) can still be loaded **without** triggering `assertModulesCanonical`.

---

## 6. Global invariant

**Stated invariant:** *NO CROSS-MODULE ANALYSIS WITH NON-CANONICAL MODULES*

- **INVARIANT_TRUE:** **NO** — enforcement is not global; many scripts add broad paths (e.g. `addpath(genpath(Aging))`) and multiple analysis scripts touch Relaxation-related inputs or naming without calling `assertModulesCanonical`. Registry rows show `Relaxation` and `Aging` as **NON_CANONICAL** while only opt-in checks exist.
- **INVARIANT_ENFORCED:** **NO** — a single optional call site cannot enforce a repo-wide invariant.

---

## Summary

Cross-module canonical enforcement (`assertModulesCanonical`) is **implemented** but **not wired** across Switching execution paths, failure allocation, signaling, or the general data layer. Infrastructure is therefore **not** fully consistent with a strict global invariant of “no cross-module analysis with non-canonical modules.”

Machine-readable rows: `tables/infra_consistency_audit.csv`, `tables/infra_consistency_status.csv`.
