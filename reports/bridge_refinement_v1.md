# Bridge Refinement v1

## Data Alignment
- N_T_FIT = 9
- N_I = 6

## Step 1: Nonlinear Scale Test
- poly_deg_1: RMSE=0.041127, R2=0.514675, LOOCV=0.052267
- poly_deg_2: RMSE=0.029694, R2=0.746996, LOOCV=0.044650
- poly_deg_3: RMSE=0.029382, R2=0.752282, LOOCV=0.261053
- NONLINEAR_RESCALING_SUFFICIENT = YES

## Step 2: Two-Mode Decomposition
- two_mode_linear: RMSE=0.017594, R2=0.911181, LOOCV=0.025611
- variance explained gain vs single-mode linear: 0.396506
- TWO_MODE_CLOSURE = YES

## Step 3: Residual Orthogonality
- corr(Phi1,Phi2_candidate) = -0.526321
- mean abs corr(residual(T,:),Phi2_candidate) = 0.967163
- std corr(residual(T,:),Phi2_candidate) = 0.025699
- PHI2_IS_REAL_MODE = NO

## Step 4: Final Classification
- FINAL_RELATION_TYPE = CONTINUOUS (nonlinear)

## Decision thresholds used
- NONLINEAR_RESCALING_SUFFICIENT=YES if best nonlinear LOOCV <= 0.9*linear LOOCV and R2 >= linear R2 + 0.02.
- TWO_MODE_CLOSURE=YES if two-mode LOOCV <= 0.85*linear LOOCV and R2 gain >= 0.05.
- PHI2_IS_REAL_MODE=YES if abs(corr(Phi1,Phi2)) <= 0.2 and mean abs corr >= 0.7 and std <= 0.2.
