# Phase failure reconciliation audit and exit-plan reset

**Mode:** Read-only reasoning; no code or implementation changes performed as part of this deliverable.  
**Authoritative phase model:** `docs/system_master_plan.md`, `docs/infrastructure_laws.md`, `docs/repo_execution_rules.md`.  
**Evidence inputs (not assumed true without reconciliation):** `reports/canonical_switching_isolation_audit.md`, `reports/plan_realign_audit.md`, `reports/isolation_feasibility_audit.md`, `reports/system_closure_audit.md`, `reports/phase_0_3_revalidation.md`, plus `reports/execution_chain_audit.md` as cited by system closure for manifest identity.

**Deliverables:** `tables/phase_failure_reconciliation.csv`, `tables/phase_failure_reconciliation_status.csv`, this report.

---

## 1. Failure reconciliation (summary)

Row-level detail: **`tables/phase_failure_reconciliation.csv`**.

### Themes reconciled against the patched model

| Theme | Dominant classification | Blocking now? |
| --- | --- | --- |
| Freeze / working-tree drift | **AUDIT_OVERREACH** vs **DOC_DRIFT** (freeze semantics) | **NO** for starting recovery if Phase 0 is read as process/boundary freeze, not “zero git diff forever.” |
| Canonical entrypoint vs alternate runnable scripts | **DEFINITION_MISMATCH** (policy SSOT vs filesystem exclusivity) | **NO** for canonical-path work; alternate `.m` files are expected to exist; agents must use `tables/switching_canonical_entrypoint.csv`. |
| Backend definition stability | **N/A failure** in inputs (backend doc + registry coherent for primary runner) | **NO**. |
| Wrapper / validator chain | **DEFINITION_MISMATCH** | **NO** — `docs/repo_execution_rules.md` keeps validator optional; single `-batch` call is normative. |
| Manifest / fingerprint trust | **REAL_DEFECT** (entry script identity linkage) | **YES** for full **execution trust** (“what ran” = registered script hash/path). |
| Execution graph completeness | **DEFINITION_MISMATCH** / **LATER_PHASE_ITEM** | **NO** as a Phase 3 “failure” — legacy depth is explicitly bounded in docs. |
| Isolation registry reliability | **REAL_DEFECT** (relative to Phase 4.5 claims) | **YES** for **isolation trust** and enforcement readiness, not for “Switching-only run executes.” |
| `assertModulesCanonical` coverage | **LATER_PHASE_ITEM** / **REAL_DEFECT** at 4.5 | **YES** for Phase 4.5 closure. |
| False safety / false closure | **REAL_DEFECT** + **DOC_DRIFT** | **YES** — `CROSS_MODULE_PROTECTION_ACTIVE=YES` vs opt-in coverage is a governance-read hazard. |

---

## 2. Phase intent recheck (0–4.5)

| PHASE | INTENDED_CLOSURE_TYPE | AUDITED_AT_CORRECT_LEVEL | NOTES |
| --- | --- | --- | --- |
| 0 | GOVERNANCE + DOCUMENTATION | PARTIAL | Revalidation applied a **strict** “no drift / no alternate executables” lens; authoritative model allows Phase 0 closure as **process freeze + boundary documentation** without implying isolation or global enforcement. |
| 1 | DOCUMENTATION + GOVERNANCE | YES | SSOT entrypoint and backend definition are the core; “no other `.m` files on disk” is **not** the Phase 1 bar per patched model. |
| 2 | RUNTIME + DOCUMENTATION | YES | Wrapper + pre-guard match policy; treating optional validator as **required in chain** is **incorrect level** (definition mismatch). |
| 3 | DOCUMENTATION + RUNTIME (reality record) | YES | Phase 3 records reality including non-canonical surfaces; audits that demand **full transitive closure** over-read Phase 3. |
| 4 | EXECUTION TRUST (limited) | PARTIAL | Correct level **if** scope is execution trust only; **manifest entry identity** is still in-scope for Phase 4 **remainder**, not “isolation.” |
| 4.5 | ISOLATION + GOVERNANCE + ENFORCEMENT (readiness) | YES | Isolation audits evaluated the right layer; findings belong here, not as retroactive Phase 0–3 code defects. |

---

## 3. True blockers only

**TRUE_BLOCKERS_NOW** (minimal ordered list — genuine impediments to claiming the **next trustworthy closures** without looping):

