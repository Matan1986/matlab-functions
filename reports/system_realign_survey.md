# System realignment survey — cross-module canonical enforcement

**Date:** 2026-04-04  
**Mode:** Read-only audit (no code or plan changes performed).  
**Scope:** System-wide impact of the module canonical status registry (`tables/module_canonical_status.csv`), `Switching/utils/assertModulesCanonical.m`, initial Switching usage, and related status (`tables/module_enforcement_status.csv`), on the existing infrastructure plan, execution model, and scientific re-entry narrative.

---

## Executive summary

A **system-level** canonical boundary for **which modules may participate in cross-module analysis** is now representable in code and data. **Mechanical enforcement is partial:** the assert helper exists and one Switching analysis script invokes it; the registered canonical Switching entrypoint and the majority of Switching analysis scripts do **not** invoke it. **Plan and closure documents** (Phase 3–4, consolidation plan, Switching canonical definition) largely describe **module-local** or **Switching-scoped** guarantees and do not yet integrate this layer. **Formalization should not be treated as unblocked** until documentation and enforcement intent are aligned.

---

## 1. Plan impact

### Original phase picture (as documented)

- **Phase 3** (`reports/phase3_system_reality_closure.md`) closes **Switching canonical execution chain** behavior: wrapper, `run_switching_canonical.m` → `createRunContext`, `run_dir`, artifacts, signaling. Verdict includes `FULLY_CANONICAL=NO` for documented non-ideal properties (global run root, failure path, external data, signaling semantics).
- **Phase 4** (`reports/phase4_scope_lock.md`) locks **four** Switching remediation items only (run root, failure path, external data contract, signaling clarification). Explicitly **no** scope drift beyond Phase 3 rows.
- **Broader formalization** (`reports/system_formalization_audit.md`, `docs/infrastructure_laws.md` PART 5–6, `docs/repo_consolidation_plan.md`) addresses consolidation gates, run system, and cross-experiment layout — **without** a `module_canonical_status` gate.

### New reality

- **`tables/module_canonical_status.csv`** assigns `CANONICAL` to **Switching** and `NON_CANONICAL` to **Relaxation** and **Aging**.
- **`assertModulesCanonical`** enforces: every module name passed in must appear in the registry with `STATUS=CANONICAL`, or execution errors (`CrossModuleNotAllowed:NonCanonicalModule`).

### Determination

| Question | Result |
| -------- | ------ |
| Which phases remain **unchanged** (as files)? | Phase 3–4 **documents** still describe the same Switching chain and Phase 4 four-item list. Infrastructure laws and consolidation **map** are unchanged textually. |
| Which phases need **explicit update**? | Any **master plan** or formalization narrative that implied Switching could be “closed” in isolation; **Phase 4** planning if cross-module policy is considered part of infrastructure governance; **`docs/repo_consolidation_plan.md`** cross-experiment subsection; **`docs/switching_canonical_definition.md`** (Switching-only scope vs registry); **`reports/system_formalization_audit.md`** “next phase ready” language. |
| New **sub-phase**? | **Yes** — an explicit **cross-module canonical alignment** step (registry rules, mandatory assert sites, script inventory by `modules_used`) is warranted before treating repo-wide formalization as complete. |
| “Closed” phase needs **clarification**? | **Yes (documentation):** Phase 3 closure characterizes **Switching pipeline** reality; it does **not** record the new **cross-module contamination** dimension. That is an **additive** clarification, not a contradiction of Phase 3 execution facts. |

**PLAN_UPDATE_REQUIRED = YES**

---

## 2. System boundary impact

- **Previously:** Canonicality was primarily **Switching-entrypoint** and **run-scoped** (registry `tables/switching_canonical_entrypoint.csv`, `run_dir` under `results/switching`, `docs/switching_canonical_definition.md` “Switching-only context”).
- **Now:** A **repository-level** table names multiple modules and their canonical **status**, and a shared assert ties **cross-module analysis** to that table.

**SYSTEM_LEVEL_CANONICAL_BOUNDARY = YES**

**NEW_INVARIANT_INTRODUCED = YES** — Any code path that calls `assertModulesCanonical` with a module list enforces: *all listed modules must be `CANONICAL` in the registry* (see `Switching/utils/assertModulesCanonical.m`).

---

## 3. Entrypoint / enforcement coverage

### Where protection exists

| Mechanism | Role |
| --------- | ---- |
| `tables/module_canonical_status.csv` | Declarative state of modules. |
| `assertModulesCanonical` | Runtime check against registry. |
| `tables/module_enforcement_status.csv` | `CROSS_MODULE_PROTECTION_ACTIVE=YES`. |
| `Switching/analysis/analyze_phi_kappa_canonical_space.m` | **Only** `.m` callsite found: `assertModulesCanonical({'Switching'})` before `createSwitchingRunContext`. |
| `createSwitchingRunContext` + `assertSwitchingRunDirCanonical` | **Different** concern: canonical **Switching run_dir** under repo before manifest; used broadly by Switching scripts that allocate runs via this helper. |

### Where it does not (cross-module list assert)

