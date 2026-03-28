# Kappa2 phenomenological audit

## Inputs used
- alpha: C:\Dev\matlab-functions\tables\alpha_structure.csv
- residual: C:\Dev\matlab-functions\results\switching\runs\run_2026_03_25_041026_kappa_phi_temperature_structure_test\tables\residual_rank_structure_vs_T.csv
- alpha size: 14 x 12
- residual size: 38 x 10
- T range after alignment: [4, 30]

## Column discovery
- alpha columns: T_K, kappa1, kappa2, alpha, I_peak_mA, median_I_q50, q90_minus_q50, q75_minus_q25, skew_I_weighted, asymmetry_q_spread, width_mA, S_peak
- residual columns: subset, T_K, kappa, I_peak_mA, S_peak, X, rel_orth_leftover_norm, cos_slice_vs_mode1, mean_pairwise_cos_norm, min_pairwise_cos_norm
- mapping used: I_peak <- I_peak_mA; kappa2 <- kappa
- missing variables: antisym_area_res2, local_curvature, slope_asymmetry, width_asymmetry

## Observable definitions
- I_peak: peak-related switching descriptor.
- width_asymmetry: local left/right width imbalance near switching.
- slope_asymmetry: asymmetry in local switching slope.
- local_curvature: local curvature-like geometry near switching peak.
- antisym_area_res2: antisymmetric residual area proxy for mode-2 structure.

## Results
- Baseline LOOCV RMSE: 0.0581598
- Single-variable and two-variable model results are in tables/kappa2_phenomenological_audit.csv.

## Best available model
- model name: I_peak
- n_used: 14
- LOOCV RMSE: 0.0474955
- Pearson: 0.5710
- Spearman: 0.4242
- delta vs baseline: -0.0106642

## Recovery notes
- warnings: kappa2 mapped from generic kappa column.
- models skipped: width_asymmetry, slope_asymmetry, local_curvature, antisym_area_res2, I_peak + width_asymmetry, I_peak + local_curvature, slope_asymmetry + antisym_area_res2

## Operational signature
- KAPPA2_HAS_OPERATIONAL_SIGNATURE: NO

## Final verdict
- KAPPA2_PHENOMENOLOGICALLY_CLOSED: NO
- KAPPA2_HAS_OPERATIONAL_SIGNATURE: NO

## Physical meaning of kappa2
- 1. deformation of collective response linked to Phi1-like deformation
