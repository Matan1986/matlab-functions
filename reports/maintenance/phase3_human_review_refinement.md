# Maintenance Phase 3 — human-review refinement (read-only triage)

**HEAD / origin/main:** `b6d6429` (*Track Switching corrected-old authoritative provenance*).  
**Switching P0:** closed (unchanged).  
**Execution mode:** read-only review of the dirty working tree; no `git add` / `git restore` / `git clean`, no edits to in-scope dirty paths except creation of this Phase 3 deliverable set.  
**Rules reference:** `docs/repo_execution_rules.md` (MATLAB execution guardrails; no broad cleanup implied).

## Inputs read

- `tables/maintenance_dirty_tree_retention_decision_audit.csv`
- `tables/maintenance_dirty_tree_retention_decision_status.csv`
- `tables/maintenance_phase2_minimal_cleanup_status.csv`
- `reports/maintenance/phase2_minimal_cleanup.md`

## Scope

- **In scope:** paths Phase 1 classified as `HOLD_HUMAN_REVIEW`, `ARCHIVE_OR_QUARANTINE_LATER`, or `KEEP_AND_TRACK_LATER`, plus post–Phase 1 maintenance artifacts (`reports/maintenance/dirty_tree_retention_decision_audit.md`, `reports/maintenance/phase2_minimal_cleanup.md`) and Phase 3 deliverables that appear as dirty paths: `tables/maintenance_phase3_human_review_refinement.csv`, `reports/maintenance/phase3_human_review_refinement.md`. **Machine-readable verdicts** also live in `tables/maintenance_phase3_human_review_refinement_status.csv`, which matches `.gitignore` pattern `tables/*status*` and therefore **does not** show in `git status`; track with path-specific `git add -f -- "tables/maintenance_phase3_human_review_refinement_status.csv"` if policy requires.
- **Out of scope (count only):** `OUT_OF_SCOPE_LEAVE_UNTOUCHED` dirty paths — **34** lines on current `git status --short` (Relaxation ver3, Aging root audits, Relaxation Python helpers per Phase 1 audit).

## `git status --short` (snapshot)

End of this pass: **88** dirty lines = **34** out-of-scope + **54** in-scope (matches row count in `tables/maintenance_phase3_human_review_refinement.csv`; excludes gitignored verdict CSV above).

## Phase 3 decision counts (in-scope)

| Phase 3 decision | Count |
|------------------|------:|
| `KEEP_FOR_FUTURE_COMMIT` | 17 |
| `NEEDS_MANUAL_DIFF_REVIEW` | 29 |
| `MOVE_TO_QUARANTINE_LATER` | 8 |
| `RESTORE_TO_HEAD_LATER` | 0 |
| `DELETE_UNTRACKED_LATER` | 0 |
| `SPLIT_INTO_SEPARATE_TASK` | 0 |

Machine-readable: `tables/maintenance_phase3_human_review_refinement_status.csv`.

## Logical bundles

| Bundle | Paths | Role |
|--------|------:|------|
| `canonical_switching_header_governance` | 25 | Modified `Switching/analysis/*.m` — header/governance batch; **gate on per-file `git diff`**. |
| `gitignore_and_governance_docs` | 3 | `.gitignore`, `docs/switching_governance_persistence_manifest.md`, `docs/decisions/switching_main_narrative_namespace_decision.md`. |
| `gauge_atlas_visualization` | 10 | Gauge drivers, CSVs, preview PNG, gauge report — align retention before any restore of binaries. |
| `corrected_old_replay_and_quarantine_scripts` | 3 | Corrected-old / replay-auth adjacency — **quarantine policy before track**. |
| `old_x_old_figure_replay_scripts` | 8 | Old X / panel / figure replay helpers (KEEP candidates + stabilized / forensic replay MOVE set). |
| `governance_and_maintenance_artifacts` | 4 | Phase 1/2 maintenance reports + Phase 3 refinement CSV/report — narrow `git add -f` after approval (verdict CSV separate; see gitignore note). |
| `miscellaneous_switching_helpers` | 1 | `Switching/diagnostics/run_switching_cdf_backbone_repair_aggressiveness_audit.m` (KEEP path). |

## High-risk paths and recommended handling

