# Phi1/Phi2 observable closure (fixed O2 pipeline)

## Verdicts
- `O2_USED_SUCCESSFULLY`: **YES**
- `KAPPA2_OBSERVABLE_SIGNATURE_FOUND`: **NO**
- `TWO_OBSERVABLE_CLOSURE_IMPROVES`: **NO**
- `MINIMAL_2D_OBSERVABLE_FOUND`: **NO**
- `N_VALID_POINTS_ALL_O2`: **14**

## Modeling summary (LOOCV)
- Results CSV: `C:\Dev\matlab-functions\tables\phi1_phi2_observable_closure_fixed.csv`

### Best kappa1 model (sanity)
- Best `loocv_rmse`: **0.0061273**

### Best kappa2 model (main target)
- Best predictor set: `local_curvature_window` (n=1)
- LOOCV RMSE: **0.13644**
- Baseline RMSE: **0.12915**
- RMSE improvement (abs): **-0.0072859**
- RMSE improvement (ratio): **-0.056414**
- Pearson: **-0.60049**; Spearman: **0.15165**

### Best 1-variable kappa2 model
- Predictor set: `local_curvature_window` (LOOCV RMSE **0.13644**) 

### Best 2-variable kappa2 model
- Predictor set: `slope_difference+local_curvature_window` (LOOCV RMSE **0.13659**) 

