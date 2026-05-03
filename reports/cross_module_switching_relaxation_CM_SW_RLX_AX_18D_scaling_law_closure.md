# CM-SW-RLX-AX-18D — Scaling-law closure (from AX-18C artifacts only)

**Type:** claim-closure audit. **No new fits, no model search, no figures.** All statements below trace to the listed AX-18C files.

## Source artifacts (read-only)

- `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_T_function_scaling_baseline_control.md`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_T_function_model_comparison.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_scaling_law_comparison.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_combined_models.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_residual_after_T.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_reparameterization_scaling_judgement.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_status.csv`

## Domain and scoring (unchanged from AX-18C)

- **n = 15** (AX-17B ladder).
- **Best simple T baseline** for both targets: **`T_linear`** (lowest LOOCV among listed T-only models in `T_function_model_comparison`).
- Empirical power-law rows use **log–log OLS** with **LOOCV_RMSE computed in original `A` space** after back-transform (see AX-18C report).

## 1. Scaling candidates tested in AX-18C (inventory)

The file `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18D_scaling_inventory.csv` lists **nine candidates per target** (18 rows), matching `scaling_law_comparison`:

| `scaling_family` (candidate) | Role |
|------------------------------|------|
| `T_power` | log–log in `T` |
| `Xeff_power` | log–log in `Xeff_chosen` |
| `invD_power` | log–log in `invD_chosen` |
| `absT_minus_23K`, `absT_minus_25K`, `absT_minus_31.5K` | log–log in fixed-\(T_c\) \(|T-T_c|\) |
| `shifted_T_minus_0K`, `shifted_T_minus_3K`, `shifted_T_minus_5K` | log–log in \((T-T_0)_+\) |

**Endpoint / exponent stability:** AX-18C does **not** record `endpoint_stable` or resampled exponent distributions. Inventory marks **`NOT_RECORDED_IN_AX_18C`** for endpoint and exponent stability columns.

## 2. Comparison axis: T_linear vs best simple T baseline

For scaling rows, **`beats_best_T_baseline`** in AX-18C is referenced to the **best simple T baseline LOOCV** ( **`T_linear`** for both targets). Therefore **`beats_T_linear`** is **equivalent** to **`beats_best_T_baseline`** here.

## 3. `invD_power` — alphas (from CSV only)

| Target | `alpha` (source field) | Decimal (for prose) |
|--------|------------------------|----------------------|
| `A_obs_canon` | `5.62460847e-1` | **0.562460847** |
| `A_svd_full_oriented_candidate` | `5.58279495e-1` | **0.558279495** |

## 4. Empirical vs physical vs “clean” power law (terminology)

- **Empirical scaling-like fit:** A template from the fixed AX-18C list, scored with LOOCV in `A` space. **invD_power** is the **only** such template in the scaling table that **beats** `T_linear` on LOOCV for **both** targets.
- **Clean power law (operational, this audit):** A single-term log–log form with a single exponent in the listed block. Still **not** a physical law without mechanism and stability.
- **Physical scaling law:** **Not established** by AX-18C. Judgement and status explicitly **empirical-only**; do not upgrade.
- **Ruled-out (within tested set):** `T_power` and `Xeff_power` **as improvements over** `T_linear` under the **stated** log–log + LOOCV-in-`A` rule. **Not** “ruled out” in other model classes (e.g. **linear** `Xeff` / `invD` in `T_function_model_comparison` can still beat `T_linear`).
- **Untested family:** See `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18D_untested_scaling_families.csv` (no new fits).

## 5. Claim summary (see also `scaling_claims.csv`)

| Question | Closure |
|----------|---------|
| **T_power** improves vs **T_linear** (LOOCV)? | **No** for both targets (`beats_best_T_baseline=NO`). |
| **Xeff_power** improves vs **T_linear**? | **No** for both targets. |
| **invD_power** best among **scaling_law_comparison** rows? | **Yes** (minimum LOOCV per target block). |
| **Physical scaling law** established? | **No.** |
| **All simple scaling laws ruled out?** | **No.** (Too broad; **invD_power** beats **T_linear** empirically.) |
| Narrow statement | **No tested template in AX-18C establishes a physical scaling law** — **Yes** (safe). |

## 6. Manuscript boundary

- **Allowed:** Descriptive language: on **n = 15**, **invD_power** (as defined in AX-18C) had **lower LOOCV** than **T_linear**; exponents are **log–log OLS slopes** from the table, not material constants. Distinguish **linear coordinate** models from **log–log power** templates when citing rankings.
- **Forbidden:** “Established physical scaling law,” “universal exponent,” “proves mechanism,” “ all scaling laws ruled out,” claiming **endpoint/exponent stability** without new diagnostics.

## Outputs (this audit)

- This report: `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_18D_scaling_law_closure.md`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18D_scaling_inventory.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18D_scaling_claims.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18D_untested_scaling_families.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18D_status.csv`

**END**
