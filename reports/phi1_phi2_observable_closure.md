# Phi1/Phi2 two-observable closure test

## Inputs
- Candidate list: `C:/Dev/matlab-functions/tables/phi1_map_observable_candidates.csv`
- Kappa table (primary): `C:/Dev/matlab-functions/tables/kappa_vs_T.csv`
- Residual decomposition table (fallback/augment): `C:/Dev/matlab-functions/tables/closure_metrics_per_temperature.csv`
- Phi1 observable table (fallback for O1): `C:/Dev/matlab-functions/tables/phi1_observable_failure_by_T.csv`

## Candidate list seen in map file
- `ridge_excess`
- `shoulder_compensation`
- `ridge_centered_second_moment`
- `lobe_balance_center_minus_shoulders`
- `matched_symmetric_gaussian_kernel`

## Models
- Scalar baseline: `kappa1 ~ central_ridge_excess` (LOOCV).
- 2D models per O2 candidate:
  - `kappa1 ~ central_ridge_excess + O2` (LOOCV).
  - `kappa2 ~ central_ridge_excess + O2` (LOOCV).

## Results table
- See `C:/Dev/matlab-functions/tables/phi1_phi2_observable_closure.csv`.

## Per-candidate summary
- O2=`antisymmetric_integral` | avail=false | scalar RMSE(k1)=0.000219219 | 2D RMSE(k1)=NaN | 2D RMSE(k2)=NaN | improvement=NaN
- O2=`slope_difference` | avail=false | scalar RMSE(k1)=0.000219219 | 2D RMSE(k1)=NaN | 2D RMSE(k2)=NaN | improvement=NaN
- O2=`local_curvature_window` | avail=false | scalar RMSE(k1)=0.000219219 | 2D RMSE(k1)=NaN | 2D RMSE(k2)=NaN | improvement=NaN

## Verdicts
- **TWO_OBSERVABLE_CLOSURE_IMPROVES: NO**
- **MINIMAL_2D_OBSERVABLE_FOUND: NO**
- Best O2 candidate by kappa1 RMSE improvement: `NONE`.
- Best absolute RMSE improvement: `NaN`.

## Run status
- Script status: **OK**
