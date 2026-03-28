# kappa2 Physical Necessity (Strict LOOCV)

- Script: `C:/Dev/matlab-functions/Switching/analysis/run_kappa2_physical_necessity.m`
- Generated: `2026-03-27 21:46:11`

## Inputs (Canonical)
- `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_25_031904_barrier_to_relaxation_mechanism/tables/barrier_descriptors.csv`
- `C:/Dev/matlab-functions/tables/alpha_structure.csv`
- `C:/Dev/matlab-functions/tables/alpha_decomposition.csv`

## Step 1: Models
- 1) R ~ PT
- 2) R ~ PT + kappa1
- 3) R ~ PT + kappa1 + alpha
- 4) R ~ PT + kappa1 + kappa2

## Step 2: Strict LOOCV Metrics
| Model | n_rows | RMSE | Pearson | transition MAE (22-24K) |
|---|---:|---:|---:|---:|
| R ~ PT | 11 | 13.6377 | 0.870999 | 14.872 |
| R ~ PT + kappa1 | 11 | 10.9809 | 0.919276 | 11.4069 |
| R ~ PT + kappa1 + alpha | 11 | 6.98805 | 0.982177 | 9.66712 |
| R ~ PT + kappa1 + kappa2 | 11 | 13.5242 | 0.869773 | 13.8714 |

## Step 3: Stability
| Model | jackknife RMSE std | jackknife RMSE range | mean prediction variance | max prediction variance |
|---|---:|---:|---:|---:|
| R ~ PT | 1.49428 | 4.99354 | 9.95194 | 79.8357 |
| R ~ PT + kappa1 | 1.21465 | 4.07509 | 6.95164 | 50.0589 |
| R ~ PT + kappa1 + alpha | 0.934441 | 3.11684 | 3.42514 | 25.4843 |
| R ~ PT + kappa1 + kappa2 | 1.92895 | 6.47186 | 12.4322 | 98.615 |

## Step 4: Term Contribution
| Term | contribution RMSE | contribution transition MAE |
|---|---:|---:|
| PT | 15.3184 | 0.63122 |
| kappa1 | 2.65679 | 3.4651 |
| alpha | 3.99288 | 1.73982 |
| kappa2 | -2.54327 | -2.46443 |

## Verdicts
- **KAPPA2_REQUIRED_FOR_AGING:** **NO**
- **ALPHA_BETTER_THAN_KAPPA2:** **YES**
- **KAPPA1_SUFFICIENT:** **NO**

- Aligned rows used (pre-model filtering): `11`
- Summary: `valid_models=4, KAPPA2_REQUIRED_FOR_AGING=NO, ALPHA_BETTER_THAN_KAPPA2=YES, KAPPA1_SUFFICIENT=NO`

## Artifacts
- Comparison CSV: `C:/Dev/matlab-functions/tables/aging_model_comparison_strict.csv`
- Report MD: `C:/Dev/matlab-functions/reports/kappa2_physical_necessity.md`
- Status CSV: `C:/Dev/matlab-functions/tables/kappa2_physical_necessity_status.csv`
