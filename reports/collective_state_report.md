# Effective collective state test (Agent 19C)

## Data
- Source: `results/switching/runs/run_2026_03_25_043610_kappa_phi_temperature_structure_test/tables/residual_rank_structure_vs_T.csv`
- Subset: `T_le_30` (T = 4..30 K, 2 K steps, includes 22 K).
- Definitions: `kappa1` = `kappa` (rank-1 weight); `kappa2` = `rel_orth_leftover_norm` (mode-2 proxy).

## 1. Embedding
- Trajectory plot: `figures/kappa1_kappa2_trajectory.png` (left: physical plane; right: PCA-style rotation of z-scored coordinates).
- PCA: PC1 explains **87.1%**, PC2 **12.9%** of variance in standardized (kappa1, kappa2).

## 2. Geometry along T
- Kendall tau(T, kappa1) = **-0.846**; tau(T, kappa2) = **0.56**.
- Sign changes in successive first differences: kappa1 **3**, kappa2 **7** (non-monotone if >0).
- Regime centroids (low / transition / high): separation norms **0.077**, **0.358**, **0.393**.
- Bend near 22-24 K: angle between segments (20-22) and (22-24) in (kappa1,kappa2) = **174.45 deg**.
- Path speed ||d(k1,k2)/dT|| ratio (22-24)/(20-22) = **0.353**.

## 3. Reduced parameterization kappa2 ~ f(kappa1)
- Pearson corr(kappa1, kappa2) = **-0.742**.
- Linear R^2 = **0.551** (RMSE **0.1382**).
- Best polynomial degree **4**: R^2 = **0.832**, RMSE **0.0846**, mean squared residual / var(kappa2) = **0.168**.

## 4. Regime structure in (kappa1, kappa2)
- Colours: blue = 4-12 K, green = 14-20 K, red = 22-30 K.
- High-T band shows a large excursion at 22 K (mode-2 proxy spike) then partial relaxation by 24-30 K.

## Verdict criteria (operational)
- **COLLECTIVE_STATE_2D = YES** if PC1 < 90% of variance *or* best poly R^2 < 0.85 (single scalar along the curve does not capture both).
- **DIMENSION_REDUCTION_POSSIBLE = YES** if best poly R^2 >= 0.85 *and* relative residual variance <= 0.15.
- **REGIME_IS_STATE_REORGANIZATION = YES** if bend angle > 25 deg, speed ratio > 1.5, or strong centroid separation across 22-30 K band.

## Final verdict
- **COLLECTIVE_STATE_2D**: **YES**
- **REGIME_IS_STATE_REORGANIZATION**: **YES**
- **DIMENSION_REDUCTION_POSSIBLE**: **NO**