- **`Switching/analysis/run_switching_canonical.m`** — registered canonical entrypoint; **no** `assertModulesCanonical` (relies on Switching-only wiring per definition; does not assert module list).
- **Other `Switching/analysis` scripts** — large surface (**103** `.m` files under `Switching/analysis` in this workspace snapshot); extensive `addpath(genpath(...Aging...))` and reads from `results/cross_experiment/...` **without** `assertModulesCanonical` listing all conceptual modules involved.
- **Relaxation-bridge scripts** under `Switching/analysis` (e.g. `run_PT_to_relaxation_mapping.m`, `run_relaxation_*.m`) — **no** `assertModulesCanonical({'Switching','Relaxation'})` in the surveyed pattern; such a call would **fail** today because **Relaxation** is `NON_CANONICAL` in the registry.

**CROSS_MODULE_ENFORCEMENT_COVERAGE = PARTIAL** — Registry and helper are real; **active** protection is not applied across the Switching entry surface or cross-module scripts. The status flag **approaches symbolic** if read as “fully protected” without reference to callsite count.

**UNGUARDED_ENTRYPOINTS** (non-exhaustive but representative):

- `Switching/analysis/run_switching_canonical.m`
- Essentially **all** other runnable `Switching/analysis/*.m` entrypoints except `analyze_phi_kappa_canonical_space.m`
- Repo-root `run_*_wrapper.m` and `analysis/` orchestration that combine experiments
- Any script that broadens path to **Aging** (beyond `Aging/utils`) or **Relaxation** without matching `assertModulesCanonical` to declared `modules_used`

---

## 4. Module classification impact

The distinction between **Type A** (reconstruction modules with legacy contamination) and **Type B** (canonical-first modules) was already **planning-relevant** in consolidation and aging docs. The registry makes it **infrastructure-relevant**: **promotion** of a module to `CANONICAL` is now a **state transition** in `tables/module_canonical_status.csv` with direct runtime effect wherever `assertModulesCanonical` is used.

**MODULE_CLASSIFICATION_REQUIRED = YES** (must be formal before treating Phase 5 formalization as complete for cross-module work).

---

## 5. Scientific re-entry impact

The following workflow rule is **consistent** with `reports/module_enforcement.md` and the assert implementation but **not** yet integrated into phase-closure documents as a **normative** re-entry rule:

- **Switching-only** analysis remains compatible with `assertModulesCanonical({'Switching'})` while Switching stays `CANONICAL`.
- **Canonicalization** of Relaxation/Aging can proceed **in parallel** in principle (registry updates).
- **Cross-module** analysis that would require **Relaxation** or **Aging** to be `CANONICAL` is **blocked** at any callsite that passes those names into `assertModulesCanonical` until statuses change.

**REENTRY_RULE_UPDATE_REQUIRED = YES**

---

## 6. Formalization readiness

**FORMALIZATION_BLOCKED_PENDING_ALIGNMENT**

**Missing alignment (precise):**

1. **Plan documents** do not yet position `module_canonical_status` and `assertModulesCanonical` as mandatory gates for **cross-module** scientific workflows alongside existing Phase 4 / formalization items.
2. **Enforcement coverage** is **thin** relative to `CROSS_MODULE_PROTECTION_ACTIVE=YES` and the size of `Switching/analysis`.
3. **Relaxation-bridge** and **cross_experiment** paths need an explicit **inventory** of conceptual `modules_used` vs registry — not performed in this survey.

---

## 7. Infrastructure alignment risk

| Risk | Basis |
| ---- | ----- |
| **Hidden inconsistency** | Registry says Relaxation `NON_CANONICAL`, but many scripts can still combine data paths without the new assert. |
| **False sense of closure** | “Protection active” in `module_enforcement_status.csv` can be read as full enforcement. |
| **Partial mistaken for full** | One `assertModulesCanonical` callsite vs 100+ analysis files. |

**ALIGNMENT_RISK = MEDIUM**

---

## 8. Required plan patch (recommendation only)

| Item | Recommendation |
| ---- | ---------------- |
| **New sub-phase after Phase 4** | **Yes** — insert **Cross-module canonical alignment** (registry governance, mandatory assert policy, script inventory, doc updates). |
| **Revise Phase 5 scope** | **Yes** — add **cross-module access policy**, registry **promotion criteria**, and **enforcement completeness** to the existing formalization backlog (doc-code parity, manifest schema, etc.). |
| **Revise Phase 6 entry conditions** | **Yes** (if Phase 6 = structural / consolidation alignment) — require explicit classification of scripts that touch multiple module namespaces vs `module_canonical_status`. |
| **Permanent cross-module access policy** | **Yes** — document: cross-module analysis **forbidden** unless all **participating** modules are `CANONICAL` **where** `assertModulesCanonical` is invoked; parallel single-module work allowed; distinguish **Aging utils** dependency for `createRunContext` from **cross-module scientific** coupling. |

---

## Artifacts

| File | Purpose |
| ---- | ------- |
| `tables/system_realign_survey.csv` | Row-level audit answers and evidence pointers. |
| `tables/system_realign_status.csv` | Machine-readable flags and `SYSTEM_REALIGNMENT_SURVEY_COMPLETE=YES`. |

**SYSTEM_REALIGNMENT_SURVEY_COMPLETE = YES**
