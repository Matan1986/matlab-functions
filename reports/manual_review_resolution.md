# Manual review resolution (post–partial rollback)

## Review set

All **44** rows that had **`FINAL_DECISION = MANUAL_REVIEW_REQUIRED`** in **`tables/rollback_decision_table.csv`** were evaluated. This matches **`REMAINING_FILES_FOR_REVIEW = 44`** in **`tables/rollback_execution_status.csv`** after the five-file partial rollback (which did **not** overlap this set).

**Authoritative boundary:** **`tables/canonical_boundary_truth.csv`** (16-file MATLAB closure) and **`tables/canonical_boundary_violations_truth.csv`**.

## Resolutions summary

| Resolution | Count | Role |
|------------|------:|------|
| **KEEP** | **0** | No manual-review row was judged clearly “retain as-is” without deferral—ambiguous docs and infra were **DEFER_PRESERVE** instead of **KEEP** to avoid fake certainty. |
| **REVERT** | **23** | Out-of-closure Switching code: **22** `Switching/analysis/*.m` noncanonical scripts + **`Switching ver12/plots/plotSwitchingPanelF.m`**. Intended next step: restore to **`HEAD`** (same mechanism as safe partial rollback), full-file. |
| **DEFER_PRESERVE** | **21** | Uncertain docs (4), deleted governance tables (4), **`runtime_execution_markers_fallback.txt`**, non-wrapper **tools** (11), bulk deletion aggregate (1). |

## KEEP (none)

No file received **KEEP** in this pass. Documentation and tooling that might otherwise be “kept” were assigned **DEFER_PRESERVE** where policy alignment or dependency mapping was not fully explicit (**prefer DEFER over unsafe REVERT** per task).

## REVERT (deterministic next-rollback batch candidate)

**23** files — **`RESOLUTION_CONFIDENCE = HIGH`** for **22** of them; **`Switching/analysis/run_minimal_canonical.m`** is **REVERT** with **MEDIUM** confidence (naming collision risk with canonical narrative).

**Legacy plot**

- `Switching ver12/plots/plotSwitchingPanelF.m`

**Noncanonical `Switching/analysis` scripts (22)**

- `analyze_phi_kappa_canonical_space.m`, `debug_fix_o2_pipeline.m`
- `experimental/run_switching_physical_baseline_model.m`, `experimental/run_switching_raw_baseline_correction_and_comparison.m`
- `run_alpha_observable_search.m`, `run_alpha_physical_validity_test.m`
- `run_kappa2_opening_test.m`, `run_kappa2_operational_signature_test.m`
- `run_minimal_canonical.m` (MEDIUM confidence)
- `run_parameter_robustness_switching_canonical.m`
- `run_phi1_observable_phi2_driver_test.m`, `run_phi1_phi2_observable_closure_fixed.m`, `run_phi1_phi2_observable_closure_test.m`
- `run_phi2_deformation_structure_test.m`, `run_phi2_extended_deformation_basis_test.m`, `run_phi2_kappa2_canonical_residual_mode.m`, `run_phi2_second_order_deformation_test.m`, `run_phi2_shape_physics_test.m`
- `run_width_interaction_closure_test_v2.m`
- `switching_a1_vs_curvature_test.m`, `switching_full_scaling_collapse.m`, `switching_ridge_susceptibility_test.m`

**Governance / runtime:** **`GOVERNANCE_VALUE = NONE`** for these code paths; **`RUNTIME_RISK_IF_REVERTED`** to the **canonical** `run_switching_canonical.m` pipeline is **NONE** or **LOW** (not in closure).

## DEFER_PRESERVE

- **Docs:** `docs/repo_context_infra.md`, `docs/repo_context_minimal.md`, `docs/repo_map.md`, `docs/templates/` — **HIGH** governance value for repo orientation; alignment with frozen canonical policy not fully resolved here.
- **Deleted tracked tables:** `tables/CANONICAL_ANALYSIS_COMPLETE.txt`, `tables/phi_kappa_canonical_verdict.csv`, `tables/phi_kappa_stability_canonical_status.csv`, `tables/phi_kappa_stability_canonical_summary.csv` — do **not** auto-restore from git without a retention decision (**mixed cleanup vs mistake**).
- **`tables/runtime_execution_markers_fallback.txt`** — preserves evidence of **`REPO_TABLES_FALLBACK_WRITE`** (**`canonical_boundary_violations_truth.csv`**).
- **Tools (11):** `classify_run_status.m`, `enforce_canonical_phi1_source.m`, `ensure_dir.m`, `get_run_status_value.m`, `getLatestRun.m`, `load_observables.m`, `load_run.m`, `resolve_results_input_dir.m`, `run_artifact_path.m`, `switching_canonical_control_scan.ps1`, `switching_canonical_run_closure.m` — **MEDIUM** runtime/automation risk if reverted without dependency audit.
- **Bulk row:** `tables/ (bulk: tracked legacy artifact deletions ~150+ paths)` — **HIGH** retention risk; not batch-reversible without explicit path list and policy.

## Ambiguity remaining

- **DEFER_PRESERVE (21)** items are **not** fully “closed”; they require later governance, dependency audit, or artifact recovery steps.
- **`run_minimal_canonical.m`** remains slightly ambiguous by name only; resolution still **REVERT** with **MEDIUM** confidence.

## Readiness for final rollback execution

- **Yes, for a bounded step:** the **23** **REVERT** rows can form a **deterministic** next execution batch (same pattern as partial rollback: `git restore --source=HEAD -- …`), subject to normal review of `git diff` before running.
- **No, for repo-wide “clean”:** **DEFER_PRESERVE** and **partial rollback already executed** mean the tree is **not** fully normalized until deferred items are addressed.

**`MANUAL_REVIEW_FULLY_RESOLVED = YES`** in **`tables/manual_review_resolution_status.csv`**: every manual-review row now has **KEEP / REVERT / DEFER_PRESERVE**; **`UNRESOLVED_COUNT = 0`**.

See **`tables/manual_review_resolution.csv`** for per-file **GOVERNANCE_VALUE** and **RUNTIME_RISK_IF_REVERTED**.
