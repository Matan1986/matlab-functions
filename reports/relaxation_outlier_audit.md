# Relaxation Outlier Audit

Script: `C:/Dev/matlab-functions/Switching/analysis/run_relaxation_outlier_audit.m`
Input relaxation: `C:/Dev/matlab-functions/tables/relaxation_full_dataset.csv`
Input outlier flags: `C:/Dev/matlab-functions/tables/relaxation_dataset_validation_status.csv`
Input kappa: `C:/Dev/matlab-functions/tables/alpha_structure.csv`
Optional switching observables: `C:/Dev/matlab-functions/results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_parameters.csv`

## Execution
- EXECUTION_STATUS: FAIL
- INPUT_FOUND: YES
- N_T: 19
- PRIOR_FLAGS_HAS_OUTLIERS: YES
- ALIGNMENT_RULE: Nearest-neighbor manual alignment by |T_relax - T_kappa| <= 1 K (tie resolves to lower T_relax).
- ALIGNMENT_N: 14
- ALIGNMENT_MEAN_DELTA_T: 1

## Step 2 (Localization)
- mean OUTLIER_SCORE inside 22-24 K: 1.1266
- mean OUTLIER_SCORE outside: 1.7014
- ratio inside/outside: 0.66215

## Step 3 (Kappa2 Correlations)







## Step 4 (Curvature)





## Step 5 (Shape Consistency)






## Final Verdicts
- OUTLIERS_LOCALIZED_AT_TRANSITION: NO
- OUTLIERS_CORRELATED_WITH_KAPPA2: NO
- OUTLIERS_HAVE_CURVATURE_SIGNATURE: NO
- OUTLIERS_FORM_CONSISTENT_SHAPE: NO
- OUTLIERS_ARE_PHYSICAL: NO
- OUTLIERS_ARE_ARTIFACT: YES

## Error Message
```
License checkout failed.
License Manager Error -15
Unable to connect to the license server.
Check that the network license manager has been started, and that the client machine can communicate with the license server.

Troubleshoot this issue by visiting:
https://www.mathworks.com/support/lme/15

Diagnostic Information:
Feature: Statistics_Toolbox
License path:
Licensing error: -15,0.

Error in matlab_runner_22900 (line 3)
eval(fileread('C:/Dev/matlab-functions/Switching/analysis/run_relaxation_outlier_audit.m'));

Error in run (line 99)
evalin('caller', strcat(script, ';'));
```
