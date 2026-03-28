# Phi2 extended deformation basis test (reuse mode)

## Inputs
- CSV path: `C:\Dev\matlab-functions\tables\phi2_extended_deformation_basis.csv`

## Best models
- Best single basis (n_basis=1): dPhi1_dx (cosine=0.3834, rmse=0.0618173, rel_rmse=0.062841)
- Best 2-basis model (n_basis=2): x_times_Phi1 + x2_times_Phi1 (cosine=0.6570, rmse=0.0504579, rel_rmse=0.0512934)
- Best 3-basis model (n_basis=3): d2Phi1_dx2 + x_times_Phi1 + x2_times_Phi1 (cosine=0.6631, rmse=0.0501038, rel_rmse=0.0509335)
- Best 4-basis model (n_basis=4): dPhi1_dx + d2Phi1_dx2 + x_times_Phi1 + x2_times_Phi1 (cosine=0.6669, rmse=0.0498745, rel_rmse=0.0507004)

## Best overall model
- Model: dPhi1_dx + d2Phi1_dx2 + x_times_Phi1 + x2_times_Phi1 (cosine=0.6669, rmse=0.0498745, rel_rmse=0.0507004)

## Comparison to previous 2-basis result
- Previous best rmse reference: 0.0057
- Current best rmse: 0.0498745
- EXTENDED_BASIS_IMPROVES (best_rmse < prev_best_rmse): NO

## Verdicts
- EXTENDED_BASIS_IMPROVES: NO
- PHI2_HIGHER_ORDER_DEFORMATION: NO
- PHI2_IRREDUCIBLE_BEYOND_DEFORMATION: YES

EXTENDED_BASIS_IMPROVES: NO
PHI2_HIGHER_ORDER_DEFORMATION: NO
PHI2_IRREDUCIBLE_BEYOND_DEFORMATION: YES

