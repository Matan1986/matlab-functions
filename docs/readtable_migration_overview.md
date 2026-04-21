# Readtable migration overview

This document explains **what** the readtable migration did and **why** the architecture looks the way it does.

---

## Original problem

**`HIDDEN_ENFORCEMENT_INSIDE_IO`**

- `readtable` (and nearby I/O paths) performed validation, coercion, or fixes.
- That behavior was **hidden** inside load routines instead of living in an explicit layer.
- Hidden enforcement **broke system layering**: it was unclear whether failures were I/O, validation, or pipeline bugs.

---

## Solution

**`EXPLICIT_VALIDATION_LAYER`**

- **Separation of concerns**: pre-I/O validation, pure I/O, then pipeline logic.
- Validation was **moved upstream** so that checks are visible, named, and testable before any read.

---

## Migration strategy

The migration proceeded in controlled steps rather than a single risky rewrite:

- **P01** — Feasibility: establish that separation and equivalence checks were workable.
- **P02 batches** — Batched rollout of migrated call sites and checks.
- **Fast batches** — Smaller, faster batch runs to validate behavior without long end-to-end cycles.
- **No-refactor approach** — Goal was to **preserve behavior** and clarify layers, not to redesign unrelated code.

---

## Key insight

**Explicit ≠ identical**  
**Explicit ≈ behavior match**

Making validation explicit does not mean byte-for-byte or line-for-line duplication of old hidden logic. It means: the **observable outcomes** of load + downstream assumptions match what the system already did (**weakening** where strict identity is impossible or undesirable — e.g. documenting tolerances, ordering, or edge cases rather than pretending two implementations are the same function).

---

## Final state

- **S2 equivalence** was achieved in the sense defined for this project (behavioral alignment under the migration tests).
- **Downstream assumptions** were exposed: failures and quirks became visible as pipeline or contract issues, not buried in I/O.
- **IO layer clean**: reads are reads; enforcement lives before or after, not inside I/O.

---

*Overview only — see `readtable_migration_decisions.md` for rationale and `io_validation_contract.md` for hard rules.*
