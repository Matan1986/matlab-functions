# MT cleaning policy diagnostics patch design (Stage 3.1)

This document defines a design-only patch plan for cleaning-policy diagnostics in `runs/run_mt_canonical.m`.
No code changes are applied in this stage.

## Objective

Make field-dependent preprocessing explicit, measurable, and gateable before full canonical MT products.

## 1) Per-file metrics to add/strengthen in `mt_cleaning_audit.csv`

Retain existing columns and add:

- `cleaning_reason_code` in `{RAW_MODE, BYPASS_LOW_FIELD, FULL_CLEAN}`
- `point_count_delta_clean` = `n_clean_non_nan - n_raw`
- `point_count_delta_smooth` = `n_smooth_non_nan - n_raw`
- `masked_points_count` (explicit mirror of current derived count)
- `masked_points_fraction`
- `points_changed_count` (point-wise changed evidence, see Section 3)
- `points_changed_fraction`
- `interp_or_fill_count` (points reconstructed by fill/interp path)
- `hampel_replaced_count` (if measurable from processing path)
- `smooth_changed_count` (where finite `M_smooth` differs from finite `M_clean` by tolerance)
- `max_abs_delta_raw_clean`
- `max_abs_delta_clean_smooth`
- `mean_abs_delta_raw_clean`
- `mean_abs_delta_clean_smooth`
- `cleaning_effect_class` in `{NONE, LOW, MEDIUM, HIGH}`
- `cleaning_policy_warning_class` in `{NONE, BRANCH_SPLIT_ONLY, CHANGED_POINTS, HIGH_EFFECT}`

If internal helper outputs do not currently expose all counts (for example Hampel replacements), mark those fields as `UNAVAILABLE` initially rather than omitting them.

## 2) Run-level fields for `mt_canonical_run_summary.csv` and report

Add:

- `MT_CLEANING_POLICY_BRANCH_SPLIT_PRESENT`
- `MT_CLEANING_CHANGED_POINTS_PRESENT`
- `MT_CLEANING_EFFECT_RISK_PRESENT`
- `MT_CLEANING_BRANCH_SPLIT_IS_BLOCKER`
- `MT_CLEANING_TRUST_LEVEL`
- `MT_CLEANING_BYPASS_FILE_COUNT`
- `MT_CLEANING_FULL_CLEAN_FILE_COUNT`
- `MT_CLEANING_CHANGED_POINTS_TOTAL`
- `MT_CLEANING_MAX_POINT_CHANGE_FRACTION`

Report section should include:

- branch counts and threshold used
- changed-point totals/fractions
- whether split is warning vs blocker
- trust label rationale

## 3) Definition of `MT_CLEANING_CHANGED_POINTS_PRESENT=YES`

Set YES if any file has one or more:

- `points_changed_count > 0`
- `masked_points_count > 0`
- `interp_or_fill_count > 0`
- `max_abs_delta_raw_clean > change_eps` (finite overlap only)

Recommended default:

- `change_eps = 0` for strict counting of exact processing differences
- optionally configurable later

If runner cannot yet compute point-wise deltas, status should be `POSSIBLY_UNRESOLVED` rather than false NO.

## 4) Branch split blocker vs warning policy

Branch split alone (`BYPASS_LOW_FIELD` + `FULL_CLEAN`) is:

- `WARNING` when changed-point evidence is zero and no high-effect signals
- `BLOCKER` when combined with changed points that create field-dependent processing asymmetry likely to impact comparability

Blocker condition template:

- split present AND (`MT_CLEANING_CHANGED_POINTS_PRESENT=YES`) AND (`MT_CLEANING_EFFECT_RISK_PRESENT=YES`)

## 5) Low-field bypass allowance in diagnostic mode

Keep low-field bypass allowed for now in diagnostic mode.

But require:

- explicit branch reporting
- explicit changed-point evidence metrics
- trust downgrade when split exists

## 6) Trust labels and assignment

Run/file trust labels: `HIGH`, `MEDIUM`, `LOW`, `FAIL`.

Suggested assignment:

- `HIGH`: no split or split with zero changed points and no effect risk
- `MEDIUM`: split present, changed points absent (current real-data expected)
- `LOW`: split present with changed points or medium/high effect
- `FAIL`: corruption-level cleaning inconsistencies or missing required diagnostics

## 7) Point-wise change computation policy

Patch should compute actual point-wise changed evidence where possible (not only non-NaN count deltas).

Minimum acceptable evidence:

- count/fraction deltas from raw to clean and clean to smooth
- max/mean absolute deviations on overlapping finite points

Count-only deltas are insufficient as final policy.

## Expected current real-data classification

- `MT_CLEANING_POLICY_BRANCH_SPLIT_PRESENT=YES`
- `MT_CLEANING_CHANGED_POINTS_PRESENT=NO` (or `POSSIBLY_UNRESOLVED` until point-wise fields land)
- `MT_CLEANING_TRUST_LEVEL=MEDIUM`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`

## Stage 3.1 verdicts

- `MT_CLEANING_POLICY_DEFINED=YES`
- `MT_CLEANING_BRANCH_SPLIT_GATE_DEFINED=YES`
- `MT_CLEANING_CHANGED_POINT_METRICS_DEFINED=YES`
- `MT_CLEANING_RUNNER_PATCH_READY=YES`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`
