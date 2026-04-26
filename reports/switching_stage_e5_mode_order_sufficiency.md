# Stage E.5 canonical mode-order sufficiency audit

- Canonical lock: `CANONICAL_RUN_ID=run_2026_04_03_000147_switching_canonical`
- Scope: canonical Switching data only; backbone unchanged; producer outputs treated as fixed.
- Hierarchy audited: backbone, backbone + Phi1, backbone + Phi1 + Phi2, and diagnostic Phi3 from the existing level-2 residual.

## Reconstruction hierarchy
- Full-domain incremental RMSE gain: Phi1 = 0.0431, Phi2 = 0.0102, Phi3 diagnostic = 0.0028.
- Fractional gain over previous level (full domain): Phi1 = 0.6709, Phi2 = 0.4851, Phi3 diagnostic = 0.2530.
- High-rank window (`5:7`) Phi3 diagnostic fractional gain = 0.0953.

## Rank-3 diagnostic tests
- RANK3_SIGNIFICANT = PARTIAL (sigma p=0.8164, gain p=0.0020, after-phi2 mode-1 energy fraction=0.4356).
- RANK3_STABLE = PARTIAL (LOTO median |cos|=0.9987, subset min=0.3426, amplitude median corr=0.9995).
- RANK3_OBSERVABLE_LINKED = NO (best canonical-observable |rho|=0.3912, shuffled-T p=0.1397; producer-control kappa3 rho=0.9912, p=0.0020).
- Strong kappa3-diagnostic vs producer-kappa3 agreement is treated as an internal consistency control, not as an observable linkage claim.
- Tail/high-rank localization: energy fraction=0.1149 with p=0.4990; total-variation p=0.2635.

## Decision
- RANK2_RECONSTRUCTION_SUFFICIENT = PARTIAL
- HIGHER_ORDER_MODES_BLOCK_CLAIMS = PARTIAL
- READY_FOR_CLAIM_READINESS_REVIEW = NO

## Notes
- Phi1 uses the documented sign convention from the canonical collapse hierarchy audit: `pred1 = backbone - kappa1 * phi1Vec'`.
- Phi2 is re-derived from the level-1 residual and paired with the existing `kappa2(T)` amplitude, matching the current canonical hierarchy script.
- Phi3 is diagnostic only and is not promoted into the model by this audit.
