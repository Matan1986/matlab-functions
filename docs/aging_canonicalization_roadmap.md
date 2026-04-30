# Aging Canonicalization Roadmap

## Purpose

This roadmap records required Aging module gates after Stage G4.1b and before any cross-module analysis.
It is a planning and governance artifact only. It does not change definitions, formulas, or execution logic.

## Lesson from Relaxation cleanup (planning principle)

Technical canonicalization is **not** sufficient if the user still cannot explain what physics survived from the old analysis. A module can have clean code and provenance but lack a reconstructed physical picture of what the prior work was actually trying to show.

Therefore Aging adds explicit **forensic** and **replay-planning** gates (I0, I1) **before** deep canonical review (I) and **before** physical synthesis (J).

## F-series branch — Tau/R semantic metadata track (logged 2026-04-30)

**Purpose:** Routing note for agents so tau/R CSV verification is not mistaken for patch failure.

- **F7G (complete, committed):** `ced4798` — Add Aging tau R semantic metadata columns. Writers append **`writer_family_id`**, **`tau_domain`**, and related columns before save; **`tau_effective_seconds`** stays as a legacy column but is disambiguated by metadata when patches run successfully.
- **F7H (attempted; blocked):** Real-output CSV inspection did **not** run to completion — **no** `tau_vs_Tp.csv` etc. generated or found. **Cause:** consolidated **`aging_observable_dataset.csv`** unavailable at writer default **`results/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv`** in the audited workspace (**empty/missing `results/` tree**, not malformed F7G code).

**Governance stops until resolved:**

1. **Do not** repeat tau/R **real-output** metadata verification cycles until **`F7I — Aging dataset availability + lineage audit`** (or equivalent) restores a known-good dataset pointer and lineage.
2. **Do not** perform tau/R **physics interpretation** off legacy/unresolved extracts when consolidation path identity is unclear.
3. **Do not** extend F7G-style metadata to replay/proxy/`WF_PIPELINE_CLOCKS` writers until **dataset lineage** is understood --- scope remains documented as **pending**.

**Pointers:** `reports/aging/aging_F7H_real_output_metadata_verification.md`, `reports/aging/aging_F7H_blocked_verification_roadmap_update.md`, `tables/aging/aging_F7H_blocked_verification_status.csv`.

## Current State Snapshot

- Measurement contract exists and is frozen.
- Canonical **materialization path** used by patched tau/R writers expects a consolidated **`aging_observable_dataset.csv`** under a **run snapshot** directory (historical writer default references `results/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/`). Separate planning rows may cite `tables/aging/aging_observable_dataset.csv` --- **presence depends on cloning/dataset policy** (see **F-series branch** above). **Agents must reconcile path + lineage before tau/R producers run.**
- Reader-path plumbing is in place.
- Multi-`Tp x tw` aggregate and consolidation support is in place.
- Latest status indicates:
  - `READY_FOR_G3_TAU_CHAIN_RUN = YES`
  - `READY_FOR_ROBUSTNESS_AUDIT = PARTIAL` (or `YES` when tau-chain and robustness work close)

## Required Stage Order

1. **Technical stabilization / source integrity** — pathing, contracts, execution hygiene, no silent legacy paths.
2. **Canonical dataset / provenance / validation** — consolidation contract, lineage, inventory-driven coverage where applicable.
3. **Tau-chain artifacts** — G3 producers and reader smoke prerequisites on the current dataset.
4. **Robustness / sensitivity** — stability and sensitivity evidence before forensic and governance gates.
5. **Gate I0 — Forensic old-analysis physics survey** — reconstruct what old Aging analysis was trying to show (see below).
6. **Gate I1 — Replay / validation plan** — classify old work and define what must be replayed under the new framework (see below).
7. **Gate I — Deep canonical review** — technical and contract governance on top of I0/I1 context.
8. **Gate J — Physical synthesis** — blocked until I0, I1, and I pass.
9. **Gate K — Repo documentation / claims** — equations, allowed/forbidden claims, old-to-new mapping.
10. **Gate L — Stop before cross-module** — no Aging x Switching / Aging x Relaxation until prerequisites below.

Cross-module work is allowed only after Switching and Relaxation readiness **and** an approved cross-module plan, in addition to Gate L criteria.

## Gate I0 — Forensic Old-Analysis Physics Survey

**When:** After technical stabilization, canonical dataset validation, tau-chain artifacts, and robustness/sensitivity work sufficient to contextualize outputs — **before** physical synthesis and **before** Gate I is treated as complete without this survey.

**Purpose:** Reconstruct what the **old** Aging analysis was actually trying to show, not only which files and columns existed.

**Required checks:**

- Scan old reports, tables, scripts, figures, and outputs.
- Identify themes, results, and claims **attempted** by old Aging analysis.
- Do **not** assume a mature claims layer already exists.
- Group old work by **physical theme**, for example:
  - AFM/FM separation
  - Dip clock / FM clock
  - Tau extraction
  - Collapse / rescaling
  - SVD / rank structure
  - Time-mode / wait-time scaling
  - High-T / transition behavior
  - Paper 1 direct phenomenology
