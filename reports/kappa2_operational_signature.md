# Kappa2 operational signature search

## Inputs
- Switching map source: `C:\Dev\matlab-functions\results\switching\runs\run_2026_03_10_112659_alignment_audit\alignment_audit\switching_alignment_samples.csv`
- Kappa2 source: `C:\Dev\matlab-functions\tables\closure_metrics_per_temperature.csv` (`kappa2_M3` fallback `kappa2`)
- Aligned temperatures with finite kappa2: **14**

## Candidate observables
- `antisymmetric_area`
- `slope_asymmetry`
- `local_curvature_imbalance`
- `center_vs_tail_difference`

## Model tests
- Tested all single-variable models and all 2-variable combinations (linear with intercept).
- Metrics per row: Pearson, Spearman, LOOCV RMSE, baseline RMSE, and RMSE gain.
- Full metric table: `tables/kappa2_operational_signature.csv`.

## Best result snapshot
- Best model by LOOCV RMSE: `slope_asymmetry`
- Best LOOCV RMSE: **0.070156**
- Baseline RMSE: **0.071441**
- Pearson / Spearman: **-0.5719 / -0.6593**

## Verdicts
- **KAPPA2_OPERATIONAL_SIGNATURE_FOUND: NO**
- **BEST_SIGNATURE_VARIABLE: slope_asymmetry**

## Decision rule
- YES: best RMSE improvement >= 0.10 and best single-feature |corr| >= 0.40.
- PARTIAL: best RMSE improvement >= 0.03 and best single-feature |corr| >= 0.25.
- Current best improvement fraction: **0.0180**.
