# System master plan — lifecycle phases and closure model

**Status:** Authoritative program model for repository **closure**, **phase entry**, and **trust semantics**.  
**Scope:** Planning, gating, and interpretation only — **no** runtime enforcement; implementation follows separate tasks.  
**ASCII only.**  
**Audited inputs:** Canonical isolation audit, plan realignment audit, isolation feasibility audit, end-to-end closure audit (see `reports/system_closure_audit.md`, `reports/plan_realign_audit.md`, `reports/isolation_feasibility_audit.md`, `reports/canonical_switching_isolation_audit.md`).

This document exists so **execution-trust** achievements are not misread as **system-wide** or **isolation** closure. Prior narrative that Phases 0–4 were “DONE” remains **historically valid** where evidence supports it; **interpretation** below is the binding plan reading.

---

## 1. Phase model (authoritative)

| Phase | Name |
| --- | --- |
| Phase 0 | System Freeze + Boundary |
| Phase 1 | Canonical Definition (Switching) |
| Phase 2 | Execution System Validation |
| Phase 3 | System Reality Audit |
| Phase 4 | Execution Trust Closure |
| Phase 4.5 | Canonical Isolation Alignment |
| Phase 5 | System Formalization |
| Phase 6 | Scientific Re-entry |

**Current status model (plan-level):** Phases 0–4 were previously marked **DONE** in program narrative; **Phase 4.5** is **ACTIVE**; **Phases 5–6** are **BLOCKED** until gates below are satisfied.

---

## 2. Trust terminology (non-interchangeable)

| Term | Meaning |
| --- | --- |
| **Execution trust** | Confidence that automated runs use the approved wrapper, emit signaling artifacts, write under canonical run roots, and record manifest/fingerprint fields for **run identity** as defined in `docs/run_system.md` and `docs/infrastructure_laws.md`. Does **not** imply correct **entry-script** identity in every manifest edge case; see execution-chain audits. |
| **System trust** | Confidence that the **repository as a whole** satisfies infrastructure laws, module participation rules, and absence of **false closure** (no document or status table claims “closed” beyond what evidence supports). Requires **Phase 4** (limited sense) **and** **Phase 4.5** closure for isolation-aligned claims. |
| **Isolation trust** | Confidence that **canonical subsystem boundaries**, **module registry** claims, and **cross-module** policy are aligned with reality and that **false safety** (believing isolation exists when it does not) is eliminated. Owned by **Phase 4.5**, not Phase 4. |

**Rule:** Do not use “trust,” “closure,” or “safe to proceed” without specifying **which** trust domain applies.

---

## 3. Phase 4 — Execution Trust Closure only

**Phase 4 closes (in scope):**

- Deterministic execution (per program scope; see `reports/phase4_scope_lock.md` for Switching remediation bounds).
- Manifest / fingerprint **presence** and run identity **artifacts** as defined for the execution-trust program.
- No silent failure and explicit signaling contract where scoped (e.g. `execution_status.csv`, probe files per `docs/repo_execution_rules.md`).
- Run identity integrity **at the level of the closure program** (not repository-wide contamination or module registry guarantees).

**Phase 4 explicitly does NOT guarantee:**

- Canonical **subsystem isolation** (Switching vs Relaxation vs Aging namespaces, aggregate inputs, or path leakage).
- **Cross-module enforcement** (assert coverage, registry reliability repo-wide).
- **Repository-wide** contamination protection or “safe for any script anywhere.”

**Reinterpretation of prior “DONE” for Phase 4:** Historical **DONE** means **execution-trust closure in the limited sense above**. It does **not** mean full **system trust** or **isolation trust**. Where audits report gaps (e.g. manifest entry identity vs. registered script), **execution trust** remains **partial** until remediated; that does not retroactively erase Phase 4 scope-lock work but **corrects** any misreading of Phase 4 as total trust.

**Normative infrastructure detail:** `docs/infrastructure_laws.md`, `docs/repo_execution_rules.md`, `reports/phase4_scope_lock.md`.

---

## 4. Phase 4.5 — Canonical Isolation Alignment (mandatory)

Phase 4.5 is **not optional**: it is the mandatory closure layer for concerns Phase 4 **excludes**.

**Phase 4.5 must close (documentation and evidence targets; enforcement is separate):**

1. **Canonical subsystem isolation verification** — audited answer to whether the canonical Switching (and related) story is **isolated** from non-canonical paths in practice (`CANONICAL_SWITCHING_ISOLATED` and related flags in isolation audits).
2. **Module-level canonical status model** — explicit representation of which modules are **canonical** for participation in governed workflows (registry and tables as referenced in plan realignment audits).
3. **Cross-module policy definition** — written policy for which analyses may combine modules (see Section 6).
4. **Enforcement alignment requirement** — plan and audits must agree on whether policy is **implementable**, registry **reliable**, and **coverage** sufficient before claiming operational closure (`POLICY_IMPLEMENTABLE`, `REGISTRY_RELIABLE`, `ENFORCEMENT_COVERAGE_SUFFICIENT`, `SYSTEM_READY_FOR_ISOLATION_ENFORCEMENT` from feasibility audit).
5. **False-safety elimination requirement** — documentation and status artifacts must not imply isolation or cross-module safety when audits say **FALSE_SAFETY_RISK = YES**.

