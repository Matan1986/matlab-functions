# Readtable migration decisions

This document preserves **critical decisions** so future work does not re-litigate them without context.

---

## Why no “system fixing”

The migration goal was to **preserve behavior** and **clarify layers**, not to “improve” the system in the sense of fixing every latent bug or smell.

- Refactoring for quality during migration would have mixed **behavior preservation** with **product changes**, making regressions hard to attribute.

---

## Why failures were not fixed as part of migration

Failures that surfaced often reflected **real system assumptions** (implicit shapes, column names, ordering, or cross-module expectations).

- **Fixing them inside I/O or validation** would have **hidden truth again** — the same class of problem the migration was meant to remove.

---

## `NON_MIGRATABLE` definition

Some call sites or modules are **not suitable** for a thin, local pre-I/O validation layer:

- **Multi-source logic** — validation that inherently depends on many inputs or contexts not available at a single read boundary.
- **Cross-table dependencies** — consistency that only makes sense after several tables or sources are combined.
- **Not suitable for thin validation** — the check is really **pipeline** or **orchestration** work, not a pre-read gate.

**Example (illustrative):** `run_alpha_res_cross_experiment_correlation` — cross-experiment, cross-run correlation logic does not map cleanly to a single `local_*_input_ok` in front of one `readtable`.

---

## Why the mega batch was abandoned

A single large “mega” batch proved **undesirable**:

- **MATLAB issues** — environment, licensing, or tooling friction at large scale.
- **Bottlenecks** — long runtimes, hard debugging, difficult bisection when something failed.
- **Risk** — one failure could invalidate a huge surface area; harder to roll forward safely.

---

## Why fast batches worked

Smaller **fast batches** aligned with the migration goals:

- **Controlled scope** — fewer sites per run, easier to verify.
- **No infra changes** — did not depend on new runners or parallel infrastructure.
- **Stable rollout** — failures were localized; fixes and re-runs were tractable.

---

## Final interpretation

**Migration:**

- **Did not fix the system** in the holistic sense — it was not a greenfield rewrite or bug-fix campaign.
- **Did expose the system** — where assumptions lived, what broke when I/O stopped “helping,” and what belonged in validation vs pipeline became visible.

---

*Decisions are descriptive of the migration as executed; they are not a mandate against future refactors — only context for why this effort stayed bounded.*
