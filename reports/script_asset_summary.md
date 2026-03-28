# Script Asset Summary

## 1. Total scripts found
- Total scripts found (focused scan): 785

## 2. Scripts by category
- infrastructure: 594
- unknown: 171
- PT: 9
- kappa1: 5
- kappa2: 3
- cross-experiment: 2
- phi2: 1

## 3. Reusable candidates (MOST IMPORTANT)
Selected scripts (heuristic: SIMPLE + PARTIAL/WORKING):
- _loocv_run.m (PARTIAL)
- Aging/analysis/aging_structured_results_export_tp12.m (WORKING)
- Aging/analysis/aging_structured_results_export_tp27.m (WORKING)
- Aging/analysis/aging_structured_results_export_tp30.m (WORKING)
- Aging/analysis/estimateRobustBaseline.m (PARTIAL)
- Aging/analysis/plotDecompositionExamples.m (PARTIAL)
- Aging/analysis/quickSanityCheck.m (PARTIAL)
- Aging/analysis/runRobustnessCheck.m (PARTIAL)
- analysis/_agent24a_exec.m (WORKING)
- analysis/common_dynamical_subspace_analysis.m (WORKING)
- analysis/get_canonical_X.m (WORKING)
- analysis/knowledge/load_run_evidence.m (PARTIAL)
- analysis/query/list_all_runs.m (PARTIAL)
- analysis/query/start_query.m (PARTIAL)
- analysis/run_alpha_res_origin_test.m (WORKING)
- analysis/run_elastic_mode_phi_test.m (WORKING)
- analysis/run_kappa1_from_pt_agent20a.m (WORKING)
- repo_state_generator.m (WORKING)
- results/aging/runs/run_2026_03_09_014130_MG119_3sec/config_snapshot.m (PARTIAL)
- results/aging/runs/run_2026_03_09_124648_geometry_visualization/config_snapshot.m (PARTIAL)
- results/aging/runs/run_2026_03_09_130918_geometry_visualization/config_snapshot.m (PARTIAL)
- results/aging/runs/run_2026_03_09_140848_geometry_visualization/config_snapshot.m (PARTIAL)
- results/aging/runs/run_2026_03_09_141328_geometry_visualization/config_snapshot.m (PARTIAL)
- results/aging/runs/run_2026_03_10_112842_geometry_visualization/config_snapshot.m (PARTIAL)
- results/aging/runs/run_2026_03_10_145239_geometry_visualization/config_snapshot.m (PARTIAL)

## 4. High-risk scripts
Selected scripts (heuristic: COMPLEX or BROKEN or uses innerjoin):
- Aging/analysis/aging_geometry_visualization.m (BROKEN; MEDIUM)
- Aging/analysis/aging_observable_identification_audit.m (BROKEN; MEDIUM)
- Aging/analysis/aging_observable_mode_correlation.m (BROKEN; MEDIUM)
- analysis/barrier_landscape_interpretation_review.m (BROKEN; MEDIUM)
- analysis/barrier_landscape_reconstruction.m (BROKEN; MEDIUM)
- analysis/barrier_observable_test.m (BROKEN; MEDIUM)
- analysis/effective_observables_catalog_run.m (BROKEN; MEDIUM)
- analysis/export_deformation_closure_figs.m (BROKEN; SIMPLE)
- analysis/finalize_relaxation_aging_run.m (BROKEN; SIMPLE)
- analysis/observable_basis_sufficiency_robustness_audit.m (BROKEN; MEDIUM)
- analysis/observable_basis_sufficiency_test.m (BROKEN; MEDIUM)
- analysis/observable_catalog_completion.m (BROKEN; MEDIUM)
- analysis/observable_naming_update.m (BROKEN; COMPLEX)
- analysis/observable_physics_completeness_audit.m (BROKEN; MEDIUM)
- analysis/observable_physics_reduction.m (BROKEN; MEDIUM)
- analysis/relaxation_aging_canonical_comparison.m (BROKEN; MEDIUM)
- analysis/relaxation_switching_bridge_visualization.m (BROKEN; MEDIUM)
- analysis/relaxation_switching_knee_comparison.m (BROKEN; MEDIUM)
- analysis/relaxation_switching_motion_test.m (BROKEN; MEDIUM)
- analysis/relaxation_tau_time_window_test.m (BROKEN; MEDIUM)
- analysis/relaxation_temperature_scaling_test.m (BROKEN; MEDIUM)
- analysis/ridge_motion_relaxation_analysis.m (BROKEN; MEDIUM)
- analysis/ridge_relaxation_comparison.m (BROKEN; MEDIUM)
- analysis/run_aging_alpha_closure_agent24f.m (BROKEN; MEDIUM)
- analysis/run_aging_hermetic_closure_agent24i.m (BROKEN; COMPLEX)

## 5. Recommendations

Reuse first: the “Reusable candidates” list above.
Ignore unless actively debugging: anything marked BROKEN, and complex scripts with heavy joins.
Notes:
- status is inferred from existing results artifacts presence (reports/tables/observables and error-like files), not from executing MATLAB.
- dependencies_notes and complexity are heuristics based on early-file scans.
