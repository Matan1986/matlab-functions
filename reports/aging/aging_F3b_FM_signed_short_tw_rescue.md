# Aging F3b FM signed short-tw rescue and sign-convention audit

## Scope and constraints
- Aging only.
- No tau extraction and no tau fitting.
- No AFM/FM tau comparison.
- No cross-module analysis and no mechanism claims.

## Inputs used
- `aggregate_structured_export_aging_Tp_tw_2026_04_26_085033/tables/observable_matrix.csv`
- `aging_observable_dataset_sidecar.csv`
- `aging_F1b_FM_signed_direct_TrackB_export.csv`

## Core findings
- Short-tw finite signed FM rows exist in direct Track B source (`FM_step_mag`) for core Tp rows.
- Short-tw rows were previously excluded from F1b signed contract export.
- Exclusion is not caused by sign-convention reversal; finite row inclusion is invariant under a global sign flip.
- Global convention selected: `FM_signed_direct_TrackB_sign_aligned = FM_step_mag` (`left_minus_right`).
- No per-row sign flipping used and no absolute-value signed replacement used.

## Revised FM tw-domain gate
- FM eligible Tp count after rescue (scope-allowed Tp): 4
- FM has sufficient tw for physical tau after rescue: YES
- Ready to build FM physical tau replay: YES
- Ready to compare AFM tau vs FM tau: NO

## Required verdicts
- F3B_FM_SIGNED_SHORT_TW_AUDIT_COMPLETED = YES
- SHORT_TW_FM_ROWS_FOUND = YES
- SHORT_TW_FM_ROWS_PREVIOUSLY_EXCLUDED = YES
- EXCLUSION_DUE_TO_SIGN_CONVENTION = NO
- GLOBAL_SIGN_CONVENTION_CORRECTION_VALID = YES
- PER_ROW_SIGN_FLIPPING_USED = NO
- FM_ABS_USED_AS_SIGNED_REPLACEMENT = NO
- FM_SIGN_ALIGNED_CHANNEL_DEFINED = YES
- FM_SIGN_ALIGNED_CHANNEL_CONTRACT_VALID = YES
- FM_HAS_SUFFICIENT_TW_FOR_PHYSICAL_TAU_AFTER_RESCUE = YES
- FM_ELIGIBLE_TP_COUNT_AFTER_RESCUE = 4
- READY_TO_BUILD_FM_PHYSICAL_TAU_REPLAY = YES
- READY_TO_COMPARE_TAU_AFM_TAU_FM = NO
- TAU_EXTRACTION_PERFORMED = NO
- TAU_FIT_PERFORMED = NO
- TRACKA_USED_AS_DIRECT_TAU_SOURCE = NO
- CROSS_MODULE_ANALYSIS_PERFORMED = NO
- NOTES = F3b concludes short-tw omission was export-contract scope, not sign-orientation rejection.
