# Aging reconstruction / prediction — meta-audit (latest repo evidence)

**Mode:** read-only survey of tracked `reports/` + `tables/` (March 2026 agent chain).  
**Not done:** recomputing LOOCV, editing legacy analysis scripts, or assuming uncommitted `results/` folders exist in every clone (paths in reports point at local run roots).

**Authoritative numerics:** CSVs under `tables/` take precedence when a prose report disagrees on a number; this audit reconciles only where both are present.

---

## TASK 1 — Chronological inventory (compact)

| Approx. date | Agent / artifact | Paths | Target | n | Role tag |
|-------------|------------------|-------|--------|---|----------|
| 2026-03-14 | Aging clock ratio (upstream) | Cited in downstream reports: `results/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/` | `R_tau_FM_over_tau_dip` → `R_T_interp` on PT grid | — | **canonical** lineage |
| 2026-03-25 | Barrier → relaxation merge | `run_2026_03_25_031904_barrier_to_relaxation_mechanism` | `barrier_descriptors.csv` incl. `spread90_50`, `R_T_interp` | — | **canonical** PT + R join |
| 2026-03-26 | **23A** | `reports/R_state_report.md` | R vs κ state | 11 | **exploratory** LOOCV on state coords |
| 2026-03-26 | **23B** | `reports/R_trajectory_report.md` | R vs κ trajectory + PT SVD baseline | 10 | **exploratory** (different PT encoding than 24B) |
| 2026-03-26 | **24D** | `reports/aging_kappa1_prediction.md`, `tables/aging_kappa1_*.csv` | κ1-only aging | 4 | **diagnostic** (non-comparable cohort) |
| 2026-03-26 | **24B** | `reports/aging_prediction_report.md`, `tables/aging_prediction_*.csv` | PT (`spread90_50`) + κ1 + trajectory | 10 | **canonical** for trajectory-null claim on this merge |
| 2026-03-26 | **24F** | `reports/aging_alpha_closure_report.md`, `tables/aging_alpha_closure_*.csv` | α / α_res / `abs(α)` extensions | 11 | **improved** vs PT+κ1; **supersedes** “α level only” as strongest sweep in that file |
| 2026-03-26 | **24G** | `reports/aging_kappa2_report.md`, `tables/aging_kappa2_*.csv` | κ2 beyond PT+κ1 | 11 | **canonical** negative result on κ2; **inconsistent headline risk** vs 24F/24I if “best LOOCV” is quoted without cross-check |
| 2026-03-26 | **24I** | `reports/aging_hermetic_closure_report.md`, `tables/aging_hermetic_closure_*.csv` | Extensions of **R ~ g(P_T) + κ1 + α** | 11 | **hermetic** (per project rule in that report) |

**Duplicates / supersession notes**

- **24B (n = 10)** and **24F/24G/24I (n = 11)** share the same temperature list in spirit but **not** the same overlap: 24B requires finite trajectory increments (drops a row). **Do not rank RMSE across these without labeling the cohort.**
- **24G** “best LOOCV model” line points at **R ~ g(P_T) + κ1 + α** (implemented with `spread90_50`; RMSE 6.988). **24F** and **24I** contain **lower RMSE** models on the same n = 11 style overlap — that is **not** a numerical contradiction, it is **partial reporting** if only 24G is read.
- **23B** “trajectory matters” and **24B** “trajectory does not add” are **compatible**: 23B’s best trajectory model still loses to a **PT SVD** baseline on its rows; 24B tests **incremental** value of **ds** on top of an already strong **g(P_T) + κ1** model (implemented via `spread90_50 + κ1`). Different PT coordinates ⇒ not a strict logical contradiction.

---

## TASK 2 — Standardized comparison (formulas, n, comparability)

**Target variable (aging):** clock-ratio style **R** as **`R_T_interp`** merged from aging clock analysis onto the barrier temperature grid (documented in each report).

**Strict apples-to-apples block (use this for global RMSE ranking):**

- **Cohort A — n = 11:** temperatures with finite **R**, **spread90_50**, **κ1**, **κ2**, **α** after `alpha_structure` / `alpha_decomposition` gates. Listed explicitly as `6;8;…;26` in `reports/aging_alpha_closure_report.md`, `reports/aging_kappa2_report.md`, `reports/aging_hermetic_closure_report.md`.
- **Cohort B — n = 10 (Agent 24B):** same PT/state sources but row set where trajectory columns (e.g. **ds**) are finite; see `reports/aging_prediction_report.md`.

