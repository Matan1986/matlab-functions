# MT time-axis warning audit (Stage 2)

## Scope and inputs

- Run directory: `C:\Dev\matlab-functions\results\mt\runs\run_2026_04_25_011031_mt_real_data_diagnostic`
- Audited files: `mt_raw_summary.csv`, `mt_file_inventory.csv`, `mt_segments.csv`, and read-only original MPMS `.DAT` files.
- No MATLAB execution in this stage.

## Q1 - trigger metric

In `runs/run_mt_canonical.m`, `time_regular_warning` is set true when:

- `nRows < 3`, or
- `dtCv > 0.05` where `dt = diff(TimeSec)`, `dtMean = mean(abs(dt))`, `dtCv = std(dt) / dtMean`.

The current threshold is strict (`0.05`). All 11 files exceed it.

## Q2 - root cause class

Observed per-file dt statistics:

- MG_119_20p54mg_10kOe_MT.dat: dt_mean=10.433 s, dt_std=2.789 s, dt_cv=0.267, neg_dt=0, zero_dt=0, gaps_gt20s=2
- MG_119_20p54mg_1kOe_MT.dat: dt_mean=10.426 s, dt_std=2.813 s, dt_cv=0.270, neg_dt=0, zero_dt=0, gaps_gt20s=2
- MG_119_20p54mg_20kOe_MT.dat: dt_mean=10.443 s, dt_std=2.793 s, dt_cv=0.267, neg_dt=0, zero_dt=0, gaps_gt20s=2
- MG_119_20p54mg_30kOe_MT.dat: dt_mean=10.479 s, dt_std=2.805 s, dt_cv=0.268, neg_dt=0, zero_dt=0, gaps_gt20s=2
- MG_119_20p54mg_3kOe_MT.dat: dt_mean=10.435 s, dt_std=2.820 s, dt_cv=0.270, neg_dt=0, zero_dt=0, gaps_gt20s=2
- MG_119_20p54mg_40kOe_MT.dat: dt_mean=10.500 s, dt_std=2.878 s, dt_cv=0.274, neg_dt=0, zero_dt=0, gaps_gt20s=2
- MG_119_20p54mg_500Oe_MT.dat: dt_mean=10.417 s, dt_std=2.776 s, dt_cv=0.267, neg_dt=0, zero_dt=0, gaps_gt20s=2
- MG_119_20p54mg_50kOe_MT.dat: dt_mean=10.598 s, dt_std=3.018 s, dt_cv=0.285, neg_dt=0, zero_dt=0, gaps_gt20s=8
- MG_119_20p54mg_5kOe_MT.dat: dt_mean=10.550 s, dt_std=3.034 s, dt_cv=0.288, neg_dt=0, zero_dt=0, gaps_gt20s=9
- MG_119_20p54mg_60kOe_MT.dat: dt_mean=10.507 s, dt_std=2.890 s, dt_cv=0.275, neg_dt=0, zero_dt=0, gaps_gt20s=2
- MG_119_20p54mg_70kOe_MT.dat: dt_mean=10.536 s, dt_std=2.881 s, dt_cv=0.273, neg_dt=0, zero_dt=0, gaps_gt20s=2

- Across files: `dt_cv` range = 0.267 to 0.288.
- `neg_dt=0` and `zero_dt=0` in all files (no timestamp reversal or duplicate-time corruption evidence).
- Large pauses (`dt > 20 s`) recur; total count across files = 35.
- Repeated ~50 s pauses appear near transition points around ~100 K and ~2 K in many files; this pattern is consistent with instrument/sequence pauses, not parse/header mismatch.
- Time stamps are absolute epoch-style seconds (`~3.95e9`) from MPMS export. Absolute scale itself is not the warning trigger; irregular spacing is.

Conclusion: warnings are primarily caused by nonuniform MPMS sampling with operational pauses (plus extra pauses in two files), not by malformed time headers or monotonicity failure.

## Q3 - segmentation danger assessment

Segmentation helper usage (`find_*_temperature_segments_MT`) uses `TimeSec` only through `Timems(2)-Timems(1)` to compute an expected temperature change scale. It does not depend on absolute epoch origin.

Risk note: because only the first dt is used, irregular dt later in the run is not explicitly modeled. This is a logic limitation, but not immediate evidence of corrupted segmentation for this dataset.

## Q4 - segment plausibility

- Segment table rows: 33 (`increasing`=22, `decreasing`=11) across all 11 files.
- Boundaries are physically plausible: increasing segments from ~2 K toward ~100 K and return-cycle segments anchored near low/high-temperature turning regions.
- No import failures and no missing segment table writes.

## Q5 - recommended runner policy

Recommended: **refine warning logic**, do not hard-block segmentation solely on current `dtCv > 0.05`.

Policy direction:

- Keep warning output (nonuniform sampling is real and should be visible).
- Split warnings into classes:
  - `TIME_NONUNIFORM_EXPECTED` (monotonic timestamps, no duplicates, pause-like gaps).
  - `TIME_CORRUPTION_RISK` (negative dt, zero-heavy duplicates, NaN bursts, severe discontinuities inconsistent with protocol).
- Only `TIME_CORRUPTION_RISK` should block segmentation by default.

## Stage 2 verdicts

- `MT_TIME_AXIS_WARNING_AUDIT_DONE=YES`
- `MT_TIME_AXIS_WARNING_CAUSE=MPMS_NONUNIFORM_SAMPLING_WITH_PAUSE_GAPS`
- `MT_TIME_AXIS_WARNING_IS_BLOCKER=NO`
- `MT_TIME_AXIS_SAFE_FOR_SEGMENTATION=YES_WITH_CAUTION`
- `MT_SEGMENTATION_TRUST_LEVEL=MEDIUM`
- `MT_RUNNER_TIME_WARNING_LOGIC_NEEDS_PATCH=YES`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`
