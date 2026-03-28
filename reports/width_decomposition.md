# Width decomposition: PT + collective

**Run script:** `C:\Dev\matlab-functions\Switching\analysis\run_width_decomposition_test.m`
**Date:** 2026-03-27 22:02:30

## Inputs
- `w(T)` source: `C:\Dev\matlab-functions\tables\alpha_structure.csv` (columns `T_K`, `width_mA`)
- `w_PT(T)` source: `C:\Dev\matlab-functions\tables\alpha_from_PT.csv` (column `std_threshold_mA_PT`)
- `kappa1(T)` source: `C:\Dev\matlab-functions\tables\kappa1_from_PT_aligned.csv` (column `kappa1`)

## Alignment and decomposition
- Manual alignment by temperature (`T_K`) with exact lookup tolerance 1e-9 K.
- Decomposition used: `delta_w(T) = w(T) - w_PT(T)`.
- Aligned finite rows: n = 12
- Aligned temperatures (K): `[4 6 8 10 12 14 16 18 20 22 24 26]`

## LOOCV models for `delta_w`
| Model | LOOCV RMSE | Pearson(y,yhat) | Spearman(y,yhat) | RMSE - baseline |
|---|---:|---:|---:|---:|
| delta_w ~ kappa1 | 2.14838 | 0.386493 | 0.531469 | -0.251786 |
| delta_w ~ PT | 2.64298 | -0.332492 | -0.867133 | 0.242811 |
| delta_w ~ kappa1 + PT | 2.20817 | 0.428682 | 0.706294 | -0.192002 |

## Component checks
- Width PT check: rmse(w~const)=3.13729, rmse(w~PT)=2.64298, corr(w,w_PT)=0.650101
- Residual collective check: rmse(delta_w~const)=2.40017, rmse(delta_w~kappa1)=2.14838, corr(delta_w,kappa1)=0.623144
- Residual PT coupling: rmse(delta_w~PT)=2.64298, corr(delta_w,PT)=0.116375
- Combined residual model: rmse(delta_w~kappa1+PT)=2.20817, corr(delta_w,yhat)=0.428682

## Verdicts
- **WIDTH_HAS_PT_COMPONENT:** **YES**
- **WIDTH_HAS_COLLECTIVE_COMPONENT:** **YES**
- **WIDTH_DECOMPOSITION_PHYSICALLY_MEANINGFUL:** **NO**

## Output files
- `C:\Dev\matlab-functions\tables\width_decomposition_models.csv`
- `C:\Dev\matlab-functions\reports\width_decomposition.md`
- `C:\Dev\matlab-functions\tables\width_decomposition_status.csv`

**Analysis status:** `YES`
