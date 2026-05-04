# REPO-FIG-INFRA-PRESTAGE-01 — Pre-staging guard (figure-governance two-commit plan)

## 1. Executive summary

**Staged index is empty** (`git diff --cached` at guard time). This document gives **copy-paste only** `git add` and `git commit` lines for **Option B** per BUNDLE-01. It **excludes** deleted `figures/switching/phase4B_*` files, `matlab_error.log`, legacy CV07 PNGs, phi2 placeholder paths, unrelated backlog, and **does not** force-add `results/**` `.fig` files in the default plan. **No commands were executed** in the task that produced this file.

**Blocker before `git commit`:** If `git status` still shows `D figures/switching/phase4B_*`, do **not** use `git commit -a` or `git add -u` without care — resolve or commit those deletions in a **separate** decision. The plans below use **only explicit path** `git add` so phase4B deletions are **not** included.

## 2. Current git state summary (guard snapshot)

- **HEAD:** `d44f6ce` (newer than prior bundle snapshot; log available in session).
- **`git diff --cached --name-only`:** empty.
- **Notable `git status --short`:** `D figures/switching/phase4B_*` (three paths); `M` on CV06 and governance-related paths; many `??` untracked (only a strict subset is staged in the plans below).

## 3. Manual issue 1: deleted phase4B files

**Found (unrelated to INFRA figure-governance sequence):**

- `figures/switching/phase4B_C01_X_like_panel_orientation_lock.png`
- `figures/switching/phase4B_C02_collapse_like_panel_range_lock.fig`
- `figures/switching/phase4B_C02_collapse_like_panel_range_lock.png`

**Classification:** Not referenced by INFRA-01B through INFRA-04D, CV06 PS1, or bundle governance paths. **Excluded** from Commit 1 and Commit 2 explicit lists.

**Restore:** **Not** performed in this task. **Separate decision:** restore from git (`git checkout HEAD -- …`), recover from backup, or **commit the deletions** intentionally in another change — **not** inside the two commits below.

## 4. Manual issue 2: ignored `.fig` under `results/`

Canonical-paper **`.fig`** files exist under `results/switching/figures/canonical_paper/` but are **not** tracked because `.gitignore` matches `results/**`. **Default plans omit** `git add -f` for them. Optional policy follow-up in section 10.

## 5. Commit 1 exact path list

**Markdown reports**

- `reports/maintenance/repo_language_figure_policy_INFRA_01B.md`
- `reports/maintenance/repo_nonmatlab_inventory_conversion_plan_INFRA_02.md`
- `reports/maintenance/repo_nonmatlab_P0_figure_decision_INFRA_03.md`
- `reports/maintenance/repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B.md`
- `reports/maintenance/repo_agent24h_renderer_resolution_INFRA_04.md`
- `reports/maintenance/repo_agent24h_renderer_input_lineage_INFRA_04B.md`
- `reports/maintenance/repo_agent24h_matlab_replacement_INFRA_04C.md`
- `reports/maintenance/repo_agent24h_infra04c_side_effect_cleanup.md`
- `reports/maintenance/repo_agent24h_cv07_canonical_only_decision_INFRA_04D.md`
- `reports/maintenance/switching_canonical_paper_figures_fig_export_INFRA_01.md`
- `reports/maintenance/repo_figure_governance_bundle_review_01.md`
- `reports/maintenance/repo_figure_governance_prestage_01.md`

**Tables (INFRA-01B)**

- `tables/maintenance_repo_language_figure_policy_INFRA_01B_doc_inventory.csv`
- `tables/maintenance_repo_language_figure_policy_INFRA_01B_future_prompt_block.csv`
- `tables/maintenance_repo_language_figure_policy_INFRA_01B_policy_matrix.csv`
- `tables/maintenance_repo_language_figure_policy_INFRA_01B_status.csv`
- `tables/maintenance_repo_language_figure_policy_INFRA_01B_supersession.csv`

**Tables (INFRA-02 / INFRA-03 / P0)**

