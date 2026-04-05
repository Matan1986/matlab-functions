# Parameter Robustness Report: Switching Canonical Features

## Scope and hard constraints
- Measurement fixed: S = (high - low) / XX
- Same dataset and same temperature grid as input alignment samples
- No baseline correction and no new observables

## Variants tested
- I_peak methods: 4
- width methods: 4
- S_peak methods: 3
- collapse scaling modes: 3
- total parameter sets: 144

## Stability metrics across variants
- min corr(I_peak variants): -0.1583
- min corr(width variants): 0.3135
- min corr(S_peak variants): 0.8066
- min corr(kappa1 variants): -0.9812
- collapse RMSE ratio range (vs canonical): [0.2539, 25.3628]

## Where differences appear
- Largest differences appear in low-signal, high-temperature points where peak/half-max crossings are weakly constrained.
- Asymmetric scaling and derivative-peak definitions produce the largest deviation from canonical collapse metrics.
- Mid-range temperatures remain comparatively stable across definitions.

## Comparison plots
- figures/switching_parameter_robustness/Ipeak_method_comparison.png
- figures/switching_parameter_robustness/width_method_comparison.png
- figures/switching_parameter_robustness/Speak_method_comparison.png
- figures/switching_parameter_robustness/kappa1_method_comparison.png

## Physics verdict
- IPEAK_ROBUST=NO
- WIDTH_ROBUST=NO
- SPEAK_ROBUST=NO
- KAPPA1_ROBUST=NO
- COLLAPSE_ROBUST=NO
- PARAMETER_ROBUST=NO
- CANONICAL_DEFINITION_STABLE=NO
