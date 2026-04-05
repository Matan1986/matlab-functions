# Active Dependency Audit

## Scope
- Read-only audit of active MATLAB system dependencies.
- Loader focus: `load(`, `readtable(`, `resolve_results_input_dir`, `getLatestRun`, `load_observables`.
- Comments were excluded; only executable code paths were scanned.

## Summary
| Metric | Value |
| --- | ---: |
| TOTAL_DEPENDENCIES | 251 |
| CANONICAL_USAGE | 92 |
| NON_CANONICAL_USAGE | 5 |
| UNKNOWN_USAGE | 154 |
| VIOLATIONS_FOUND | YES |

## Violations
| file_path | line_number | loader_type | run_dir | pipeline_status |
| --- | ---: | --- | --- | --- |
| Aging/analysis/aging_observable_mode_correlation.m | 37 | readtable | fullfile(repoRoot, 'results', 'aging', 'runs', 'run_legacy_svd_pca', ... | NON_CANONICAL |
| Switching/analysis/run_PT_kappa_relaxation_mapping.m | 51 | readtable | 'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing/tables/S_time_cuts_values.csv' | NON_CANONICAL |
| Switching/analysis/run_PT_kappa_relaxation_mapping.m | 52 | readtable | 'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing/tables/S_time_cuts_meta.csv' | NON_CANONICAL |
| Switching/analysis/run_PT_to_relaxation_mapping.m | 45 | readtable | 'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing/tables/S_time_cuts_values.csv' | NON_CANONICAL |
| Switching/analysis/run_PT_to_relaxation_mapping.m | 46 | readtable | 'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing/tables/S_time_cuts_meta.csv' | NON_CANONICAL |

## Unknowns
- Full unknown line-level list is in `tables/active_run_dependencies.csv` (`classification = UNKNOWN`).
| file_path | unknown_count | representative_run_dir |
| --- | ---: | --- |
| analysis/relaxation_tau_time_window_test.m | 12 | fullfile(sources.relax.legacySurveyRunDir, 'tables', 'fit_observable_stability_by_temp.csv') |
| analysis/barrier_landscape_interpretation_review.m | 10 | fullfile(source.coordinateRunDir, 'tables', 'coordinates_relaxation.csv') |
| Aging/analysis/aging_observable_identification_audit.m | 9 | fullfile(runPath, 'tables', 'DeltaM_map.csv') |
| analysis/aging_fm_switching_sector_link.m | 6 | fullfile(source.switchRunDir, 'observable_matrix.csv') |
| analysis/simple_switching_observable_search_vs_relaxation.m | 5 | fullfile(switchRunDir, 'observables.csv') |
| analysis/unified_dynamical_crossover_synthesis.m | 5 | fullfile(auditRunDir, 'tables', 'aging_observable_recommendation_table.csv') |
| analysis/relaxation_switching_knee_comparison.m | 5 | fullfile(switchRunDir, 'observable_matrix.csv') |
| tools/run_phi1_from_pt_shape_test.m | 5 | fullfile(repoRoot, 'results', 'switching', 'runs', ... |
| tools/run_phi1_curvature_generator_test.m | 5 | fullfile(repoRoot, 'results', 'switching', 'runs', ... |
| analysis/ridge_relaxation_comparison.m | 4 | fullfile(switchRunDir, 'observable_matrix.csv') |
| analysis/aging_timescale_bridge.m | 4 | fullfile(source.dipTauRunDir, 'tables', 'tau_vs_Tp.csv') |
| Switching/analysis/run_prediction_falsification_test.m | 4 | fullfile(repoRoot, 'results', 'switching', 'runs', cfg.ptRunId, 'tables', 'PT_summary.csv') |
| analysis/run_alternative_coordinate_search.m | 3 | fullfile(repoRoot, 'results', 'switching', 'runs', ... |
| analysis/run_pt_to_phi_prediction.m | 3 | fullfile(repoRoot, 'results', 'switching', 'runs', ... |
| analysis/switching_chi_shift_shape_decomposition.m | 3 | fullfile(char(switchRunDir), 'alignment_audit', 'switching_alignment_observables_vs_T.csv') |
| analysis/relaxation_aging_canonical_comparison.m | 3 | fullfile(source.agingObservableRunDir, 'tables', 'svd_mode_coefficients.csv') |
| analysis/common_dynamical_subspace_analysis.m | 3 | fullfile(source.switchRunDir,'observable_matrix.csv') |
| analysis/relaxation_switching_motion_test.m | 3 | fullfile(runDir, 'tables', 'temperature_observables.csv') |
| Switching/analysis/run_width_interaction_closure_test.m | 2 | 'C:\Dev\matlab-functions\results\switching\runs\_extract_run_2026_03_24_220314_residual_decomposition\run_2026_03_24_220314_residual_decomposition\tables\phi_shape.csv' |
| analysis/run_kappa1_pt_vs_speak_test.m | 2 | fullfile(kappaRunDir, 'tables', 'kappa_vs_T.csv') |
| analysis/run_nonlinear_response_agent19h.m | 2 | fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.alignmentRunId, ... |
| tools/tau_vs_barrier_minimal_probe.m | 2 | fullfile(repo_root, 'results', 'switching', 'runs', 'run_2026_03_25_013356_pt_robust_canonical', ... |
| run_x_vs_r_predictor_comparison_wrapper.m | 2 | fullfile(repoRoot, 'results', 'aging', 'runs', ... |
| Switching/analysis/run_parameter_robustness_switching_canonical.m | 2 | fullfile(baseFolder, 'results', 'switching', 'runs', ... |
| Switching/analysis/run_asymmetric_spread_analysis.m | 2 | fullfile(auditRunDir, 'tables', 'pt_robustness_metrics_by_variant.csv') |
| analysis/run_deformation_closure_agent19e.m | 2 | fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.alignmentRunId, ... |
| analysis/run_alpha_from_pt_agent20b.m | 2 | ptMatrixPath |
| analysis/run_alpha_with_kappa1_agent21c.m | 2 | ptMatrixPath |
| analysis/run_alpha_structure_agent19f.m | 2 | fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.alignmentRunId, ... |
| Aging/analysis/aging_observable_mode_correlation.m | 2 | fullfile(repoRoot, 'results', 'aging', 'runs', ... |
| Switching/analysis/run_PT_to_relaxation_mapping.m | 1 | 'C:/Dev/matlab-functions/results/switching/runs/run_2026_03_25_013356_pt_robust_canonical/tables/PT_matrix.csv' |
| Switching/analysis/run_residual_decomposition_22k_failure_audit.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', fullScalingRunId, ... |
| Switching/analysis/run_residual_temperature_structure_test.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', fullScalingRunId, ... |
| Switching/analysis/run_residual_rank2_audit.m | 1 | fullfile(baseRunDir, 'tables', 'residual_decomposition_sources.csv') |
| Switching/analysis/run_PT_kappa_relaxation_mapping.m | 1 | 'C:/Dev/matlab-functions/results/switching/runs/run_2026_03_25_013356_pt_robust_canonical/tables/PT_matrix.csv' |
| Switching/analysis/run_phi_pt_restricted_deformation_5_1.m | 1 | fullfile(repoRoot, 'analysis', 'knowledge', 'run_registry.csv') |
| Switching/analysis/run_phi_pt_independence_test.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', char(cfg.ptRunId), 'tables', 'PT_summary.csv') |
| analysis/knowledge/load_run_evidence.m | 1 | fullfile(repoRoot, 'analysis', 'knowledge', 'run_registry.csv') |
| Switching/analysis/run_phi_physical_identification.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', ... |
| tools/get_run_status_value.m | 1 | fullfile(runDir, 'run_status.csv') |
| tools/build_kappa2_phen_inputs.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', 'run_2026_03_25_043610_kappa_phi_temperature_structure_test', 'tables', 'residual_rank_structure_vs_T.csv') |
| Aging/analysis/aging_fm_timescale_analysis.m | 1 | tauPath |
| Aging/pipeline/runPhaseC_leaveOneOut.m | 1 | fullfile(pwd, 'results', 'baseline_resultsLOO.mat') |
| Switching/analysis/switching_geometry_diagnostics.m | 1 | fullfile(sourceRunDir, 'tables', 'switching_full_scaling_parameters.csv') |
| analysis/get_canonical_X.m | 1 | fullfile(opts.repoRoot, 'results', 'switching', 'runs', opts.runName, 'observables.csv') |
| Switching/analysis/run_switching_peak_jump_audit.m | 1 | fullfile(runsRoot, referenceScalingRunId, 'tables', 'switching_full_scaling_parameters.csv') |
| Switching/analysis/switching_full_scaling_collapse.m | 1 | fullfile(info.run_dir, 'tables', 'switching_energy_scale_collapse_metrics.csv') |
| Switching/analysis/switching_energy_mapping_analysis.m | 1 | fullfile(runDir, 'tables', 'PT_matrix.csv') |
| Switching/analysis/run_phi_even_deformation_test.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', ... |
| run_parameter_robustness_stage1_canonical.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', canonicalRunId, ... |
| run_kappa2_robust_audit.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', ... |
| analysis/relaxation_temperature_scaling_test.m | 1 | fullfile(repoRoot, 'results', 'relaxation', 'runs', ... |
| run_parameter_robustness_stage1b_width_kappa.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', canonicalRunId, ... |
| analysis/run_alpha_decomposition_agent21a.m | 1 | ptMatrixPath |
| analysis/run_effective_collective_state_test.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', ... |
| analysis/run_elastic_mode_phi_test.m | 1 | fullfile(rootDir, 'results', 'switching', 'runs', ... |
| analysis/run_phi2_reconciliation_audit.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', ... |
| analysis/run_local_shift_agent19g.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.alignmentRunId, ... |
| Switching/analysis/debug_fix_o2_pipeline.m | 1 | fullfile(runsRoot, candRunId, 'tables', 'closure_metrics_per_temperature.csv') |
| Switching/analysis/run_kappa2_physical_necessity.m | 1 | fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ... |
| Switching/analysis/run_kappa2_opening_test.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', ... |
| Switching/analysis/run_phi_asymmetry_link.m | 1 | fullfile(repoRoot, 'results', 'switching', 'runs', char(alignmentRunId), 'observables.csv') |
| analysis/query/list_all_runs.m | 1 | fullfile(repoRoot, 'analysis', 'knowledge', 'run_registry.csv') |
| analysis/query/query_system.m | 1 | fullfile(repoRoot, 'analysis', 'knowledge', 'run_registry.csv') |
| Switching/analysis/run_aging_nonlinear_law_test.m | 1 | fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ... |
| Switching/analysis/run_aging_kappa_comparison.m | 1 | fullfile(repoRoot, 'results', 'aging', 'runs', ... |
| Switching/analysis/run_alpha_physical_validity_test.m | 1 | 'C:/Dev/matlab-functions/results/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/tables/table_clock_ratio.csv' |
| Switching/analysis/run_alpha_observable_search.m | 1 | 'C:/Dev/matlab-functions/results/switching/runs/run_2026_03_10_112659_alignment_audit/switching_alignment_core_data.mat' |

## Explicit Run Identity Resolution
| run_id | example_file | line_number | pipeline_status | manifest_exists | experiment |
| --- | --- | ---: | --- | --- | --- |
| run_2026_03_10_112659_alignment_audit | Switching/analysis/run_alpha_observable_search.m | 94 | UNKNOWN | YES | switching |
| run_2026_03_12_223709_aging_timescale_extraction | tools/tau_vs_barrier_minimal_probe.m | 38 | UNKNOWN | YES | aging |
| run_2026_03_14_074613_aging_clock_ratio_analysis | Switching/analysis/run_alpha_physical_validity_test.m | 132 | UNKNOWN | YES | aging |
| run_2026_03_24_220314_residual_decomposition | Switching/analysis/run_width_interaction_closure_test.m | 28 | UNKNOWN | YES | switching |
| run_2026_03_25_013356_pt_robust_canonical | Switching/analysis/run_PT_kappa_relaxation_mapping.m | 50 | UNKNOWN | YES | switching |
| run_2026_03_25_043610_kappa_phi_temperature_structure_test | tools/build_kappa2_phen_inputs.m | 43 | UNKNOWN | YES | switching |
| run_legacy_derivative_smoothing | Switching/analysis/run_PT_kappa_relaxation_mapping.m | 51 | NON_CANONICAL | YES | relaxation |
| run_legacy_svd_pca | Aging/analysis/aging_observable_mode_correlation.m | 37 | NON_CANONICAL | YES | aging |

## Verdict
- "ACTIVE system depends only on canonical runs" = NO
- SYSTEM_CANONICAL_DEPENDENCY = NO

Note: By safety rule, any non-canonical dependency forces `SYSTEM_CANONICAL_DEPENDENCY = NO`.