- `tables/maintenance_repo_nonmatlab_inventory_INFRA_02.csv`
- `tables/maintenance_repo_nonmatlab_inventory_INFRA_02_status.csv`
- `tables/maintenance_repo_matlab_conversion_plan_INFRA_02.csv`
- `tables/maintenance_repo_matlab_parity_requirements_INFRA_02.csv`
- `tables/maintenance_repo_nonmatlab_output_lineage_INFRA_02.csv`
- `tables/maintenance_repo_nonmatlab_risk_ranking_INFRA_02.csv`
- `tables/maintenance_repo_nonmatlab_P0_figure_conversion_plan_INFRA_03.csv`
- `tables/maintenance_repo_nonmatlab_P0_figure_decision_INFRA_03.csv`
- `tables/maintenance_repo_nonmatlab_P0_figure_decision_INFRA_03_status.csv`
- `tables/maintenance_repo_nonmatlab_P0_figure_quarantine_INFRA_03.csv`
- `tables/maintenance_repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B.csv`
- `tables/maintenance_repo_nonmatlab_P0_figure_mandatory_conversion_queue_INFRA_03B.csv`
- `tables/maintenance_repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B_status.csv`

**Tables (INFRA-04 / 04B / 04C / clean / 04D)**

- `tables/maintenance_repo_agent24h_renderer_resolution_INFRA_04_decision.csv`
- `tables/maintenance_repo_agent24h_renderer_resolution_INFRA_04_output_audit.csv`
- `tables/maintenance_repo_agent24h_renderer_resolution_INFRA_04_source_audit.csv`
- `tables/maintenance_repo_agent24h_renderer_resolution_INFRA_04_status.csv`
- `tables/maintenance_repo_agent24h_renderer_input_lineage_INFRA_04B_decision.csv`
- `tables/maintenance_repo_agent24h_renderer_input_lineage_INFRA_04B_input_status.csv`
- `tables/maintenance_repo_agent24h_renderer_input_lineage_INFRA_04B_search_hits.csv`
- `tables/maintenance_repo_agent24h_renderer_input_lineage_INFRA_04B_status.csv`
- `tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_generator_audit.csv`
- `tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_input_materialization.csv`
- `tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_replacement_outputs.csv`
- `tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_status.csv`
- `tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_visual_parity_check.csv`
- `tables/maintenance_repo_agent24h_infra04c_side_effect_actions.csv`
- `tables/maintenance_repo_agent24h_infra04c_side_effect_inventory.csv`
- `tables/maintenance_repo_agent24h_infra04c_side_effect_status.csv`
- `tables/maintenance_repo_agent24h_cv07_canonical_only_decision_INFRA_04D_canonical_candidate_artifacts.csv`
- `tables/maintenance_repo_agent24h_cv07_canonical_only_decision_INFRA_04D_path_options.csv`
- `tables/maintenance_repo_agent24h_cv07_canonical_only_decision_INFRA_04D_reference_hits.csv`
- `tables/maintenance_repo_agent24h_cv07_canonical_only_decision_INFRA_04D_status.csv`

**Tables (SW-FIG-INFRA-01)**

- `tables/maintenance_switching_canonical_paper_figures_fig_export_INFRA_01_file_audit.csv`
- `tables/maintenance_switching_canonical_paper_figures_fig_export_INFRA_01_status.csv`

**Tables (bundle + prestage meta)**

- `tables/maintenance_repo_figure_governance_bundle_review_01_candidate_paths.csv`
- `tables/maintenance_repo_figure_governance_bundle_review_01_commit_plan.csv`
- `tables/maintenance_repo_figure_governance_bundle_review_01_exclusions.csv`
- `tables/maintenance_repo_figure_governance_bundle_review_01_status.csv`
- `tables/maintenance_repo_figure_governance_prestage_01_commit1_paths.csv`
- `tables/maintenance_repo_figure_governance_prestage_01_commit2_paths.csv`
- `tables/maintenance_repo_figure_governance_prestage_01_exclusions.csv`
- `tables/maintenance_repo_figure_governance_prestage_01_status.csv`

**Tool**

- `tools/agent24h_render_figures_matlab_replacement.m`

## 6. Commit 1 exact commands

Run from repository root. **Verify** `git diff --cached --name-only` is empty before `git add`.

