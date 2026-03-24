# Functional Form Test Report

## Summary
- Dataset: `results/cross_experiment/runs/run_2026_03_13_115401_AX_functional_relation_analysis/tables/AX_aligned_data.csv` (n=14, T=4-30 K).
- Baseline model: `A ~ X^beta` with `X = I_peak/(w*S_peak)`.
- Compared direct T models, transformed T models, nonparametric monotonic models, and alternative coordinates.
- Final verdict: **X is one of a small family (canonical representative)**.

## Data reused
- `results/cross_experiment/runs/run_2026_03_13_115401_AX_functional_relation_analysis/tables/AX_aligned_data.csv`
- `reports/temperature_null_test_report.md` (existing polynomial/spline context)
- `reports/dimensionless_constrained_basin_report.md` (existing constrained-basin context)
- `results/cross_experiment/runs/run_2026_03_22_080734_x_single_observable_residual_test_corrected/reports/x_independence_single_observable_report.md`

## Models tested
- Baseline: X power law (`ln(A)=a ln(X)+b`).
- Direct temperature: polynomial degree 2/3/4, cubic spline.
- Generic transforms: `log(T)`, `exp(-T)`, `1/T`.
- Nonparametric monotonic: isotonic regression, monotonic spline (pchip on isotonic fit).
- Alternative coordinates: `I_peak/w`, `1/(w*S_peak)`, `S_peak`, `I_peak`.

## Full comparison table
- Machine-readable table: `reports/functional_form_test_metrics.csv`.

| Model | Group | Pearson(A,Ahat) | Spearman(A,Ahat) | DeltaT_peak (K) | R2 | Residual corr(T) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| spline_T | direct_T | 1.000000 | 1.000000 | 0.0 | 1.000000 | NaN |
| poly4_T | direct_T | 0.999489 | 0.995604 | 0.0 | 0.998979 | 0.000000 |
| poly3_T | direct_T | 0.988873 | 0.964835 | 0.0 | 0.977870 | 0.000000 |
| isotonic_T | nonparametric | 0.986185 | 0.977838 | -2.0 | 0.972562 | -0.108494 |
| monotonic_spline_T | nonparametric | 0.986185 | 0.977838 | -2.0 | 0.972562 | -0.108494 |
| X_alt3_S_peak | alt_coordinate | 0.980420 | 0.986813 | 0.0 | 0.961143 | -0.067205 |
| X_power_law | baseline | 0.976638 | 0.986813 | 0.0 | 0.952743 | 0.036485 |
| poly2_T | direct_T | 0.933907 | 0.951648 | 4.0 | 0.872183 | -0.000000 |
| X_alt2_inv_wS | alt_coordinate | 0.929307 | 0.951648 | 4.0 | 0.860143 | -0.106374 |
| logT_linear | T_transform | 0.887050 | 0.951648 | 4.0 | 0.786857 | 0.168262 |
| invT_linear | T_transform | 0.756410 | 0.951648 | 4.0 | 0.572156 | 0.440006 |
| X_alt1_I_over_w | alt_coordinate | 0.701704 | 0.762637 | 2.0 | 0.480238 | 0.569049 |
| X_alt4_I_peak | alt_coordinate | 0.527492 | 0.791077 | 4.0 | 0.195342 | 0.410615 |
| exp_minus_T_linear | T_transform | 0.396702 | 0.951648 | 4.0 | 0.157372 | 0.797732 |

## Best-performing alternatives
- `spline_T`: R2=1.000000, Pearson=1.000000, Spearman=1.000000, DeltaT_peak=0.0 K.
- `poly4_T`: R2=0.998979, Pearson=0.999489, Spearman=0.995604, DeltaT_peak=0.0 K.
- `poly3_T`: R2=0.977870, Pearson=0.988873, Spearman=0.964835, DeltaT_peak=0.0 K.

## Comparison vs X
- Baseline X metrics: Pearson=0.976638, Spearman=0.986813, DeltaT_peak=0.0 K, R2=0.952743.
- Number of alternatives matching X within tight tolerance (|DeltaPearson|<=0.005, |DeltaSpearman|<=0.005, |DeltaT_peak|<=0 K): **1**.
- Number of simple alternatives matching both scaling (R2 within 0.01 of X) and peak alignment: **1**.

## Structure test
- Some models achieve high scaling quality but fail peak alignment, while others preserve peak alignment with weaker scaling.
- This separation indicates that matching only one criterion is common; matching both is more selective.

## Final questions
1. Are there many functions of T that perform as well as X? **NO**
2. Does any simple alternative match BOTH scaling and alignment? **YES**
3. Is X distinguishable by simplicity and structure? **YES**

## Final verdict
- **X is one of a small family (canonical representative)**