- Identify which old results were quantitative claims, diagnostics, exploratory plots, or obsolete/legacy.
- Identify which old results already have canonical replacement artifacts.
- Identify which old results need replay under the new Aging canonical framework.
- Identify which old results should be quarantined or retired.

**Suggested future artifacts** (to be produced when I0 is executed; names are targets, not a commitment to run now):

- `tables/aging/aging_old_analysis_physics_theme_inventory.csv`
- `tables/aging/aging_old_analysis_replay_validation_plan.csv` (may be superseded or merged with I1 outputs; see Gate I1)
- `reports/aging/aging_old_analysis_physics_survey.md`

## Gate I1 — Replay / Validation Plan

**When:** Immediately after Gate I0 outputs exist — **before** physical synthesis and **before** Gate I closure if I depends on replay scope.

**Purpose:** Define what must be replayed or validated under the new canonical framework before any physics synthesis.

**Required classifications** (each old theme or artifact row should map to one of these where possible):

- `KEEP_CANONICAL`
- `REPLAY_REQUIRED`
- `DIAGNOSTIC_ONLY`
- `QUARANTINE_LEGACY`
- `RETIRE`
- `DEFER_TO_PAPER2`
- `UNKNOWN_NEEDS_REVIEW`

**Principle:** Do **not** write physical synthesis until the old-analysis survey (I0) and the replay/validation plan (I1) exist.

**Suggested future artifact:**

- `tables/aging/aging_old_analysis_replay_validation_plan.csv` (primary machine-readable plan for I1; align columns with classification vocabulary above.)

## Gate I — Deep Canonical Review

**When:** After I0 and I1 are in place (draft or PASS per project rules) and robustness evidence is sufficient.

Must verify all of the following (in addition to incorporating I0/I1 findings):

- No hidden assumptions were introduced by new canonicalization steps.
- Track A vs Track B separation remains valid.
- `aging_observable_dataset.csv` is treated as a consolidation contract, not raw truth.
- Ragged `Tp x tw` coverage is handled correctly.
- `source_run` lineage is valid and traceable.
- Old readers/artifacts are reproducible or explicitly marked legacy (aligned with I0/I1).
- No incompatible observable mixing is present.
- Local path/config fixes are plumbing-only changes.
- Outputs trace to scripts and manifests.
- All claims are supported by artifacts.

## Gate J — Physical Synthesis

This gate is blocked until **Gate I0**, **Gate I1**, and **Gate I** all pass (or meet the project’s explicit PASS criteria for each).

When Gate J is opened, it must answer:

- What new Aging observables mean physically.
- What changed versus prior Aging analysis language.
- What survived.
- What weakened.
- What must be dropped.
- What can be claimed for Paper 1.
- What must be deferred.

## Gate K — Repo Documentation / Claims

Must produce repository documentation covering:

- Equations.
- Variable definitions.
- Lineage.
- Interpretation scope.
- Allowed claims.
- Forbidden claims.
- Track A vs Track B caveats.
- Ragged `Tp x tw` caveats.
- Mapping between old and new language (grounded in I0/I1).

## Gate L — Stop Before Cross-Module

Explicit stop rule:

No Aging x Switching or Aging x Relaxation cross-analysis is allowed until all are true:

- Gate I0 forensic survey is complete (or explicitly waived only by documented project decision — default is **required**).
- Gate I1 replay/validation plan exists and is accepted for scope before synthesis.
- Aging canonical review is complete (Gate I).
- Aging physical synthesis is documented (Gate J).
- Repo claims documentation is in place (Gate K) as required by project policy.
- Switching canonicalization is ready.
- Relaxation canonicalization is ready.
- A separate cross-module plan is approved.

## Current Blocking Policy

- **Physical synthesis** is blocked until **I0, I1, and I** pass (not merely technical canonicalization or tau-chain completion).
- **Cross-module analysis** is blocked until Aging forensic survey (I0), replay plan (I1), review (I), synthesis (J), and claims documentation (K) are done **and** Switching and Relaxation are ready **and** a cross-module plan is approved (Gate L).
- Advancing from tau-chain or robustness work **directly** into physical synthesis or cross-module analysis without I0/I1 is forbidden.
- `PHYSICAL_SYNTHESIS_ALLOWED_NOW = NO`
- `CROSS_MODULE_ANALYSIS_ALLOWED_NOW = NO`

## Required Verdicts

- `AGING_ROADMAP_UPDATED = YES`
- `FORENSIC_OLD_ANALYSIS_GATE_I0_DEFINED = YES`
- `REPLAY_VALIDATION_GATE_I1_DEFINED = YES`
- `DEEP_CANONICAL_REVIEW_GATE_DEFINED = YES`
- `PHYSICAL_SYNTHESIS_GATE_DEFINED = YES`
- `CLAIMS_DOCUMENTATION_GATE_DEFINED = YES`
- `CROSS_MODULE_STOP_GATE_DEFINED = YES`
- `PHYSICAL_SYNTHESIS_ALLOWED_NOW = NO`
- `CROSS_MODULE_ANALYSIS_ALLOWED_NOW = NO`
