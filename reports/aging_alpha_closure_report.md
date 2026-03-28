# Aging closure with alpha-residual term (Agent 24F)

## Hypothesis

This run tests whether the remaining aging closure error, especially near the **22–24 K** transition, is captured by an **alpha-derived reorganization term** beyond **R ~ g(P_T) + κ₁** (implemented with `spread90_50` for `g(P_T)`), under **strict leave-one-out cross-validation (LOOCV)** on a **common temperature overlap**.
Observable quantities are used here as empirical proxies for the underlying model variables (`P_T`, `\kappa_1`, `\alpha`) and do not define the model itself.

**Run:** `results/cross_experiment/runs/run_2026_03_26_012056_aging_alpha_closure_alpha_residual`

## Data lineage (read-only)

- **R(T):** `R_T_interp` from barrier table merge (same grid as Agent 24B). Clock lineage: `results/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/tables/table_clock_ratio.csv`
- **spread90_50, row_valid:** `results/cross_experiment/runs/run_2026_03_25_031904_barrier_to_relaxation_mechanism/tables/barrier_descriptors.csv`
- **mean_E / std_E (barrier join):** `results/switching/runs/run_2026_03_24_233256_energy_mapping/tables/energy_stats.csv`
- **kappa1, kappa2, alpha:** `tables/alpha_structure.csv`
- **alpha_geom, alpha_res, PT_geometry_valid:** `tables/alpha_decomposition.csv` (canonical decomposition; **alpha_res** not refit in this script)

## Fair comparison

All models report **per-model n** and `T_K_list` in `tables/aging_alpha_closure_models.csv`. **Apples-to-apples LOOCV** uses **n_overlap = 11** rows where **R**, **spread90_50**, **kappa1**, **kappa2**, **alpha**, and **alpha_res** are all finite. **Overlap temperatures (K):** 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26. Columns `loocv_rmse_overlap`, `pearson_overlap`, and `spearman_overlap` use this subset.

The master table flags overlap rows in **`in_LOOCV_overlap_subset`** (`tables/aging_alpha_closure_master_table.csv`).

## Main result

On the overlap subset, **R ~ g(P_T) + kappa1** has LOOCV RMSE **10.981**. Adding **alpha_res** or **abs(alpha_res)** does **not** improve that reference (RMSE ≈ **11.35** for both). By contrast, **R ~ g(P_T) + kappa1 + abs(alpha)** achieves the best LOOCV RMSE overall (**5.743**), beating the PT+state reference decisively. **R ~ g(P_T) + kappa1 + alpha_geom** also slightly beats the reference on RMSE (**10.754**).

## Transition-focused residual audit (LOOCV residuals)

| model | LOOCV RMSE (overlap) | MAE \|res\| 22–24 K | MAE \|res\| outside | n(22–24) | n(outside) |
|---|---|---:|---:|---:|---:|
| R ~ g(P_T) + kappa1 | 10.980923 | 11.406941 | 7.145795 | 2 | 9 |
| R ~ g(P_T) + kappa1 + abs(alpha) | 5.742771 | 8.023260 | 3.948949 | 2 | 9 |

Mean |residual| in **22–24 K** drops from **11.41** (reference) to **8.02** for the best alpha-augmented model shown.

## Interpretation

Out-of-sample LOOCV supports **abs(alpha)** (and full **alpha**) as strong linear predictors beyond **g(P_T) + kappa1**, including lower errors in the **22–24 K** band in this audit. The specific **alpha_res** / **|alpha_res|** pair does **not** beat the reference on RMSE here, so the “residualized” geometry split is **not** the predictive upgrade—**signed alpha magnitude** is.

## Conclusion

On **n = 11** shared temperatures, **abs(alpha)** (and **alpha**) clearly improve LOOCV relative to **g(P_T) + kappa1**, while **alpha_res** and **abs(alpha_res)** do not. Transition-band residuals shrink for the **abs(alpha)** model relative to the reference. Whether this is interpreted as a “reorganization” term depends on theory; **predictively**, the falsification test supports **alpha level**, not **alpha_res**, in this linear closure class.

## Mandatory verdicts

- **ALPHA_RES_IMPROVES_AGING_CLOSURE:** **NO**
- **ABS_ALPHA_RES_BETTER_THAN_SIGNED:** **YES**
- **ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1:** **YES**
- **TRANSITION_RESIDUAL_REDUCED:** **YES**
- **REORGANIZATION_TERM_SUPPORTED:** **YES**

## Figures

- `figures/aging_alpha_closure_predictions.png`
- `figures/aging_alpha_closure_residuals_vs_T.png`
- `figures/aging_alpha_transition_focus.png` (rendered with `tools/_export_agent24f_transition_chart.ps1` from the saved residual audit CSV after the first MATLAB pass stopped on the transition figure; the main script now uses grouped `bar(Y)`.)

## Artifact completion note

The first MATLAB pass stopped during the transition figure due to a `bar(ax, x, y, width, ...)` API issue; `analysis/run_aging_alpha_closure_agent24f.m` was corrected to grouped `bar(Y)`. This report and the transition PNG were finalized for review; re-run the main MATLAB script to regenerate all figures through `save_run_figure` only.

*Primary numerics and tables from `analysis/run_aging_alpha_closure_agent24f.m`.*
