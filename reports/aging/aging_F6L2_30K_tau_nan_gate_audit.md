# F6L2 30K tau NaN-gate audit

diagnostic_only; archived-lineage context; no canonical reinterpretation.

## Inputs

- Old tau table: `C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_12_223709_aging_timescale_extraction\tables\tau_vs_Tp.csv`
- Old tau report: `C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_12_223709_aging_timescale_extraction\reports\aging_timescale_extraction_report.md`
- Replay tau table: `C:\Dev\matlab-functions\results\aging\runs\run_2026_04_28_094514_aging_timescale_extraction\tables\tau_vs_Tp.csv`

## 30K NaN source

- Old 30K half-range status: `no_upward_crossing`
- Old 30K consensus method count: 0
- Old report consensus rule: `Consensus reported only when direct half-range is resolved`

## Method-level 30K

- logistic_log_tw: old=700.016 (ok), replay=700.016 (ok)
- stretched_exp: old=5.02594e+11 (extrapolated), replay=5.02594e+11 (extrapolated)
- direct_half_range: old=NaN (no_upward_crossing), replay=NaN (no_upward_crossing)

## Phase classification

- Tp=6 -> IN_PHASE
- Tp=10 -> IN_PHASE
- Tp=14 -> IN_PHASE
- Tp=18 -> IN_PHASE
- Tp=22 -> IN_PHASE
- Tp=26 -> IN_PHASE
- Tp=30 -> IN_PHASE
- Tp=34 -> PHASE_EXCLUDED_DIAGNOSTIC_ONLY

## Gated parity result (summary)

- In-phase tau_Dip matches after old gate: 7 / 7
- In-phase R matches after old gate: 7 / 7

## Verdicts

- **F6L2_30K_TAU_NAN_GATE_AUDIT_COMPLETED**: YES
- **PHASE_WINDOW_RULE_APPLIED**: YES
- **TP34_CLASSIFIED_PHASE_EXCLUDED_DIAGNOSTIC_ONLY**: YES
- **OLD_30K_TAU_NAN_SOURCE_TRACED**: YES
- **OLD_30K_TAU_NAN_GATE_RECOVERED**: YES
- **METHOD_LEVEL_30K_ESTIMATES_COMPARED**: YES
- **TP30_TAU_DIP_NAN_REPRODUCED**: YES
- **IN_PHASE_OLD_TAU_DIP_REPRODUCED_AFTER_GATE**: YES
- **IN_PHASE_OLD_R_RATIO_REPRODUCED_AFTER_GATE**: YES
- **ALL_ROW_PARITY_BLOCKED_ONLY_BY_PHASE_EXCLUDED_ROWS**: YES
- **ARCHIVED_LINEAGE_REPLAY_FLAGGED**: YES
- **CANONICAL_PHYSICS_EVIDENCE**: NO
- **CURRENT_CANONICAL_REPLAY**: NO
- **METHOD_SEARCH_PERFORMED**: NO
- **R_VS_X_ANALYSIS_PERFORMED**: NO
- **MECHANISM_VALIDATION_PERFORMED**: NO
- **READY_FOR_F6M_SOURCE_SELECTION_BRIDGE**: YES
- **READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH**: NO
