# Switching Measurement Robustness Report

## Data source
- Latest run used: C:/Dev/matlab-functions/results/switching/runs/run_2026_03_29_014529_switching_physics_output_robustness_fast
- Variant tables: C:\Dev\matlab-functions\results\switching\runs\run_2026_03_29_014529_switching_physics_output_robustness_fast\physics_output_robustness\tables

## Contract sanity
- CONTRACT_SANITY_OK=YES
- Required columns found in all three tables.
- Row counts matched across variants.
- T_K alignment was exact after sorting by T_K.
- No required column was all-NaN.

## Observable robustness summary
- I_peak: pearson_min=0.846676, spearman_min=0.783013, nrmse_max=0.125000, trend_consistent=YES, verdict=UNSTABLE, extra=ridge_delta_T=18.000000
- width: pearson_min=1.000000, spearman_min=1.000000, nrmse_max=0.000000, trend_consistent=YES, verdict=STABLE, extra=scale_stability_check
- S_peak: pearson_min=0.999499, spearman_min=0.991176, nrmse_max=0.541525, trend_consistent=YES, verdict=UNSTABLE, extra=amplitude_stability_check
- kappa1: pearson_min=-1.000000, spearman_min=-1.000000, nrmse_max=0.675358, trend_consistent=NO, verdict=UNSTABLE, extra=sign_consistency_min=0.000000
- collapse_score: pearson_min=1.000000, spearman_min=NaN, nrmse_max=1.000000, trend_consistent=YES, verdict=UNSTABLE, extra=collapse_conclusion_stability_check

## Physics interpretation
- At least one observable fails strict robustness checks; measurement definition changes can alter physical interpretation for those metrics.
