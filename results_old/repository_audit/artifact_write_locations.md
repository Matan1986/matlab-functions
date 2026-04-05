# Artifact Write Locations Audit

Date: 2026-03-09

## Scope

This audit scans tracked MATLAB files in the active experiment areas and shared analysis layer:

- `Aging/`
- `Relaxation ver3/`
- `Switching/`
- `analysis/`

The scan looked for direct artifact-writing APIs including:

- figure writes: `saveas`, `savefig`, `exportgraphics`
- table writes: `writetable`, `writematrix`, `writecell`
- report writes: `fopen(...,'w'/'a')` plus paired `fprintf(fid, ...)`

## Notes

- This is an audit only. No scripts were modified.
- The new standardized helpers already exist in `tools/save_run_figure.m`, `tools/save_run_table.m`, and `tools/save_run_report.m`.
- Expected run-system internals were not treated as migration targets in the lists below. Excluded examples include `Aging/utils/createRunContext.m` and debug/logging utilities under `Aging/utils/`.
- Read-only file access such as `fopen(...,'r')` was excluded.

## Summary

- Figure-writing scripts found: 43
- Table-writing scripts found: 38
- Report-writing scripts listed below: 19 direct writers after excluding read-only and run-system internals
- Separate review ZIP writers were also detected, but ZIP output was not the primary target of this audit

## Scripts Writing Figures Directly

### Aging

- `Aging/analysis/aging_geometry_visualization.m` using `saveas` for multiple PNG outputs
- `Aging/analysis/debugAgingStage4.m` using `saveas`
- `Aging/diagnostics/auditDecompositionStability.m` using `saveas`
- `Aging/diagnostics/diagnose_FM_construction_audit.m` using `saveas`
- `Aging/diagnostics/diagnose_FM_sign_stability.m` using `saveas`
- `Aging/diagnostics/diagnose_baseline_subtracted_FM.m` using `saveas`
- `Aging/diagnostics/diagnose_decomposition_audit_waittimes.m` using `saveas`
- `Aging/diagnostics/diagnose_decomposition_audit_waittimes_clean.m` using `saveas`
- `Aging/diagnostics/diagnose_deltaM_shifted_byTp_waittimes.m` using `saveas`
- `Aging/diagnostics/diagnose_deltaM_svd_pca.m` using `saveas`
- `Aging/diagnostics/diagnose_fit_vs_derivative_audit.m` using `saveas`
- `Aging/diagnostics/diagnose_highT_basis_comparison.m` using `saveas`
- `Aging/diagnostics/diagnose_linear_combo_switching.m` using `saveas`
- `Aging/diagnostics/diagnose_mode1_separability.m` using `saveas`
- `Aging/diagnostics/diagnose_shifted_basis_fit.m` using `saveas`
- `Aging/diagnostics/diagnose_switching_regime_features.m` using `saveas`
- `Aging/diagnostics/diagnose_waittime_to_current_mapping.m` using `saveas`
- `Aging/models/analyzeAFM_FM_derivative.m` using `saveas`
- `Aging/pipeline/runPhaseC_leaveOneOut.m` using `saveas`
- `Aging/pipeline/stage9_export.m` using `savefig`
- `Aging/verification/verifyRobustBaseline_RealData.m` using `saveas`
- `Aging/verification/verifyRobustBaseline_RealData_Main.m` using `saveas`

### Relaxation

- `Relaxation ver3/aging_geometry_visualization.m` using `saveas`
- `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m` using `saveas`
- `Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m` using `saveas`
- `Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m` using `saveas`
- `Relaxation ver3/diagnostics/survey_relaxation_observables.m` using `saveas`
- `Relaxation ver3/diagnostics/validate_relaxation_band_boundaries.m` using `saveas`
- `Relaxation ver3/diagnostics/visualize_relaxation_band_maps.m` using `saveas`
- `Relaxation ver3/diagnostics/visualize_relaxation_geometry.m` using `saveas`

### Switching

- `Switching/analysis/switching_XI_Xshape_analysis.m` using `saveas`
- `Switching/analysis/switching_alignment_audit.m` using `saveas` extensively
- `Switching/analysis/switching_mechanism_followup.m` using `saveas`
- `Switching/analysis/switching_mechanism_survey.m` using `saveas`
- `Switching/analysis/switching_mode23_analysis.m` using `saveas`
- `Switching/analysis/switching_observable_basis_test.m` using `saveas`
- `Switching/analysis/switching_observable_stability_survey.m` using `saveas`
- `Switching/analysis/switching_second_coordinate_duel.m` using `saveas`
- `Switching/analysis/switching_second_structural_observable_search.m` using `saveas`
- `Switching/analysis/switching_shape_rank_analysis.m` using `saveas`

### Cross-experiment analysis

- `analysis/cross_experiment_observables.m` using `saveas`
- `analysis/switching_observable_summary.m` using `saveas`

## Scripts Writing Tables Directly

### Aging

