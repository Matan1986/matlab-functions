# Local shift / backbone deformation test (Agent 19G)

## Sources
- Alignment: `run_2026_03_10_112659_alignment_audit`
- Full scaling: `run_2026_03_12_234016_switching_full_scaling_collapse`
- PT matrix: `run_2026_03_24_212033_switching_barrier_distribution_from_map`
- Canonical window: T <= 30 K

## Method
- For each T, **deltaI** minimizes RMSE between **S(I)** and **S_CDF(I - deltaI)** on the alignment current grid (PT-derived CDF backbone times S_peak).
- **Tangent model:** `deltaS(I) ~ deltaI(T) * dS_CDF/dI`.
- **Rank-2 reference:** `deltaS ~ kappa1*Phi1 + kappa2*Phi2` with LSQ **kappa2** on the same I samples as the residual (Phi evaluated at row-wise x).

## Aggregate metrics (low-T window)
| Quantity | Value |
| --- | --- |
| Median RMSE (tangent vs deltaS) | 0.0673553 |
| Median RMSE (rank-2 vs deltaS, I grid) | 0.0162345 |
| Median corr (deltaS, tangent) | -0.4760 |
| Median corr (deltaS, rank-2) | 0.9844 |
| corr(deltaI, kappa2) | NaN |
| corr(deltaI, alpha) | NaN |
| LOOCV mean |Delta corr| (deltaI vs kappa2) | NaN |

## Final verdict

| Verdict | Value |
| --- | --- |
| **RESIDUAL_IS_LOCAL_SHIFT** | NO |
| **SHIFT_EXPLAINS_KAPPA2** | NO |
| **DEFORMATION_INTERPRETATION_VALID** | NO |

### Interpretation notes
- **RESIDUAL_IS_LOCAL_SHIFT** is YES when the tangent approximation tracks deltaS about as well as the rank-2 surface fit and **S** matches the shifted CDF backbone with high correlation.
- **SHIFT_EXPLAINS_KAPPA2** reports whether the scalar shift moves with the second amplitude kappa2 across low-T rows.
- **DEFORMATION_INTERPRETATION_VALID** combines the above; a strong rank-2 edge without tangent support favors an independent second mode rather than pure I-space shear of the CDF.

## Per-temperature table
See `tables/local_shift_metrics.csv` for full rows.
