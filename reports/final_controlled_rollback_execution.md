# Final controlled rollback execution

## Authority

Execution followed **`tables/manual_review_resolution.csv`** only: rows with **`FINAL_RESOLUTION = REVERT`**. No new classification was performed.

## Files reverted in this step (23)

All paths were restored with **`git restore --staged --worktree --source=HEAD`** at commit **`e1506a4955eaf9d29354e3990a6459db6b472fa1`** (**`HEAD`** / **`main`**).

1. `Switching ver12/plots/plotSwitchingPanelF.m`
2. `Switching/analysis/analyze_phi_kappa_canonical_space.m`
3. `Switching/analysis/debug_fix_o2_pipeline.m`
4. `Switching/analysis/experimental/run_switching_physical_baseline_model.m`
5. `Switching/analysis/experimental/run_switching_raw_baseline_correction_and_comparison.m`
6. `Switching/analysis/run_alpha_observable_search.m`
7. `Switching/analysis/run_alpha_physical_validity_test.m`
8. `Switching/analysis/run_kappa2_opening_test.m`
9. `Switching/analysis/run_kappa2_operational_signature_test.m`
10. `Switching/analysis/run_minimal_canonical.m`
11. `Switching/analysis/run_parameter_robustness_switching_canonical.m`
12. `Switching/analysis/run_phi1_observable_phi2_driver_test.m`
13. `Switching/analysis/run_phi1_phi2_observable_closure_fixed.m`
14. `Switching/analysis/run_phi1_phi2_observable_closure_test.m`
15. `Switching/analysis/run_phi2_deformation_structure_test.m`
16. `Switching/analysis/run_phi2_extended_deformation_basis_test.m`
17. `Switching/analysis/run_phi2_kappa2_canonical_residual_mode.m`
18. `Switching/analysis/run_phi2_second_order_deformation_test.m`
19. `Switching/analysis/run_phi2_shape_physics_test.m`
20. `Switching/analysis/run_width_interaction_closure_test_v2.m`
21. `Switching/analysis/switching_a1_vs_curvature_test.m`
22. `Switching/analysis/switching_full_scaling_collapse.m`
23. `Switching/analysis/switching_ridge_susceptibility_test.m`

**Result:** **`git`** exit code **0**; **`FILES_FAILED = 0`**. Each target matches the tree at **`HEAD`** (no remaining diff for these paths).

## DEFER_PRESERVE files: not touched

**21** rows marked **DEFER_PRESERVE** in **`manual_review_resolution.csv`** were **not** passed to **`git restore`**. No docs, deferred tables, **`runtime_execution_markers_fallback.txt`**, non-wrapper **tools**, or bulk-deletion aggregate were modified by this step.

## Previously reverted files (partial rollback): not re-touched

The five paths from **`tables/rollback_execution_log.csv`** (Relaxation / PT–relaxation scripts) were **not** included in this command line and were **not** re-touched. They do not appear in the **REVERT** set of **`manual_review_resolution.csv`** (disjoint sets).

## Failures

**None** for the 23 targeted files.

## Remaining preserved items (outside this rollback)

- **DEFER_PRESERVE (21)** per **`manual_review_resolution.csv`** — still deferred (governance, tooling audit, bulk retention).
- **Other modified/untracked paths** elsewhere in the repo (if any) were **not** part of this execution; **`SYSTEM_STATE_AFTER_FINAL_ROLLBACK = CLEANED_SCOPE`** refers to completion of **this** approved **REVERT** batch only, not an entire clean working tree.

## Traceability

- **`tables/final_rollback_execution_log.csv`**
- **`tables/final_rollback_execution_status.csv`**
