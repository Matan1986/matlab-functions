# MT Stage 7.0 — Exploratory Analysis Plan (Cross-Module Mechanism Integration)

## Purpose and scope

This document is an **exploratory analysis plan only**. It describes how the MT (magnetization vs temperature/field) module **could eventually** align with Switching, Aging, and Relaxation for mechanism-oriented work, **without** performing cross-module analysis, changing code, or asserting physics.

**Stage 7.0 is planning only and does not perform cross-module analysis or make mechanism claims.**

Checkpoint reference: MT Stage 6.0 committed as `7b5c365` (Record MT module checkpoint stop state).

---

## Current allowed MT analysis scope

MT may support **diagnostic and canonical descriptive review** using table outputs built from:

- **row_count** — coverage and completeness at the table level
- **T_K_summary** — temperature axis sanity (range, monotonicity checks where defined in gates)
- **H_Oe_summary** — field axis sanity
- **M_emu_clean_summary** — moment summaries after cleaning path
- **M_over_H_emu_per_Oe_summary** — ratio summaries where defined and gated

These groups are suitable for **MT-only** inventory, QC, and internal review. They do **not** authorize production release, advanced analysis, or interpretive claims beyond what the tables explicitly encode.

---

## Current forbidden scope

Until further implementation and validation stages complete, the following remain **out of scope** for claims and for automated cross-module stitching:

- Derivatives and transition-candidate constructions
- Mass-normalized observables (without provenance)
- Segment-based and ZFC / FCC / FCW comparative framing as science outputs
- Hysteresis-like metrics (loops, remanence/coercivity narratives tied to MT alone)
- Cross-module mechanism or pathway claims
- Production canonical release or advanced-analysis sign-off

Blocked claims and evidence needs are enumerated in `tables/mt_stage70_blocked_claims.csv`. Cross-module prerequisites are in `tables/mt_stage70_cross_module_requirements.csv`.

---

## Safe first MT-only exploratory questions

These questions are answerable **in principle** with current allowed inputs, subject to run artifacts and gate pass/fail semantics (no new code assumed):

1. **Coverage:** Do canonical point tables exist and pass row-count expectations for each configured series?
2. **Axes:** What are the reported `T_K_summary` and `H_Oe_summary` ranges; are they internally consistent with labels and protocol?
3. **Signal level:** What do `M_emu_clean_summary` and `M_over_H_emu_per_Oe_summary` show as descriptive summaries (not interpreted as transitions or phases)?
4. **Gate health:** Which hardened gates failed, and do failures isolate bad rows vs systematic issues?
5. **Reproducibility:** Do repeated runs (if available) produce stable summary tables for the same inputs?

See `tables/mt_stage70_analysis_questions.csv` for structured question IDs and blockers.

---

## What MT features might eventually matter

### For Switching

Switching work often stresses **thresholds, barriers, and field-driven reconfiguration**. MT could eventually contribute:

- Field-aligned **M(H,T)** structure at fixed T slices relevant to switching experiments
- Descriptive **M/H** behavior where it supports boundary conditions for models (not coercivity claims without hysteresis implementation)
- **Temperature** context for whether a state is probed in a comparable regime to switching protocols

**Additional implementation before a designed connection:** derivatives or smooth local structure if Switching models need slopes; segment or protocol tags if experiments differ by ZFC/FCW; explicit alignment keys (sample id, run id, T/H grids) documented in a cross-module alignment design stage.

### For Aging

Aging stresses **time evolution** at often fixed or slowly varying (T,H). MT is primarily **(T,H) point** product today. A future link might use:

- **Baseline** magnetization summaries at (T,H) points that match aging hold conditions
- **QC** that aging-time series are paired with MT tables that share sample and condition metadata

**Additional implementation before a designed connection:** provenance for mass and normalization if aging comparisons use moment per mass; temporal alignment is an Aging-side construct — MT must expose stable identifiers and (T,H) keys only after alignment design.

### For Relaxation

Relaxation is **time-domain** after perturbation. MT point tables do not replace relaxation traces. A future role:

- **Equilibrium or reference** moment at (T,H) matching relaxation initial or final states
- **Regime consistency:** same T/H grid or explicit interpolation rules once alignment design exists

**Additional implementation before a designed connection:** no relaxation claims from MT summaries alone; require relaxation artifacts plus cross-module alignment and, where needed, derivatives or segment labels for protocol matching.

---

## Additional implementation required before each cross-module connection

| Connection | Required MT-side (conceptual) | Other modules |
|------------|-------------------------------|---------------|
| Switching | Stable keys; possibly dM/dH or local structure; protocol/segment tags if comparing to field protocols | Switching observables and shared id/T/H convention |
| Aging | Stable (T,H) summaries; mass provenance if normalized comparisons | Time index and sample linkage |
| Relaxation | Reference M at matched (T,H); alignment spec | Relaxation run metadata and T/H match rules |

All of the above sit **after** MT-only descriptive review and **after** a dedicated **cross-module alignment design** stage; **mechanism testing** comes last.

---

## Explicit staged roadmap

1. **MT-only descriptive review** — Use only allowed summary groups; document gaps and gate outcomes; no cross-module joins.
2. **Derivative / transition candidate implementation** — Implement and validate in MT pipeline with explicit gates; still no cross-module claims until alignment design.
3. **Mass provenance implementation** — Trace mass source, units, and normalization rules; validate before any normalized cross-module comparison.
4. **Segment / ZFC–FCW implementation** — Protocol and segment labels in tables; validate segment consistency before comparative claims.
5. **Cross-module alignment design** — Written spec for keys, T/H matching, tolerances, and forbidden joins; no mechanism testing yet.
6. **Mechanism testing** — Only after the above, with claim classes restricted by evidence in `tables/mt_stage70_blocked_claims.csv` and readiness flags.

---

## Artifacts

| File | Role |
|------|------|
| `tables/mt_stage70_analysis_questions.csv` | Question bank with answerability and blockers |
| `tables/mt_stage70_cross_module_requirements.csv` | Per-module connection prerequisites |
| `tables/mt_stage70_blocked_claims.csv` | Claims that must not be made yet |
| `status/mt_stage70_exploratory_analysis_status.txt` | Stage 7.0 status flags |

---

## Closing statement

**Stage 7.0 is planning only and does not perform cross-module analysis or make mechanism claims.**

MT remains suitable for **diagnostic and canonical descriptive review** within the allowed observable groups until derivative, mass, segment, and alignment stages are implemented, validated, and reviewed.
