# Phase 4.5 design lock — isolation enforcement (implementation plan only)

**Status:** Design lock and ordered implementation plan. **No code changes** are part of this document.  
**Authoritative model:** `docs/system_master_plan.md` (Phases 0–4 execution-trust vs Phase 4.5 isolation; cross-module law).  
**Reconciled evidence:** `reports/isolation_feasibility_audit.md`, `reports/canonical_switching_isolation_audit.md`, `reports/system_closure_audit.md`, `tables/phase_failure_reconciliation.csv`.

---

## 1. Minimal enforcement surface

See **`tables/phase45_design_lock.csv`** for the full table (SURFACE, ROLE, WHY_REQUIRED, CHANGE_TYPE, IS_MANDATORY).

Summary: Phase 4.5 requires a **small registry** (`module_canonical_status`), one **enforcement primitive** (`assertModulesCanonical`), **governance alignment** for overclaiming status (`module_enforcement_status`), **signaling** so success does not imply a module gate ran (`writeSwitchingExecutionStatus` and/or a companion artifact), the **canonical Switching entrypoint** on the registry reliability story (`run_switching_canonical.m`), and **multiple analysis chokepoints** where cross-module work actually happens (inventory-driven), not repo-wide legacy cleanup.

---

## 2. Single choke-point decision

**ENFORCEMENT_MODEL = MULTI_POINT_REQUIRED**

**Why single choke-point is insufficient (minimal):**

- Cross-module analysis can start from **many** runnable scripts under `Switching/analysis/` and related tools; `assertModulesCanonical` is **caller-list-dependent** and currently has **opt-in coverage** (audits: one primary analysis callsite, canonical runner does not consult the registry).
- There is **no** single MATLAB entry that all cross-module analyses are required to use today, and adding **wrapper orchestration** or multi-stage runners is **out of scope** per `docs/repo_execution_rules.md` (single-call wrapper policy).
- **Mechanical primitive** remains **one function** (`assertModulesCanonical`); **mandatory coordinated call sites** are required wherever a script is classified as performing **cross-module** work (participation list declared **before** cross-module data access).

**Minimal coordinated set:**

1. `assertModulesCanonical` (unchanged role: single enforcement implementation).
2. **Inventory-classified** cross-module scripts each calling the assert with the **full** participating module list at **top of script** (before reads/addpath that pull other modules).
3. **Registry + signaling + governance tables** aligned so operators cannot infer system-wide protection from a partial gate.

---

## 3. Registry design requirement

**REGISTRY_MIN_REQUIREMENTS** (ordered, minimal for Phase 4.5 closure):

1. **Fixed path and schema:** `tables/module_canonical_status.csv` exists, readable by `assertModulesCanonical`, with required columns **`MODULE`**, **`STATUS`** (as implemented).
2. **Completeness for participation:** Every module name that may appear in any **declared** `assertModulesCanonical` list has exactly one row (no silent omission).
3. **Interpretable STATUS values:** `CANONICAL` vs non-canonical states are unambiguous for enforcement (`CANONICAL` required for allow).
4. **Execution-path coupling:** Any workflow claiming **registry-gated** Switching execution must **read** this file on that path (audits: canonical entrypoint currently does not — closure requires either coupling **or** explicit documented exclusion without implying cross-module enforcement).
5. **Drift control:** Change process is documented (who may edit the table; no shadow copies as SSOT).
6. **No scope creep:** Do not expand to a second registry system; extend rows/columns only if required for closure.

---

## 4. False safety correction path

**FALSE_SAFETY_FIX_PATH** (ordered):

1. **Measure:** Record current `assertModulesCanonical` callsites and whether `run_switching_canonical.m` reads `module_canonical_status.csv` (baseline = audits).
2. **Governance alignment first:** Align **`tables/module_enforcement_status.csv`** (and any dependent one-line claims) so **`CROSS_MODULE_PROTECTION_ACTIVE`** does not assert **YES** while mechanical coverage is partial — **unless** the value is explicitly defined as **aspirational** in a separate column (not done in minimal design; prefer honest **NO**/scoped label).
3. **Implementation:** Add **minimal** registry coupling, **inventory-driven** asserts on cross-module scripts, and **signaling** (module gate ran / modules list) per locked surface table.
4. **Re-raise operational flag:** Set protection/active flags to **YES** only when **EXIT_CRITERION** for enforcement coverage is met.

