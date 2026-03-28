# PHI1 Observable Failure Analysis by Temperature

## Input and method
- Inputs: `results/switching/runs/run_2026_03_25_011649_rsr_child_nxgrid_180/tables/kappa_vs_T.csv`, `results/switching/runs/run_2026_03_25_011649_rsr_child_nxgrid_180/tables/phi_shape.csv`, and `tables/closure_metrics_per_temperature.csv`.
- Central ridge excess follows the same Phi1-only map-evaluation convention as `phi1_map_observable_search`: `central_ridge_excess(T) = kappa1(T) * integral_{|x|<=x_ridge} Phi1(x) dx`.
- `x_ridge` is the first +x sign-change boundary of `Phi1(x)`: `x_ridge = 0.122456702205`.
- Ridge integral constant: `C = integral_{|x|<=x_ridge} Phi1(x) dx = 0.030423579281457815`.
- Per-T deviation from global fit uses: `kappa1 = a + b * central_ridge_excess`, with `a = 1.38778e-17`, `b = 32.8692`.
- Global correlation between `central_ridge_excess` and `kappa1`: `1.000000`.
- Reconstruction error per T uses canonical `rmse_M2` (PT + kappa1*Phi1 closure), with z-score normalization across temperatures.
- Significant deviation threshold: `|z_rmse| > 1.5` OR top 20% of reconstruction error.

## Key quantitative results
- Mean reconstruction error in 22-24K: `0.010634`.
- Mean reconstruction error outside 22-24K: `0.008640`.
- Inside/outside error ratio: `1.231`.
- Maximum reconstruction error: `T=30 K`, `rmse_M2=0.025101`.
- Inside-band maximum (22-24K): `T=24 K`, `rmse_M2=0.011817`.
- Significant-deviation temperatures: `30, 4, 24`.

## Required verdicts
PHI1_OBSERVABLE_FAILURE_LOCALIZED: NO
FAILURE_AT_22K_REGION: YES
OBSERVABLE_STABLE_ACROSS_T: NO

## Interpretation
- The scalar central ridge excess remains perfectly aligned with `kappa1(T)` under Phi1-only reconstruction (correlation ~1 by construction).
- Degradation appears in reconstruction quality (`rmse_M2`), not in scalar alignment, indicating additional residual structure beyond rank-1/Phi1 at selected temperatures.
- The 22-24K band shows elevated mean error, but the global worst case is at 30K, so failure is not strictly localized to the 22-24K region.
- The pattern is consistent with missing/subleading mode contributions (for example Phi2) or limits of a scalar observable for full closure.
- Practical conclusion: central ridge excess is a stable amplitude proxy, but not a complete standalone observable across all temperatures.
