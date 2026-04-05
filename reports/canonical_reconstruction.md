# Canonical Hermetic Reconstruction (LOTO)

## Protocol
- Strict leave-one-temperature-out reconstruction.
- PT(T_holdout) built from TRAIN_T only (PT rows + TRAIN_T S_peak interpolation).
- Phi1 built from TRAIN_T residual slices only.
- kappa1 obtained by direct projection only (no fitting, no optimization).
- Model A: PT only. Model B: PT + kappa1*Phi1.

## No Leakage Confirmation
- Holdout temperature excluded from training set in every fold.
- PT(T_holdout) does not use S(T_holdout) in construction.
- Phi1 does not use holdout data.
- No per-row fitting and no holdout normalization used for PT/Phi1 construction.

## Aggregated Results
- mean RMSE_PT: 0.0695742780954322
- mean RMSE_FULL: 0.0193655063005014
- median delta_RMSE (PT - FULL): 0.0519728585047438
- improvement_count: 14/14

## Mandatory Verdicts
PHI1_IMPROVES_RECONSTRUCTION = YES
PT_SUFFICIENT_HERMETIC = NO
DELTA_STRUCTURE_REAL = YES
FINAL_MODEL = PT_PLUS_PHI1

## Interpretation
Verdict is based only on strict LOTO out-of-sample reconstruction metrics under one fixed protocol.
