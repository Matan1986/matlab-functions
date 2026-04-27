# Aging F4B FM physical tau replay

## Scope and constraints
- FM-side only: `tau_FM_physical_canon_replay`.
- Input signal only: `FM_signed_direct_TrackB_sign_aligned` from `FM_step_mag` basis.
- No AFM tau modification and no AFM/FM tau comparison.
- No Track A direct tau source and no absolute-value signed replacement.
- No cross-module analysis and no global mechanism claims.

## Input domain
- Domain restricted to F3b gate rows with `eligible_min3=YES` and `tp_scope_allowed_for_physical_tau=YES`.
- Eligible Tp values used: 18, 22, 26, 30
- Per-Tp minimum finite tw points for fitting: 3.

## Model families used
- Primary physical candidate: single exponential approach/saturation vs tw.
- Non-primary diagnostic context: log10(tw) linear model.

## Selection policy
- tau selected only when primary model passes quality gates.
- Quality gate: r2 >= 0.600, finite positive tau, and tw support >= 3.
- Failed Tp rows are recorded with explicit failure reasons.

## Outcome summary
- Selected Tp count: 3
- Failed Tp count: 1
- FM_TAU_MODEL_QUALITY_SUFFICIENT = PARTIAL

## Required verdicts
- F4B_FM_PHYSICAL_TAU_REPLAY_COMPLETED = YES
- FM_INPUT_DOMAIN_MATCHES_F3B_GATE = YES
- FM_TAU_FIT_PERFORMED = YES
- FM_TAU_PHYSICAL_VALUES_SELECTED = YES
- FM_TAU_SELECTED_TP_COUNT = 3
- FM_TAU_FAILED_TP_COUNT = 1
- FM_TAU_MODEL_QUALITY_SUFFICIENT = PARTIAL
- AFM_TAU_MODIFIED = NO
- AFM_FM_TAU_COMPARISON_PERFORMED = NO
- FM_ABS_USED_AS_SIGNED_REPLACEMENT = NO
- PER_ROW_SIGN_FLIPPING_USED = NO
- TAU_PROXY_AS_PHYSICAL_TAU_USED = NO
- TRACKA_USED_AS_DIRECT_TAU_SOURCE = NO
- CROSS_MODULE_ANALYSIS_PERFORMED = NO
- GLOBAL_AGING_MECHANISM_CLAIMED = NO
- NOTES = FM-only replay built on F3b sign-aligned direct TrackB signed channel; no AFM changes and no AFM/FM comparison performed.
