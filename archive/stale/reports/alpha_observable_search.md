# Alpha Observable Modeling Search (Stable Pipeline)

- Script: `C:/Dev/matlab-functions/Switching/analysis/run_aging_nonlinear_law_test.m`
- Generated: `2026-03-27 08:35:55`

## Inputs (Canonical)
- `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_25_031904_barrier_to_relaxation_mechanism/tables/barrier_descriptors.csv`
- `C:/Dev/matlab-functions/tables/alpha_structure.csv`
- `C:/Dev/matlab-functions/tables/alpha_decomposition.csv`

## Pipeline Guards
- Manual `T_K` alignment only (no `innerjoin`).
- No interpolation / no artificial fill.
- Per-model finite filtering (`X_raw -> mask -> X_model`).
- `size(X_model,1) < 5` => model skipped.
- Near-constant columns removed (`std < 1e-10`).
- Safe regression uses `pinv` in LOOCV.

## Stability Outcome
- EXECUTION_STATUS: **SUCCESS**
- BASELINE_WORKS: **YES**
- N_VALID_MODELS: `8`
- MAIN_RESULT_SUMMARY: `valid_models=8, baseline_works=YES, best_model='R ~ spread90_50 + kappa1 + alpha + log(kappa1)', best_rmse=3.5342`

## Artifacts
- Debug table: `C:/Dev/matlab-functions/tables/alpha_observable_debug_full.csv`
- Models table: `C:/Dev/matlab-functions/tables/alpha_observable_models.csv`
- Status table: `C:/Dev/matlab-functions/tables/alpha_observable_status.csv`
- Report: `C:/Dev/matlab-functions/reports/alpha_observable_search.md`
