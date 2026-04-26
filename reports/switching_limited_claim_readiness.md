# Limited claim-readiness review

- Canonical lock: `CANONICAL_RUN_ID=run_2026_04_03_000147_switching_canonical`
- Scope: read-only review after E5B; no modeling, reruns, or claim/context/snapshot updates performed.

## Flags
- LIMITED_CLAIM_READINESS_COMPLETED = YES
- LIMITED_CLAIMS_ALLOWED = YES
- FULL_CLOSURE_CLAIMS_BLOCKED = YES
- RANK3_DOCUMENTED_AS_OPEN_RESIDUAL = YES
- READY_FOR_LIMITED_CONTEXT_UPDATE = PARTIAL
- READY_FOR_SNAPSHOT_UPDATE = PARTIAL

## Allowed now
- Within the canonical Switching analysis, the backbone + Phi1 + Phi2 hierarchy is currently the leading-order interpretable model, reducing full-domain RMSE from 0.0642 to 0.0211 to 0.0109 and explaining 97.13% of the backbone residual variance.
- Phi1 is interpreted as a stable first residual correction consistent with the D4 `backbone_error` classification and the Stage E canonical observable mapping for kappa1.
- Phi2 is interpreted as a stable second residual correction consistent with the D4 `backbone_tail_residual` / `tail_burden_tracker` classification and is especially important in the high-rank tail region, where the rank-2 model explains 99.06% of backbone residual variance.
- This rank-2 interpretation should be stated as leading-order only, not as full closure, because a diagnostic rank-3 residual still yields 0.2530 fractional fit gain after Phi2 (p=0.0020).
- Rank-3 should be documented only as an open residual branch classified as `weak_structured_residual`: it is not promoted into the canonical model and does not yet show convincing canonical observable linkage (best |rho|=0.3912, p=0.1397).

## Blocked now
- Blocked: any statement that the canonical model is fully closed at rank-2 or that higher-order residual structure is negligible.
- Blocked: any statement that rank-3 is a resolved physical mode, an established observable-linked signal, or part of the promoted model.

## Update readiness
- Context updates may be partially opened only if they preserve the leading-order / not-full-closure boundary and explicitly document rank-3 as an open residual branch.
- Snapshot updates may be partially opened only in a caveated form that includes the same closure disclaimer; uncaveated compressed summaries remain blocked.
- Claims/context/snapshot/query files themselves remain untouched in this stage.