**Formulas (exact strings as in CSVs):**

| Formula | n | LOOCV RMSE (from table) | Primary source |
|---------|---|-------------------------|----------------|
| `R ~ g(P_T) + kappa1 + alpha + kappa1*alpha` | 11 | 5.682 | `tables/aging_hermetic_closure_models.csv` |
| `R ~ g(P_T) + kappa1 + abs(alpha)` | 11 | 5.743 | `tables/aging_alpha_closure_models.csv` |
| `R ~ g(P_T) + kappa1 + alpha + abs(alpha_res)` | 11 | 6.352 | `tables/aging_hermetic_closure_models.csv` |
| `R ~ g(P_T) + kappa1 + alpha` | 11 | 6.988 | `tables/aging_kappa2_models.csv`, hermetic ref |
| `R ~ g(P_T) + kappa2` | 11 | 10.649 | `tables/aging_kappa2_models.csv` |
| `R ~ g(P_T) + kappa1` | 11 | 10.981 | `tables/aging_kappa2_models.csv` |
| `R ~ g(P_T) + kappa1` | 10 | 11.915 | `tables/aging_prediction_models.csv` |
| `R ~ g(P_T) + kappa1 + ds` | 10 | 13.187 | `tables/aging_prediction_models.csv` |

**Comparability flags**

- **Direct:** all **n = 11** rows in `aging_kappa2_models.csv`, `aging_alpha_closure_models.csv`, `aging_hermetic_closure_models.csv` for models that use only columns defined on that overlap.
- **Approximate / narrative only:** comparing **n = 10** 24B RMSE to **n = 11** closure chain.
- **Hermetic rule baseline:** 24I defines extensions relative to **`R ~ g(P_T) + kappa1 + alpha`**, not relative to **`R ~ g(P_T) + kappa1`**. Percent improvements in `aging_hermetic_closure_models.csv` use that **α-inclusive** reference (RMSE 6.988).

---

## TASK 3 — Ranked model tables (views A–D)

### A. Best overall predictive models (strict LOOCV RMSE, n = 11)

1. **R ~ g(P_T) + kappa1 + alpha + kappa1*alpha** — RMSE **5.682** (`aging_hermetic_closure_models.csv`).  
2. **R ~ g(P_T) + kappa1 + abs(alpha)** — RMSE **5.743** (`aging_alpha_closure_models.csv`).  
3. **R ~ g(P_T) + kappa1 + alpha + abs(alpha_res)** — RMSE **6.352** (hermetic table).  
4. **R ~ g(P_T) + kappa1 + alpha** — RMSE **6.988**.

*Caveat:* (1) is only enumerated in the **hermetic** extension table, not in the full 24F grid; (2) is the minimum RMSE in the **wider** 24F model list. Treat them as **related but non-nested** headline options until a single script exports one joint CSV.

### B. Best canonical / minimal models

1. **R ~ g(P_T) + kappa1** — RMSE **10.981**, n = 11 — best **two-term** interpretable bridge (PT landscape scalar + first collective amplitude).  
2. **R ~ g(P_T)** — RMSE **13.638**, n = 11 — minimal PT-only scalar model (implemented by `spread90_50`).  
3. **R ~ g(P_T) + kappa1** — RMSE **11.915**, n = 10 — use **only** when discussing **24B trajectory** results; state **n = 10**.

### C. Best hermetic-closure models (project criterion, not RMSE-only)

Per `reports/aging_hermetic_closure_report.md`: an extension **passes** if LOOCV RMSE improves by **≥ 3%** *and* mean |residual| in **22–24 K** improves by **≥ 10%** vs **`R ~ g(P_T) + kappa1 + alpha`**.

- **Qualifying extension:** **`+ abs(alpha_res)`** — transition residual reduction **~34%** vs reference; LOOCV improvement **~9.1%** (both thresholds met).  
- **`+ kappa1*alpha`:** **lowest LOOCV** among tested extensions but **transition improvement ~4.98%** vs α-base ⇒ **INTERACTION_TERM_SUPPORTED = PARTIAL** in that report (fails the **10%** transition leg).

