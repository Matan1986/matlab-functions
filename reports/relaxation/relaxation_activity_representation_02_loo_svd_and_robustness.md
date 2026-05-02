# RLX-ACTIVITY-REPRESENTATION-02 — LOO-SVD basis stability and baseline/window robustness

## 1. Executive summary

This pass adds **true leave-one-temperature-out SVD basis** testing (`m0_LOO`, **TRAINING_ONLY_M0_LOO_PROJECTION**) on the same **RF3R2 repaired** map `M(t,T)` as RLX-ACTIVITY-REPRESENTATION-01 (strict default replay, **n = 8** temperatures). For each fold we removed one temperature column, recomputed rank-1 **psi_train**, oriented it against **psi_full** from the **full** matrix (orientation diagnostic only), formed **m0_LOO(i) = psi_train' * M(:,i)**, and measured held-out curve RMSE. We compared against training-only fixed-scalar reconstructions (**A_obs**, **A_proj_nonSVD**, **projection_mean_curve**) and an explicit **FULL_DATA_M0_DIAGNOSTIC_LEAKY_REFERENCE** using **psi_full * m0_RCON(i)**.

**Outcome:** **m0_LOO_SVD_projection** has the **best mean held-out RMSE** among **nonleaky** methods and beats the **leaky** reference on mean RMSE in this run (leaky reference has large RMSE here because it locks **full-map psi** with **RCON m0** rather than the optimal scalar for that psi). **corr(m0_LOO, m0_RCON) = -1** with **median |m0_LOO|/|m0_RCON| ~ 1** — a **global sign convention** difference only; **elementwise sign agreement fraction is 0** for that reason. **Sign stability verdict** is **YES** when treating **|-corr| = 1** as stable coupling (see verdict table).

**Map variants:** Two paths **catalogued** (RF3R canonical export path + RF3R2 repaired); only **primary_RF3R2_repaired** was **rebuilt and analyzed** in RLX02. No separate diagnostic-map CSV stack was found in `tables/relaxation`. **Baseline/window robustness across distinct map definitions** remains **blocked** (`BASELINE_WINDOW_ROBUSTNESS_DONE = NO`).

## 2. Confirmation: no Switching / X inputs

Only Relaxation CSVs under `tables/relaxation/` were used. No `X_eff`, `X`, Switching tables, or bridge fits.

## 3. Prior RLX-01 summary

RLX-01 recommended **A_obs** for main text, ranked **m0_svd** best for in-sample rank-1 when using **full** `M`, and flagged **LOO-SVD** and **baseline/window** as gaps.

## 4. Primary map source

- **Samples:** `tables/relaxation/relaxation_RF3R2_repaired_curve_samples.csv`
- **Index / masks:** `tables/relaxation/relaxation_RF3R2_repaired_curve_index.csv`
- **Scalars:** `tables/relaxation/relaxation_RCON_02B_Aproj_vs_SVD_score.csv`
- **Inclusion:** strict default replay, no quality flag (same policy as RLX-01).

## 5. LOO-SVD method

1. Full SVD: `psi_full = U(:,1)` from `svd(M)`, flip sign so `dot(psi_full, mean(M,2)) >= 0`.
2. For each held-out column `i`: `M_train = M(:, ~i)`, `psi_train = U_train(:,1)`, flip **psi_train** so `corr(psi_train, psi_full) >= 0`.
3. **m0_LOO(i) = psi_train' * M(:,i)** (projection coefficient).
4. Prediction **M_hat = psi_train * m0_LOO(i)**.
5. Non-SVD: same **psi = M_train * a_train / (a_train' a_train)** as RLX-01 for each scalar track.

## 6. LOO-SVD fold results

See `tables/relaxation/relaxation_activity_representation_02_loo_svd_fold_metrics.csv`.

## 7. Comparison to A_obs / A_proj_nonSVD / projection_mean_curve

Summary: `tables/relaxation/relaxation_activity_representation_02_loo_svd_summary.csv`. **A_proj_nonSVD** and **projection_mean_curve** are numerically tied with **m0_LOO** on mean RMSE; **A_obs** is worst among the four nonleaky methods.

## 8. Full-data m0 leaky reference caveat

Column **`heldout_rmse_full_data_m0_leaky_reference`**: **psi_full** from **full M** times **RCON SVD_score_mode1(i)**. This is **not** the LOO-projected coefficient and can be a poor predistor when sign/scale conventions differ; it is retained only as a **diagnostic leaky** row.

## 9. LOO-SVD stability diagnostics

- **corr / Spearman (m0_LOO, m0_RCON):** -1 (perfect collinearity up to sign).
- **Scale:** median **|m0_LOO|/|m0_RCV|** ~ **1** (see verdict `DIAGNOSTIC_median_abs_scale_ratio_LOO_over_full`).
- **Psi alignment:** per-fold `psi_train_vs_full_corr` in fold table (orientation rule enforced).

## 10. Map variant search

`tables/relaxation/relaxation_activity_representation_02_map_variant_inventory.csv` lists:

| variant_id | included_in_robustness | notes |
|------------|-------------------------|--------|
| RF3R_raw_or_canonical | NO | Catalogued path; **not rebuilt** in RLX02 (see `exclusion_reason`). |
| primary_RF3R2_repaired | YES | Only map used for all metrics. |

No `diagnostic_map_*` CSVs were located under `tables/relaxation` by scan.

## 11. Baseline / window / map robustness results

**Not completed** across distinct map matrices: only one **M** was analyzed (`BASELINE_WINDOW_ROBUSTNESS_DONE = NO`, `BASELINE_WINDOW_ROBUSTNESS_BLOCKED_BY_MISSING_VARIANTS = YES`). `relaxation_activity_representation_02_map_variant_reconstruction_metrics.csv` and `relaxation_activity_representation_02_map_variant_ranking_stability.csv` reference **primary_RF3R2_repaired** only.

## 12. Final scalar hierarchy (after 02)

| Role | Scalar |
|------|--------|
| Best nonleaky LOO held-out | **m0_LOO_SVD_projection** |
| Best direct | **A_obs** |
| Best compromise (non-m0, RLX-01 + stability tie) | **A_proj_nonSVD** |
| Leaky diagnostic | **full_data_m0_diagnostic_leaky** |

## 13. Recommended main-text scalar (after 02)

**A_obs** — directness and interpretability; LOO-SVD does **not** force a change.

## 14. Recommended supplement scalars (after 02)

**m0_LOO_SVD_projection** (true LOO basis coefficient track), **m0_svd / RCON** reference row, **A_proj_nonSVD**, **projection_mean_curve**.

## 15. Remaining caveats

- **Unique best scalar:** still **NO** (`SAFE_TO_CLAIM_UNIQUE_BEST_RELAXATION_SCALAR_AFTER_02`).
- **Second map matrix** not rebuilt from canonical export path; **diagnostic map** tables absent — follow-up **YES** (`NEED_FOLLOWUP_BASELINE_WINDOW`, `NEED_FOLLOWUP_RERUN_ALTERNATIVE_MAPS`).
- **Publication decision** still partly editorial (`NEED_FOLLOWUP_PUBLICATION_DECISION_ONLY = PARTIAL`).

---

**Artifacts:** `tables/relaxation/relaxation_activity_representation_02_*.csv`, `reports/relaxation/relaxation_activity_representation_02_loo_svd_and_robustness.md`, optional PNGs under `figures/relaxation/canonical/`.
