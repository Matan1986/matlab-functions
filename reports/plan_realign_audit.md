# Canonicalization plan realignment audit (canonical isolation)

**Date:** 2026-04-04  
**Mode:** Read-only audit — no code or plan file edits performed as part of this task.  
**Scope:** How **canonical isolation** (repository-level module status + `assertModulesCanonical`) changes the **canonicalization plan**, gates, and infrastructure assumptions.  
**Sources:** `docs/repo_consolidation_plan.md`, `reports/phase4_scope_lock.md`, `reports/system_formalization_audit.md`, `docs/infrastructure_laws.md` (PART 5–6), `reports/module_enforcement.md`, `reports/system_realign_survey.md`, `tables/module_canonical_status.csv`, `Switching/utils/assertModulesCanonical.m`.

---

## Verdict summary

| Item | Verdict |
| --- | --- |
| **PLAN_UPDATE_REQUIRED** | **YES** |
| **PHASE_4_UPDATE_REQUIRED** | **YES** |
| **PHASE_5_UPDATE_REQUIRED** | **YES** |
| **PHASE_6_UPDATE_REQUIRED** | **YES** |
| **MODULE_MODEL_REQUIRED** | **YES** |
| **CROSS_MODULE_POLICY_REQUIRED** | **YES** |
| **Formalization readiness** | **FORMALIZATION_BLOCKED_PENDING_PLAN_PATCH** |

Machine-readable copy: `tables/plan_realign_status.csv`.

---

## 1. Plan impact (master plan)

**PLAN_UPDATE_REQUIRED = YES**

The staged map in **`docs/repo_consolidation_plan.md`** centers on entrypoints, `createRunContext`, results layout, module “isolation” of legacy trees, and **`analysis/`** + **`results/cross_experiment/`** for cross-experiment logic. It does **not** yet encode a **participation gate** tied to **`tables/module_canonical_status.csv`** or runtime **`assertModulesCanonical`**. The **system formalization audit** (`reports/system_formalization_audit.md`) likewise prioritized doc–code parity and manifest/schema alignment, not a **cross-module canonical registry** as a formalization precondition.

Canonical isolation introduces a **second axis**: besides “Switching entrypoint + run contract,” the repository now has a **declared per-module STATUS** and a **helper that can forbid** cross-module analysis when listed modules are not `CANONICAL`. That axis must be **woven into** the master plan narrative (or an explicitly named annex) so the plan does not imply that **Switching-only** closure or consolidation gates subsume **cross-module** policy.

---

## 2. Phase impact

### Phase 4 closure language — **PHASE_4_UPDATE_REQUIRED = YES**

**Substance:** `reports/phase4_scope_lock.md` remains valid as a **Switching-only** lock on four remediation buckets (run root, failure path, external data, signaling). Those four items are **not** replaced by canonical isolation.

**Why update anyway:** “Closure” language must be **disambiguated** so readers do not infer that completing Phase 4 means the **repository** is ready for **unrestricted cross-module** scientific workflows. Canonical isolation adds an explicit **cross-module contamination / participation** dimension that Phase 4 does not address. The master plan (or Phase 4 companion note) should **state the boundary**: Phase 4 does **not** include **module registry governance** or **assertModulesCanonical** deployment policy.

### Phase 5 formalization scope — **PHASE_5_UPDATE_REQUIRED = YES**

**Formalization** (as described in `reports/system_formalization_audit.md`) must expand to include:

- **`module_canonical_status`** as part of the **formalized** system map for cross-module work.
- **Enforcement completeness**: what “rules match enforcement” means when **`CROSS_MODULE_PROTECTION_ACTIVE=YES`** but call-site coverage is **thin** (see `reports/system_realign_survey.md`).
- **Promotion criteria**: what evidence is required before a module transitions from `NON_CANONICAL` to `CANONICAL` in the registry.

Without this, Phase 5 can reach “doc-code parity” on wrapper/manifest details while **still** mis-stating **cross-module** formalization status.

### Phase 6 scientific re-entry conditions — **PHASE_6_UPDATE_REQUIRED = YES**

**Phase 6** is interpreted here as: **infrastructure rollout order** (`docs/infrastructure_laws.md` PART 6) plus **conditions for returning to cross-module scientific analysis** as a **governed** activity. Neither is fully aligned with canonical isolation yet:

