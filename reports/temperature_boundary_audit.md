# Temperature Boundary Audit

Assessed whether 4K (low-T edge) and 30K (high-T boundary) look like edge artifacts or robust physics.

## Inputs
- `phi1_observable_failure_by_T.csv`: `C:\Dev\matlab-functions\tables\phi1_observable_failure_by_T.csv`
- `kappa_vs_T.csv`: `C:\Dev\matlab-functions\results\switching\runs\_extract_run_2026_03_24_220314_residual_decomposition\run_2026_03_24_220314_residual_decomposition\tables\kappa_vs_T.csv`
- Residual/error metric used: `reconstruction_rmse_M2`

## Boundary Metrics

| T (K) | Error | Error/Median | Error z (robust) | Error/Neighbors | kappa1 z | kappa2 z |
|---:|---:|---:|---:|---:|---:|---:|
| 4 | 0.0149086 | 2.10787 | 2.25013 | 1.61338 | 1.13645 | NaN |
| 30 | 0.0251007 | 3.5489 | 5.17694 | 3.1268 | -0.80228 | NaN |

## Optional Exclusion Fit Check

| T (K) | Delta RMSE (exclude this T) | Delta RMSE (exclude both 4K and 30K) |
|---:|---:|---:|
| 4 | -0.000867613 | -0.00382088 |
| 30 | -0.00251637 | -0.00382088 |

## Verdicts

- LOW_T_EDGE_EFFECT: **YES**
- HIGH_T_BOUNDARY_EFFECT: **YES**
- SHOULD_EXCLUDE_FROM_MODEL: **YES**