**Order clarification:** **Staged alignment** — **status and governance correction first** (stop false safety in labels), **then** implementation that earns the claim, **then** re-enable strong operational flags. **Not** “implementation first” alone (would leave misleading **YES** during rollout). **Not** “status only” without implementation (would leave REGISTRY_RELIABLE / coverage unfixed).

---

## 5. Safe implementation order

| STEP | ACTION | DEPENDS_ON | STOP_IF | EXIT_CRITERION |
| --- | --- | --- | --- | --- |
| 1 | Correct **FALSE_SAFETY** in governance tables (`module_enforcement_status`) and any doc line that implies repo-wide mechanical protection | None | User conflict on flag semantics | `CROSS_MODULE_PROTECTION_ACTIVE` matches measured coverage (or honest NO) |
| 2 | Freeze **cross-module script inventory** (Switching/analysis + cited tools e.g. `load_observables` if in scope): each file tagged **cross-module vs Switching-only** | Step 1 | Unbounded repo scan / science expansion | Written inventory with explicit `modules_used` per cross-module script |
| 3 | **Registry reliability:** Ensure `module_canonical_status` schema + rows complete for inventory; decide **minimal** coupling for `run_switching_canonical.m` (read registry and record outcome **or** documented Switching-only path with **no** cross-module implication) | Step 2 | Redesign of whole manifest stack | SSOT runner behavior matches written rule; no false implication |
| 4 | **Enforcement:** At each inventory **cross-module** script — call `assertModulesCanonical` with **full** module list **before** cross-module access; Switching-only scripts do not fake multi-module lists | Step 3 | Attempt to gate 100+ files blindly | Every listed cross-module script has assert at top; grep-verifiable |
| 5 | **Signaling:** Record module-gate evidence in run artifacts (extend `MAIN_RESULT_SUMMARY` convention and/or companion file under `run_dir/` if schema stays five-column) | Step 4 | Changing wrapper to multi-call | Success path shows gate ran when claimed |
| 6 | **Governance re-alignment:** Set `CROSS_MODULE_PROTECTION_ACTIVE=YES` only if coverage complete for **in-scope** inventory | Step 5 | Claiming repo-wide safety beyond inventory | Operator cannot confuse Switching-only success with cross-module enforcement |

**Stop gates:** Stop at any step that **reopens Phase 0–3** science definition, **broad repo cleanup**, or **parallel infra** (violates `docs/repo_execution_rules.md` serial infra rule).

---

## 6. Non-goals

**NON_GOALS:**

- Re-auditing or rewriting **Phase 0–3** canonical physics, definitions, or “failure” narratives except **attachment points** needed for Phase 4.5 (registry path, asserts, signaling).
- Changing **canonical Switching model math**, observables, or **Relaxation/Aging** science code beyond participation gating hooks where strictly required.
- **Broad repo cleanup**, mass deletion, or **legacy refactors** outside the locked surfaces.
- **New parallel** run systems, manifests, or **wrapper orchestration** (second MATLAB call, staged wrapper).
- **Repository-wide** grep-and-patch of every `.m` file without inventory discipline.
- Expanding Phase 4.5 into **Phase 5/6** formalization or **cross-module scientific** workflows beyond **enforcement** of the participation law.

---

## 7. Final verdict

| Verdict | Value |
| --- | --- |
| **PHASE_4_5_DESIGN_LOCKED** | **YES** |
| **SAFE_TO_IMPLEMENT_PHASE_4_5** | **YES** |

**Exact first implementation step (only):** Align **`tables/module_enforcement_status.csv`** so **`CROSS_MODULE_PROTECTION_ACTIVE`** does not claim **YES** while mechanical enforcement remains partial; align dependent wording. Then proceed to **Step 2** (inventory) in the table above.

---

## Output artifacts

| File |
| --- |
| `tables/phase45_design_lock.csv` |
| `tables/phase45_design_lock_status.csv` |
| `reports/phase45_design_lock.md` |

**PHASE45_DESIGN_LOCK_COMPLETE = YES**
