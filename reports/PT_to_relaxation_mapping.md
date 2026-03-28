# PT to relaxation mapping

**EXECUTION_STATUS:** SUCCESS

## Inputs
- PT: `C:/Dev/matlab-functions/results/switching/runs/run_2026_03_25_013356_pt_robust_canonical/tables/PT_matrix.csv`
- Relaxation: `C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing/tables/S_time_cuts_values.csv`
- Time-cuts meta: `C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing/tables/S_time_cuts_meta.csv`

## Method
- Step 1: normalize PT row to P(E).
- Step 2: map barrier to time with `tau(E,T)=exp(E/T)`.
- Step 3: build `R_pred(T,t)=sum_E P(E) * exp(-t/tau(E,T))`.
- Step 4: compare against relaxation cuts over temperature.

## Verdicts
- **PT_EXPLAINS_RELAXATION_SHAPE:** NO
- **PEAK_POSITION_MATCH:** NO
- **WIDTH_MATCH:** NO
