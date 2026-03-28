# R Variable Audit

Scope: repository `.m` scripts scanned for ambiguous standalone `R` usage.

## Summary

- Files scanned: 1415
- Ambiguous standalone `R` count: 1442
- Files with ambiguous standalone `R`: 180

## Ambiguous `R` Usage

| File | Classification | Standalone R occurrences | Mixes time + scalar signals |
|---|---|---:|---|
| `C:/Dev/matlab-functions/AC HC MagLab ver8/ACHC_main.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/AC HC MagLab ver8/PlotsACHC.m` | unclear | 4 | NO |
| `C:/Dev/matlab-functions/Aging old/pipeline/stage8_globalJfit_shiftGating.m` | unclear | 3 | NO |
| `C:/Dev/matlab-functions/Aging/analysis/aging_clock_ratio_analysis.m` | unclear (mixed time+aging signals) | 18 | YES |
| `C:/Dev/matlab-functions/Aging/analysis/aging_clock_ratio_lower_support_audit.m` | likely aging | 3 | NO |
| `C:/Dev/matlab-functions/Aging/analysis/aging_clock_ratio_temperature_scaling.m` | unclear (mixed time+aging signals) | 49 | YES |
| `C:/Dev/matlab-functions/Aging/analysis/aging_clock_ratio_temperature_support_audit.m` | unclear (mixed time+aging signals) | 9 | YES |
| `C:/Dev/matlab-functions/Aging/analysis/aging_log_time_scaling_test.m` | likely aging | 3 | NO |
| `C:/Dev/matlab-functions/Aging/diagnostics/auditDecompositionStability.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/Aging/diagnostics/diagnose_highT_basis_comparison.m` | likely aging | 28 | NO |
| `C:/Dev/matlab-functions/Aging/diagnostics/diagnose_linear_combo_switching.m` | likely aging | 6 | NO |
| `C:/Dev/matlab-functions/Aging/diagnostics/diagnose_mode1_separability.m` | likely aging | 2 | NO |
| `C:/Dev/matlab-functions/Aging/diagnostics/diagnose_shifted_basis_fit.m` | likely aging | 14 | NO |
| `C:/Dev/matlab-functions/Aging/diagnostics/diagnose_switching_regime_features.m` | likely aging | 18 | NO |
| `C:/Dev/matlab-functions/Aging/diagnostics/diagnose_waittime_to_current_mapping.m` | likely aging | 3 | NO |
| `C:/Dev/matlab-functions/Aging/diagnostics/tri_collapse_diagnostics.m` | unclear (mixed time+aging signals) | 9 | YES |
| `C:/Dev/matlab-functions/Aging/Main_Aging.m` | likely aging | 6 | NO |
| `C:/Dev/matlab-functions/Aging/models/analyzeAFM_FM_components.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Aging/models/fitFMstep_plus_GaussianDip.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Aging/models/reconstructSwitchingAmplitude.m` | likely aging | 16 | NO |
| `C:/Dev/matlab-functions/Aging/pipeline/runPhaseC_leaveOneOut.m` | likely aging | 29 | NO |
| `C:/Dev/matlab-functions/Aging/pipeline/stage7_reconstructSwitching.m` | unclear (mixed time+aging signals) | 15 | YES |
| `C:/Dev/matlab-functions/Aging/pipeline/stage8_globalJfit_shiftGating.m` | unclear | 3 | NO |
| `C:/Dev/matlab-functions/Aging/pipeline/stage8_plotting.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/Aging/tests/prl_validation_Jmodel.m` | likely aging | 6 | NO |
| `C:/Dev/matlab-functions/Aging/utils/dbgSummaryPhysics.m` | likely aging | 2 | NO |
| `C:/Dev/matlab-functions/Aging/utils/debugPlotGeometry.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Aging/utils/debugPlotSwitchingReconstruction.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/analysis/activation_coordinate_test.m` | unclear (mixed time+aging signals) | 7 | YES |
| `C:/Dev/matlab-functions/analysis/aging_switching_clock_bridge.m` | likely aging | 35 | NO |
| `C:/Dev/matlab-functions/analysis/ax_functional_relation_analysis.m` | unclear (mixed time+aging signals) | 4 | YES |
| `C:/Dev/matlab-functions/analysis/ax_scaling_temperature_robustness.m` | likely aging | 2 | NO |
| `C:/Dev/matlab-functions/analysis/barrier_landscape_interpretation_review.m` | unclear (mixed time+aging signals) | 2 | YES |
| `C:/Dev/matlab-functions/analysis/barrier_landscape_reconstruction.m` | unclear (mixed time+aging signals) | 1 | YES |
| `C:/Dev/matlab-functions/analysis/barrier_observable_test.m` | unclear (mixed time+aging signals) | 8 | YES |
| `C:/Dev/matlab-functions/analysis/creep_activation_scaling.m` | unclear (mixed time+aging signals) | 1 | YES |
| `C:/Dev/matlab-functions/analysis/effective_observables_catalog_run.m` | unclear (mixed time+aging signals) | 2 | YES |
| `C:/Dev/matlab-functions/analysis/helpers/resolve_R_variable.m` | unclear (mixed time+aging signals) | 3 | YES |
| `C:/Dev/matlab-functions/analysis/observable_basis_sufficiency_robustness_audit.m` | unclear (mixed time+aging signals) | 4 | YES |
| `C:/Dev/matlab-functions/analysis/observable_basis_sufficiency_test.m` | unclear (mixed time+aging signals) | 4 | YES |
| `C:/Dev/matlab-functions/analysis/observable_catalog_completion.m` | unclear (mixed time+aging signals) | 3 | YES |
| `C:/Dev/matlab-functions/analysis/observable_physics_completeness_audit.m` | unclear (mixed time+aging signals) | 4 | YES |
| `C:/Dev/matlab-functions/analysis/observable_physics_reduction.m` | unclear (mixed time+aging signals) | 4 | YES |
| `C:/Dev/matlab-functions/analysis/phase_diagram_synthesis.m` | unclear (mixed time+aging signals) | 19 | YES |
| `C:/Dev/matlab-functions/analysis/R_X_reconciliation_analysis.m` | unclear (mixed time+aging signals) | 25 | YES |
| `C:/Dev/matlab-functions/analysis/relaxation_switching_knee_comparison.m` | unclear (mixed time+aging signals) | 15 | YES |
| `C:/Dev/matlab-functions/analysis/relaxation_tau_time_window_test.m` | unclear (mixed time+aging signals) | 2 | YES |
| `C:/Dev/matlab-functions/analysis/relaxation_temperature_scaling_test.m` | unclear (mixed time+aging signals) | 5 | YES |
| `C:/Dev/matlab-functions/analysis/ridge_crossover_vs_relaxation.m` | unclear (mixed time+aging signals) | 14 | YES |
| `C:/Dev/matlab-functions/analysis/ridge_motion_relaxation_analysis.m` | unclear (mixed time+aging signals) | 11 | YES |
| `C:/Dev/matlab-functions/analysis/ridge_relaxation_comparison.m` | unclear (mixed time+aging signals) | 5 | YES |
| `C:/Dev/matlab-functions/analysis/run_agent24h_figures.m` | likely aging | 4 | NO |
| `C:/Dev/matlab-functions/analysis/run_aging_alpha_closure_agent24f.m` | unclear (mixed time+aging signals) | 38 | YES |
| `C:/Dev/matlab-functions/analysis/run_aging_hermetic_closure_agent24i.m` | unclear (mixed time+aging signals) | 22 | YES |
| `C:/Dev/matlab-functions/analysis/run_aging_kappa1_prediction_agent24d.m` | likely aging | 28 | NO |
| `C:/Dev/matlab-functions/analysis/run_aging_kappa2_agent24g.m` | unclear (mixed time+aging signals) | 33 | YES |
| `C:/Dev/matlab-functions/analysis/run_aging_prediction_agent24b.m` | unclear (mixed time+aging signals) | 28 | YES |
| `C:/Dev/matlab-functions/analysis/run_aging_R_vs_collective_state_agent23a.m` | unclear (mixed time+aging signals) | 30 | YES |
| `C:/Dev/matlab-functions/analysis/run_aging_vs_trajectory_agent23b.m` | unclear (mixed time+aging signals) | 33 | YES |
| `C:/Dev/matlab-functions/analysis/run_alpha_decomposition_agent21a.m` | unclear | 2 | NO |
| `C:/Dev/matlab-functions/analysis/run_alpha_res_cross_experiment_correlation.m` | likely aging | 6 | NO |
| `C:/Dev/matlab-functions/analysis/run_alpha_res_physics_agent21b.m` | likely relax | 9 | NO |
| `C:/Dev/matlab-functions/analysis/run_alpha_res_transition_agent22a.m` | likely relax | 4 | NO |
| `C:/Dev/matlab-functions/analysis/run_alpha_structure_agent19f.m` | likely aging | 5 | NO |
| `C:/Dev/matlab-functions/analysis/run_alternative_coordinate_search.m` | unclear (mixed time+aging signals) | 4 | YES |
| `C:/Dev/matlab-functions/analysis/run_barrier_relaxation_mechanism_closure.m` | unclear (mixed time+aging signals) | 49 | YES |
| `C:/Dev/matlab-functions/analysis/run_barrier_to_relaxation_mechanism.m` | unclear (mixed time+aging signals) | 29 | YES |
| `C:/Dev/matlab-functions/analysis/run_deformation_closure_agent19e.m` | likely aging | 5 | NO |
| `C:/Dev/matlab-functions/analysis/run_effective_collective_state_test.m` | likely relax | 4 | NO |
| `C:/Dev/matlab-functions/analysis/run_nonlinear_response_agent19h.m` | likely aging | 3 | NO |
| `C:/Dev/matlab-functions/analysis/run_R_variable_disambiguation.m` | unclear (mixed time+aging signals) | 15 | YES |
| `C:/Dev/matlab-functions/analysis/run_residual_shape_consistency.m` | likely aging | 5 | NO |
| `C:/Dev/matlab-functions/analysis/run_transition_driver_comparison.m` | unclear (mixed time+aging signals) | 16 | YES |
| `C:/Dev/matlab-functions/analysis/simple_switching_observable_search_vs_relaxation.m` | unclear (mixed time+aging signals) | 9 | YES |
| `C:/Dev/matlab-functions/analysis/switching_a1_amplitude_response_test.m` | likely aging | 4 | NO |
| `C:/Dev/matlab-functions/analysis/switching_a1_model_scan.m` | likely aging | 6 | NO |
| `C:/Dev/matlab-functions/analysis/switching_a1_vs_geometry_deformation_test.m` | likely aging | 4 | NO |
| `C:/Dev/matlab-functions/analysis/switching_a1_vs_logdS_test.m` | likely aging | 2 | NO |
| `C:/Dev/matlab-functions/analysis/switching_a1_vs_mobility_test.m` | likely aging | 5 | NO |
| `C:/Dev/matlab-functions/analysis/switching_activation_signature_test.m` | likely aging | 6 | NO |
| `C:/Dev/matlab-functions/analysis/switching_composite_observable_scan.m` | unclear (mixed time+aging signals) | 9 | YES |
| `C:/Dev/matlab-functions/analysis/switching_creep_barrier_analysis.m` | unclear (mixed time+aging signals) | 5 | YES |
| `C:/Dev/matlab-functions/analysis/switching_creep_scaling_test.m` | likely relax | 2 | NO |
| `C:/Dev/matlab-functions/analysis/switching_joule_heating_null_test.m` | unclear (mixed time+aging signals) | 18 | YES |
| `C:/Dev/matlab-functions/analysis/switching_relaxation_bridge_robustness_audit.m` | unclear (mixed time+aging signals) | 3 | YES |
| `C:/Dev/matlab-functions/analysis/switching_ridge_temperature_susceptibility_test.m` | likely aging | 2 | NO |
| `C:/Dev/matlab-functions/analysis/switching_susceptibility_ridge_motion_test.m` | unclear (mixed time+aging signals) | 2 | YES |
| `C:/Dev/matlab-functions/analysis/switching_width_dynamics_analysis.m` | unclear (mixed time+aging signals) | 6 | YES |
| `C:/Dev/matlab-functions/analysis/switching_width_relaxation_correlation.m` | unclear (mixed time+aging signals) | 5 | YES |
| `C:/Dev/matlab-functions/analysis/unified_dynamical_crossover_synthesis.m` | unclear (mixed time+aging signals) | 2 | YES |
| `C:/Dev/matlab-functions/Fitting ver1/fit_script_sin3_with_amp_force.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Fitting ver1/fit_script_sin4.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Fitting ver1/fit_script_sin5.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Fitting ver1/fit_script_ver_sinN.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/General ver2/appearanceControl/CtrlGUI/name2rgb.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/github_repo/cmocean/cmocean.m` | likely aging | 39 | NO |
| `C:/Dev/matlab-functions/GUIs/tests/legacy/refLineGUI.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Relaxation ver3/diagnostics/compare_relaxation_models.m` | likely relax | 2 | NO |
| `C:/Dev/matlab-functions/Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m` | unclear (mixed time+aging signals) | 8 | YES |
| `C:/Dev/matlab-functions/Relaxation ver3/diagnostics/run_relaxation_observable_stability_audit.m` | unclear (mixed time+aging signals) | 29 | YES |
| `C:/Dev/matlab-functions/Relaxation ver3/diagnostics/run_relaxation_time_mode_analysis.m` | unclear (mixed time+aging signals) | 3 | YES |
| `C:/Dev/matlab-functions/Relaxation ver3/diagnostics/run_relaxation_timelaw_observables.m` | unclear (mixed time+aging signals) | 3 | YES |
| `C:/Dev/matlab-functions/Relaxation ver3/fitStretchedExp.m` | unclear | 2 | NO |
| `C:/Dev/matlab-functions/Relaxation ver3/plotRelaxationParamsVsTemp.m` | likely relax | 4 | NO |
| `C:/Dev/matlab-functions/Relaxation ver3/showRelaxationFitTable.m` | likely relax | 1 | NO |
| `C:/Dev/matlab-functions/Resistivity MagLab ver1/ACHC_RH_main.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Resistivity MagLab ver1/PlotsRHC.m` | unclear | 4 | NO |
| `C:/Dev/matlab-functions/Resistivity ver6/clean_resistivity_curve_auto.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Resistivity ver6/Resistivity_main.m` | unclear | 4 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_15_210701_effective_observables_catalog/reports/effective_observables_catalog_run_script_copy.m` | unclear (mixed time+aging signals) | 2 | YES |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_25_041503_temperature_regime_analysis/run_temperature_regime_analysis.m` | likely relax | 2 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_25_235802_R_trajectory/config_snapshot.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_000112_R_trajectory/config_snapshot.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_003414_aging_prediction_pt_state_trajectory/config_snapshot.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_004501_aging_kappa1_prediction_agent24d/config_snapshot.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_005343_aging_kappa1_prediction_agent24d/config_snapshot.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_011319_aging_kappa2_closure/config_snapshot.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_011408_aging_alpha_closure_alpha_residual/config_snapshot.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_011517_aging_alpha_closure_alpha_residual/config_snapshot.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_012056_aging_alpha_closure_alpha_residual/config_snapshot.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_012433_aging_kappa2_closure/config_snapshot.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_014455_aging_hermetic_closure_agent24i/config_snapshot.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/results/cross_experiment/runs/run_2026_03_26_015008_aging_hermetic_closure_agent24i/config_snapshot.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/results/switching/runs/run_2026_03_25_203006_tail_ablation_test/config_snapshot.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/results/switching/runs/run_2026_03_25_203400_tail_ablation_test/config_snapshot.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/run_kappa2_robust_audit.m` | unclear | 3 | NO |
| `C:/Dev/matlab-functions/run_threshold_distribution_model.m` | likely aging | 6 | NO |
| `C:/Dev/matlab-functions/run_x_vs_r_predictor_comparison_wrapper.m` | likely aging | 18 | NO |
| `C:/Dev/matlab-functions/scripts/run_adversarial_observable_search.m` | likely aging | 21 | NO |
| `C:/Dev/matlab-functions/svd_projection_test.m` | likely aging | 7 | NO |
| `C:/Dev/matlab-functions/Switching ver12/computeMedianAbsP2P_fromStoredData.m` | unclear | 2 | NO |
| `C:/Dev/matlab-functions/Switching ver12/createP2PSwitching.m` | unclear | 5 | NO |
| `C:/Dev/matlab-functions/Switching ver12/createP2PSwitchingConfig.m` | unclear | 2 | NO |
| `C:/Dev/matlab-functions/Switching ver12/debugPlotBlockwisePulseDrift.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Switching ver12/debugPlotGlobalPulseDrift_blocks.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Switching ver12/debugPlotGlobalPulseDrift_TimeAxis.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Switching ver12/extractMetric_switchCh.m` | unclear | 2 | NO |
| `C:/Dev/matlab-functions/Switching ver12/main/analyzeSwitchingStability.m` | unclear | 12 | NO |
| `C:/Dev/matlab-functions/Switching ver12/main/processFilesSwitching.m` | unclear | 3 | NO |
| `C:/Dev/matlab-functions/Switching ver12/main/Switching_main.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/Switching ver12/plots/plotAmpTempSwitchingMap_switchCh.m` | unclear | 19 | NO |
| `C:/Dev/matlab-functions/Switching ver12/plots/plotFilteredCenteredSubplotsDiffConfig.m` | unclear | 3 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_aging_collapse_kappa1_kappa2.m` | likely aging | 21 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_aging_kappa_comparison.m` | likely aging | 22 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_aging_nonlinear_law_test.m` | unclear (mixed time+aging signals) | 15 | YES |
| `C:/Dev/matlab-functions/Switching/analysis/run_alpha_physical_validity_test.m` | likely aging | 4 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_collapse_failure_mode_test.m` | likely aging | 17 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_kappa2_operational_signature_test.m` | likely aging | 2 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_kappa2_physical_necessity.m` | unclear (mixed time+aging signals) | 8 | YES |
| `C:/Dev/matlab-functions/Switching/analysis/run_phi2_extended_deformation_basis_test.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_phi2_second_order_deformation_test.m` | likely aging | 27 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_phi_asymmetry_link.m` | likely aging | 8 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_phi_even_deformation_test.m` | likely aging | 15 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_phi_physical_identification.m` | likely aging | 8 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_phi_physical_structure_test.m` | likely aging | 7 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_prediction_falsification_test.m` | unclear (mixed time+aging signals) | 8 | YES |
| `C:/Dev/matlab-functions/Switching/analysis/run_pt_deformation_mode_test.m` | likely aging | 3 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_PT_kappa_relaxation_mapping.m` | likely relax | 3 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_PT_to_relaxation_mapping.m` | likely relax | 1 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_pt_width_spread_observable_analysis.m` | likely aging | 3 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_residual_decomposition_22k_failure_audit.m` | likely aging | 11 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_residual_sector_robustness.m` | likely aging | 10 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_residual_temperature_structure_test.m` | likely aging | 18 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/run_tail_ablation_test.m` | unclear (mixed time+aging signals) | 12 | YES |
| `C:/Dev/matlab-functions/Switching/analysis/run_trajectory_geometry_aging_test.m` | likely aging | 21 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/switching_alignment_audit.m` | unclear (mixed time+aging signals) | 14 | YES |
| `C:/Dev/matlab-functions/Switching/analysis/switching_energy_mapping_analysis.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/switching_mechanism_followup.m` | unclear (mixed time+aging signals) | 4 | YES |
| `C:/Dev/matlab-functions/Switching/analysis/switching_mechanism_survey.m` | likely aging | 2 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/switching_mode23_analysis.m` | likely aging | 4 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/switching_observable_basis_test.m` | likely aging | 5 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/switching_residual_decomposition_analysis.m` | likely aging | 11 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/switching_ridge_susceptibility_test.m` | likely aging | 1 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/switching_second_coordinate_duel.m` | likely aging | 4 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/switching_second_structural_observable_search.m` | likely aging | 4 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/switching_shape_rank_analysis.m` | likely aging | 9 | NO |
| `C:/Dev/matlab-functions/Switching/analysis/switching_XI_Xshape_analysis.m` | likely aging | 6 | NO |
| `C:/Dev/matlab-functions/x_necessity_and_pairing_tests.m` | likely aging | 2 | NO |
| `C:/Dev/matlab-functions/zfAMR ver11/analysis/plot_AMR_maps_one_channel.m` | unclear | 1 | NO |
| `C:/Dev/matlab-functions/zfAMR ver11/analysis/print_AMR_spectra.m` | unclear | 2 | NO |

## Notes

- This step is scan-only for ambiguity classification.
- No physics/computation logic was modified by the audit pass.