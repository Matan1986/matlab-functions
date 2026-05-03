# CM-SW-RLX-AX-18C — T-function and empirical scaling baseline control

## Domain

- Source: `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_17B_visual_dataset.csv` (strict AX-17B ladder).
- Filter: `relaxation_T_K < 31.5` (redundant with 17B export).
- **n = 15** (all rows preserved; **no duplicate-T collapsing**).

## Temperature axis

Models use **relaxation ladder** `T = relaxation_T_K`.

## Scoring rule

- **Primary LOOCV_RMSE** for every model is computed in **original `A` space**.
- Empirical power-law forms use **log–log OLS** on **positive** values; LOOCV folds predict **\(\hat A = \exp(\widehat{\log A})\)** and RMSE is vs observed **`A`**.

## Best simple T baselines (lowest LOOCV among listed T-only families)

| Target | Best model | LOOCV_RMSE |
|--------|------------|------------|
| A_obs_canon | T_linear | 2.25193197e-6 |
| A_svd_full_oriented_candidate | T_linear | 3.87822583e-5 |

## Switching coordinates (single linear predictor in `A` space)

| Target | coord | LOOCV_RMSE |
|--------|-------|------------|
| A_obs | invD_linear | 1.73954856e-6 |
| A_obs | Xeff_linear | 2.06055271e-6 |
| A_svd | invD_linear | 2.97165391e-5 |
| A_svd | Xeff_linear | 3.53419532e-5 |

## Outputs

- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_T_function_model_comparison.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_scaling_law_comparison.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_combined_models.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_residual_after_T.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_reparameterization_scaling_judgement.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_status.csv`

## Closure language

- **Empirical** power-law templates are **not** physical scaling laws.
- **Small n = 15** → LOOCV comparisons are **diagnostic**, not confirmatory.

**END**
