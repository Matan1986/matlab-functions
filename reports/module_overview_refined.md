# Module overview refined (Phase 5A.2 FIX)

**Source of truth:** `tables/module_overview.csv` only (no filesystem rescan, no added modules).

## What changed from the original classification

| Area | Original | Refined |
| --- | --- | --- |
| **Schema** | `canonical_presence` | Replaced by **`canonical_candidate`** (YES / WEAK / NO) with conservative semantics |
| **Roles** | Implicit in notes | Explicit **`module_role`** on every row |
| **Canonical strength** | Binary YES + UNKNOWN | **WEAK** for prior filename-scan hints on core trees; **NO** where clearly non-canonical (e.g. **`tools`**) |
| **Mixed** | Often YES for core + analysis | **Aggressively NO** except **`zfAMR ver11`** (legacy label + prior `analysis_presence` YES → treated as structural boundary case) |
| **Prioritization** | — | **`relevance`** and **`candidate_for_deep_dive`** added for Phase 5 planning |

## Corrections applied (per required fixes)

- **`tools`:** **`module_role`** = `INFRA_COMPONENT`; **`canonical_candidate`** = `NO` (not an experiment canonical tree; wrappers/infra only, per fix).
- **Root `analysis`:** **`module_role`** = `ANALYSIS_MODULE`; **`canonical_candidate`** = `NO`; **`mixed`** = `NO` (single-purpose analysis zone).
- **`* verX*` modules (including `Tools ver1`, instrument packages, etc.):** **`module_role`** = `LEGACY_MODULE`; **`Relaxation ver3`** stays **`CORE_MODULE`** (Relaxation-like system, not classed as legacy-only).
- **Core trio (`Aging`, `Switching`, `Relaxation ver3`):** **`module_role`** = `CORE_MODULE`; **`canonical_candidate`** = `WEAK` (prior table only showed path/filename hints, not verified entrypoints).

## Remaining uncertainties

- **`canonical_candidate`:** No row is **`YES`** (strong entrypoint signal) because the source CSV did not encode verified entrypoint lists—only prior YES/NO/UNKNOWN from a structural scan. Upgrading to **`YES`** would require evidence outside this file (disallowed here).
- **`GUIs`**, **`review`:** Left as **`UNKNOWN`** role; low impact for Phase 5 unless UI work is in scope.
- **`claims`**, **`snapshot_scientific_v3`:** Classed as **`INFRA_COMPONENT`** with **`WEAK`** canonical-adjacent filename cues from the original table—role boundaries may still need run-contract review in 5B.

## Is module structure now reliable for Phase 5B?

**Yes, for decision-making at the “which buckets matter” level:** roles, relevance, and deep-dive candidates are aligned with the refined rules and the specific corrections (`tools`, root `analysis`, `verX` legacy). **Caveat:** **`canonical_candidate`** is deliberately conservative (mostly **`WEAK`** or **`NO`**); Phase 5B should treat **`WEAK`** as “needs confirmation,” not proof of canonical runners.

**Machine-readable outputs:** `tables/module_overview_refined.csv`, `tables/module_refined_status.csv`.