1. **Governance false safety:** `tables/module_enforcement_status.csv` asserts `CROSS_MODULE_PROTECTION_ACTIVE=YES` while runtime coverage is opt-in and non-coextensive with the registered canonical Switching path (`isolation_feasibility_audit`, `system_closure_audit`). This blocks **trustworthy interpretation** of protection status until narrowed or aligned with behavior.

2. **Execution-trust remainder (manifest identity):** `run_manifest.json` `script_path` / `script_hash` resolving to `createRunContext.m` instead of the SSOT runnable (`execution_chain_audit`) blocks **full execution trust** for “what script ran” equals registry entrypoint.

3. **Phase 4.5 substantive closure:** Isolation alignment is **ACTIVE** and **not satisfied** per `docs/system_master_plan.md` Section 4 — policy implementability, registry path alignment, coverage, gate visibility in artifacts, participation model — which **gates Phase 5** until addressed.

Items **explicitly not** listed as blockers here (already covered as definition mismatch or later phase): strict git-clean freeze as Phase 0 failure; alternate `Switching/analysis/*.m` on disk; absence of validator inside `run_matlab_safe.bat`; incomplete mechanical call graph inside legacy Switching ver12.

---

## 4. Exit-plan reset (no loops)

**RESET_PLAN** — minimal ordering, explicit stop conditions, no re-auditing of dimensions already settled by the **patched** model unless **new evidence** appears.

| Step | Scope | Actions (conceptual) | Exit criteria | Do not revisit unless |
| --- | --- | --- | --- | --- |
| A | **Documentation / governance** (bottom layer) | Freeze semantics: align `tables/system_freeze_status.csv` / freeze docs with **actual** intended meaning (process snapshot vs repo-wide no-edit). Update cross-references so Phase 0 does not imply isolation closure. | Single narrative: Phase 0 = boundary/freeze **as documented**; no contradiction with `SYSTEM_CLOSED=NO` | Governance model changes |
| B | **False safety elimination** (bottom layer) | Reconcile `CROSS_MODULE_PROTECTION_ACTIVE` (and related rows) with **measured** coverage **or** rename scope in the same table family. | Status tables do not imply repo-wide mechanical enforcement beyond evidence | Protection mechanism changes |
| C | **Execution trust completion** (runtime + manifest) | Resolve manifest `script_path` / `script_hash` to registered entry script **or** publish authoritative alternate verification path in `docs/run_system.md` / manifest contract with same stop condition. | Fingerprint answers “what runnable executed” per SSOT **or** documented exception path | Manifest writer or resolution rules change |
| D | **Signaling contract clarity** (bottom layer) | Document or unify `execution_status.csv` placement (run root vs `tables/`) for multi-entry Switching surfaces. | Consumers have machine-readable rule; no silent ambiguity | New entry scripts |
| E | **Phase 4.5 isolation work** (isolation layer — **not** mixed with A–D closure) | Registry alignment with canonical runner; gate visibility in artifacts; `modules_used` / participation model; enforcement design feasibility; Type A/B promotion criteria in plan text. | `docs/system_master_plan.md` Phase 4.5 gate conditions and `isolation_feasibility_audit` flags support closure **or** explicit deferred scope with **no** false-safe tables | Policy or registry schema changes |
| F | **Phase 5 entry** | Only after B–E (as required by gates) and per `docs/system_master_plan.md` Section 7. | `SAFE_TO_ENTER_PHASE_5=YES` per updated audits | N/A |

**Clear distinction:** Steps A–D are **bottom-layer recovery** (trustworthy docs, execution identity, signaling clarity). Step E is **isolation alignment** — do **not** re-audit Phases 0–3 “failure” lists while doing E unless new regressions appear.

---

## 5. Final verdict

| Field | Value |
| --- | --- |
| **RECONCILIATION_COMPLETE** | **YES** |
| **PHASE_MODEL_NOW_TRUSTWORTHY** | **YES** — the patched model in `docs/system_master_plan.md` correctly separates execution trust, system trust, and isolation trust; prior audit “failures” often applied wrong-phase criteria. |
| **SAFE_TO_START_RECOVERY** | **YES** — recovery can start with Steps A–C (governance + manifest identity) without repeating full Phase 0–3 revalidation cycles, provided work follows the reset plan order and does not conflate Phase 4 remainder with Phase 4.5 isolation work. |

**Required status:** `PHASE_FAILURE_RECONCILIATION_COMPLETE=YES`

---

## Output files

| File | Role |
| --- | --- |
| `tables/phase_failure_reconciliation.csv` | Row-level reconciliation |
| `tables/phase_failure_reconciliation_status.csv` | Machine-readable verdicts |
| `reports/phase_failure_reconciliation.md` | This report |
