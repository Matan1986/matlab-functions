# Aging collapse: `R(T)` vs collective state `(kappa1, kappa2)`

- Generated: 2026-03-27 00:21:28

## Inputs (absolute paths)
- canonical kappa table: `C:\Dev\matlab-functions\tables\R_vs_state.csv`
- aging R table: `C:\Dev\matlab-functions\tables\R_vs_state.csv`

## Alignment
- Manual alignment by `T_K` (tolerance = 1.0e-09).
- Aligned rows (n): 11.  `T_K` range: [6, 26].

## LOOCV metrics

| Model | LOOCV RMSE | Pearson(y,yhat) | Spearman(y,yhat) |
| --- | ---: | ---: | ---: |
| R ~ 1 | 0.0454473 | -1 | -1 |
| R ~ kappa1 | 0.031534 | 0.660731 | 0.763636 |
| R ~ kappa2 | 0.0504888 | -0.17938 | 0.136364 |
| R ~ kappa1 + kappa2 | 0.0294289 | 0.722599 | 0.736364 |
| R ~ kappa1 + kappa2 + (kappa1*kappa2) | 0.00823962 | 0.981613 | 1 |

## Collapse tests (vs kappa1-only)

- kappa1-only (R ~ kappa1): RMSE = 0.031534
- best model (kappa1+kappa2 or with interaction): RMSE = 0.00823962
- overall relative RMSE improvement vs kappa1-only: 0.738707
- 22-24K region relative RMSE improvement vs kappa1-only: 0.765304

- Residual dependence proxy (Pearson corr of LOOCV residual vs kappa2):
  - kappa1-only: 0.402599
  - best model: 0.100667
- Residual correlation with interaction term `(kappa1*kappa2)` (best): 0.0970109

## Verdicts

- `AGING_DEPENDS_ON_KAPPA2`: NO
- `KAPPA2_IMPROVES_PREDICTION`: YES
- `AGING_COLLAPSE_SUCCESS`: YES