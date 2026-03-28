# Coefficient Physics Test (Agent 18B)

## Definitions used
- kappa1 (mode-1 proxy): kappa from residual decomposition tables
- kappa2 (mode-2 proxy): rel_orth_leftover_norm from rank-structure table
- PT observables: tail metrics from barrier_descriptors.csv, mean/std from PT summary, and I_peak_mA

## Model Metrics

| target | model | n | LOOCV RMSE | Pearson | Spearman |
|---|---|---:|---:|---:|---:|
| kappa1 | kappa1~tail_log10 | 13 | 0.0622852 | -0.792871 | -0.994505 |
| kappa1 | kappa1~q90_I_mA+iq90_10_mA | 10 | NaN | NaN | NaN |
| kappa2 | kappa2~I_peak_mA | 13 | 0.109878 | 0.832017 | 0.302198 |
| kappa2 | kappa2~I_peak+mean+std+shape | 10 | 0.367282 | 0.252028 | 0.163636 |

## FINAL VERDICT
- KAPPA1_TAIL_CONTROLLED: YES
- KAPPA2_LANDSCAPE_LINKED: NO
- COEFFICIENTS_PREDICTABLE: NO
