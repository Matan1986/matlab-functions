# Switching raw baseline correction report

This is an observable-definition / signal-isolation analysis.
This is not a mixed robustness test.

## Inputs
- Trace-level source: C:\Dev\matlab-functions\results\switching\runs\run_2026_03_29_014323_switching_physics_output_robustness\alignment_audit\switching_alignment_samples.csv
- Normalized comparison source: C:\Dev\matlab-functions\results\switching\runs\run_2026_03_29_014529_switching_physics_output_robustness_fast\physics_output_robustness\tables\variant_observables_xy_over_xx.csv
- Common temperatures analyzed: 16

## Baseline model
- Local baseline from non-switching windows only.
- Per-trace model: constant offset or offset plus linear slope.
- Linear fraction: 0.000
- Constant fraction: 1.000

## A. raw XY behavior
- I_peak total variation: 35
- kappa1 sign flips: 3
- collapse median score: 0.127783

## B. corrected XY behavior
- I_peak total variation: 35
- kappa1 sign flips: 3
- collapse median score: 0.0720475

## C. normalized XY/XX behavior
- I_peak total variation: 35
- kappa1 sign flips: 3
- collapse median score: 0.147041

## Final verdicts
- RAW_XY_UNSTABLE_DUE_TO_BASELINE=NO
- BASELINE_CORRECTION_IMPROVES_IPEAK=NO
- BASELINE_CORRECTION_IMPROVES_KAPPA1=NO
- BASELINE_CORRECTION_IMPROVES_COLLAPSE=YES
- CORRECTED_XY_APPROACHES_NORMALIZED_BEHAVIOR=NO
- NORMALIZED_OBSERVABLE_STILL_BEST=NO
