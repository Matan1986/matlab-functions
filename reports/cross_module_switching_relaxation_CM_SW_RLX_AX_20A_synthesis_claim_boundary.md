# CM-SW-RLX-AX-20A — Cross-module AX synthesis and manuscript claim boundary

**Nature:** evidence synthesis only. **No new fits, no scripts executed, no figures.** Sources are the CM-SW-RLX audits AX-17B, XEFF-width-18, AX-18B, AX-18C, AX-18D, and AX-19A listed in the task specification.

**Domain (consistent across audits referenced):** strict Switching–Relaxation AX ladder, **`relaxation_T_K < 31.5 K`**, **`included_in_fit == 1`**, **n = 15**.

---

## Synthesis decisions (required)

### A. Final relationship classification

**`EMPIRICAL_INVD_POWERLIKE_SCALING`** — Supported as the **bounded** summary: across audits, **`invD_chosen`** (inverse denominator–area structure) is the **stronger empirical organizer** of **`A`** than **`Xeff_chosen`** on tested scores, and AX-18C/18D document **empirical** invD–power-law templates that **beat** the chosen simple **T** baseline under stated rules. **Not** a physical scaling-law identification.

### B. `X_eff` final role

**Dimensionless composite coordinate (`useful composite`), not the primary empirical scaling predictor** — AX-17B presentation policy and XEFF-width audit retain **`X_eff`** as the natural **ratio/dimensionless** label (**`I_peak/(width·S_peak)`** materialization); numeric benchmarks consistently favor **`invD`** over **`Xeff`** for **`A`** prediction under the tested metrics (equivalently: **useful dimensionless composite coordinate**, not primary empirical predictor).

### C. `invD` final role

**Denominator / area-scale proxy** **and** **best tested empirical scaling organizer** (among the AX-18C scaling candidate list and AX-17B/18B/19A benchmarks). **Not** asserted as a fundamental physical control variable **replacing** **`X_eff`** — AX-18B status **`SAFE_TO_SAY_INVD_REPLACES_XEFF = NO`**; AX-19A warns against wholesale replacement framing.

### D. Power-law status

| Quantity | Value |
|----------|-------|
| **`alpha` (`invD_power`, `A_obs_canon`)** | **0.562460847** (AX-18D / AX-18C scaling table) |
| **`alpha` (`invD_power`, `A_svd_full_oriented_candidate`)** | **0.558279495** |
| **`alpha_summary`** | **≈ 0.56** (descriptive log–log slopes; **n = 15**) |
| **`physical_scaling_law_established`** | **NO** |

### E. Temperature-control status

| Item | Closure |
|------|---------|
| **Best simple T-only baseline (AX-18C)** | **`T_linear`** on **`relaxation_T_K`** (lowest LOOCV among listed T-only family in **`T_function_model_comparison`**) |
| **`invD` vs `T_linear`** | **Beats** **`T_linear`** as single predictor in **linear-in-coordinate** space (AX-18C) and **`invD_power`** beats **`T_linear`** in **scaling-law comparison** (AX-18C/18D); AX-19A: **`log(invD_chosen)`** ranks **#1** LOOCV among one-predictor **`log(A)`** models vs tested **`T_relax_*`** proxies |
| **`invD` adds beyond `T`** | **Yes** in AX-18C combined models (**`invD_adds…`** flags); AX-19A **`invD_improves_beyond_best_T = 1`** for **`log(A)`** partial-control table |
| **`T` adds beyond `invD`** | AX-18C: **`BEST_T_ADDS_BEYOND_INVD_* = YES`**; AX-19A **`best_T_improves_beyond_invD = 1`** — **temperature retains incremental information** despite **`invD`–`T` collinearity** |
| **Caveat** | **n = 15**; strong **`T`–`invD` correlation** (~0.989 \|corr\| in AX-19A paper decision); series is **temperature-ordered** — causal uniqueness **not** claimed |

---

## Answers to required questions (with evidence)

1. **Final status of `X_eff`** — Canonical **P0 dimensionless composite** on this ladder (**width audit**); **not** the top empirical predictor of **`A`** vs **`invD`** (**17B judgement**, **19A** one-predictor ranks).
2. **Final status of `invD = 1/(w·S_peak)`** — **Denominator / area-scale coordinate** realized as **`invD_chosen`** in AX tables; **stronger organizer** of **`A`** than **`X_eff`** on audited metrics; **highly collinear** with **`T_relax`** (**19A**).
3. **Which is better globally?** **`invD_chosen`** — **17B visual judgement**, **18B shape judgement**, **18C** coordinate LOOCV and scaling winners, **19A** rankings (**not** “unique physics”).
4. **Dimensionless / physically interpretable coordinate?** **`X_eff`** is the **ratio composite** label for dimensionless discussion; **`invD`** is **interpretable as inverse effective area / denominator emphasis** — **not** interchangeable roles (see **17B** policy, **19A** guidance).
5. **Best empirical predictor / scaling organizer?** **`invD`** (and **`invD_power`** template within AX-18C list per **18D**).
6. **AX-18B turnover / high-T** — **`A`** peaks **≈ 29 K**; **`invD`** peak aligns with **`A`**; **`Xeff`** peak **offset ~4 K`**; **`invD`** wins **all four** high-**T** window composites vs **`Xeff`** (**18B report / shape judgement**).
7. **AX-18C simple T baselines** — Best among tested **T-only** models: **`T_linear`**; **hinge/quadratic** competitive but not best on LOOCV (**18C status / judgement**).
8. **AX-18D empirical power-law** — **`invD_power`** only scaling template **beating** **`T_linear`** on LOOCV (in **A** space); **`T_power` / `Xeff_power`** **do not**; **no physical law** (**18D**).
9. **AX-19A `invD` beyond `T`** — Classification **`INVD_NONTRIVIAL_BEYOND_T`**: **`log(invD)`** improves vs best **`T_relax_raw`** model; residual **`log A \| T`** vs **`log invD \| T`** correlations **moderate ~0.56** — signal **not fully absorbed** by linear **`T`** control (**19A report / status**).
10. **Exact allowed manuscript claim** — Bounded dual-axis narrative: **temperature trend** **plus** **denominator scaling** via **`invD`**; **empirical** power-law **slopes ~0.56** are **descriptive**; **`invD` preferred predictor** on this ladder **does not** retire **`X_eff`** as the **dimensionless ratio** label.
11. **Exact forbidden claim** — **Physical scaling law**, **universal exponent**, **mechanism proof**, **`invD` replaces `X_eff` wholesale**, **`X_eff` explains turnover better than `invD`**, **causal uniqueness** given **collinearity**.

---

## Tables produced by this synthesis

- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_evidence_matrix.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_final_claims.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_variable_roles.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_powerlike_scaling_summary.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_manuscript_wording.csv`
- `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_status.csv`

**END**