```bat
git add reports/maintenance/repo_language_figure_policy_INFRA_01B.md
git add reports/maintenance/repo_nonmatlab_inventory_conversion_plan_INFRA_02.md
git add reports/maintenance/repo_nonmatlab_P0_figure_decision_INFRA_03.md
git add reports/maintenance/repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B.md
git add reports/maintenance/repo_agent24h_renderer_resolution_INFRA_04.md
git add reports/maintenance/repo_agent24h_renderer_input_lineage_INFRA_04B.md
git add reports/maintenance/repo_agent24h_matlab_replacement_INFRA_04C.md
git add reports/maintenance/repo_agent24h_infra04c_side_effect_cleanup.md
git add reports/maintenance/repo_agent24h_cv07_canonical_only_decision_INFRA_04D.md
git add reports/maintenance/switching_canonical_paper_figures_fig_export_INFRA_01.md
git add reports/maintenance/repo_figure_governance_bundle_review_01.md
git add reports/maintenance/repo_figure_governance_prestage_01.md
git add tables/maintenance_repo_language_figure_policy_INFRA_01B_doc_inventory.csv
git add tables/maintenance_repo_language_figure_policy_INFRA_01B_future_prompt_block.csv
git add tables/maintenance_repo_language_figure_policy_INFRA_01B_policy_matrix.csv
git add tables/maintenance_repo_language_figure_policy_INFRA_01B_status.csv
git add tables/maintenance_repo_language_figure_policy_INFRA_01B_supersession.csv
git add tables/maintenance_repo_nonmatlab_inventory_INFRA_02.csv
git add tables/maintenance_repo_nonmatlab_inventory_INFRA_02_status.csv
git add tables/maintenance_repo_matlab_conversion_plan_INFRA_02.csv
git add tables/maintenance_repo_matlab_parity_requirements_INFRA_02.csv
git add tables/maintenance_repo_nonmatlab_output_lineage_INFRA_02.csv
git add tables/maintenance_repo_nonmatlab_risk_ranking_INFRA_02.csv
git add tables/maintenance_repo_nonmatlab_P0_figure_conversion_plan_INFRA_03.csv
git add tables/maintenance_repo_nonmatlab_P0_figure_decision_INFRA_03.csv
git add tables/maintenance_repo_nonmatlab_P0_figure_decision_INFRA_03_status.csv
git add tables/maintenance_repo_nonmatlab_P0_figure_quarantine_INFRA_03.csv
git add tables/maintenance_repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B.csv
git add tables/maintenance_repo_nonmatlab_P0_figure_mandatory_conversion_queue_INFRA_03B.csv
git add tables/maintenance_repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B_status.csv
git add tables/maintenance_repo_agent24h_renderer_resolution_INFRA_04_decision.csv
git add tables/maintenance_repo_agent24h_renderer_resolution_INFRA_04_output_audit.csv
git add tables/maintenance_repo_agent24h_renderer_resolution_INFRA_04_source_audit.csv
git add tables/maintenance_repo_agent24h_renderer_resolution_INFRA_04_status.csv
git add tables/maintenance_repo_agent24h_renderer_input_lineage_INFRA_04B_decision.csv
git add tables/maintenance_repo_agent24h_renderer_input_lineage_INFRA_04B_input_status.csv
git add tables/maintenance_repo_agent24h_renderer_input_lineage_INFRA_04B_search_hits.csv
git add tables/maintenance_repo_agent24h_renderer_input_lineage_INFRA_04B_status.csv
git add tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_generator_audit.csv
git add tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_input_materialization.csv
git add tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_replacement_outputs.csv
git add tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_status.csv
git add tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_visual_parity_check.csv
git add tables/maintenance_repo_agent24h_infra04c_side_effect_actions.csv
git add tables/maintenance_repo_agent24h_infra04c_side_effect_inventory.csv
git add tables/maintenance_repo_agent24h_infra04c_side_effect_status.csv
git add tables/maintenance_repo_agent24h_cv07_canonical_only_decision_INFRA_04D_canonical_candidate_artifacts.csv
git add tables/maintenance_repo_agent24h_cv07_canonical_only_decision_INFRA_04D_path_options.csv
git add tables/maintenance_repo_agent24h_cv07_canonical_only_decision_INFRA_04D_reference_hits.csv
git add tables/maintenance_repo_agent24h_cv07_canonical_only_decision_INFRA_04D_status.csv
git add tables/maintenance_switching_canonical_paper_figures_fig_export_INFRA_01_file_audit.csv
git add tables/maintenance_switching_canonical_paper_figures_fig_export_INFRA_01_status.csv
git add tables/maintenance_repo_figure_governance_bundle_review_01_candidate_paths.csv
git add tables/maintenance_repo_figure_governance_bundle_review_01_commit_plan.csv
git add tables/maintenance_repo_figure_governance_bundle_review_01_exclusions.csv
git add tables/maintenance_repo_figure_governance_bundle_review_01_status.csv
git add tables/maintenance_repo_figure_governance_prestage_01_commit1_paths.csv
git add tables/maintenance_repo_figure_governance_prestage_01_commit2_paths.csv
git add tables/maintenance_repo_figure_governance_prestage_01_exclusions.csv
git add tables/maintenance_repo_figure_governance_prestage_01_status.csv
git add tools/agent24h_render_figures_matlab_replacement.m
```

