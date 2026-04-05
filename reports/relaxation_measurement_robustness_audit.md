# Relaxation Measurement Robustness Audit

## Audit Purpose
Assess whether the relaxation observable is stable under measurement-definition choices using raw traces only.

## Scripts And Inputs
- script: `C:\Dev\matlab-functions\Relaxation ver3\diagnostics\run_relaxation_measurement_robustness_audit_script.m`
- dataDir: `L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM`
- trace_count: 19
- run_dir: `C:\Dev\matlab-functions\results\relaxation\runs\run_2026_03_29_184220_relaxation_measurement_robustness_audit_01`

## Variant Definitions
- t0: earliest valid start, post-settling 10%, delayed 20%
- window: full usable, early-heavy end at 70%, late-trimmed end at 85%
- baseline: raw, tail subtraction (last 10%), tail linear detrend (last 20%)
- normalization: none, initial-amplitude, area-over-logtime
- smoothing: none, moving median 5, moving median 11

## Key Quantitative Results
- overall_median_corr: 1.0000
- overall_median_nRMSE: 0.0085
- overall_worst_nRMSE: 17.9678
- baseline_amplitude_scale: 0.0304331
- baseline_t_half_s: 454.09
- baseline_mean_log_slope: -0.0124159

## Interpretation
Axis sensitivity is declared when median nRMSE is above 0.08, worst nRMSE above 0.15, median correlation below 0.95, or median descriptor drift above 20%.

## Verdicts
- RELAXATION_MEASUREMENT_STABLE: false
- T0_SENSITIVE: true
- WINDOW_SENSITIVE: true
- BASELINE_SENSITIVE: false
- NORMALIZATION_SENSITIVE: true
- SMOOTHING_SENSITIVE: false
- RELAXATION_OBSERVABLE_PHYSICAL: false
- SAFE_TO_PROCEED_TO_PARAMETER_ROBUSTNESS: false

## Recommendation
Do not proceed to parameter robustness yet.
