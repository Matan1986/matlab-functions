# RLX-ACTIVITY-REPRESENTATION-03 robustness audit

## 1. Variant design

| variant_id | baseline | window | grid | inclusion |
|---|---|---|---|---|
| AR03_B1_W1_G1_I1 | ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT | FULL_TRACE | CANONICAL_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |
| AR03_B2_W1_G1_I1 | MEDIAN_FIRST_5_PERCENT | FULL_TRACE | CANONICAL_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |
| AR03_B3_W1_G1_I1 | MEAN_FIRST_5_PERCENT | FULL_TRACE | CANONICAL_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |
| AR03_B4_W1_G1_I1 | MEDIAN_FIRST_10_PERCENT | FULL_TRACE | CANONICAL_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |
| AR03_B1_W2_G1_I1 | ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT | TRIM_FIRST_5_PERCENT | CANONICAL_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |
| AR03_B1_W3_G1_I1 | ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT | TRIM_FIRST_10_PERCENT | CANONICAL_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |
| AR03_B1_W4_G1_I1 | ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT | TRIM_LAST_10_PERCENT | CANONICAL_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |
| AR03_B1_W1_G1_I2 | ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT | FULL_TRACE | CANONICAL_GRID | INCLUDE_ALL_VALID_CREATION_CURVES |
| AR03_B1_W1_G2_I1 | ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT | FULL_TRACE | HALF_DENSITY_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |
| AR03_B2_W1_G2_I1 | MEDIAN_FIRST_5_PERCENT | FULL_TRACE | HALF_DENSITY_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |
| AR03_B1_W2_G2_I1 | ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT | TRIM_FIRST_5_PERCENT | HALF_DENSITY_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |
| AR03_B2_W2_G1_I1 | MEDIAN_FIRST_5_PERCENT | TRIM_FIRST_5_PERCENT | CANONICAL_GRID | STRICT_DEFAULT_NO_QUALITY_FLAG |

**G3 LOG_TIME_GRID:** not included (no shared RF3R2 table helper in-repo for RLX03).

## 2. Reconstruction comparison

Full table: `relaxation_activity_representation_03_reconstruction_metrics.csv`.

**m0_LOO_SVD_projection** held-out LOO RMSE range across variants: `5.834e-07` – `6.517e-07` (rel. spread ~11.7%).

## 3. Ranking behavior summary

| scalar | times_best | times_top2 | times_worst |
|---|---:|---:|---:|
| m0_LOO_SVD_projection | 12 | 12 | 0 |
| m0_svd_full_reference | 0 | 0 | 12 |
| A_proj_nonSVD | 0 | 8 | 0 |
| A_obs | 0 | 4 | 0 |

Detail per variant: `relaxation_activity_representation_03_ranking_summary.csv`.

## 4. Ranking flips

Unique best scalars across variants: **m0_LOO_SVD_projection**.

Reference **best_scalar** (`AR03_B1_W1_G1_I1`): **m0_LOO_SVD_projection**.

No flip vs reference: every variant agrees on **m0_LOO_SVD_projection**.

## 5. Interpretation

If **m0_LOO_SVD_projection** remains top under map preprocessing changes, the coordinate is **intrinsic** to rank-1 temporal structure; large sensitivity suggests **map-dependent** artifacts.

## 6. Final verdict

- **BASELINE_WINDOW_ROBUSTNESS_DONE:** YES
- **SCALAR_RANKING_STABLE_ACROSS_VARIANTS:** YES
- **M0_LOO_ALWAYS_BEST:** YES
- **M0_LOO_MAJORITY_BEST:** YES
- **A_PROJ_NONSVD_STABLE_COMPROMISE:** YES
- **A_OBS_NEVER_BEST:** YES
- **UNIQUE_BEST_SCALAR_CLAIMABLE:** YES
- **LOG_TIME_GRID_G3_INCLUDED:** NO_NOT_STANDARD_FOR_RF3R2_COMMON_BUILD
- **VARIANTS_REQUESTED:** 12
- **VARIANTS_EFFECTIVE:** 12