**Therefore:** “Hermetic closure” in the **24I sense** is tied to **`abs(alpha_res)`** on the **α-augmented** base, not to the lowest global RMSE extension.

### D. Best PT-proxy mapping view (secondary measurement language)

- **Primary PT scalar proxy:** **spread90_50** (q90−q50 of threshold current ladder) — dominant observable proxy for `g(P_T)` in every aging prediction table reviewed.  
- **Augmented observable language:** `tables/latent_to_observable_replacement_table.csv` maps **α** to skew / width / asymmetry proxies for prose; **numeric closure** in CSVs still uses latent **α** from `alpha_structure` unless a separate observable-only refit is run (none in these tables).

---

## TASK 4 — True current status (conservative)

- **Not closed** if the bar is “aging fully determined by PT observables alone without latent state.” **spread90_50** alone is strong but **κ1** still wins LOOCV when added (n = 11).  
- **Partially closed** if the bar is “PT + low-dimensional collective state (κ1, α).” LOOCV is **low single digits to ~7** on n = 11 with α-level models — strong but **n = 11** is thin.  
- **Strongly closed (numeric, same cohort):** justified for **predictive** summaries that include **α** (or **`abs(α)`**) with PT + κ1 under strict LOOCV.  
- **Hermetically closed (project definition in 24I):** the report sets **`HERMETIC_CLOSURE_ACHIEVED: YES`** via **`+ abs(alpha_res)`** on the α-inclusive base; this is a **rule-based** statement anchored in that file, not a claim of zero systematic error.

**Strongest single justified sentence:** *On the documented n = 11 temperature overlap, aging R(T) is tightly predictable in LOOCV from barrier PT spread and collective-state scalars, with the best linear models using α (including `abs(α)` and κ1·α interaction extensions) and a hermetic-style residual correction `abs(α_res)` on top of α that specifically collapses 22–24 K error per Agent 24I’s dual criterion.*

**One-line summary:** *Aging is strongly predictable from **spread90_50 + κ1 + α** with modest extensions (`abs(α)`, κ1·α, `abs(α_res)`) lowering LOOCV further; κ2 and trajectory add-ons fail to improve the main PT+state story on the tested cohorts.*

---

## TASK 5 — Contradictions, missed quotes, confusion audit

| Issue | Verdict |
|-------|---------|
| “Best model is PT + κ1 + α at 6.988” (from 24G only) | **Superseded** as *global* best RMSE by **24F** (`abs(α)`) and **24I** (`+ κ1*α`). |
| “Trajectory helps aging” (23B) vs “trajectory adds nothing” (24B) | **Not incompatible** — different PT bases (SVD scores vs spread90_50) and different tests (marginal vs incremental on PT+κ1). |
| “Closure” without naming baseline | **Unsafe** — 24B **PARTIAL** refers to PT+state+trajectory *full* closure; **24I** “hermetic” is relative to **α-inclusive** baseline. |
| Better model from overlap change | **n = 10 vs n = 11** shifts reference RMSE; always disclose **n**. |
| Mixing **PT + κ1**, **PT + κ1 + α**, **+ κ1*α**, **+ abs(α_res)** | **Common confusion** — each tier is a **different** model class; **α_res** on PT+κ1 **fails** (24F) but **succeeds** on PT+κ1+α for the hermetic rule (24I). |

**Forgotten stronger result?** If the only artifact read is **`reports/aging_kappa2_report.md`**, yes — **`abs(α)`** and **`+ κ1*α`** are **stronger** on LOOCV in other tables.

---

## TASK 6 — Variable roles (evidence-based)

