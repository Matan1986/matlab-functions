# MT time-axis patch validation (Stage 2.3)

This document records validation of MT time-axis diagnostics after runner patch `d9a0fa2` (`Refine MT time-axis diagnostics`).

## Validation context

- Runner: `runs/run_mt_canonical.m` (patched)
- Wrapper command: `.\tools\run_matlab_safe.bat "C:\Dev\matlab-functions\runs\run_mt_canonical.m"`
- Run directory: `C:\Dev\matlab-functions\results\mt\runs\run_2026_04_25_224938_mt_real_data_diagnostic`
- Input: real MPMS MT `.DAT` set (11 files)
- Scope: artifact validation only (no MATLAB execution in this stage)

## Execution status

- `EXECUTION_STATUS=SUCCESS`
- `INPUT_FOUND=YES`
- `N_T=11`
- `MAIN_RESULT_SUMMARY=diagnostic artifacts written with time-axis warnings`

## Run-level time-axis outcomes

From `tables/mt_canonical_run_summary.csv` and run report:

- `MT_TIME_AXIS_WARNINGS_PRESENT=YES`
- `MT_TIME_AXIS_CORRUPTION_PRESENT=NO`
- `MT_TIME_AXIS_PAUSE_GAPS_PRESENT=YES`
- `MT_TIME_AXIS_SEGMENTATION_RISK_PRESENT=NO`
- `MT_SEGMENTATION_TRUST_LEVEL=MEDIUM`
- `FULL_CANONICAL_DATA_PRODUCT=NO`
- `MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE=NO`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`

## Per-file classification check

From `tables/mt_raw_summary.csv` and `tables/mt_file_inventory.csv`:

- All 11 files have:
  - `time_warning_class=PAUSE_GAPS`
  - `time_quality=MEDIUM`
  - `segmentation_trust=MEDIUM`
  - `negative_dt_count=0`
  - `zero_dt_count=0`
- New metrics present per file:
  - `dt_mean_s`, `dt_std_s`, `dt_cv`, `dt_median_s`, `dt_q90_s`, `dt_q99_s`, `dt_max_s`
  - `pause_gap_count`, `pause_gap_fraction`
  - `time_blocker_reason` (empty for this dataset)

Interpretation: the patch distinguishes benign pause-gap nonuniformity from corruption on this real dataset.

## Validation verdict

- Patch behavior matches Stage 2 and Stage 2.1 policy intent:
  - Pause-gap-only warning path is active.
  - Corruption path is not triggered.
  - Segmentation trust is downgraded to `MEDIUM` (not failed).
  - Advanced analysis remains blocked at this stage by policy and product completeness gates.

## Stage 2.3 verdicts

- `MT_TIME_AXIS_PATCH_VALIDATED=YES`
- `MT_TIME_AXIS_CORRUPTION_PRESENT=NO`
- `MT_TIME_AXIS_PAUSE_GAPS_PRESENT=YES`
- `MT_TIME_AXIS_SEGMENTATION_RISK_PRESENT=NO`
- `MT_SEGMENTATION_TRUST_LEVEL=MEDIUM`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`
