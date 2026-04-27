# Aging F5 AFM/FM physical tau comparison readiness audit

## Scope
- Readiness and domain audit only.
- No mechanism validation and no global Aging mechanism claims.
- No Switching, Relaxation, or MT comparison.

## F4A/F4B status checks
- F4A_STATUS_VALID = YES
- F4B_STATUS_VALID = YES
- Proxy-as-physical and Track A direct use: asserted NO per F4A/F4B status tables.

## Shared comparison domain
- SHARED_SELECTED_TP_COUNT = 3
- Shared Tp values: 22, 26, 30
- AFM_FM_TAU_COMPARISON_ALLOWED = PARTIAL
- MAX_ALLOWED_CLAIM_LEVEL = LEVEL_2 (within-Aging only on shared Tp; not mechanism)

## Required verdicts
- F5_AFM_FM_TAU_READINESS_AUDIT_COMPLETED = YES
- F4A_STATUS_VALID = YES
- F4B_STATUS_VALID = YES
- AFM_PHYSICAL_TAU_AVAILABLE = YES
- FM_PHYSICAL_TAU_AVAILABLE = YES
- SHARED_SELECTED_TP_COUNT = 3
- AFM_FM_TAU_COMPARISON_ALLOWED = PARTIAL
- MAX_ALLOWED_CLAIM_LEVEL = LEVEL_2
- TAU_PROXY_AS_PHYSICAL_TAU_USED = NO
- TRACKA_USED_AS_DIRECT_TAU_SOURCE = NO
- CROSS_MODULE_ANALYSIS_PERFORMED = NO
- MECHANISM_VALIDATION_PERFORMED = NO
- GLOBAL_AGING_MECHANISM_CLAIMED = NO
- READY_FOR_NEXT_COMPARISON_STEP = YES
