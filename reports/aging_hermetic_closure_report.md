# Aging hermetic closure (Agent 24I)

**Computed by:** `tools/compute_aging_hermetic_agent24i.ps1` (leverage LOOCV, same as MATLAB `localLoocvOls`).

## 1. Question
Does a **single minimal** extension to `R ~ g(P_T) + kappa1 + alpha` (implemented with `spread90_50` for `g(P_T)`) close LOOCV error globally and in **22-24 K**?
Observable quantities are used here as empirical proxies for the underlying model variables (`P_T`, `\kappa_1`, `\alpha`) and do not define the model itself.

## 2. Data (same merge as Agents 24B / 24G)
- **R(T):** `R_T_interp`; clock lineage: `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/tables/table_clock_ratio.csv`
- **PT:** `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_25_031904_barrier_to_relaxation_mechanism/tables/barrier_descriptors.csv`
- **Energy join:** `C:/Dev/matlab-functions/results/switching/runs/run_2026_03_24_233256_energy_mapping/tables/energy_stats.csv`
- **State / gates:** `C:/Dev/matlab-functions/tables/alpha_structure.csv`, `C:/Dev/matlab-functions/tables/alpha_decomposition.csv`
- **Overlap:** n = **11** (finite R, spread90_50, kappa1, kappa2, alpha).
- **Model C:** `alpha_res` finite on all overlap rows.
- **T grid:** `6 8 10 12 14 16 18 20 22 24 26`

## 3. Models (LOOCV OLS, intercept)
| model | n | LOOCV RMSE | Pearson | mean abs res 22-24 K | mean abs res outside | pct RMSE vs ref | pct transition vs ref |
|---|---:|---:|---:|---:|---:|---:|---:|
| R ~ g(P_T) + kappa1 + alpha | 11 | 6.98804575007817 | 0.982177433124039 | 9.66711707326165 | 4.18515948437256 | 0 | 0 |
| R ~ g(P_T) + kappa1 + alpha + kappa1*alpha | 11 | 5.68199255914414 | 0.982939789310599 | 9.18573173510092 | 3.31612975467054 | -18.6898202679829 | -4.9796163066257 |
| R ~ g(P_T) + kappa1 + alpha + g23(T) | 11 | 16.9441642512107 | 0.975208837000687 | 9.61559127127512 | 8.46699775478131 | 142.473573545525 | -0.533000703271153 |
| R ~ g(P_T) + kappa1 + alpha + abs(alpha_res) | 11 | 6.35176881617559 | 0.989016125291927 | 6.37867950810206 | 3.76886331160961 | -9.10521992354525 | -34.0167346711369 |

**Model B:** ``g(T) = exp(-(T-23)^2/(2*1.5^2))`` K; sigma = 1.5 K fixed (not fitted).

## 4. Global vs transition
- **Reference LOOCV RMSE:** 6.98804575007817
- **Best LOOCV model (lowest RMSE):** `R ~ g(P_T) + kappa1 + alpha + kappa1*alpha` (LOOCV RMSE = 5.68199255914414)
- **RMSE_IMPROVED_OVER_BASELINE (best LOOCV vs ref):** 18.69 % reduction
- **Mean abs residual 22-24 K (for best LOOCV model):** reference = 9.66711707326165; best = 9.18573173510092 (reduction 4.98 % of reference)
- **Model C (|alpha_res|):** LOOCV RMSE 6.35176881617559; mean abs res 22-24 K 6.37867950810206 => **9.105 %** RMSE gain vs ref, **34.017 %** transition residual reduction vs ref.

## 5. Answers (brief)
1. Minimal correction: see best model row vs reference (LOOCV RMSE and 22-24 K mean abs residual).
2. 22-24 K mechanism: compare extension A (interaction), B (fixed Gaussian in T), C (|alpha_res|) using transition columns.
3. Remaining error: inspect residual vs T (baseline vs best); systematic banding implies structure.

## 6. Verdicts
- **INTERACTION_TERM_SUPPORTED:** **PARTIAL**
- **LOCAL_TRANSITION_TERM_SUPPORTED:** **NO**
- **RESIDUAL_DEFORMATION_TERM_SUPPORTED:** **YES**
- **HERMETIC_CLOSURE_ACHIEVED:** **YES**

Support rule (per term A/B/C): YES if LOOCV RMSE improves by >=3% *and* mean abs res in 22-24 K drops by >=10% vs reference; PARTIAL if only one holds.
HERMETIC_CLOSURE_ACHIEVED = YES if *any* extension satisfies both thresholds simultaneously (not necessarily the lowest LOOCV model overall).

## Figures
- `C:/Dev/matlab-functions/figures/aging_hermetic_predictions.png` (observed R vs LOOCV best)
- `C:/Dev/matlab-functions/figures/aging_hermetic_residuals_vs_T.png` (baseline vs best LOOCV residual vs T; shaded 22-24 K)
MATLAB twin: `analysis/run_aging_hermetic_closure_agent24i.m` writes the same names under a run directory and mirrors to `figures/`.
