# Stage E5B rank-2 claim-boundary review

- Canonical lock: `CANONICAL_RUN_ID=run_2026_04_03_000147_switching_canonical`
- Scope: read-only review of Stage E5 outputs plus Stage D4 / Stage E context.
- No producer changes, reruns, or claim updates were performed.

## Decision
- RANK2_INTERPRETABLE_MODEL_ALLOWED = YES
- RANK2_FULL_CLOSURE_CLAIM_ALLOWED = NO
- RANK3_PROMOTION_ALLOWED = NO
- RANK3_CLASSIFICATION = weak_structured_residual
- CLAIMS_ALLOWED_LIMITED = YES
- CLAIMS_BLOCKED_FULL_CLOSURE = YES
- ADDITIONAL_TEST_REQUIRED = PARTIAL
- READY_FOR_LIMITED_CLAIM_READINESS = YES

## Why rank-2 is allowed
- Rank-2 explains 97.13% of full-domain backbone residual variance and 99.06% in the high-rank window.
- Phi1 and Phi2 are stable under subset exclusion (subset minima 0.5903 and 0.7003) and already have D4/E interpretive support.
- Phi2 remains especially important in the tail/high-rank region with fractional gain 0.6375.

## Why full closure is blocked
- Diagnostic rank-3 still improves full-domain reconstruction by 0.2530 fractional gain (p=0.0020).
- But that diagnostic does not pass physical promotion tests: sigma p=0.8164, canonical observable rho/p=0.3912/0.1397, tail localization p=0.4990, smoothness p=0.2635.
- Internal consistency remains strong against producer kappa3 (rho=0.9912, p=0.0020), which supports classification as `weak_structured_residual` rather than a promoted physical mode.

## Allowed claims
- Rank-2 is the current interpretable leading-order model for the canonical Switching residual hierarchy.
- Phi1 is a stable first residual correction consistent with the D4 backbone-error classification.
- Phi2 is a stable second residual correction consistent with the D4 tail-burden interpretation.

## Blocked claims
- Do not claim full rank-2 closure or the absence of higher-order residual structure.
- Do not promote rank-3 into the interpretable model.
- Do not claim a resolved physical interpretation for rank-3.

## Minimum additional test
- Only needed if stronger-than-limited claims are desired: run one contiguous transition-band block exclusion test centered on the 28-32 K cluster and re-check diagnostic rank-3 persistence/localization.
- If that test fails, the current limited-claim boundary should stand; if it passes cleanly, a follow-up review can revisit whether the residual remains merely weakly structured.
