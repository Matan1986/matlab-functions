# Aging Decomposition Map

This map is the global clarity layer for Aging decomposition families.
It is aligned to:

- [aging_decomposition_methods.csv](/C:/Dev/matlab-functions/tables/aging_decomposition_methods.csv)
- [aging_method_code_map.csv](/C:/Dev/matlab-functions/tables/aging/aging_method_code_map.csv)

| method_name | family | stage | file | affects_summary | canonical_role |
|-------------|--------|-------|------|-----------------|----------------|
| Direct smooth+residual with plateau means | DIRECT | stage4 | [stage4_analyzeAFM_FM.m](/C:/Dev/matlab-functions/Aging/pipeline/stage4_analyzeAFM_FM.m) | NO | representation |
| Direct smooth+residual with plateau means | DIRECT | stage4 | [analyzeAFM_FM_components.m](/C:/Dev/matlab-functions/Aging/models/analyzeAFM_FM_components.m) | NO | representation |
| Direct smooth+residual with plateau means | DIRECT | other | [plotAFM_FM_decomposition.m](/C:/Dev/matlab-functions/Aging/plots/plotAFM_FM_decomposition.m) | NO | representation |
| Direct smooth+residual with robust FM baseline | DIRECT | stage4 | [analyzeAFM_FM_components.m](/C:/Dev/matlab-functions/Aging/models/analyzeAFM_FM_components.m) | NO | representation |
| Direct smooth+residual with robust FM baseline | DIRECT | other | [estimateRobustBaseline_canonical.m](/C:/Dev/matlab-functions/Aging/analysis/estimateRobustBaseline_canonical.m) | NO | auxiliary |
| Direct smooth+residual with robust FM baseline | DIRECT | other | [estimateRobustBaseline.m](/C:/Dev/matlab-functions/Aging/analysis/estimateRobustBaseline.m) | NO | auxiliary |
| Direct smooth+residual with robust FM baseline | DIRECT | other | [estimateRobustBaseline.m](/C:/Dev/matlab-functions/Aging/utils/estimateRobustBaseline.m) | NO | auxiliary |
| Derivative-assisted stage4 extraction | DERIVATIVE | stage4 | [stage4_analyzeAFM_FM.m](/C:/Dev/matlab-functions/Aging/pipeline/stage4_analyzeAFM_FM.m) | NO | representation |
| Derivative-assisted stage4 extraction | DERIVATIVE | stage4 | [analyzeAFM_FM_derivative.m](/C:/Dev/matlab-functions/Aging/models/analyzeAFM_FM_derivative.m) | NO | representation |
| Tanh step + Gaussian dip fit | FIT | other | [fitFMstep_plus_GaussianDip.m](/C:/Dev/matlab-functions/Aging/models/fitFMstep_plus_GaussianDip.m) | YES | fit_model |
| Tanh step + Gaussian dip fit | FIT | stage5 | [stage5_fitFMGaussian.m](/C:/Dev/matlab-functions/Aging/pipeline/stage5_fitFMGaussian.m) | YES | fit_model |
| Tanh step + Gaussian dip fit | FIT | stage6 | [stage6_extractMetrics.m](/C:/Dev/matlab-functions/Aging/pipeline/stage6_extractMetrics.m) | YES | observable_source |
| Extrema-smoothed method | EXTREMA | stage4 | [stage4_analyzeAFM_FM.m](/C:/Dev/matlab-functions/Aging/pipeline/stage4_analyzeAFM_FM.m) | YES | representation |
| Extrema-smoothed method | EXTREMA | stage4 | [analyzeAFM_FM_extrema_smoothed.m](/C:/Dev/matlab-functions/Aging/models/analyzeAFM_FM_extrema_smoothed.m) | YES | representation |
| Extrema-smoothed method | EXTREMA | stage6 | [stage6_extractMetrics.m](/C:/Dev/matlab-functions/Aging/pipeline/stage6_extractMetrics.m) | YES | observable_source |
| Legacy mean-field + Gaussian fit | LEGACY | other | [fitAFM_FM_MeanField_and_DipGaussian.m](/C:/Dev/matlab-functions/Aging/fitAFM_FM_MeanField_and_DipGaussian.m) | NO | legacy |
| Legacy mean-field + Lorentzian fit | LEGACY | other | [fitAFM_FM_MeanField_and_DipLorentzian.m](/C:/Dev/matlab-functions/Aging/fitAFM_FM_MeanField_and_DipLorentzian.m) | NO | legacy |

Default-path note:

- The default summary source is fit-based at stage5/stage6.
- Stage4 direct/derivative decomposition remains an important representation
  and diagnostic layer, but it is not the default observable source.
