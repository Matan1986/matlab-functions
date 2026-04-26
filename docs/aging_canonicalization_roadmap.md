# Aging Canonicalization Roadmap

## Purpose

This roadmap records required Aging module gates after Stage G4.1b and before any cross-module analysis.
It is a planning and governance artifact only. It does not change definitions, formulas, or execution logic.

## Current State Snapshot

- Measurement contract exists and is frozen.
- Real consolidated dataset exists at `tables/aging/aging_observable_dataset.csv`.
- Reader-path plumbing is in place.
- Multi-`Tp x tw` aggregate and consolidation support is in place.
- Latest status indicates:
  - `READY_FOR_G3_TAU_CHAIN_RUN = YES`
  - `READY_FOR_ROBUSTNESS_AUDIT = PARTIAL`

## Required Stage Order

1. **G3 tau-chain run / artifact generation**
2. **G4 multi-`Tp x tw` coverage and consolidation**
3. **Robustness and sensitivity**
4. **Gate I - Deep canonical review**
5. **Gate J - Physical synthesis**
6. **Gate K - Repo documentation and claims**
7. **Gate L - Explicit stop before cross-module**
8. **Cross-module allowed only after Switching and Relaxation readiness**

## Gate I - Deep Canonical Review

Must verify all of the following:

- No hidden assumptions were introduced by new canonicalization steps.
- Track A vs Track B separation remains valid.
- `aging_observable_dataset.csv` is treated as a consolidation contract, not raw truth.
- Ragged `Tp x tw` coverage is handled correctly.
- `source_run` lineage is valid and traceable.
- Old readers/artifacts are reproducible or explicitly marked legacy.
- No incompatible observable mixing is present.
- Local path/config fixes are plumbing-only changes.
- Outputs trace to scripts and manifests.
- All claims are supported by artifacts.

## Gate J - Physical Synthesis

This gate is blocked until Gate I passes.

When Gate J is opened, it must answer:

- What new Aging observables mean physically.
- What changed versus prior Aging analysis language.
- What survived.
- What weakened.
- What must be dropped.
- What can be claimed for Paper 1.
- What must be deferred.

## Gate K - Repo Documentation / Claims

Must produce repository documentation covering:

- Equations.
- Variable definitions.
- Lineage.
- Interpretation scope.
- Allowed claims.
- Forbidden claims.
- Track A vs Track B caveats.
- Ragged `Tp x tw` caveats.
- Mapping between old and new language.

## Gate L - Stop Before Cross-Module

Explicit stop rule:

No Aging x Switching or Aging x Relaxation cross-analysis is allowed until all are true:

- Aging canonical review is complete (Gate I).
- Aging physical synthesis is documented (Gate J).
- Switching canonicalization is ready.
- Relaxation canonicalization is ready.
- A separate cross-module plan is approved.

## Current Blocking Policy

- Physical synthesis work is blocked now.
- Cross-module Aging x Switching and Aging x Relaxation analysis is blocked now.
- Advancing from Aging tau-chain/pipeline tasks directly into cross-module analysis is forbidden.

## Required Verdicts

- `AGING_ROADMAP_UPDATED = YES`
- `DEEP_CANONICAL_REVIEW_GATE_DEFINED = YES`
- `PHYSICAL_SYNTHESIS_GATE_DEFINED = YES`
- `CLAIMS_DOCUMENTATION_GATE_DEFINED = YES`
- `CROSS_MODULE_STOP_GATE_DEFINED = YES`
- `PHYSICAL_SYNTHESIS_ALLOWED_NOW = NO`
- `CROSS_MODULE_ANALYSIS_ALLOWED_NOW = NO`
