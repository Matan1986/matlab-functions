# Switching canonical current truth freeze (Phase A)

This document freezes the current **canonical Switching truth state** before further scientific interpretation.

## Scope and guardrails

- Switching only.
- No new scientific analyses were run for this freeze artifact.
- No producer changes.
- No changes to canonical reconstruction or mode definitions.
- No legacy artifacts promoted as truth.
- Provisional observable and dynamic appendix artifacts remain provisional leads only.

## Freeze inventory

Machine-readable inventory:
- `tables/switching_canonical_current_truth_inventory.csv`

Machine-readable status flags:
- `tables/switching_canonical_current_truth_status.csv`

The inventory classifies each artifact as one of:
- `canonical truth`
- `canonical diagnostic`
- `provisional lead`
- `legacy diagnostic`
- `excluded / unsafe`

and records:
- producer script (if known)
- metadata-gated status
- allow-list for Phase B/C
- allow-list for claims/context/snapshot updates

## Canonical truth core (frozen)

Primary canonical truth tables (gated PASS):
- `switching_canonical_S_long.csv`
- `switching_canonical_phi1.csv`
- `switching_mode_amplitudes_vs_T.csv`
- `switching_residual_global_rank_structure.csv`
- `switching_residual_rank_structure_by_regime.csv`
- `tables/switching_canonical_input_gate_status.csv`
- `tables/switching_canonical_collapse_hierarchy_error_vs_T.csv`
- `tables/switching_canonical_collapse_hierarchy_dominance.csv`
- `tables/switching_canonical_collapse_hierarchy_status.csv`

## Canonical diagnostics (inspection/validation, not new truth)

Included as canonical diagnostics:
- Stage 1 map visualizations and backbone/residual map reports.
- Stage 2 reconstruction visualization status/report.
- Stage 3 transition/high-T diagnostics status/report.
- PT-CDF collapse overlay status/report.
- Canonical collapse visualization status/report.
- Decision-gated roadmap artifacts.

## Provisional leads (frozen as provisional only)

- `tables/switching_observable_mapping_candidates.csv`
- `tables/switching_observable_mapping_status.csv`
- `reports/switching_observable_mapping_audit.md`
- `tables/switching_observable_mapping_dynamic_provisional.csv`
- `reports/switching_observable_mapping_dynamic_appendix.md`

These remain **candidate leads** only and are explicitly blocked from official stage promotion until required Phase B/C/D conditions are satisfied.

## Legacy and excluded artifacts

- Legacy diagnostics remain non-truth references (e.g., `tables/switching_collapse_error_vs_T.csv`, `tables/switching_collapse_subrange_degradation.csv`).
- `tables/switching_scaling_canonical_test.csv` remains excluded/unsafe for canonical truth.

## Phase A status flags

- `CURRENT_TRUTH_FROZEN = YES`
- `CANONICAL_INPUTS_GATED = YES`
- `PROVISIONAL_OBSERVABLES_CLASSIFIED = YES`
- `DYNAMIC_APPENDIX_CLASSIFIED = YES`
- `LEGACY_TRUTH_DEPENDENCE = NO`
- `READY_FOR_PHASE_B_BACKBONE_VALIDITY = YES`
- `CLAIMS_CONTEXT_SNAPSHOT_UPDATE_ALLOWED = NO`

## 2026-04-26 append-only canonical interpretation update

This section is appended after the Phase A freeze and preserves all earlier truth classifications above.

### Stage progression now on record

- Stage D4 resolved the canonical mode relationship:
  - `Phi1 = backbone_error`
  - `Phi2 = backbone_tail_residual`
  - `Kappa2 = tail_burden_tracker`
- Stage E passed canonical static observable mapping for `kappa1` and `kappa2`.
- Stage E5 and E5B established that rank-2 is the current leading-order interpretable canonical model but not a full closure.
- Limited claim-readiness passed with limited claims allowed and full-closure claims blocked.

### Current canonical interpretation status

- Safe canonical model statement:
  `S ~= S_backbone + kappa1 Phi1 + kappa2 Phi2`.
- This statement is allowed only as a leading-order interpretable canonical model.
- It must not be stated as an exact or fully closed decomposition.

### Rank-3 status

- Rank-3 remains an open branch classified as `weak_structured_residual`.
- Rank-3 is not promoted into the canonical interpreted model.
- Rank-3 is not to be described as a resolved physical mode.

### Claims and context boundary

- Limited canonical claims are allowed.
- Full-closure claims remain blocked.
- Context documentation can be partially updated only if the non-closure caveat and the open-rank3 note remain attached.
- Snapshot updates remain only partially open and are not performed in this document.

### Canonical / noncanonical separation rule

- Historical or noncanonical `kappa1`, `kappa2`, `Phi1`, and `Phi2` findings remain preserved as provenance only.
- They must not be treated as canonical scientific authority unless revalidated in the canonical pipeline.
- This append-only update does not delete or rewrite older noncanonical history; it separates current canonical interpretation from preserved historical material.
