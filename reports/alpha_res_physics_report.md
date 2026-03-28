# Alpha residual physics test (Agent 21B)

**Goal:** test whether `alpha_res` (PT-geometry residual from Agent 20B) tracks physical scalars `kappa1`, `R(T)`, and temperature.

- **alpha_res source:** `tables/alpha_from_PT.csv` column `residual_best` (recompute with `analysis/run_alpha_from_pt_agent20b.m` if needed).
- **kappa1 source:** `tables/alpha_structure.csv`
- **R(T) source:** `results/cross_experiment/runs/run_2026_03_25_031904_barrier_to_relaxation_mechanism/tables/barrier_descriptors.csv` (column `R_T_interp`). There is **no** relaxation row at **T = 4 K** in this barrier export, so **R** is missing for that temperature (pairwise exclusion for correlations).

## Correlations (pairwise complete observations)

| pair | Pearson | Spearman | n |
|---|---:|---:|---:|
| alpha_res vs kappa1 | -0.437469 | -0.391608 | 12 |
| alpha_res vs R(T) | -0.122837 | -0.318182 | 11 |
| alpha_res vs T | 0.186375 | 0.209790 | 12 |

## Regime test (below vs above 22–24 K)

- **Mean alpha_res for T < 22 K:** -0.0412679 (n = 9)
- **Mean alpha_res for T > 24 K:** -0.0289467 (n = 1; 28–30 K rows lack `residual_best` in `alpha_from_PT.csv`)
- **Welch two-sample t-test** p-value: **NaN** (not defined when one side has fewer than two finite samples; see `analysis/run_alpha_res_physics_agent21b.m`).
- **Regime flag heuristic:** |mean_lo − mean_hi| > 0.5·std(alpha_res) **or** p < 0.1.

## Variance concentration (22–24 K band)

- **Fraction of total sum-of-squares** of `alpha_res` about the global mean contributed by rows with **22 ≤ T ≤ 24**:
  **0.438032** (SS_band / SS_total).

## Linked-to-physics flags (threshold |ρ| or |ρ_s| ≥ 0.35 for “linked”; n ≥ 4)

- **ALPHA_RES_LINKED_TO_R** = **NO** (|Pearson| and |Spearman| both below 0.35)
- **ALPHA_RES_LINKED_TO_KAPPA1** = **YES** (|Pearson| and |Spearman| both ≥ 0.35)
- **ALPHA_RES_IS_REGIME_VARIABLE** = **NO** (small difference in means vs 0.5·std; no valid p-value)

## Artifacts

- `tables/alpha_res_physics.csv` — metric/value summary

*Regenerate with `analysis/run_alpha_res_physics_agent21b.m` (MATLAB) to refresh numbers from your current inputs.*
