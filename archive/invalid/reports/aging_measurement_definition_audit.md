# Aging Measurement Definition Audit

## INVALID AGING ANALYSIS
- VALID_FOR_AGING: NO
- DEFINITION_CONTAMINATION: YES
- SHOULD_BE_USED: NO
- Definition mismatch: this lineage applies relaxation measurement logic to aging, so outputs are invalid for aging interpretation and must not be used for aging conclusions.

## Scope
- Stage 0-1 integrity audit only (no PT, no kappa layers, no physics fitting).
- Observable extracted using current canonical definition: R_relax_canonical = -slope_Huber(M vs ln(tau)) on canonical fit window.

## Perturbations Applied
- t0 shifts: +/- 1*tau_min
- window: start x0.5/x1.5 and end x0.8/x1.2
- normalization: none (current), initial amplitude, tail referenced
- baseline/drift: none, tail subtraction, local detrend
- sampling/binning: downsample x2, x4, and x2 + minimal smoothing (movmedian 5)

## Interpretation Rule Outcome
- Classification: MEASUREMENT FAILURE

## Short Summary
- Dataset traces loaded: 19
- Baseline-supported traces: 0
- Global trace correlation median: NaN
- Global trace nRMSE median: NaN
- Global shape similarity median: NaN
- Global ordering consistency (Kendall tau) median: NaN
- Scalar stability across axes: NO
- Trace stability across axes: NO
- Interpretation class: MEASUREMENT FAILURE
- Ready for next stage: NO

## Verdict Block
AGING_OBSERVABLE_DEFINED=NO
AGING_OBSERVABLE_PHYSICAL=NO

AGING_T0_STABLE=NO
AGING_WINDOW_STABLE=NO
AGING_NORMALIZATION_STABLE=NO
AGING_BASELINE_STABLE=NO
AGING_SAMPLING_STABLE=NO

AGING_TRACE_STRUCTURE_STABLE=NO


