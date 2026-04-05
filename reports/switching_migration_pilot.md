# Switching Migration Pilot

## Scope
- Agent type: NARROW (pilot migration validation)
- Dataset scope: exactly one canonical switching dataset
- Canonical source target: run_2026_03_10_112659_alignment_audit
- Hard constraints honored: no logic modifications, no parameter changes, no scope expansion

## Execution Attempt
- Wrapper used: tools/run_matlab_safe.bat
- Runnable script prepared and validated to wrapper contract (ASCII/header/pure-script/run-context checks passed).
- MATLAB execution result from wrapper: timeout at 300 seconds (MATLAB exit code 124).
- Wrapper diagnostic included fallback run-directory discovery warning.

## Required Comparison Outputs
Because the NEW-system run did not complete, the requested NEW vs OLD quantitative comparisons could not be computed:
- correlation(S_new, S_old): not available
- RMSE map: not available
- phi1 cosine/shape: not available
- kappa1 correlation/scaling: not available
- reconstruction delta-RMSE consistency: not available

Execution did not complete - no physics verdict is valid.

## Mandatory Verdicts
- MAP_PRESERVED = INVALID
- PHI1_PRESERVED = INVALID
- KAPPA1_PRESERVED = INVALID
- RECONSTRUCTION_PRESERVED = INVALID

- PHYSICS_PRESERVED = INVALID

## Decision
PHYSICS_PRESERVED = INVALID

Reason: blocked NEW-system runtime (wrapper timeout) prevented a completed controlled pilot comparison.
