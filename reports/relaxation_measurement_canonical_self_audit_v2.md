# Relaxation Canonical Self-Audit

## Scope
- Prior mathematically stable choice under test: t0=earliest_valid_start, normalization=none, window=full_usable_window.
- This self-audit checks physical meaning against raw time/field/moment traces, not only numerical stability.

## Data and Method
- script: `C:\Dev\matlab-functions\run_relaxation_measurement_canonical_self_audit.m`
- dataDir: `L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM`
- traces loaded: 19, valid analyzed: 19
- t0 audit: checks whether first sample is already in low field and whether early region includes field transition.
- normalization audit: checks whether absolute moment span carries coherent temperature structure and stable scaling.
- full-window audit: checks early transient indicators and late-tail noise relative to total relaxation span.

## Key Metrics
- p_lowH_at_first_point = 0.0000
- p_early_field_transition = 1.0000
- median_delay_to_lowH_s = 457.3610
- median_early_jump_ratio = 0.9999
- median_early_slope_ratio = 10.9280
- median_late_noise_ratio = 0.0000
- median_monotonic_fraction = 0.5242
- corr(temp, |M_start-M_tail|) = -0.0437
- scale_ratio median/IQR = 616.6467 / 422.6614

## Verdicts
- EARLIEST_T0_IS_AFTER_FIELD_REMOVAL: false
- EARLIEST_T0_CONTAINS_TRANSIENT: true
- NO_NORMALIZATION_IS_PHYSICALLY_MEANINGFUL: false
- FULL_WINDOW_IS_PHYSICALLY_VALID: false
- STABLE_CHOICE_IS_ALSO_PHYSICAL: false
- CANONICAL_CHOICE_CONFIRMED: false
- REQUIRES_REVISED_CANONICAL_DEFINITION: true

## Distinction
- Mathematical stability identifies reproducibility under perturbations.
- Physical canonical validity additionally requires that t0 maps to post-field-removal relaxation and that the selected normalization/window do not mix artifacts with physics.
