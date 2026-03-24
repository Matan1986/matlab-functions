# Temperature Null Test: Does X Add Information Beyond T?

## Summary
- Dataset: `AX_aligned_data.csv` with n=14 aligned temperatures (4-30 K).
- Best A(T) polynomial by LOOCV: degree 4 (LOOCV RMSE = 4.43208e-05).
- A(T) spline baseline (cubic spline interpolation): LOOCV RMSE = 7.92656e-05.
- A(X) power-law baseline (`ln A = beta ln X + b`): LOOCV RMSE = 0.000174191.
- Partial corr: corr(A,X|T linear)=0.7966 (p=0.0006494), corr(A,X|T poly3)=0.5664 (p=0.03473).
- Residual corr: corr(A-Afit_poly(T),X)=-0.0251 (p=0.9322), corr(A-Afit_spline(T),X)=NaN (p=NaN).
- Peak alignment to X peak (T=26.0 K): |DeltaT| poly=0.035 K, spline=0.620 K, A(X)-model=0.000 K.

## Data Reused
- `results/cross_experiment/runs/run_2026_03_13_115401_AX_functional_relation_analysis/tables/AX_aligned_data.csv`
- `results/cross_experiment/runs/run_2026_03_13_123230_AX_scaling_temperature_robustness/reports/AX_scaling_temperature_robustness.md` (reused published LOOCV reference for A(X)).

## Models Tested
1. **Direct T fit baseline**
- Polynomial A(T), degrees 2/3/4; selected by minimum LOOCV RMSE.
- Cubic spline A(T) baseline.
2. **A(X) comparator**
- Power-law model `ln A = beta ln X + b`.
3. **Partial correlation**
- corr(A, X | T) with linear T control and cubic polynomial T control.
4. **Residual test**
- corr(A - A_fit(T), X) for polynomial and spline T-only fits.
5. **Peak structure test**
- Compare predicted A-peak temperature vs observed X-peak temperature.

## Quantitative Comparison vs X
### Direct fit quality
- A(X) power law: R2=0.952743, RMSE=0.000153629, LOOCV RMSE=0.000174191.
- A(T) polynomial deg 2: R2=0.872183, RMSE=0.000252659, LOOCV RMSE=0.000387635.
- A(T) polynomial deg 3: R2=0.977870, RMSE=0.000105132, LOOCV RMSE=0.000229901.
- A(T) polynomial deg 4: R2=0.998979, RMSE=2.25787e-05, LOOCV RMSE=4.43208e-05.
- A(T) spline: R2=1.000000, RMSE=0, LOOCV RMSE=7.92656e-05.

### Conditional dependence and residual signal
- corr(A, X | T linear) = 0.7966 (p=0.0006494).
- corr(A, X | T poly3) = 0.5664 (p=0.03473).
- corr(A - A_fit_poly(T), X) = -0.0251 (p=0.9322).
- corr(A - A_fit_spline(T), X) = NaN (p=NaN).

### Peak structure
- Observed peaks: A(T) at 26.0 K, X(T) at 26.0 K.
- Peak mismatch vs X peak: polynomial 0.035 K, spline 0.620 K, A(X) model 0.000 K.

## Final Conclusion
**NO**

The observed A-X relation is explainable by shared temperature dependence under these tests.

Answer to final question: **NO**
