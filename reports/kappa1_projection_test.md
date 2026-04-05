# Kappa1 Projection Test

## Method description (projection vs baseline)
- Intended baseline: canonical kappa1_base(T) from residual decomposition output kappa_vs_T.csv.
- Intended projection estimator: kappa1_proj(T) = <DeltaS_norm(I,T), Phi1(I)> where DeltaS_norm(I,T) = DeltaS(I,T) / ||DeltaS(I,T)|| and DeltaS = S - S_CDF.
- Scope honored in implementation: no intended change to Phi1 definition, PT source, pipeline, or data loading chain; only kappa1 extraction pathway was targeted.

## Stability assessment
- EXECUTION_VALID: NO
- RUN_COMPLETED: NO
- CORRELATION: NaN
- RMSE: NaN
- MAX_REL_DIFF: NaN

A wrapper-run runtime artifact prevented canonical extraction artifacts from being written despite script validation.

## Width/I_peak sensitivity
Could not be assessed because execution validity gate failed.

## Execution gate verdicts
- PHYSICS_PRESERVED: UNKNOWN
- KAPPA1_PROJECTION_VALID: UNKNOWN
- KAPPA1_EXTRACTION_ARTIFACT: UNKNOWN

## Notes
- Wrapper validation checks passed for the projection script.
- Wrapper reported timeout/non-artifact behavior during canonical run attempts, so outputs are emitted in mandatory failure-safe form per gate policy.
