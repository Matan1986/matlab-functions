# Deformation ratio structure (Agent 19F)

## Definition
- **alpha(T)** = `kappa2 / kappa1`, with `kappa1` = rank-1 amplitude (`kappaAll`), `kappa2` = coefficient on **Phi2** in the per-temperature rank-2 fit to the residual strip.
- Same pipeline as Agent 19E (`switching_residual_decomposition_analysis`).

## Sources
- Alignment: `run_2026_03_10_112659_alignment_audit`
- Full scaling: `run_2026_03_12_234016_switching_full_scaling_collapse`
- PT run: `run_2026_03_24_212033_switching_barrier_distribution_from_map`

## 1. Correlations with alpha
| Variable | Pearson | Spearman |
| --- | --- | --- |
| I_peak | 0.5421 | -0.2087 |
| median_I_q50 | 0.5356 | -0.3890 |
| q90_minus_q50 | 0.6961 | 0.1516 |
| q75_minus_q25 | 0.6448 | -0.1473 |
| skew_I_weighted | -0.4969 | 0.2659 |
| asymmetry_q_spread | 0.2813 | 0.4857 |
| T_K | -0.1736 | 0.4374 |
| width_mA | 0.3116 | -0.3978 |
| S_peak | -0.0343 | -0.5429 |

## 2. Regime / 22–24 K
- max |d alpha / dT| in 21.5–24.5 K / median |d alpha / dT| elsewhere: **9.313** (sharp if > 2.5)
- max |d alpha / dT| in band (raw discrete): **1.0524**
- Slopes (discrete, sorted T): before 22K **0.465079**, 22→24 **-0.197755**, after 24K **-0.338014**

## 3. Stability
- Monte Carlo: 1% multiplicative noise on kappa1,kappa2 (valid T); relative std of batch-mean **alpha**: **0.0065**; of batch-mean **kappa2**: **0.0037**
- LOO at 22K: std(kappa2): **0.0343519**; std(alpha) using kappa2_LOO / kappa1(22K full): **0.896994**
- Alpha more MC-sensitive than kappa2: **1** (1=yes)

## 4. Artifacts
- Per-temperature table: `tables/alpha_structure.csv`
- Figure: `figures/alpha_vs_T.png`

## Final verdict

- **ALPHA_IS_PHYSICAL_COORDINATE**: YES
- **ALPHA_LINKED_TO_GEOMETRY**: YES
- **ALPHA_EXPLAINS_REGIME_CHANGE**: YES

### Notes
Ratios amplify relative noise when |kappa1| is small; interpret MC and LOO stability together with correlation structure.