**Authoritative audit posture (as of plan patch):** Isolation layer is **not** aligned with canonical subsystem; **false safety risk** is present; system is **not** ready for isolation enforcement as a closed operational loop. Phase 4.5 therefore remains **ACTIVE** until documentation and evidence support closure.

---

## 5. Module model — Type A vs Type B

| Type | Definition |
| --- | --- |
| **Type A** | Modules with **prior non-canonical** analysis paths that require **canonical reconstruction** (re-onboarding under registry, dependency boundaries, and run-system rules). |
| **Type B** | Modules that can follow **canonical-first onboarding** without a prior reconstruction program (no substantial legacy cross-contamination in scope). |

**Classification (plan default):**

- **Switching**, **Relaxation** (`Relaxation ver3/` tree), and **Aging** are **Type A** reconstruction modules for this program.
- **Other modules** are treated as **Type B** unless an audit proves Type A conditions.

Relaxation and Aging may be canonicalized **in parallel** with Switching work; **cross-module scientific workflows** remain **blocked** until every **participating** module in that workflow is **canonical** per the participation rule (Section 6).

---

## 6. Cross-module canonical participation (system law)

**Law (binding, normative):** **Cross-module analysis is allowed only if all participating modules are canonical** for the scope of that analysis (module canonical status, entrypoints, and dependency rules as defined by the program).

**Operational status:** Until **enforcement** is **real** and **coverage-complete**, this rule is **normative** but **not** **operationally closed** — i.e. the repository must **treat** cross-module analysis as **governed** by this law, but **cannot** claim the law is **fully enforced** everywhere. This matches audited findings: policy implementability and enforcement coverage are **not** yet sufficient for closure.

**Formal duplicate:** The same rule is stated in `docs/infrastructure_laws.md` (PART 7) as infrastructure law text.

---

## 7. Phase-entry gates

| Transition | Gate |
| --- | --- |
| **Phase 5 (System Formalization)** | **Phase 4** closed in the **execution-trust** sense **and** **Phase 4.5** closed per audit criteria (isolation alignment, false-safety elimination at documentation/evidence level, and agreed enforcement-readiness where the program requires it). If **FORMALIZATION_BLOCKED_PENDING_PLAN_PATCH** or equivalent audit flags apply, formalization completion cannot be claimed **system-wide**. |
| **Phase 6 (Scientific Re-entry) — cross-module** | **All participating modules** in the scientific workflow must be **canonical**. Cross-module science remains **blocked** until that holds. |
| **Phase 6 — Switching-only** | Scientific re-entry **within Switching-only canonical scope** may be narrated separately from cross-module re-entry; it does **not** unlock cross-module work. |
| **Parallel canonicalization** | Relaxation and Aging may advance toward canonical state **in parallel**; **cross-module** science stays **blocked** until **canonical closure of all involved modules** in that workflow. |

**Closure audit posture (as of plan patch):** **SYSTEM_CLOSED = NO**; **SAFE_TO_ENTER_PHASE_5 = NO**; **FALSE_CLOSURE_PRESENT = YES** at the **system** level — meaning narrative must not claim full closure. **Phase 5–6** remain **BLOCKED** until gates and audits support otherwise.

---

## 8. False closure correction (preserve history, fix interpretation)

| Prior claim | Correct reading |
| --- | --- |
| Phases 0–3 **DONE** | May remain **closed** where **prior evidence** and audit files support the factual record (freeze, definition, execution validation, reality audit). |
| Phase 4 **DONE** | Closed **only** in the **execution-trust** sense (Section 3). **Not** full system or isolation closure. |
| “System closed” or “safe for formalization / cross-module science” | **Not** established; **full system closure was not achieved** by Phases 0–4. |
| Why Phase 4.5 exists | Precisely because **full** closure — including **isolation trust** and **cross-module** safety — **was not** achieved by Phase 4 alone. |

**Evidence preservation:** Completed audits and scope locks (`reports/phase3_system_reality_closure.md`, `reports/phase4_scope_lock.md`, execution-chain and closure audits) remain **historical evidence**; this document **reframes** how they combine into **system** conclusions without deleting them.

---

## Related documents

- `docs/infrastructure_laws.md` — PART 7 cross-module law; consolidation gate  
- `docs/repo_execution_rules.md` — wrapper and signaling  
- `docs/repo_context_infra.md` — execution vs system vs isolation trust pointers  
- `reports/system_closure_audit.md` — end-to-end closure verdicts  
- `reports/plan_realign_audit.md` — plan update requirements  
- `reports/canonical_switching_isolation_audit.md` — isolation findings  
- `reports/isolation_feasibility_audit.md` — enforcement feasibility  
