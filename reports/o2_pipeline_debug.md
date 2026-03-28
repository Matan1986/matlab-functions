# O2 pipeline debug + fix report

## Execution status

- `EXECUTION_STATUS`: **SUCCESS**
- `O2_PIPELINE_FIXED`: **YES**
- `O2_READY_FOR_CLOSURE_TEST`: **YES**

## Key artifacts

- Raw: `C:\Dev\matlab-functions\tables\o2_observables_raw.csv`
- Aligned: `C:\Dev\matlab-functions\tables\o2_observables_aligned.csv`
- Status: `C:\Dev\matlab-functions\tables\o2_pipeline_status.csv`
- This report: `C:\Dev\matlab-functions\reports\o2_pipeline_debug.md`

## Verdicts / availability

- `O2_COMPUTED`: **YES**
- `O2_ALIGNED`: **YES**
- `O2_AVAILABLE_FOR_MODELING`: **YES**
- `N_VALID_POINTS`: **14**
- `ANY_COLUMN_MISSING`: **NO**
- `ANY_COLUMN_ALL_NAN`: **NO**

## Windows / formulas used

- `antisymmetric_integral`: `integral_x sign(x) * deltaS(x,T)` (trapz)
- `slope_difference`: linear-fit slope in `x in [-xHalfSlope,0)` and `(0,xHalfSlope]`
- `local_curvature_window`: mean second derivative over `abs(x) < x0Curv`

## Minimal sanity test

- Regression: `kappa2 ~ antisymmetric_integral`
- Pearson (kappa2 vs LOOCV prediction): **-0.960907**
- LOOCV RMSE: **0.152984**
