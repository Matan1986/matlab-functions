# Relaxation Outlier Audit (No Toolbox)

Script: `C:/Dev/matlab-functions/Switching/analysis/run_relaxation_outlier_audit_no_toolbox.m`
Data source (relaxation): `C:/Dev/matlab-functions/tables/relaxation_full_dataset.csv`
Data source (flags): `C:/Dev/matlab-functions/tables/relaxation_dataset_validation_status.csv`
Data source (kappa): `C:/Dev/matlab-functions/tables/alpha_structure.csv`

## Alignment Summary
- Rule: Nearest T_K alignment by minimum |T_relax - T_kappa|, tie->lower T_relax
- Rows aligned: 14
- T_relax used: 3 5 7 9 11 13 15 17 19 21 23 25 27 29
- T_kappa used: 4 6 8 10 12 14 16 18 20 22 24 26 28 30

## Correlations (Manual Pearson/Spearman)
- OUTLIER_SCORE_vs_kappa2: Pearson=-0.224842, Spearman=-0.085809, N=14, zeroVarP=0, zeroVarS=0
- WIDTH_ZSCORE_vs_kappa2: Pearson=-0.373766, Spearman=-0.363437, N=14, zeroVarP=0, zeroVarS=0
- SHAPE_FLIP_vs_kappa2: Pearson=-0.239681, Spearman=-0.107417, N=14, zeroVarP=0, zeroVarS=0
- CURV_ANOM_vs_OUTLIER_SCORE: Pearson=0.480457, Spearman=0.347979, N=19, zeroVarP=0, zeroVarS=0
- CURV_ANOM_vs_kappa2: Pearson=0.140819, Spearman=0.094505, N=14, zeroVarP=0, zeroVarS=0

## Transition Localization
- mean OUTLIER_SCORE inside 22-24 K: 1.126574
- mean OUTLIER_SCORE outside: 1.201389
- ratio inside/outside: 0.937726

## Shape Consistency (Pairwise L2)
- mean intra-outlier L2: 0.046472 (pairs=55)
- mean intra-non-outlier L2: 0.016324 (pairs=28)
- mean inter-group L2: 0.033837 (pairs=88)

## Robustness Flags
- OUTLIER_SCORE_vs_kappa2: meaningful=1, validN=14, zeroVarP=0, zeroVarS=0
- WIDTH_ZSCORE_vs_kappa2: meaningful=1, validN=14, zeroVarP=0, zeroVarS=0
- SHAPE_FLIP_vs_kappa2: meaningful=1, validN=14, zeroVarP=0, zeroVarS=0
- CURV_ANOM_vs_OUTLIER_SCORE: meaningful=1, validN=19, zeroVarP=0, zeroVarS=0
- CURV_ANOM_vs_kappa2: meaningful=1, validN=14, zeroVarP=0, zeroVarS=0

## Final Verdicts
- OUTLIERS_LOCALIZED_AT_TRANSITION: NO
- OUTLIERS_CORRELATED_WITH_KAPPA2: NO
- OUTLIERS_HAVE_CURVATURE_SIGNATURE: NO
- OUTLIERS_FORM_CONSISTENT_SHAPE: NO
- OUTLIERS_ARE_PHYSICAL: NO
- OUTLIERS_ARE_ARTIFACT: YES

## Physical Interpretation
- Evidence favors artifact-like outliers (not localized/correlated strongly enough for kappa2-driven reorganization).

## Error
```

```
