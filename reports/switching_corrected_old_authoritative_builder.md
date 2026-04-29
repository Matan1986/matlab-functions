# Switching full corrected-old authoritative builder

> **Switching namespace / evidence warning**
>
> - **NAMESPACE_ID:** CORRECTED_CANONICAL_OLD_ANALYSIS / corrected_old_authoritative (gated builder outputs listed below)
> - **EVIDENCE_STATUS:** AUTHORITATIVE_FOR_CORRECTED_OLD_PATH for the **listed tables** from this run — subject to publication and reconstruction-program gates
> - **BACKBONE_FORMULA:** PT_matrix-locked Speak·cdfRow branch per builder gates (not CANON_GEN `S_model_pt_percent`)
> - **SVD_INPUT:** per builder implementation on aligned x-grid (see builder `.m` — not edited here)
> - **COORDINATE_GRID:** x alignment from locked observables — width **alignment input only**
> - **SAFE_USE:** manuscript candidate evidence for corrected-old narrative when cited with this report + `tables/switching_corrected_old_authoritative_artifact_index.csv`
> - **UNSAFE_USE:** mixing outputs here with quarantined diagnostic PNG flows or CANON_GEN phi/kappa columns as the same evidence class
> - **NOT_MAIN_MANUSCRIPT_EVIDENCE_IF_APPLICABLE:** publication figures remain gated (`SAFE_TO_CREATE_PUBLICATION_FIGURES=PARTIAL`)
> - **Current state entrypoint:** `reports/switching_corrected_canonical_current_state.md`

- Run mode: gated authorized full builder
- Source view: `C:\Dev\matlab-functions\results\switching\runs\run_2026_04_24_233348_switching_canonical\tables\switching_canonical_source_view.csv`
- Locked observables: `C:\Dev\matlab-functions\tables\switching_corrected_old_effective_observables_locked.csv`
- Legacy PT_matrix: `results_old/switching/runs/run_2026_03_24_212033_switching_barrier_distribution_from_map/tables/PT_matrix.csv`

## Required verdicts

- CORRECTED_OLD_AUTHORITATIVE_BUILDER_IMPLEMENTED=YES
- PREVIOUS_GATES_RECHECKED=YES
- ALL_REQUIRED_GATES_PASSED=YES
- SOURCE_VIEW_USED=YES
- SOURCE_VIEW_IS_CLEAN=YES
- LOCKED_EFFECTIVE_OBSERVABLES_USED=YES
- LEGACY_PT_MATRIX_USED=YES
- OLD_AUTHORITATIVE_BRANCH_PT_ONLY=YES
- FALLBACK_USED=NO
- CANON_GEN_DIAGNOSTIC_OUTPUTS_USED=NO
- QUARANTINED_CORRECTED_OLD_ARTIFACTS_USED=NO
- OLD_FIGURES_USED_AS_DATA=NO
- BACKBONE_MAP_WRITTEN=YES
- RESIDUAL_MAP_WRITTEN=YES
- PHI1_WRITTEN=YES
- KAPPA1_WRITTEN=YES
- MODE1_RECONSTRUCTION_WRITTEN=YES
- RESIDUAL_AFTER_MODE1_WRITTEN=YES
- QUALITY_METRICS_WRITTEN=YES
- CORRECTED_OLD_AUTH_NAMESPACE_UNBLOCKED=YES
- SAFE_TO_USE_CORRECTED_OLD_AS_AUTHORITATIVE=YES
- SAFE_TO_CREATE_PUBLICATION_FIGURES=PARTIAL
- PHYSICS_LOGIC_CHANGED=NO
- FILES_DELETED=NO

## Quality metrics

- n_temperatures: 14
- temperature_list_K: 4;6;8;10;12;14;16;18;20;22;24;26;28;30
- n_current_points: 6
- n_x_grid_points: 220
- fraction_finite_aligned_residual: 0.47273
- svd_mode1_explained_variance: 0.90334
- rmse_backbone_only: 0.051777
- rmse_after_mode1: 0.009511
- improvement_factor_backbone_to_mode1: 5.4439
- phi1_kappa1_sign_convention: native_positive_mean_kappa
- missing_temperatures: NONE
- interpolation_failures_count: 50

## Diagnostic visual QA (TASK_002A, non-authoritative)

Manual-review PNGs derived **only** from the clean source view + authoritative corrected-old tables (see refinement report). Not manuscript evidence by themselves.

- Report / manifest / status: `reports/switching_corrected_old_quality_metrics_visual_QA_refinement.md`, `tables/switching_corrected_old_quality_metrics_visual_QA_refined_manifest.csv`, `tables/switching_corrected_old_quality_metrics_visual_QA_refined_status.csv`
- Refined PNG folder: `figures/switching/diagnostics/corrected_old_task002_quality_QA_refined/`
- Driver (rerun not required for governance closure): `Switching/diagnostics/run_switching_corrected_old_task002_visual_QA_refinement.m`

## Output artifacts

- `C:\Dev\matlab-functions\tables\switching_corrected_old_authoritative_backbone_map.csv`
- `C:\Dev\matlab-functions\tables\switching_corrected_old_authoritative_residual_map.csv`
- `C:\Dev\matlab-functions\tables\switching_corrected_old_authoritative_phi1.csv`
- `C:\Dev\matlab-functions\tables\switching_corrected_old_authoritative_kappa1.csv`
- `C:\Dev\matlab-functions\tables\switching_corrected_old_authoritative_mode1_reconstruction_map.csv`
- `C:\Dev\matlab-functions\tables\switching_corrected_old_authoritative_residual_after_mode1_map.csv`
- `C:\Dev\matlab-functions\tables\switching_corrected_old_authoritative_quality_metrics.csv`
- `C:\Dev\matlab-functions\tables\switching_corrected_old_authoritative_builder_status.csv`

## Notes

- Excluded current bins with non-finite S_percent in window: 50
