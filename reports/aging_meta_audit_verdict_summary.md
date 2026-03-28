# Aging meta-audit — one-page verdict (repo evidence only)

**Evidence anchor:** root `tables/*.csv` + `reports/*aging*.md` (March 26, 2026 agent chain); cohort **n = 11** on temperatures **6–26 K** where `R_T_interp`, `spread90_50`, `kappa1`, `kappa2`, and `alpha` are finite after the documented merges.

## Best model (strict LOOCV RMSE)

**`R ~ g(P_T) + kappa1 + alpha + kappa1*alpha`** — LOOCV RMSE **5.682** (`tables/aging_hermetic_closure_models.csv`, with `g(P_T)` implemented by `spread90_50`). Same cohort as the alpha closure chain.

## Best simple / canonical model

**`R ~ g(P_T) + kappa1`** — LOOCV RMSE **10.981** on **n = 11** (`tables/aging_kappa2_models.csv` / `aging_alpha_closure_models.csv`; `g(P_T)` implemented by `spread90_50`). Agent 24B reports **11.915** on **n = 10** (trajectory merge) — **not** the same overlap; quote **n** whenever you cite RMSE.

## Best hermetic-closure model (project rule in 24I)

**`R ~ g(P_T) + kappa1 + alpha + abs(alpha_res)`** — qualifies under the dual rule (≥3% LOOCV gain **and** ≥10% mean |residual| reduction in **22–24 K** vs `R ~ g(P_T) + kappa1 + alpha`). LOOCV RMSE **6.352** (`tables/aging_hermetic_closure_models.csv`). This is **not** the lowest LOOCV extension; it is the one that satisfies the stated closure criterion.

## Key variables

- **spread90_50:** dominant PT scalar in the documented fits; strong alone, stronger with state.
- **kappa1:** required beyond PT-only on n = 11; **kappa1 alone** fails LOOCV on the wide grid (`reports/R_state_report.md`, `reports/aging_kappa1_prediction.md` on n = 4).
- **alpha / abs(alpha):** large LOOCV gains over `g(P_T) + kappa1` (`tables/aging_alpha_closure_models.csv`).
- **kappa1*alpha:** best LOOCV among tested extensions of the alpha-level base; **partial** on 24I’s interaction support rule (transition improvement <10% vs alpha-base).
- **abs(alpha_res):** **on top of PT + kappa1 only** does **not** beat the reference (`reports/aging_alpha_closure_report.md`); **on top of PT + kappa1 + alpha** it is the hermetic-qualifying deformation term per 24I.
- **kappa2:** does **not** improve over `g(P_T) + kappa1` in the main tensor test (`reports/aging_kappa2_report.md`).
- **Trajectory (ds, Δθ, …):** with **g(P_T) + kappa1** (implemented by `spread90_50 + kappa1`), trajectory does **not** lower LOOCV on the 24B n = 10 cohort (`reports/aging_prediction_report.md`). Agent 23B remains valid as **correlational / alternate PT encoding** (PT SVD scores), not as a contradiction to 24B’s headline.

## What to quote going forward

1. Always state **n** and **target** (`R_T_interp` from clock-ratio lineage, per reports).
2. For **overall predictive strength** on the shared alpha overlap: cite **`R ~ g(P_T) + kappa1 + alpha + kappa1*alpha`** (best LOOCV) **or** **`R ~ g(P_T) + kappa1 + abs(alpha)`** (best in the broader 24F table) — and note they are **different formula classes**.
3. For **hermetic closure language**, cite **`+ abs(alpha_res)`** on the **alpha-augmented** base `R ~ g(P_T) + kappa1 + alpha` per 24I, not lowest RMSE alone.

Observable quantities are used here as empirical proxies for the underlying model variables (`P_T`, `\kappa_1`, `\alpha`) and do not define the model itself.

REPORT_LANGUAGE_AUDIT_COMPLETE: YES
REPORTS_REFACTORED: YES
NO_OBSERVABLE_PRIMARY_USAGE: YES
4. Do **not** quote the 24G line “best LOOCV = PT + kappa1 + alpha” as the **strongest** model in the repo without noting **newer 24F/24I rows** with lower RMSE.
