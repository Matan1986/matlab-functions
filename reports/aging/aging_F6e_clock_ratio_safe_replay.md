# Aging F6e safe clock-ratio replay

## Inputs
All tau and bridge paths were **`results_old/...`** (`RESULTS_OLD_INPUTS_USED = YES`). Default missing `results/aging/...` mirrors were **not** used for computation (`MISSING_RESULTS_DEFAULTS_USED` documents shadow check).

## Replay runs
- Clock-ratio analysis output: `C:/Dev/matlab-functions/results/aging/runs/run_2026_04_27_222920_aging_F6e_replay_clock_ratio_analysis/tables/table_clock_ratio.csv`
- Temperature scaling data output: `C:/Dev/matlab-functions/results/aging/runs/run_2026_04_27_223022_aging_F6e_replay_clock_ratio_temperature/tables/clock_ratio_data.csv`
- Temperature scaling metrics: `C:/Dev/matlab-functions/results/aging/runs/run_2026_04_27_223022_aging_F6e_replay_clock_ratio_temperature/tables/aging_clock_ratio_temperature_scaling.csv`

## Comparison summary
- `REPLAY_MATCHES_RECOVERED_OUTPUTS`: **YES** (per-row R differences within tolerance).
- Ratio orientation **tau_FM / tau_dip** verified on replay rows where both taus finite.
- Finite R band and 26 K spike reproducibility recorded in comparison tables.
- **No new tau extraction fitting** was performed (`NEW_TAU_FITTING_PERFORMED = NO`). Scripts consumed fixed `tau_effective_seconds` inputs only.
- Temperature-scaling fit metrics (replay minus recovered): slope_eta_delta=0; intercept_a_delta=0; R2_delta=0; RMSE_delta=0; N_points_delta=0

## Canonical evidence
**Blocked** (`OLD_VALUES_USED_AS_CANONICAL_EVIDENCE = NO`). Replay establishes technical reproducibility only.

## Minimal figure-save fix (replay unblock)
Repository `save_run_figure` requires each figure `Name` to match the save basename; `create_figure` did not set `Name`. **Six** `set(fig,'Name',...)` lines were added: **four** in `Aging/analysis/aging_clock_ratio_analysis.m` and **two** in `Aging/analysis/aging_clock_ratio_temperature_scaling.m` immediately before `save_run_figure`. No change to ratio definitions or tau inputs.

## Verdict columns
- F6E_SAFE_REPLAY_COMPLETE = YES
- RESULTS_OLD_INPUTS_USED = YES
- MISSING_RESULTS_DEFAULTS_USED = NO_PRIMARY_DEFAULT_MIRROR_ABSENT_CFG_USED_results_old_ONLY
- NEW_TAU_FITTING_PERFORMED = NO
- RATIO_ORIENTATION_CONFIRMED = YES
- REPLAY_MATCHES_RECOVERED_OUTPUTS = YES
- FINITE_R_BAND_CONFIRMED = YES
- SPIKE_AT_26K_REPRODUCED = YES
- FINITE_R_ABOVE_26K_FOUND = NO
- OLD_VALUES_USED_AS_CANONICAL_EVIDENCE = NO
- READY_FOR_F6F_CANONICAL_BRIDGE_DESIGN = YES
- CROSS_MODULE_SYNTHESIS_PERFORMED = NO
