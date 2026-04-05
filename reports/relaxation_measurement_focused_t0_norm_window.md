# Relaxation Measurement Focused Audit: t0 + normalization + window

## Objective
Can relaxation measurement be stabilized by a clean choice of t0 + normalization + window?

## Raw Input
- script: `C:\Dev\matlab-functions\run_relaxation_measurement_focused_t0_norm_window.m`
- dataDir: `L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM`
- trace_count: 19
- run_dir: `C:\Dev\matlab-functions\results\relaxation\runs\run_2026_03_29_232553_relaxation_measurement_focused_t0_norm_w`

## Exact Tested Variant Grid
- t0: earliest_valid_start, post_settling_start_10pct, conservative_delayed_start_20pct
- normalization: none, initial_amplitude_y_over_y0, tail_referenced_contrast
- window: full_usable_window, early_heavy_70pct, conservative_late_trimmed_85pct
- combinations tested: 27

## Stability Ranking (Top 8)
- rank 1: combo_01 | t0=earliest_valid_start | norm=none | window=full_usable_window | stable=true | score=0.00000 | corr_med=1.0000 | nrmse_med=0.0000 | nrmse_worst=0.0000 | slope_med=1.0000
- rank 2: combo_03 | t0=earliest_valid_start | norm=none | window=conservative_late_trimmed_85pct | stable=true | score=0.17667 | corr_med=1.0000 | nrmse_med=0.0000 | nrmse_worst=0.0000 | slope_med=1.0000
- rank 3: combo_02 | t0=earliest_valid_start | norm=none | window=early_heavy_70pct | stable=false | score=0.42844 | corr_med=1.0000 | nrmse_med=0.0000 | nrmse_worst=0.0000 | slope_med=1.0000
- rank 4: combo_19 | t0=conservative_delayed_start_20pct | norm=none | window=full_usable_window | stable=false | score=3.51164 | corr_med=0.5291 | nrmse_med=0.5618 | nrmse_worst=0.6451 | slope_med=0.0159
- rank 5: combo_21 | t0=conservative_delayed_start_20pct | norm=none | window=conservative_late_trimmed_85pct | stable=false | score=3.54132 | corr_med=0.5033 | nrmse_med=0.5682 | nrmse_worst=0.6553 | slope_med=0.0286
- rank 6: combo_20 | t0=conservative_delayed_start_20pct | norm=none | window=early_heavy_70pct | stable=false | score=3.60169 | corr_med=0.4596 | nrmse_med=0.5763 | nrmse_worst=0.6674 | slope_med=0.0321
- rank 7: combo_10 | t0=post_settling_start_10pct | norm=none | window=full_usable_window | stable=false | score=4.60525 | corr_med=0.3921 | nrmse_med=0.5375 | nrmse_worst=0.5980 | slope_med=0.0539
- rank 8: combo_12 | t0=post_settling_start_10pct | norm=none | window=conservative_late_trimmed_85pct | stable=false | score=4.68772 | corr_med=0.3438 | nrmse_med=0.5434 | nrmse_worst=0.6059 | slope_med=0.0334

## Best Candidate Canonical Combination
- combination: combo_01
- t0: earliest_valid_start
- normalization: none
- window: full_usable_window
- classification: actually stable

## Verdicts
- STABLE_SUBREGION_EXISTS: true
- CANONICAL_T0_IDENTIFIED: YES
- CANONICAL_NORMALIZATION_IDENTIFIED: YES
- CANONICAL_WINDOW_IDENTIFIED: YES
- RELAXATION_MEASUREMENT_CAN_BE_STABILIZED: true
- SAFE_TO_DEFINE_NEW_CANONICAL_MEASUREMENT: true

## Recommendation
- adopt candidate
