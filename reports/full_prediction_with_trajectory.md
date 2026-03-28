# Full S prediction with trajectory-corrected rank-2 (Agents 23C / 24C)

**Goal:** Temperature LOOCV on the residual strip dS = S - S_CDF on the common x-grid; RMSE matches full S(I,T) up to the shared backbone S_CDF.

**Interpretation (Agent 24C):** Results are reframed from the numeric outputs in `tables/full_prediction_trajectory.csv` without recomputation. The rank-1 collective mode accounts for the bulk of predictive gain; rank-2 geometry and trajectory-dependent corrections are **subleading** and, in this cohort, **negligible** at the aggregate LOOCV level.

## Model

R_hat = kappa1_hat * Phi1 + kappa1_hat * (alpha_geom_hat + alpha_res_hat) * Phi2, with kappa1_hat from PT tail (`tail_width_q90_q50`, `S_peak`), alpha_geom_hat from PT (`spread90_50`, `asymmetry`), alpha_res_hat from a single trajectory scalar (22D/22E-style), selected by minimum alpha_res LOOCV on this cohort.

**Selected trajectory term:** `delta_theta_smoothed_rad`.

## Inputs

- `tables/full_prediction_trajectory.csv` (aggregate row `aggregate_rms_over_T`)
- `figures/prediction_comparison.png`
- Source tables referenced in the 23C pipeline: `tables/kappa1_from_PT.csv`, `tables/alpha_decomposition.csv`

## Relative improvements (aggregate LOOCV RMSE)

Values below use the `aggregate_rms_over_T` row in `full_prediction_trajectory.csv`. Relative improvement from model A to model B is \((\mathrm{RMSE}_A - \mathrm{RMSE}_B) / \mathrm{RMSE}_A \times 100\%\).

| Step | RMSE before | RMSE after | Relative improvement |
|------|-------------:|------------:|---------------------:|
| PT only → rank-1 | 0.053518 | 0.011018 | **79.4%** |
| rank-1 → rank-2 (geom) | 0.011018 | 0.010953 | **0.59%** |
| rank-2 (geom) → rank-2 + trajectory | 0.010953 | 0.010935 | **0.16%** |

The last two steps are **well below a 1–2%** improvement threshold; the trajectory increment over rank-2 geometric is **negligible** for aggregate LOOCV RMSE.

## Model hierarchy (LOOCV)

1. **PT-only backbone** — Leaves the full residual strip unexplained; **large** aggregate error.
2. **Rank-1** — Adding \(\hat\kappa_1 \Phi_1\) collapses error by ~80% in this summary; **dominant** improvement.
3. **Rank-2 (geometry-only)** — Adjusts the second mode using PT-based \(\hat\alpha_\mathrm{geom}\); **marginal** further gain (~0.6% vs rank-1).
4. **Rank-2 + trajectory** — Adds a trajectory-scalar correction to \(\alpha_\mathrm{res}\); **negligible** further gain (~0.2% vs rank-2 geom) on the aggregate metric.

Higher-order structure is retained in the analysis for transparency, but it does **not** materially change the LOOCV picture relative to rank-1.

## Key physical statement

The switching observable is predominantly determined by a **rank-1 collective correction** to the PT backbone. Higher-order modes and trajectory-dependent corrections exist but **do not significantly improve** predictive performance on the aggregate LOOCV RMSE reported here.

## LOOCV RMSE (aggregate_rms_over_T)

| model | RMSE |
|------|---:|
| PT only | 0.053518315 |
| rank-1 | 0.011018319 |
| rank-2 (geom only) | 0.010952963 |
| rank-2 + trajectory | 0.010935068 |

| n (valid PT temperatures) | 12 |

## Flags (revised interpretation)

- **TRAJECTORY_IMPROVES_S_PREDICTION** = **NEGLIGIBLE** (rank-2 → rank-2+traj relative improvement ≈ **0.16%**, below a 1–2% practical threshold).
- **TRAJECTORY_REQUIRED_FOR_S** = **NO** (trajectory term not required for predictive modeling at this level of gain).
- **MODEL_PREDICTS_S** = **YES** (rank-1 and rank-2 stacks remain far below the PT-only baseline; the full rank-2+traj model is still the numerical minimum RMSE, but the extra gain over rank-2 geom is negligible).

**Caution:** Although the rank-2 + trajectory model achieves the **lowest** aggregate RMSE, the improvement over rank-2 geometric is **negligible**, indicating that **trajectory effects are not required** for predictive modeling of switching in this metric. Prefer interpretations that emphasize **rank-1 dominance** and treat rank-2 and trajectory as **subleading corrections**.

## Figure: `figures/prediction_comparison.png`

**Caption:** Aggregate LOOCV RMSE across models. The dominant improvement arises from the rank-1 correction. Rank-2 and trajectory terms provide only marginal gains.

*(The figure file is unchanged; this caption is the reference interpretation for publication or slides.)*

## Transparency

All four models remain reported above and in `tables/full_prediction_trajectory.csv`; only the **wording** of their roles has been corrected. Per-temperature rows and coefficients are unchanged.

**Note:** If `alpha_res_hat` is undefined for a holdout temperature (NaN trajectory feature), the 23C pipeline uses **0** for the strip RMSE while leaving NaN in the table for that coefficient. `alpha_res` training targets follow `tables/alpha_decomposition.csv`.

## Artifacts

- `tables/full_prediction_trajectory.csv`
- `figures/prediction_comparison.png`

*Numeric results from Agent 23C (`analysis/run_full_prediction_trajectory_agent23c.m`). Interpretation and flags revised by Agent 24C (post-processing only; no recomputation).*
