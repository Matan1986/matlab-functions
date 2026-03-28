# Kappa1 from PT tail law (Agent 20A)

## Data sources
- **PT_matrix (tail features)**: `results/switching/runs/run_2026_03_24_212033_switching_barrier_distribution_from_map/tables/PT_matrix.csv`
- **kappa1 (kappaAll)**: `results/switching/runs/_extract_run_2026_03_24_220314_residual_decomposition/run_2026_03_24_220314_residual_decomposition/tables/kappa_vs_T.csv`
- **S_peak**: `results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_parameters.csv`

*Note: Canonical decomposition used PT from `run_2026_03_24_212033_switching_barrier_distribution_from_map`; this report uses PT row shapes (`run_2026_03_24_212033_switching_barrier_distribution_from_map`) for tail metrics.*

## Correlations (kappa1 vs tail features)
| Feature | Pearson | Spearman |
| --- | --- | --- |
| q90_I | 0.7784 | 0.8112 |
| tail width (q90-q50) | 0.6649 | 0.6224 |
| tail_mass_quantile_top12p5 | -0.0936 | -0.0699 |
| S_peak | 0.9678 | 0.9650 |

## Models
| Model | LOOCV RMSE | in-sample RMSE | Pearson(y,yhat) | Spearman(y,yhat) | LOOCV excl 22-24 K |
| --- | --- | --- | --- | --- | --- |
| linear: kappa1 ~ q90 | 0.0415046318307142 | 0.0326624295254295 | 0.7784 | 0.8112 | 0.0424832407426521 |
| linear: kappa1 ~ tail_width | 0.049812950087808 | 0.0388657624244542 | 0.6649 | 0.6224 | 0.0457037932982388 |
| linear: kappa1 ~ tail_mass_q | 0.0619432767314626 | 0.0518038124354384 | 0.0936 | 0.0699 | 0.056354609740236 |
| linear: kappa1 ~ q90 + width | 0.0643513405244636 | 0.0309500856620937 | 0.8039 | 0.9021 | 0.0784991058209829 |
| linear: kappa1 ~ width + S_peak | 0.0184738729675384 | 0.0122414172685026 | 0.9719 | 0.9510 | 0.0146341813051525 |
| log_kappa: log(kappa1) ~ q90 | 0.397595048986269 | 0.281636319008053 | 0.8193 | 0.8112 | 0.276472209356269 |
| log_kappa: log(kappa1) ~ tail_width | 0.501190765524797 | 0.333665373033448 | 0.7339 | 0.6224 | 0.348462400231593 |
| log_kappa: log(kappa1) ~ tail_mass_q | 0.583695914628881 | 0.48935977423845 | 0.0861 | 0.0699 | 0.45442622129524 |
| log_kappa: log(kappa1) ~ q90 + width | 0.518705422671269 | 0.276380668073368 | 0.8267 | 0.8462 | 0.507576587019434 |
| log_kappa: log(kappa1) ~ width + S_peak | 0.311448815307899 | 0.169887322885478 | 0.9383 | 0.9510 | 0.148237839571912 |
| linear: kappa1 ~ log(q90) | 0.0439936110201823 | 0.0336390940419011 | 0.7629 | 0.8112 | 0.0456174224593783 |
| linear: kappa1 ~ log(tail_width) | 0.0539209456648831 | 0.0400346244626256 | 0.6387 | 0.6224 | 0.045195987163881 |
| linear: kappa1 ~ log(q90)+log(width) | 0.0778067568138097 | 0.0316924026682133 | 0.7931 | 0.8881 | 0.0922883313485465 |

## Best model (linear `kappa1` predictors, min LOOCV)
- **Name**: `linear: kappa1 ~ width + S_peak`
- **Formula / coefficients**: kappa1 ~ tail_width + S_peak | beta=[-0.00660088222539643 0.00286425576251391 0.482776396389109]
- **Explicit (tail width `W` = q90-q50, mA; `S` = S_peak)**: `kappa1 = -0.00660088222539643 + 0.00286425576251391*W + 0.482776396389109*S`
- **q95_I**: finite for all aligned temperatures in this run (tail upper bound stable on the PT grid).
- **Geom. tail mass (top 12.5% of I axis)**: often NaN on coarse grids; **tail_mass_quantile_top12p5** (mass above q87.5) is used as the tail-mass regressor.
- **LOOCV RMSE**: 0.0184738729675384 (relative to std(kappa1): 0.355)
- **LOOCV excluding T in [22,24] K** (n=10): 0.0146341813051525
- **Pearson / Spearman (y vs yhat)**: 0.9719, 0.9510
- **Stability (22-24 K exclusion)**: PASS

## PT alignment change (vs previous unaligned model)
- PT artifact in this aligned run: run_2026_03_24_212033_switching_barrier_distribution_from_map
- Previous LOOCV RMSE: 0.0184738729675381
- Aligned LOOCV RMSE: 0.0184738729675384
- Delta LOOCV RMSE (aligned - previous): 3.15719672627779E-16
- Previous Pearson/Spearman: 0.971931177717572 / 0.951048951048951
- Aligned Pearson/Spearman: 0.971931177717572 / 0.951048951048951
- Delta Pearson/Spearman: 0 / 0
- MODEL_STABLE_AFTER_ALIGNMENT: YES

## Final flags
- `KAPPA1_PREDICTABLE_FROM_PT` = **YES**
- `KAPPA1_TAIL_DOMINATED` = **NO** (|corr(kappa,q90)|=0.778 vs |corr(kappa,q50)|=0.801)
- `MINIMAL_MODEL_FOUND` = **YES**
- PT_ALIGNMENT_FIXED = **YES**
- MODEL_STABLE_AFTER_ALIGNMENT = **YES**
