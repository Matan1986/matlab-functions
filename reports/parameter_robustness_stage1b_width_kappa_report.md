# Parameter Robustness Stage 1B: Width/Kappa1 Forensic Audit

## Canonical lock
- run_id: `run_2026_03_10_112659_alignment_audit`
- source_file: `C:\Dev\matlab-functions\results\switching\runs\run_2026_03_10_112659_alignment_audit\alignment_audit\switching_alignment_samples.csv`
- CANONICAL_SOURCE_LOCKED = YES

## Q1 - Width failure origin
- COARSE_GRID_CAUSE = YES (ratio_loose=0.66667)
- HALFMAX_UNDERSAMPLED = YES (ratio_under=0.77778)
- EDGE_OR_ASYMMETRY_CAUSE = NO (ratio_edge_asym=0.22222)
- median_rel_dev_nearest_vs_linear = 0.51335
- median_rel_dev_fine_vs_linear = 0.012552
- median_abs_delta_if_insert40_mA = 0

## Q2/Q3 - kappa1 dependence
- Case A: min_corr=0.67412, median_rel=0.026395, worst_rel=59.8521, valid_T=15
- Case B: min_corr=0.73574, median_rel=0.041862, worst_rel=59.8521, valid_T=15
- Case C: min_corr=0.99955, median_rel=0.024144, worst_rel=0.093598, valid_T=15
- Case D: min_corr=0.67412, median_rel=0.016905, worst_rel=16.0819, valid_T=15
- KAPPA1_SENSITIVE_TO_WIDTH = YES
- KAPPA1_SENSITIVE_TO_IPEAK = YES
- KAPPA1_SENSITIVE_TO_SPEAK = NO

## Q4 - Map vs scalarization
- collapse_min_corr_noncanonical = 1
- width_min_corr_noncanonical = 0.75235
- MAP_STABLE_BUT_SCALARIZATION_FRAGILE = YES

## Temperature structure
- WIDTH_FAILURE_LOCALIZED = NO
- KAPPA1_FAILURE_LOCALIZED = NO
- FAILURE_REGION = mid_T,low_T

## Final verdicts
- WIDTH_FAILURE_EXPLAINED_BY_GRID = YES
- WIDTH_FAILURE_EXPLAINED_BY_PEAK_SHIFT = NO
- KAPPA1_FAILURE_EXPLAINED_BY_WIDTH = NO
- KAPPA1_FAILURE_INDEPENDENT = YES
- MAP_STABILITY_THREATENED = NO
- FINAL_INTERPRETATION = kappa estimator artifact dominates
