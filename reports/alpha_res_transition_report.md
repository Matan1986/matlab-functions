# Alpha residual vs transition coordinate (Agent 22A)

**Goal:** test whether `alpha_res` behaves as a **transition coordinate** / distance-to-regime variable relative to the 22–24 K band (center **T = 23 K**).

## Data sources (existing tables only)

| Role | File |
| --- | --- |
| Primary `alpha_res` | `tables/alpha_decomposition.csv` (`alpha_res`, with `PT_geometry_valid` where present) |
| Fallback | `tables/alpha_from_PT.csv` (`residual_best`) when decomposition residual is missing |
| T_K alignment | `results/cross_experiment/runs/run_2026_03_25_031904_barrier_to_relaxation_mechanism/tables/barrier_descriptors.csv` (inner consistency; no recomputation of decomposition) |

**α_res(T) construction:** for each temperature row, use the decomposition residual when it is finite and `PT_geometry_valid` is true; otherwise use `residual_best` from `alpha_from_PT.csv`.

**Barrier-aligned fit set:** rows with finite `alpha_res` and `T_K` present in `barrier_descriptors.csv` (**n = 11**, **T = 6…26 K** in steps of 2). Row **T = 4 K** has a decomposition residual but is **not** on the barrier grid and is excluded from correlation/model fitting.

## Related work in this repo

- **Agent 21B** (`analysis/run_alpha_res_physics_agent21b.m`): correlations of `alpha_res` with `kappa1`, R(T), and T; regime split **T < 22** vs **T > 24** and variance in the 22–24 K band (`reports/alpha_res_physics_report.md`).
- **Crossover / regime language** appears in relaxation–switching bridge scripts (e.g. `analysis/relaxation_tau_time_window_test.m`, `analysis/ridge_crossover_vs_relaxation.m`); this agent focuses specifically on **α_res vs distance to the 22–24 K band**.

## Transition-centered coordinates

- **dT** = T_K − 23 (K)
- **|dT|**
- **Regimes:** **low** (T < 22), **mid** (22 ≤ T ≤ 24), **high** (T > 24)

## Correlations (barrier-aligned finite sample, n = 11)

| Pair | Pearson | Spearman |
| --- | ---: | ---: |
| α_res vs \|dT\| | −0.198529 | −0.077626 |
| α_res vs dT | 0.130279 | −0.009091 |

Spearman uses average ranks for ties (e.g. duplicate \|dT\| = 1 K at 22 and 24 K). Re-running `analysis/run_alpha_res_transition_agent22a.m` uses MATLAB’s `corr(...,'type','Spearman')`, which may differ in the last digit.

## Piecewise statistics (barrier-aligned)

| Regime | n | mean(α_res) | RMS(α_res) | mean(\|α_res\|) |
| --- | ---: | ---: | ---: | ---: |
| low (T < 22) | 8 | −0.104748 | 0.418928 | 0.341995 |
| mid (22–24 K) | 2 | 0.417223 | 0.671680 | **0.526383** |
| high (T > 24 K) | 1 | −0.200609 | 0.200609 | 0.200609 |

**Peak-at-transition:** **mid** has the largest **mean(\|α_res\|)** among the three regimes. The single largest **\|α_res\|** among barrier-aligned points occurs at **T = 22 K** (rank 1 in the full decomposition ranking among finite residuals).

## Models (in-sample R²)

| Model | R² |
| --- | ---: |
| (1) α_res ~ \|dT\| | 0.039414 |
| (2) α_res ~ regime dummies (mid reference) | 0.201845 |
| (3) α_res ~ dT + dT² | 0.025569 |
| Constant mean | 0 (reference) |

The regime-mean (dummy) model captures the largest share of variance among these three; the linear “distance to T* = 23 K” in \|dT\| and the quadratic in dT are comparatively weak at this n.

## LOOCV RMSE and improvement vs constant

| Model | LOOCV RMSE | Δ RMSE vs constant (positive = better than constant) |
| --- | ---: | ---: |
| Constant (mean of training fold) | 0.507635 | 0 |
| (1) α_res ~ \|dT\| | 0.570361 | −0.062727 |
| (2) Regime dummies | 0.507635 | 0 |
| (3) Quadratic dT | 0.629284 | −0.121649 |

None of the structured models **beats** the constant predictor under LOOCV on this small sample; the regime model’s in-sample R² does not translate into better out-of-sample RMSE here (partly because leaving one point out barely changes group means, and the mid band has only two temperatures).

## “Peak at transition” ranking (barrier-aligned)

Top temperatures by \|α_res\| (descending): **22, 20, 10, 16, 8, …** — the maximum is at **22 K** (inside the 22–24 K band).

## Final flags

| Flag | Value | Rationale (this run) |
| --- | --- | --- |
| **ALPHA_RES_IS_DISTANCE_TO_TRANSITION** | **NO** | Pearson \|ρ\| between α_res and \|dT\| is ~0.20 (below a strict “distance coordinate” threshold); LOOCV does not improve over a constant. |
| **ALPHA_RES_PEAKS_AT_TRANSITION** | **YES** | Mean(\|α_res\|) is highest in the **mid** regime; global max \|α_res\| at **22 K**. |
| **TRANSITION_MODEL_EXPLAINS_RESIDUAL** | **NO** | Best in-sample R² ≈ 0.20 is below a 0.25 bar and LOOCV gains are ≤ 0 vs constant for the best-structured case. |

## Visualization choices

- **Figure:** `figures/alpha_res_vs_dT.png` — scatter of **\|dT\|** vs **α_res** for the barrier-aligned points; marker color encodes signed **dT** (parula-like gradient). One panel; no colormap-by-curve (point cloud).
- **Exports:** PNG at 300 dpi equivalent; editable **FIG** can be regenerated with `analysis/run_alpha_res_transition_agent22a.m` (`alpha_res_vs_dT.fig`). Figure window **Name** matches file base per `docs/visualization_rules.md`.

## Artifacts

- `tables/alpha_res_vs_transition.csv` — per-T rows + metric block
- `figures/alpha_res_vs_dT.png`
- `analysis/run_alpha_res_transition_agent22a.m` — reproducible MATLAB driver (recomputes metrics from tables)

*Auto-generated for Agent 22A. Numeric block in CSV cross-checked against barrier-aligned subset; rerun the MATLAB script to refresh all digits and MATLAB Spearman.*