| Variable | Global LOOCV | Transition (22–24 K) | Robustness | Canonical vs corrective | Observable-backed? |
|----------|----------------|----------------------|------------|-------------------------|--------------------|
| **spread90_50** | Strong alone; major share of variance | Large residuals remain vs R in 24B narrative | **Robust** anchor across agents | **Canonical** PT scalar | Yes (quantile ladder) |
| **kappa1** | Required with PT on n = 11; alone fails vs naive mean on n = 11 | Part of residual structure before α | **Fragile** alone; **stable** with PT | **Canonical** with spread | Latent (map-derived); proxies per dictionary |
| **kappa2** | No gain in `+ κ2` tensor test; `spread + κ2` beats `spread + κ1` *only* among κ-only swaps | Worse than α path per 24G | **Fragile** for aging closure here | Corrective / second mode — **not supported** | Partial (I_peak links in dictionary) |
| **alpha** | Large drop vs PT+κ1 | Still elevated error before hermetic fix | Strong in linear class | **Canonical** in “full” aging story after 24F | Latent; prose proxies in dictionary |
| **kappa1*alpha** | **Best LOOCV** extension in 24I table | **Fails** 10% transition gain vs α-base | **Mixed** — best RMSE, partial hermetic interaction flag | Corrective / interaction | Latent |
| **alpha_res** (added to PT+κ1 only) | **Does not** improve LOOCV (24F) | — | **Fragile** in that role | Not a global corrective there | Decomposition latent |
| **abs(alpha_res)** (on PT+κ1+α) | Moderate RMSE gain vs α-base | **Large** | Supported **where α is already in model** | **Hermetic** deformation term per 24I | Latent |
| **Trajectory (ds, Δθ, …)** | **No** gain on top of spread+κ1 (24B n = 10) | 24B cites larger mean |**Not robust** in preferred headline spec | Corrective only if ever | Mixed (κ path geometry) |

---

## Machine-readable companions

- `tables/aging_meta_audit_result_inventory.csv` — one row per run / table family.  
- `tables/aging_meta_audit_model_ranking.csv` — ranked models with comparability flags.

---

## FINAL VERDICTS

BEST_OVERALL_AGING_MODEL: R ~ g(P_T) + kappa1 + alpha + kappa1*alpha (LOOCV RMSE 5.682, n = 11, tables/aging_hermetic_closure_models.csv); runner-up by RMSE in a wider sweep: R ~ g(P_T) + kappa1 + abs(alpha) (5.743, tables/aging_alpha_closure_models.csv).

BEST_CANONICAL_AGING_MODEL: R ~ g(P_T) + kappa1 (LOOCV RMSE 10.981, n = 11, tables/aging_kappa2_models.csv).

BEST_HERMETIC_CLOSURE_MODEL: R ~ g(P_T) + kappa1 + alpha + abs(alpha_res) (qualifies Agent 24I dual-threshold rule vs the alpha-inclusive reference; LOOCV RMSE 6.352, tables/aging_hermetic_closure_models.csv).

AGING_STATUS_NOW: PARTIALLY_CLOSED_NUMERICALLY_STRONG_ON_N11 — hermetic closure language is supported only under the explicit 24I rule on the alpha-inclusive base; not a claim that PT observables alone close aging.

TRAJECTORY_ROLE: INCREMENTAL_NULL_ON_SPREAD_PLUS_KAPPA1_COHORT_N10 — Agent 24B; do not merge with n = 11 RMSE without relabeling.

ALPHA_ROLE: STRONG_GLOBAL_PREDICTOR_BEYOND_PT_PLUS_KAPPA1 — signed alpha and especially abs(alpha) materially reduce LOOCV on n = 11 (tables/aging_alpha_closure_models.csv).

ALPHA_RES_ROLE: CONTEXT_DEPENDENT — does not improve closure added only to PT+kappa1 (24F); as abs(alpha_res) on PT+kappa1+alpha it is the hermetic-qualifying transition fixer (24I).

DID_WE_MISS_A_STRONGER_RESULT: YES — if only Agent 24G’s “best LOOCV = PT+kappa1+alpha” line is quoted, lower-RMSE models in 24F/24I tables are missed.

MAIN_COMPARABILITY_CAVEAT: n = 10 (24B trajectory merge) vs n = 11 (alpha / kappa2 / hermetic chain); hermetic % gains vs R ~ g(P_T) + kappa1 + alpha, not vs PT+kappa1 alone.

RECOMMENDED_MODEL_TO_QUOTE_IN_FUTURE: State n and purpose: for minimal story use R ~ g(P_T) + kappa1 (n=11); for best LOOCV use R ~ g(P_T) + kappa1 + alpha + kappa1*alpha or R ~ g(P_T) + kappa1 + abs(alpha) with formula explicit; for hermetic claim use R ~ g(P_T) + kappa1 + alpha + abs(alpha_res) per 24I rule, not interchangeably with the lowest-RMSE interaction model.
