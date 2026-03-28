# Kappa2 state vs geometry (Agent 19A)

## Data sources (read-only)

- kappa2 = `rel_orth_leftover_norm`, subset **T_le_30**: `C:/Dev/matlab-functions/results/switching/runs/run_2026_03_25_043610_kappa_phi_temperature_structure_test/tables/residual_rank_structure_vs_T.csv`
- PT summary: `C:/Dev/matlab-functions/results/switching/runs/run_2026_03_25_013849_pt_robust_minpts7/tables/PT_summary.csv`
- Barrier quantiles: `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_25_031904_barrier_to_relaxation_mechanism/tables/barrier_descriptors.csv`
- Threshold residual per T: `C:/Dev/matlab-functions/results/switching/runs/run_2026_03_24_013519_switching_threshold_residual_structure/tables/switching_threshold_residual_metrics_vs_temperature.csv`
- Rank spectrum: `C:/Dev/matlab-functions/results/switching/runs/run_2026_03_25_043610_kappa_phi_temperature_structure_test/tables/residual_rank_spectrum.csv`

## Correlations vs kappa2


analysis_block        name                         pearson           spearman  n loocv_rmse loocv_pearson global_metric
                                                                                                                 _value
--------------        ----                         -------           --------  - ---------- ------------- -------------
correlation_vs_kappa2 asym_q_barrier     0.787137913262814  0.581818181818182 11        NaN           NaN           NaN
correlation_vs_kappa2 gap_q75_q25       -0.820686869704636 -0.836363636363636 11        NaN           NaN           NaN
correlation_vs_kappa2 gap_q90_q50       -0.733320641604492 -0.563636363636364 11        NaN           NaN           NaN
correlation_vs_kappa2 gap_q90_q75_proxy -0.724119566478246 -0.336363636363636 11        NaN           NaN           NaN
correlation_vs_kappa2 I_peak_mA         -0.898977116460627 -0.821998429608966 14        NaN           NaN           NaN
correlation_vs_kappa2 kappa1            -0.742124142053164 -0.837362637362637 14        NaN           NaN           NaN
correlation_vs_kappa2 kappa2_norm_k1     0.971495116698194   0.96043956043956 14        NaN           NaN           NaN
correlation_vs_kappa2 kappa2_norm_S      0.981970192054354  0.956043956043956 14        NaN           NaN           NaN
correlation_vs_kappa2 mean_threshold_mA -0.767616301136798 -0.573426573426573 12        NaN           NaN           NaN
correlation_vs_kappa2 median_I_use      -0.862519638967561 -0.779045301358731 11        NaN           NaN           NaN
correlation_vs_kappa2 residual_l2       -0.621532124279946 -0.686813186813187 13        NaN           NaN           NaN
correlation_vs_kappa2 residual_rmse     -0.621532124279946 -0.686813186813187 13        NaN           NaN           NaN
correlation_vs_kappa2 residual_variance -0.495542863284347 -0.681318681318681 13        NaN           NaN           NaN
correlation_vs_kappa2 skewness          0.0604535582180411 0.0839160839160839 12        NaN           NaN           NaN
correlation_vs_kappa2 skewness_quantile  0.792757668662073  0.642370687085269 11        NaN           NaN           NaN
correlation_vs_kappa2 std_threshold_mA  -0.706143472689384 -0.482517482517482 12        NaN           NaN           NaN




## Normalization vs I_peak


analysis_block          name                                   pearson           spearman  n loocv_rmse loocv_pearson g
                                                                                                                      l
                                                                                                                      o
                                                                                                                      b
                                                                                                                      a
                                                                                                                      l
                                                                                                                      _
                                                                                                                      m
                                                                                                                      e
                                                                                                                      t
                                                                                                                      r
                                                                                                                      i
                                                                                                                      c
                                                                                                                      _
                                                                                                                      v
                                                                                                                      a
                                                                                                                      l
                                                                                                                      u
                                                                                                                      e
--------------          ----                                   -------           --------  - ---------- ------------- -
normalization_vs_I_peak corr(kappa2, I_peak)        -0.898977116460627 -0.821998429608966 14        NaN           NaN N
normalization_vs_I_peak corr(kappa2/S_peak, I_peak) -0.912602897998436 -0.821998429608966 14        NaN           NaN N
normalization_vs_I_peak corr(kappa2/kappa1, I_peak) -0.850143486374154 -0.821998429608966 14        NaN           NaN N




## LOOCV models


analysis_block name                              pearson spearman  n        loocv_rmse     loocv_pearson global_metric_
                                                                                                                  value
-------------- ----                              ------- --------  -        ----------     ------------- --------------
loocv_model    kappa2 ~ I_peak                       NaN      NaN 14 0.113456194057352 0.835765856863153            NaN
loocv_model    kappa2 ~ I_peak + std + (q90-q50)     NaN      NaN 11 0.112058649409926 0.712562466266902            NaN
loocv_model    kappa2 ~ kappa1 + std + (q90-q50)     NaN      NaN 11 0.281223431183294 0.269385683869162            NaN




## Globals (stack T_le_30)

- energy_outside_rank1 (1-E1): 0.042358383359126
- energy_mode2_only (E12-E1): 0.025487340877407

## Figure

- `figures/kappa2_vs_shape.png`

## FINAL VERDICT

- **KAPPA2_IS_STATE_LIKE**: YES (max |Spearman| state block=0.8374, Sp(kappa1)=-0.8374)
- **KAPPA2_IS_GEOMETRIC_LIKE**: YES (max |Spearman| geometry block=0.8364)
- **KAPPA2_SIMPLE_PREDICTABLE**: YES (best LOOCV RMSE=0.112058649409926, sigma(k2)=0.213938, ratio=0.5238, Pearson LOO=0.712562466266902)

Notes: q95-q75 uses **q90-q75** proxy (no q95 in barrier CSV). Barrier join is missing at some T; correlations use pairwise-complete `n`.