- **PART 6** lists documentation and labeling steps before code consolidation; it should **acknowledge** module-registry alignment and cross-module assert policy as **preconditions** (or explicit substeps) where the goal is **system-wide** formalization, not only Switching/run-system closure.
- **Scientific re-entry** must be **conditional** on **which modules** a workflow conceptually **uses** vs **`module_canonical_status`** — consistent with `reports/module_enforcement.md` and the assert contract, but not yet folded into a single “re-entry” checklist in phase-closure docs.

---

## 3. Module model — **MODULE_MODEL_REQUIRED = YES**

The registry already **encodes** different situations: **Switching** = `CANONICAL`; **Relaxation** and **Aging** = `NON_CANONICAL`. That matches the informal distinction:

- **Type A** — modules with **heavy prior non-canonical analysis** where reconstruction / migration is part of becoming trustworthy (Relaxation, Aging in the user framing).
- **Type B** — modules that can be **canonicalized from the ground up** without reconstructing a large legacy analysis stack.

The plan should **name these types** and tie them to **registry promotion** (what “canonical” means for each type, and what evidence is required). Otherwise **`NON_CANONICAL`** stays a label without a **plan-level** story.

---

## 4. Cross-module policy — **CROSS_MODULE_POLICY_REQUIRED = YES**

**Permanent system policy** (already stated in `reports/module_enforcement.md`, implemented in **`assertModulesCanonical`**) should be **elevated** into the **master plan / agent-facing policy chain**: cross-module analysis that **invokes** the assert with a module list is **allowed only** if **every listed module** is `CANONICAL` in **`tables/module_canonical_status.csv`**.

**Clarification the plan must preserve:** **Infrastructure-only** use of **`Aging/utils`** + **`createRunContext`** for run identity (per `docs/switching_dependency_boundary.md`) is a **different** question from **cross-module scientific coupling**; the plan should **not** conflate them when stating policy.

---

## 5. Formalization readiness

**FORMALIZATION_BLOCKED_PENDING_PLAN_PATCH**

Phase 5 **documentation and parity work** on execution and manifests can proceed **incrementally**, but **formalization cannot be declared complete** for **system-wide** cross-module science until the **master plan explicitly** includes canonical isolation as an **infrastructure rule** (registry + policy + enforcement intent), aligned with **`reports/system_realign_survey.md`** (partial mechanical enforcement vs. status flags).

---

## 6. Required plan patch (recommendation only; no implementation)

**Do not rewrite the whole plan.** Insert or revise **minimally**:

1. **New subsection (or sub-phase)** after Phase 4 scope lock: **“Cross-module canonical alignment”** — owns **`module_canonical_status`**, **`assertModulesCanonical`** call-site policy, inventory of scripts by conceptual `modules_used`, and distinction from Phase 4’s four Switching fixes.
2. **`docs/repo_consolidation_plan.md` § cross-experiment / `analysis/`**: add a **sentence** that cross-module **scientific** orchestration must comply with **`reports/module_enforcement.md`** and the registry (not only `results/cross_experiment` paths).
3. **`reports/system_formalization_audit.md` (or successor plan row):** extend **“remaining gaps” / formalization scope** with **registry governance**, **promotion criteria**, and **enforcement completeness** for cross-module workflows.
4. **`docs/infrastructure_laws.md` PART 5–6 or pointers:** add **one** bullet that **consolidation / rollout** that touches **cross-module** analysis must reference **`module_canonical_status`** and the assert policy (without duplicating full rules; point to **`reports/module_enforcement.md`**).
5. **Phase 4 lock doc or one-line pointer in master plan:** clarify that Phase 4 **does not** complete **module-registry** or **cross-module assert** rollout.
6. **Type A / Type B** module model: **define** in plan text and link **promotion** to registry updates.

---

## Output files

| File | Role |
| --- | --- |
| `tables/plan_realign_audit.csv` | Row-level audit trail |
| `tables/plan_realign_status.csv` | Required flags including **PLAN_REALIGN_AUDIT_COMPLETE=YES** |
| `reports/plan_realign_audit.md` | This report |

**PLAN_REALIGN_AUDIT_COMPLETE = YES**