1. **`Switching/analysis/run_switching_canonical.m`** — `risk=high`, `NEEDS_MANUAL_DIFF_REVIEW`. Treat as **mandatory** human diff before any commit touching the canonical bundle.
2. **Quarantine / forensics cluster (`MOVE_TO_QUARANTINE_LATER`, `risk=high` unless noted):**  
   `scripts/run_sw_corr_old_replay_auth.m`, `scripts/run_sw_old_inv_phi1_viz.m`, `scripts/run_switching_corrected_old_replay_inventory_and_phi1_visual_sanity.m` — align with quarantine registry before track or delete.  
3. **Figure / stabilized replay cluster:**  
   `scripts/run_switching_old_fig_forensic_and_canonical_replot.m`, `scripts/run_switching_stabilized_gauge_figure_replay.m`, `scripts/run_switching_stabilized_gauge_robustness_summary.m`, `scripts/run_switching_stabilized_gauge_xpanel_style_fix.m` — same **manual relocation + registry** pattern; do not bulk-stage.
4. **`figures/switching/diagnostics/switching_gauge_atlas_G001_G254_G014_preview.png`** — `risk=medium`; archive copy **before** any `git restore` that would discard local binary delta.

## Paths safe to restore / delete later (explicit, current verdict)

- **`RESTORE_TO_HEAD_LATER`:** none assigned at Phase 3 without completing the **29** manual diffs; each `NEEDS_MANUAL_DIFF_REVIEW` row lists path-specific `git restore -- "<path>"` in the refinement CSV **only after** human rejects the local change.
- **`DELETE_UNTRACKED_LATER`:** none for in-scope paths; Phase 2 already removed the three Phase 1 `DELETE_UNTRACKED_LATER` targets.

## Paths that must remain manual review (`NEEDS_MANUAL_DIFF_REVIEW`)

Exact set (29):

- `.gitignore`
- `Switching/analysis/run_minimal_canonical.m`
- `Switching/analysis/run_parameter_robustness_switching_canonical.m`
- `Switching/analysis/run_phi2_kappa2_canonical_residual_mode.m`
- `Switching/analysis/run_switching_backbone_confidence_audit.m`
- `Switching/analysis/run_switching_backbone_stress_test.m`
- `Switching/analysis/run_switching_backbone_validity_audit.m`
- `Switching/analysis/run_switching_canonical.m`
- `Switching/analysis/run_switching_canonical_collapse_hierarchy.m`
- `Switching/analysis/run_switching_canonical_collapse_visualization.m`
- `Switching/analysis/run_switching_canonical_first_figure_anchor.m`
- `Switching/analysis/run_switching_canonical_map_backbone_residual_visualization.m`
- `Switching/analysis/run_switching_canonical_map_visualization.m`
- `Switching/analysis/run_switching_canonical_metadata_sidecar_audit.m`
- `Switching/analysis/run_switching_canonical_observable_dictionary_audit.m`
- `Switching/analysis/run_switching_canonical_ptcdf_collapse_overlay.m`
- `Switching/analysis/run_switching_canonical_reconstruction_visualization.m`
- `Switching/analysis/run_switching_canonical_root_pipeline_isolation.m`
- `Switching/analysis/run_switching_canonical_transition_highT_diagnostics.m`
- `Switching/analysis/run_switching_collapse_breakdown_analysis.m`
- `Switching/analysis/run_switching_collapse_subrange_analysis.m`
- `Switching/analysis/run_switching_geocanon_descriptor_audit.m`
- `Switching/analysis/run_switching_mode_hierarchy_synthesis_audit.m`
- `Switching/analysis/run_switching_phi1_kappa1_experimental_replay.m`
- `Switching/analysis/run_switching_phi2_replacement_audit.m`
- `Switching/analysis/switching_residual_decomposition_analysis.m`
- `docs/switching_governance_persistence_manifest.md`
- `reports/switching_gauge_atlas_preview.md`
- `docs/decisions/switching_main_narrative_namespace_decision.md`

## Phase 4 readiness

- **`SAFE_TO_PROCEED_TO_PHASE4_SCOPED_ACTIONS`:** **YES** — only **path-scoped** `git add -f`, `git restore -- "<path>"`, file-system quarantine copies, and registry updates per row in `tables/maintenance_phase3_human_review_refinement.csv`.
- **`BROAD_ACTIONS_RECOMMENDED`:** **NO** — no wildcards, no `git restore .`, no `git clean`.

## Verdict row

See `tables/maintenance_phase3_human_review_refinement_status.csv`.
