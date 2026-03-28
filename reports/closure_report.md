# Perturbative Closure Test

## Goal
Test whether adding rank-2 residual mode yields predictive closure beyond rank-1.

## Inputs
- PT-based backbone from CDF reconstruction in `switching_residual_decomposition_analysis`.
- `Phi1` and `Phi2` from residual SVD mode extraction.
- Data matrix `S(I,T)` through residual representation on common x-grid.
- Canonical temperature window: T <= 30.0 K.

## Holdout protocol
- Per temperature: fit coefficients on odd x-grid indices.
- Evaluate RMSE and Pearson correlation on even x-grid indices.

## Aggregate metrics

                     <strong>model</strong>                     <strong>rmse_mean</strong>    <strong>rmse_median</strong>    <strong>corr_mean</strong>    <strong>corr_median</strong>
    <strong>_______________________________________</strong>    <strong>_________</strong>    <strong>___________</strong>    <strong>_________</strong>    <strong>___________</strong>

    "M1_PT_only"                                 0.04692      0.040926          NaN           NaN  
    "M2_PT_plus_kappaPhi1"                     0.0089249     0.0070728      0.95223       0.99368  
    "M3_PT_plus_kappa1Phi1_plus_kappa2Phi2"    0.0056813     0.0051418        0.975       0.99314  



## Improvement

    <strong>comparison</strong>    <strong>rmse_relative_improvement</strong>    <strong>corr_delta</strong>
    <strong>__________</strong>    <strong>_________________________</strong>    <strong>__________</strong>

    "M2_vs_M1"             0.80978                   NaN 
    "M3_vs_M2"             0.36344              0.022775 



## Final Verdict
- RANK2_IMPROVES_PREDICTION: **YES**
- CLOSURE_ACHIEVED: **YES**
- RESIDUAL_STRUCTURE_REQUIRED: **YES**

## Artifacts
- `tables/closure_metrics.csv`
- `figures/closure_comparison.png`
- `reports/closure_report.md`
