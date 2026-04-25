# MT time-axis policy patch design (Stage 2.1)

This document defines a refined time-axis diagnostic policy for `runs/run_mt_canonical.m`.
It is design-only for this stage; runner code is not patched here.

## Scope

- Applies to MT diagnostic canonical runner time-axis checks only.
- Does not modify `MT ver2/` helpers.
- Keeps Stage 2 conclusion: MPMS pause-gap nonuniformity is real, but not automatically a segmentation blocker.

## 1) Per-file time-axis metrics to report

For each imported file, compute from `TimeSec`:

- `time_n_rows`
- `time_nonfinite_count` (non-finite values in `TimeSec`)
- `time_dt_count` (`n_rows - 1` after finite filtering)
- `time_dt_mean_s` (`mean(abs(dt))`)
- `time_dt_std_s` (`std(dt)`)
- `time_dt_cv` (`time_dt_std_s / time_dt_mean_s`, guarded for zero mean)
- `time_dt_min_s`
- `time_dt_median_s`
- `time_dt_q90_s`
- `time_dt_q99_s`
- `time_dt_max_s`
- `time_dt_negative_count`
- `time_dt_zero_count`
- `time_pause_gap_count` (count where `dt > pause_gap_threshold_s`)
- `time_pause_gap_fraction` (`time_pause_gap_count / time_dt_count`)
- `time_pause_gap_max_s`
- `time_quality_class` in `{OK, WARNING, RISK, BLOCKER}`
- `time_warning_class` in `{NONE, PAUSE_GAPS, NONUNIFORM, SEGMENTATION_RISK, CORRUPTION}`
- `time_blocker_reason` (empty unless BLOCKER)
- `time_segmentation_trust` in `{HIGH, MEDIUM, LOW, FAIL}`

Policy constants for first patch:

- `pause_gap_threshold_s = 20`
- `dt_cv_warn_threshold = 0.20`
- `dt_cv_risk_threshold = 0.50`
- `duplicate_dt_fraction_block = 0.10`
- `pause_gap_fraction_risk = 0.20`

These constants should be config-overridable later but have safe defaults.

## 2) Blocker criteria (must block segmentation readiness)

Per-file `BLOCKER` if any:

- `time_nonfinite_count > 0`
- `time_dt_negative_count > 0`
- `time_dt_zero_count / time_dt_count >= duplicate_dt_fraction_block`
- `time_n_rows < 3`
- File parse/import succeeded but no usable finite dt samples (`time_dt_count == 0`)
- Severe unexplained discontinuity pattern: `time_pause_gap_fraction >= pause_gap_fraction_risk` AND segmentation windows become non-interpretable (no plausible segment structure for that file)

Run-level blocker flags are YES if any file is BLOCKER.

## 3) Warning-only criteria (do not block alone)

Per-file warning conditions:

- `time_dt_cv > dt_cv_warn_threshold` with low pause-gap burden
- sparse pause gaps consistent with instrument stabilization/turnaround behavior
- isolated large gaps with otherwise monotonic, finite timeline

These map to warning class `PAUSE_GAPS` or `NONUNIFORM`.

## 4) Trust downgrade without block

Segmentation trust downgrade rules:

- `HIGH`: no warnings and no risk signals
- `MEDIUM`: warning-only nonuniform sampling or sparse pause gaps; no corruption indicators
- `LOW`: elevated segmentation risk (large pause-gap burden or high dt variance) but no hard corruption
- `FAIL`: blocker conditions present

Important: `MEDIUM` is expected for MPMS datasets with benign pause gaps.

## 5) Output field exposure plan

### `mt_raw_summary.csv`

Add per-file columns:

- `time_nonfinite_count`
- `time_dt_cv`
- `time_dt_negative_count`
- `time_dt_zero_count`
- `time_pause_gap_count`
- `time_pause_gap_fraction`
- `time_quality_class`
- `time_warning_class`
- `time_segmentation_trust`
- Keep legacy `time_regular_warning` for compatibility during transition.

### `mt_file_inventory.csv`

Add the same time diagnostics and classes, plus:

- `time_blocker_reason`

### `mt_canonical_run_summary.csv`

Keep `MT_TIME_AXIS_WARNINGS_PRESENT` (backward compatibility), and add:

- `MT_TIME_AXIS_CORRUPTION_PRESENT`
- `MT_TIME_AXIS_PAUSE_GAPS_PRESENT`
- `MT_TIME_AXIS_SEGMENTATION_RISK_PRESENT`
- `MT_TIME_AXIS_BLOCKER_PRESENT`
- `MT_SEGMENTATION_TRUST_LEVEL`

### `mt_canonical_run_report.md`

Add a dedicated section:

- counts by `time_quality_class`
- counts by `time_warning_class`
- explicit blocker/warning split
- run-level trust level and rationale

## 6) Legacy flag strategy

`MT_TIME_AXIS_WARNINGS_PRESENT` should remain for now, but treated as legacy aggregate.
It should be derived as:

- YES if any of the split warning/corruption/risk classes are present
- NO otherwise

Primary decision logic should move to the split fields:

- `MT_TIME_AXIS_CORRUPTION_PRESENT`
- `MT_TIME_AXIS_PAUSE_GAPS_PRESENT`
- `MT_TIME_AXIS_SEGMENTATION_RISK_PRESENT`

## Stage 2.1 verdicts

- `MT_TIME_AXIS_POLICY_DEFINED=YES`
- `MT_TIME_AXIS_BLOCKER_CRITERIA_DEFINED=YES`
- `MT_TIME_AXIS_WARNING_SPLIT_DEFINED=YES`
- `MT_RUNNER_PATCH_READY=YES`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`

## Patch-readiness note

Design is clear enough for a runner patch in a next step. No code changes are included in this stage by request.
