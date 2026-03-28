# Alpha_res cross-experiment correlation (Agent A)

## Goal
Test whether the switching-stack residual amplitude (rank-1 kappa from `switching_residual_decomposition_analysis`, tabulated as `kappa` in `kappa_vs_T.csv`) tracks the aging closure residual and/or `alpha_res` from PT geometry decomposition, on a common temperature grid.

## Data sources
- **Switching residual amplitude:** `results/switching/runs/run_2026_03_24_220314_residual_decomposition/tables/kappa_vs_T.csv`
- **Aging + alpha merge:** `tables/aging_alpha_closure_master_table.csv`
- **Best aging model (overall):** `R ~ g(P_T) + kappa1 + abs(alpha)` → predictors: **spread90_50 (PT proxy for g(P_T)), kappa1, abs_alpha**
Observable quantities are used here as empirical proxies for the underlying model variables (`P_T`, `\kappa_1`, `\alpha`) and do not define the model itself.

## Alignment
- **n (finite overlap):** 11
- **T_K (K):** 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26

## Identity check (pipeline consistency)
- **Pearson(switching kappa, master kappa1):** 1 (1.0 expected when decomposition uses the same ridge amplitude as `alpha_structure`.)

## Aligned quantities (per T)
| T_K | switching kappa (rank-1 res.) | alpha_res | aging LOOCV residual | |aging res.| |
|---:|---:|---:|---:|---:|
| 6 | 0.190781 | 0.250005 | 5.42378 | 5.42378 |
| 8 | 0.196908 | -0.320296 | -2.57836 | 2.57836 |
| 10 | 0.177107 | -0.712487 | -3.37251 | 3.37251 |
| 12 | 0.152695 | -0.0140321 | -3.53028 | 3.53028 |
| 14 | 0.124471 | 0.183128 | 0.449992 | 0.449992 |
| 16 | 0.107135 | 0.344779 | 2.51767 | 2.51767 |
| 18 | 0.0980186 | 0.169705 | 4.25976 | 4.25976 |
| 20 | 0.0898318 | -0.741531 | -1.42434 | 1.42434 |
| 22 | 0.0382966 | 0.943606 | -9.40134 | 9.40134 |
| 24 | 0.0699735 | -0.10916 | 6.64519 | 6.64519 |
| 26 | 0.064059 | -0.200609 | -11.9838 | 11.9838 |

## Correlations
| comparison | n | Pearson r | Spearman rho |
|---|---:|---:|---:|
| switching_kappa_abs_vs_aging_loocv_residual | 11 | 0.279744 | 0.2 |
| switching_kappa_abs_vs_abs_aging_loocv_residual | 11 | -0.531607 | -0.472727 |
| switching_kappa_abs_vs_alpha_res | 11 | -0.358586 | -0.163636 |
| switching_kappa_vs_aging_loocv_residual | 11 | 0.279744 | 0.2 |
| switching_kappa_vs_abs_aging_loocv_residual | 11 | -0.531607 | -0.472727 |
| switching_kappa_vs_alpha_res | 11 | -0.358586 | -0.163636 |

## Figure
- `figures/alpha_res_cross_scatter.png` (PDF/FIG siblings written alongside)

## Tables
- `tables/alpha_res_cross_correlation.csv` — correlation summary

## Interpretation notes
- **Small n:** With n≈11, correlation magnitudes are indicative only; use alongside mechanistic audits.
- **Kappa naming:** Decomposition `kappa` is the rank-1 amplitude of **delta S** after the PT-CDF term; when sourced from the default switching runs it matches `kappa1` in `alpha_structure` / master table (see identity check above).

## Final verdict
ALPHA_RES_SHARED_BETWEEN_EXPERIMENTS: **PARTIAL**

Interpretation: the decomposition `kappa` tracks `kappa1` exactly on this grid (identity check), so cross-experiment tests against `alpha_res` and aging residuals are not independent of the state coordinate already in the aging model. The largest linear signal is **Pearson ≈ −0.53** between `|kappa_sw|` and **|aging LOOCV residual|** under the best `spread90_50 + kappa1 + abs(alpha)` model; **Pearson ≈ −0.36** vs `alpha_res`. With **n = 11**, treat as exploratory.

_Generated: 2026-03-26 02:49:21_