# Switching Intra-Definition Measurement Robustness Report

## Correction of previous robustness analysis
- Previous measurement robustness result was INVALID.
- Reason: mixing of different observables (e.g., XY vs XY/XX), which is not an intra-definition robustness test.
- That mixed-observable comparison does NOT reflect measurement robustness.
- Current analysis fixes this by enforcing observable consistency: same channel and normalization, varying only baseline/readout definition.

## Coherent group selection
- Group used: raw_xy_delta vs baseline_aware.
- Both correspond to the same underlying observable family (raw XY-based observables), with measurement-definition variation only.
- Excluded from this analysis as invalid mix: xy_over_xx variant (different normalization/observable).

## Contract sanity
- Exact T_K alignment: YES.
- Row count match: YES.
- No all-NaN required columns: YES.

## Robustness results
- I_peak: pearson=0.846676, spearman=0.783013, nrmse=0.125000, max_rel_dev=0.333333, trend_consistent=YES, verdict=UNSTABLE, extra=ridge_delta_T=18.000000
- width: pearson=1.000000, spearman=1.000000, nrmse=0.000000, max_rel_dev=0.000000, trend_consistent=YES, verdict=STABLE, extra=scale_stability_check
- S_peak: pearson=0.999499, spearman=0.991176, nrmse=0.541525, max_rel_dev=0.970451, trend_consistent=YES, verdict=UNSTABLE, extra=amplitude_stability_check
- kappa1: pearson=-0.999957, spearman=-1.000000, nrmse=0.675358, max_rel_dev=1.996065, trend_consistent=NO, verdict=UNSTABLE, extra=sign_consistency=0.000000
- collapse_score: pearson=NaN, spearman=NaN, nrmse=1.000000, max_rel_dev=0.012014, trend_consistent=YES, verdict=UNSTABLE, extra=collapse_consistency_check

## Verdict
- IPEAK_STABLE=NO
- WIDTH_STABLE=YES
- SPEAK_STABLE=NO
- KAPPA1_STABLE=NO
- COLLAPSE_STABLE=NO
- INTRA_DEFINITION_ROBUST=NO

Measurement definition affects physical observables.
