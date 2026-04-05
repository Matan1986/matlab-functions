# Kappa1 PT Control Analysis

## Scope
- Dataset: TRUSTED_CANONICAL Switching runs only
- Input tables: switching_canonical_S_long.csv, switching_canonical_observables.csv
- Run used: results/switching/runs/run_2026_04_03_091018_switching_canonical

## PT Descriptor Definitions
- mean_I_pt: weighted mean of current_mA using PT_pdf as weights
- std_I_pt: weighted standard deviation of current_mA using PT_pdf as weights
- skewness_pt: weighted standardized third central moment of current_mA
- kurtosis_pt: weighted excess kurtosis of current_mA, defined as E[((I-mean)/std)^4] - 3
- median_I_pt: weighted median current_mA
- q90_minus_q50: weighted 90th percentile minus weighted median current_mA

## Correlation And Model Results
| feature | pearson_corr | spearman_corr | r2 | rmse |
| --- | ---: | ---: | ---: | ---: |

## Best PT Predictor
- best_PT_model = 
- best_PT_model_r2 = 0
- best_PT_model_rmse = 0

## Comparison To S_peak + I_peak
- PT_combined_r2 = 0
- PT_combined_rmse = 0
- S_peak_plus_I_peak_r2 = 0
- S_peak_plus_I_peak_rmse = 0

## Final Verdict
- KAPPA1_DERIVED_FROM_PT = NO
- PT_EXPLAINS_KAPPA1_BETTER_THAN_OBSERVABLES = NO

## Notes
- Correlations are computed between kappa1 and each PT descriptor across matched T_K values.
- Model rows use fitted values from least-squares regression on the same matched T_K set.
