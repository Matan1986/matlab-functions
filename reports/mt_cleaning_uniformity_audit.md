# MT cleaning uniformity audit (Stage 3)

This audit evaluates whether the current MT cleaning branch split (`low_field_bypass` vs `cleaned`) is acceptable for the latest real-data diagnostic run and what policy/gating is needed before full canonical products.

## Scope and sources

- Run directory: `C:\Dev\matlab-functions\results\mt\runs\run_2026_04_25_224938_mt_real_data_diagnostic`
- Reviewed artifacts:
  - `tables/mt_cleaning_audit.csv`
  - `tables/mt_raw_summary.csv`
  - `tables/mt_file_inventory.csv`
  - `tables/mt_canonical_run_summary.csv`
- Reviewed code (read-only):
  - `MT ver2/clean_MT_data.m`
  - `runs/run_mt_canonical.m` (for branch labeling only)
- No MATLAB execution in this stage.

## Q1) Exact split trigger

In `clean_MT_data.m`, branch logic is:

- `ViewRAW == true` -> return raw (no cleaning).
- Else if `fieldOe < field_threshold` -> return raw (low-field bypass).
- Else -> run outlier mask/interpolation/smoothing pipeline.

For this run, `field_threshold_oe = 20000` and `unfiltered_mode = 0`.

Observed split in `mt_cleaning_audit.csv`:

- `low_field_bypass`: files 1-5 (500 Oe to 10 kOe)
- `cleaned`: files 6-11 (20 kOe to 70 kOe)

## Q2) Did cleaning alter points in this run?

No effective point removal/interpolation impact is evident in this dataset:

- For all files: `n_raw == n_clean_non_nan == n_smooth_non_nan`
- For all files: `n_masked_or_nan_after_clean = 0`

So despite branch split labels, resulting non-NaN point counts are unchanged for this run.

## Q3) Is split a comparability risk here?

For this specific run: **low immediate risk** because no points were changed.

However, preprocessing policy differs by field class, so comparability risk remains **latent**:

- Low-field files are guaranteed raw pass-through.
- High-field files are eligible for outlier masking/interpolation/smoothing.
- On noisier future runs, this can create field-dependent preprocessing bias.

## Q4) Could future data produce field-dependent bias?

Yes. Under current threshold policy, high-field curves can be algorithmically modified while low-field curves are not, which can bias cross-field derived observables when data quality degrades.

## Q5) Recommended canonical policy direction

Recommended near-term policy:

1. Keep current branch split for diagnostic continuity.
2. Expose branch split as explicit warning/gate in run summary.
3. Require evidence metrics for changed points before allowing advanced analysis.

Not recommended yet:

- Silent acceptance of split as "uniform".
- Declaring advanced readiness based on current summary-level tables.

Possible longer-term options (for future patch discussion):

- Uniform cleaning strategy for all fields.
- Dual outputs (raw and cleaned) for all fields with explicit provenance columns.
- Diagnostic mode defaulting to raw-truth exports, with cleaning as sidecar.

## Q6) Fields to strengthen in future patch

Add/strengthen in `mt_cleaning_audit.csv`:

- `points_changed_count` (actual count where cleaned differs from raw)
- `points_changed_fraction`
- `interpolated_points_count`
- `hampel_replaced_count`
- `sg_applied` (logical)
- `movingavg_applied` (logical)
- `cleaning_reason_code` (`BYPASS_LOW_FIELD`, `FULL_CLEAN`, `RAW_MODE`)

Add run-level summary fields:

- `MT_CLEANING_POLICY_BRANCH_SPLIT_PRESENT`
- `MT_CLEANING_CHANGED_POINTS_PRESENT`
- `MT_CLEANING_BRANCH_SPLIT_IS_BLOCKER`
- `MT_CLEANING_TRUST_LEVEL`

## Stage 3 verdicts

- `MT_CLEANING_UNIFORMITY_AUDIT_DONE=YES`
- `MT_CLEANING_POLICY_BRANCH_SPLIT_PRESENT=YES`
- `MT_CLEANING_CHANGED_POINTS_PRESENT=NO`
- `MT_CLEANING_BRANCH_SPLIT_IS_BLOCKER=NO`
- `MT_CLEANING_POLICY_NEEDS_PATCH=YES`
- `MT_CLEANING_TRUST_LEVEL=MEDIUM`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`

Interpretation: branch split is not a hard blocker for this exact dataset because no point-level changes were observed, but policy remains non-canonical for cross-field comparability and should be patched/gated before full canonical readiness.