- `Aging/analysis/debugAgingStage4.m` using `writetable`
- `Aging/diagnostics/auditDecompositionStability.m` using `writetable`
- `Aging/diagnostics/diagnose_FM_construction_audit.m` using `writetable`
- `Aging/diagnostics/diagnose_FM_sign_stability.m` using `writetable`
- `Aging/diagnostics/diagnose_baseline_subtracted_FM.m` using `writetable`
- `Aging/diagnostics/diagnose_decomposition_audit_waittimes.m` using `writetable`
- `Aging/diagnostics/diagnose_deltaM_svd_pca.m` using `writetable`
- `Aging/diagnostics/diagnose_fit_vs_derivative_audit.m` using `writetable`
- `Aging/diagnostics/diagnose_highT_basis_comparison.m` using `writetable`
- `Aging/diagnostics/diagnose_linear_combo_switching.m` using `writetable`
- `Aging/diagnostics/diagnose_mode1_separability.m` using `writetable`
- `Aging/diagnostics/diagnose_shifted_basis_fit.m` using `writetable`
- `Aging/diagnostics/diagnose_switching_regime_features.m` using `writetable`
- `Aging/diagnostics/diagnose_waittime_to_current_mapping.m` using `writetable`
- `Aging/pipeline/runPhaseC_leaveOneOut.m` using `writetable`
- `Aging/pipeline/stage9_export.m` using `writetable`
- `Aging/pipeline/stageC2_sweepDipWindow.m` using `writetable`
- `Aging/verification/verifyRobustBaseline_RealData.m` using `writetable`

### Relaxation

- `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m` using `writetable` and `writematrix`
- `Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m` using `writetable`
- `Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m` using `writetable`
- `Relaxation ver3/diagnostics/survey_relaxation_observables.m` using `writetable`
- `Relaxation ver3/diagnostics/validate_relaxation_band_boundaries.m` using `writetable`
- `Relaxation ver3/diagnostics/visualize_relaxation_band_maps.m` using `writetable`
- `Relaxation ver3/diagnostics/visualize_relaxation_geometry.m` using `writetable`
- `Relaxation ver3/showRelaxationFitTable.m` using `writetable`

### Switching

- `Switching/analysis/switching_XI_Xshape_analysis.m` using `writetable`
- `Switching/analysis/switching_alignment_audit.m` using `writetable`
- `Switching/analysis/switching_mechanism_followup.m` using `writetable`
- `Switching/analysis/switching_mechanism_survey.m` using `writetable`
- `Switching/analysis/switching_mode23_analysis.m` using `writetable`
- `Switching/analysis/switching_observable_basis_test.m` using `writetable`
- `Switching/analysis/switching_observable_stability_survey.m` using `writetable`
- `Switching/analysis/switching_second_coordinate_duel.m` using `writetable`
- `Switching/analysis/switching_second_structural_observable_search.m` using `writetable`
- `Switching/analysis/switching_shape_rank_analysis.m` using `writetable`

### Cross-experiment analysis

- `analysis/cross_experiment_observables.m` using `writetable`
- `analysis/switching_observable_summary.m` using `writetable`

## Scripts Writing Reports Directly

### Aging

- `Aging/analysis/aging_geometry_visualization.m` using `fopen(reportPath, 'w')`
- `Aging/analysis/debugAgingStage4.m` using `fopen(logPath, 'w')`
- `Aging/diagnostics/diagnose_deltaM_svd_pca.m` using `fopen(filePath, 'w')`
- `Aging/diagnostics/diagnose_mode1_separability.m` using `fopen(filePath, 'w')`
- `Aging/pipeline/stage7_reconstructSwitching.m` using `fopen(logPath, 'a')`
- `Aging/verification/verifyRobustBaseline_RealData.m` using `fopen(filename, 'w')`
- `Aging/verification/verifyRobustBaseline_WithLogging.m` using `fopen(logfile, 'w')`

### Relaxation

- `Relaxation ver3/aging_geometry_visualization.m` using `fopen(reportPath, 'w')`
- `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m` using `fopen(mdPath, 'w')`
- `Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m` using `fopen(path, 'w')`

### Switching

- `Switching/analysis/switching_XI_Xshape_analysis.m` using `fopen(reportOut, 'w')`
- `Switching/analysis/switching_alignment_audit.m` using `fopen(latestPtr, 'w')`
- `Switching/analysis/switching_mechanism_followup.m` using `fopen(reportOut, 'w')`
- `Switching/analysis/switching_mechanism_survey.m` using `fopen(reportOut, 'w')`
- `Switching/analysis/switching_mode23_analysis.m` using `fopen(reportOut, 'w')`
- `Switching/analysis/switching_observable_basis_test.m` using `fopen(repOut, 'w')`
- `Switching/analysis/switching_second_coordinate_duel.m` using `fopen(repOut, 'w')`
- `Switching/analysis/switching_second_structural_observable_search.m` using `fopen(repOut, 'w')`
- `Switching/analysis/switching_shape_rank_analysis.m` using `fopen(repOut, 'w')`

## Separate Review ZIP Writers Detected

These are not part of the requested figure/table/report lists, but they are relevant for later migration to any standardized review-bundle helper:

- `Aging/analysis/aging_geometry_visualization.m`
- `Relaxation ver3/aging_geometry_visualization.m`
- `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m`
- `Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m`
- `Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m`
- `Relaxation ver3/diagnostics/validate_relaxation_band_boundaries.m`
- `Relaxation ver3/diagnostics/visualize_relaxation_band_maps.m`
- `Switching/analysis/switching_mechanism_followup.m`
- `Switching/analysis/switching_mechanism_survey.m`
- `Switching/analysis/switching_observable_basis_test.m`
- `Switching/analysis/switching_second_coordinate_duel.m`
- `Switching/analysis/switching_second_structural_observable_search.m`
- `Switching/analysis/switching_shape_rank_analysis.m`

## Recommended Migration Order

1. Migrate high-volume figure writers first: `Switching/analysis/switching_alignment_audit.m`, the Relaxation diagnostics, and `Aging/analysis/aging_geometry_visualization.m`.
2. Migrate table-heavy diagnostics next, especially the Relaxation diagnostics and Switching analysis scripts that already write CSV outputs in run directories.
3. Replace direct report creation with `tools/save_run_report.m` in the scripts listed above, while leaving run-system metadata writers untouched.
