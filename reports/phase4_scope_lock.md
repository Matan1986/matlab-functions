# Phase 4.0 — Scope Lock (Switching remediation)

**Documentation only.** **Switching module only.** This document gates all Phase 4 work: no scope drift beyond what Phase 3 explicitly documented as non-canonical.

**Status flags:** `PHASE4_SCOPE_LOCKED=YES`, `SCOPE_DRIFT_ALLOWED=NO`.

Machine-readable scope rows: `tables/phase4_scope_lock.csv`. Machine-readable flags: `tables/phase4_scope_status.csv`.

---

## Rule: Phase 4 fixes only Phase 3 non-canonical items

Phase 4 remediation may address **only** the non-canonical aspects **explicitly identified and recorded** in Phase 3 closure (`reports/phase3_system_reality_closure.md`, `tables/phase3_system_reality_summary.csv`). Any other change is **out of scope** and requires a separate planning record; it is **not** part of Phase 4.

---

## IN_SCOPE (exact)

| ID | Item | Phase 3 reference |
|----|------|-------------------|
| SW_P4_01 | **Run directory canonical root** — align with a single globally enforced canonical run root (today: module-specific `results/Switching/runs` via `createRunContext`). | Section 3 (A), NON_CANONICAL_A |
| SW_P4_02 | **Failure path canonicalization** — failure runs follow the same manifest + fingerprint + `run_dir` contract as success (address early failure / `switching_canonical_failure` / `run_failure_*` gaps). | Section 3 (B), NON_CANONICAL_B, BS-05 |
| SW_P4_03 | **External data contract (formalization only)** — defined root, deterministic resolution, stable identity; **no** raw data relocation into the repo. | Section 3 (C), NON_CANONICAL_C, BS-04 |
| SW_P4_04 | **Signaling contract clarification** — clear final-state semantics (e.g. `execution_status.csv` overwritten during run; **last write wins**; mid-run copies non-final). | Section 3 (D), NON_CANONICAL_D, BS-02 |

---

## OUT_OF_SCOPE (explicit)

The following are **excluded** from Phase 4 Switching remediation:

- **Scientific logic** — physics, observables, algorithms, numerical interpretation.
- **Pipeline redesign** — new stages or replacement of the verified execution chain.
- **Performance changes** — speed, parallelization, batching, resource use.
- **Refactoring** — stylistic or structural cleanup not required to remediate the four Phase 3 items above.
- **Caching** — new or changed caches for inputs, outputs, or intermediates.
- **Data relocation into the repository** — contradicts Phase 3 intentional external-data policy; formalization only is in scope.
- **Any issue not explicitly documented in Phase 3 closure** — no ad-hoc expansion; new gaps need a new phase or amendment outside Phase 4.

---

## Locked scope statement (gate)

**Phase 4 (Switching) is authorized solely to remediate the four documented non-canonical areas from Phase 3: (1) run directory canonical root, (2) failure path canonicalization, (3) external data contract formalization without relocation, and (4) signaling contract clarification. All other work—including scientific changes, pipeline redesign, performance work, refactoring, caching, importing external data into the repo, and fixes for issues not recorded in Phase 3—is forbidden under Phase 4. Scope drift is not allowed.**

---

## Relation to Phase 3 verdict

Phase 3 closed with `FULLY_CANONICAL=NO` and `PHASE_3_CLOSED=YES`. Phase 4 does not reopen Phase 3 for new findings; it implements **only** the locked list above.