```bat
git commit -m "docs(maintenance): figure governance INFRA + CV07 closure evidence"
```

Adjust `-m` message if your project prefers another convention.

## 7. Commit 2 exact path list

- `scripts/run_switching_canonical_paper_figures.ps1`
- `reports/switching_canonical_paper_figures.md`
- `tables/switching_canonical_paper_figures_manifest.csv`
- `results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.pdf`
- `results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.png`
- `results/switching/figures/canonical_paper/switching_supp_Xeff_components.pdf`
- `results/switching/figures/canonical_paper/switching_supp_Xeff_components.png`

**Does not include** `*.fig` under `results/` in the default plan.

## 8. Commit 2 exact commands

Run **after** Commit 1 is complete and working tree still has these modifications.

```bat
git add scripts/run_switching_canonical_paper_figures.ps1
git add reports/switching_canonical_paper_figures.md
git add tables/switching_canonical_paper_figures_manifest.csv
git add results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.pdf
git add results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.png
git add results/switching/figures/canonical_paper/switching_supp_Xeff_components.pdf
git add results/switching/figures/canonical_paper/switching_supp_Xeff_components.png
```

```bat
git commit -m "fix(switching): canonical paper PS1 fig export and regenerated paper outputs"
```

## 9. Explicit exclusions

See `tables/maintenance_repo_figure_governance_prestage_01_exclusions.csv`. Summary: phase4B deletions; `matlab_error.log`; legacy CV07 PNG trio; phi2 placeholder paths (absent); Relaxation ver3; unrelated scripts/docs; `governor_summary_latest`, `maintenance_findings_latest`, `aging_F7X7` draft; tmp dirs; **no** `git add .`.

## 10. Optional `.fig` policy follow-up

**Default:** Do **not** stage `.fig` under `results/switching/figures/canonical_paper/`.

**If** policy requires tracked MATLAB figure sources for CV06 compliance:

1. Decide in a **separate** maintenance note whether to `git add -f` specific paths, **or** add an export/copy step to a **tracked** directory outside `results/**`.
2. Example **only if explicitly approved**:

```bat
git add -f results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.fig
git add -f results/switching/figures/canonical_paper/switching_supp_Xeff_components.fig
```

Either amend Commit 2 or create a small follow-up commit; do not mix with Commit 1.

## 11. Final safety checklist

- [ ] `git diff --cached --name-only` empty before starting Commit 1 adds.
- [ ] No `git add .`, `git add -A`, `git clean`.
- [ ] Phase4B `D` entries **not** in explicit add lists; separate restore/delete decision.
- [ ] `git status` after each commit reviewed before pushing.
- [ ] Optional: run `git diff --cached` before each `git commit` to verify paths only.

---

**Guard metadata:** Plans only; no `git add`, `git commit`, or `git push` executed in this task; ASCII only.
