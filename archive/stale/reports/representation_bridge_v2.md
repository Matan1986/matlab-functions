# Representation Bridge v2

## Scope
Bridge-only comparison between legacy width-dependent state representation and non_canonical_phi1 empirical Phi1/kappa1 representation.
No migration, replacement, wrapper execution, or legacy regeneration was performed.

## Exact Files Used
- Locked switching CSV: results/switching/runs/run_2026_03_10_112659_alignment_audit/alignment_audit/switching_alignment_samples.csv
- Legacy kappa1 source: tables/kappa1_from_PT_aligned.csv
- Legacy PT proxy source: tables/kappa1_from_PT.csv
- non_canonical_phi1 kappa1 source: tables/kappa1_phi1_local_v2_20260329_234420.csv
- non_canonical_phi1 source: tables/phi1_local_shape_v2_20260329_234420.csv
- non_canonical_phi1 status source: tables\kappa1_phi1_local_v2_status_20260329_234420.csv
- non_canonical_phi1 report source: reports/kappa1_phi1_local_v2_20260329_234420.md

## Alignment Method (Deterministic)
- Temperature key defined as nearest integer: T_key = round(T).
- non_canonical_phi1 and legacy tables were matched by exact equality on T_key.
- Unmatched temperatures were reported explicitly.

## Kappa1 Bridge Metrics
- matched_temperature_count = 12
- Pearson(local, legacy) = 0.710073167669095
- Spearman(local, legacy) = 0.902097902097902
- sign_agreement_fraction = 0.833333333333333
- normalized_scale_mismatch = 3.52135048817196
- rank_ordering_consistency = 0.893939393939394
- unmatched_non_canonical_phi1_temperatures = 34, 32, 30, 28
- unmatched_legacy_temperatures = 

## Residual-Sector Bridge
- non_canonical_phi1 residual field reconstructed from locked CSV only:
  - S_norm(I,T) = S(I,T)/S_peak(T)
  - DeltaS(I,T) = S_norm(I,T) - mean_T[S_norm(I,T)]
- Legacy direct Phi1 was not available; surrogate used:
  - legacy_direction(I) proportional to sum_T kappa1_legacy(T) * unit(DeltaS(:,T))
- cosine_non_canonical_phi1_vs_legacy = 0.696127998553052
- explained_variance_non_canonical_phi1 = 0.416857190270202
- sign_consistency_fraction = 0.75

## Limitations
- No direct legacy Phi1 vector was found in the allowed legacy tables; surrogate comparison was used.
- Legacy and PT-proxy kappa1 are numerically aligned in available legacy tables, reducing independent redundancy.
- Any verdict on continuity is contingent on surrogate validity for legacy residual direction.

## Interpretation
- REPRESENTATION_RELATION = PARTIAL_CONTINUITY
- NON_CANONICAL_PHI1_LEGACY_T_ALIGNMENT_OK = NO
- KAPPA1_BRIDGE_CORRELATED = YES
- KAPPA1_BRIDGE_MONOTONIC = YES
- PHI1_BRIDGE_SUPPORTED = YES
- LEGACY_STATE_APPROXIMATED_BY_LOCAL = YES
- SAFE_TO_PROCEED_TO_RECONSTRUCTION = NO

## Mandatory Verdicts
- LOCAL_LEGACY_ALIGNMENT_DEFINED = YES
- NON_CANONICAL_PHI1_KAPPA1_TRACKS_LEGACY = YES
- NON_CANONICAL_PHI1_SUPPORTS_LEGACY_RESIDUAL_SECTOR = YES
- NEW_REPRESENTATION_IS_CONTINUOUS_WITH_OLD = NO
- SAFE_TO_PROCEED_TO_RECONSTRUCTION = NO
