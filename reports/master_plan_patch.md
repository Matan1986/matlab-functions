# Master plan patch — system closure realignment (documentation only)

**Date:** 2026-04-04  
**Type:** Read-only documentation patch; **no** code changes; **no** enforcement implementation.  
**Goal:** Align the master system plan with audited reality; remove ambiguity where Phase 4 was misread as full trust; formalize Phase 4.5 and cross-module law.

---

## Summary

The repository now has a single authoritative program document, **`docs/system_master_plan.md`**, that:

- Defines Phases **0–6** including **Phase 4.5 — Canonical Isolation Alignment**.
- Limits **Phase 4** to **Execution Trust Closure** and lists explicit **non-guarantees** (canonical isolation, cross-module enforcement, repository-wide contamination protection).
- States **cross-module analysis is allowed only if all participating modules are canonical** (normative law; operationally not closed until enforcement is real and coverage-complete — per feasibility audit inputs).
- Introduces **Type A** (reconstruction: Switching, Relaxation, Aging) vs **Type B** (canonical-first) module model.
- Separates **execution trust**, **system trust**, and **isolation trust**.
- **Reinterprets** prior Phase 0–4 **DONE** language without erasing history: Phase 4 **DONE** = execution-trust sense only; **full system closure** was not achieved; Phase **4.5** exists because that gap remains.

**Infrastructure law duplicate:** `docs/infrastructure_laws.md` **PART 7** states the cross-module participation rule and points to the master plan.

**Supporting edits:** `docs/AGENT_RULES.md` (precedence **1b**), `docs/repo_consolidation_plan.md` (principle pointer), `docs/repo_map.md`, `docs/repo_context_infra.md` (trust section), `docs/repo_execution_rules.md` (pointer under infrastructure laws).

---

## Authoritative audit inputs (unchanged; cited by plan)

| Input | Role in patch |
| --- | --- |
| Canonical isolation audit | `CANONICAL_SWITCHING_ISOLATED = NO`; isolation layer not aligned; `FALSE_SAFETY_RISK = YES` |
| Plan realignment audit | Plan and Phases 4–6 updates required; module model and cross-module policy required |
| Isolation feasibility audit | Policy not implementable; registry not reliable; enforcement coverage insufficient; system not ready |
| End-to-end closure audit | `SYSTEM_CLOSED = NO`; `SAFE_TO_ENTER_PHASE_5 = NO`; `FALSE_CLOSURE_PRESENT = YES` |

These values are mirrored as informational rows in `tables/master_plan_patch_status.csv` with `_INPUT` suffix so they are not confused with patch completion flags.

---

## Deliverables (required)

| File | Purpose |
| --- | --- |
| `tables/master_plan_patch_audit.csv` | Row-level trace from requirement to document change |
| `tables/master_plan_patch_status.csv` | `MASTER_PLAN_PATCH_COMPLETE=YES` and per-requirement patch flags |
| `reports/master_plan_patch.md` | This report |

---

## Patch completion flags

| Flag | Value |
| --- | --- |
| MASTER_PLAN_PATCH_COMPLETE | YES |
| PHASE_4_LANGUAGE_PATCHED | YES |
| PHASE_4_5_FORMALIZED | YES |
| CROSS_MODULE_POLICY_FORMALIZED | YES |
| MODULE_MODEL_FORMALIZED | YES |
| PHASE_GATES_PATCHED | YES |
| TRUST_TERMINOLOGY_PATCHED | YES |
| FALSE_CLOSURE_LANGUAGE_PATCHED | YES |

---

## Related documents

- `docs/system_master_plan.md`  
- `docs/infrastructure_laws.md` (PART 7)  
- `reports/system_closure_audit.md`  
- `reports/plan_realign_audit.md`  
