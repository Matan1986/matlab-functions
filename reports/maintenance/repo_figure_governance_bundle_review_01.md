# REPO-FIG-INFRA-BUNDLE-01 — Figure-governance commit bundle review

## 1. Executive summary

The working tree mixes **intended figure-governance deliverables** (untracked `reports/maintenance/` and `tables/maintenance_repo_*` INFRA artifacts), **CV06-related tracked edits** (`scripts/run_switching_canonical_paper_figures.ps1`, regenerated `results/switching/figures/canonical_paper/*.{png,pdf}`, and manifest/report updates), and **unrelated** modified or deleted paths (for example `reports/maintenance/governor_summary_latest.md`, `reports/aging/*`, deleted `figures/switching/phase4B_*`, maintenance findings CSV). **Staged index was empty** at review time; **no** commit should bundle unrelated backlog.

**Recommended split: Option B** — (1) **Governance documentation** for INFRA-01B through INFRA-04D, CV07 closure evidence, SW-FIG-INFRA-01 where present, plus **`tools/agent24h_render_figures_matlab_replacement.m`** as the documented MATLAB replacement candidate; (2) **CV06 technical change** — PowerShell script plus **tracked** regenerated canonical-paper raster/PDF outputs and the **switching canonical paper** report/manifest rows tied to that run. **`.fig`** files under `results/switching/figures/canonical_paper/` are **present on disk** but **ignored** by `.gitignore` (`results/**`); committing them requires an **explicit policy decision** and `git add -f` if the repo should track them — **defer or manual review**, not silent default.

## 2. Current git state summary

- **`git diff --cached --name-only`:** empty (safe to plan without unstaged-index conflicts).
- **`git status --short`:** large mixed tree; key observations:
  - **Untracked (`??`):** many `reports/maintenance/repo_*INFRA*.md`, `tables/maintenance_repo_*INFRA*.csv`, INFRA-04 agent24h suite, `tools/agent24h_render_figures_matlab_replacement.m`, Relaxation/Switching backlog, etc.
  - **Modified (`M`):** `scripts/run_switching_canonical_paper_figures.ps1`, four files under `results/switching/figures/canonical_paper/` (pdf/png only in index), `reports/switching_canonical_paper_figures.md`, `tables/switching_canonical_paper_figures_manifest.csv`, plus **non-bundle** paths (`governor_summary_latest`, `aging_F7X7`, `maintenance_findings_latest`, etc.).
  - **Deleted (`D`):** `figures/switching/phase4B_*` — **not** part of this bundle; **manual review** before any commit.

## 3. Completed governance sequence recap

INFRA-03B (mandatory remediation), SW-FIG-INFRA-01 / CV06 (`.fig` export alongside png/pdf per narrative), INFRA-04B (CV07 input lineage), INFRA-04C (blocked materialization), INFRA-04C-CLEAN (removed invalid phi2 placeholders; preserved evidence), INFRA-04D (canonical-only CV07 decision: supersession, formal non-authority, keep replacement blocked pending charter). **No repair** of old runs in this review.

## 4. Candidate commit paths

See `tables/maintenance_repo_figure_governance_bundle_review_01_candidate_paths.csv`. Summary groups:

- **COMMIT_GOVERNANCE:** INFRA-01B, INFRA-02, INFRA-03/03B tables and reports listed in scope, full INFRA-04 (04B/04C/04C-CLEAN/04D + `repo_agent24h_renderer_resolution_INFRA_04*`), SW-FIG-INFRA-01 maintenance docs/tables if included in governance scope, `tools/agent24h_render_figures_matlab_replacement.m`.
- **COMMIT_CV06_CODE:** `scripts/run_switching_canonical_paper_figures.ps1`.
- **COMMIT_CV06_OUTPUT_OPTIONAL (tracked):** modified `results/switching/figures/canonical_paper/*.pdf`, `*.png`, `reports/switching_canonical_paper_figures.md`, `tables/switching_canonical_paper_figures_manifest.csv`.
- **DEFER_NEEDS_POLICY_DECISION:** `results/switching/figures/canonical_paper/*.fig` (exist locally; **`results/**` ignored** — force-add only if owners require tracked `.fig`).

## 5. Explicit exclusions

See `tables/maintenance_repo_figure_governance_bundle_review_01_exclusions.csv`. Includes: **`matlab_error.log`** (ignored `*.log`); **legacy CV07 PNGs** under `figures/` (typically ignored; do not promote in this bundle); **removed phi2 placeholders** (already absent — nothing to stage); **Relaxation ver3**, **Aging** drafts, **Switching analysis backlog**, **tmp_***, unrelated **maintenance** inventories, **deleted** `figures/switching/phase4B_*` without restoration decision; **`reports/maintenance/governor_summary_latest.md`**, **`tables/maintenance_findings_latest.csv`** unless explicitly folded into a separate maintenance PR.

## 6. CV06 commit decision

- **Code:** Commit **`scripts/run_switching_canonical_paper_figures.ps1`** with the second commit (Option B).
- **Tracked outputs:** Commit modified **PDF/PNG** and the **canonical paper report + manifest** updates together with the script so the run record matches artifacts (same commit as script or immediately after in commit 2).
- **`.fig` outputs:** **Not** in the index by default (ignore rule). **Recommendation:** Treat as **optional** commit content: add only after explicit decision to track binary results under `results/` (use `git add -f` for selected `.fig` paths). If policy keeps `results/**` untracked, document that **`.fig` remain local-only** and CI must regenerate.

## 7. CV07 governance decision summary

CV07 MATLAB replacement **execution** remains **blocked** without chartered canonical inputs (INFRA-04D). **Include** all INFRA-04B through INFRA-04D **reports and tables** in the **governance** commit. **Do not** stage legacy System.Drawing PNGs or **`tools/agent24h_render_figures.ps1`** edits (none in tree for this sequence per constraints).

## 8. Recommended commit split

**Option B — two commits:**

1. **`docs: figure governance INFRA + CV07 closure evidence`**  
   All `COMMIT_GOVERNANCE` paths from the candidate CSV (INFRA maintenance markdown/tables, INFRA-04 suite, MATLAB replacement `.m`).

2. **`fix(sw-fig): canonical paper figures export fig + regenerate outputs`**  
   `COMMIT_CV06_CODE` + tracked `COMMIT_CV06_OUTPUT_OPTIONAL` paths. Optionally append **forced** `.fig` adds in the **same** commit if policy allows.

**Option A** (single commit) is **acceptable only** if maintainers want one atomic “figure policy + CV06 export” story — higher noise and mixes governance prose with binary PDF/PNG.

**Option C** (three or more) — use only if splitting INFRA by phase (for example INFRA-03B vs INFRA-04) is required for review size; not mandatory from this inspection.

## 9. Risks / manual review items

- **`D figures/switching/phase4B_*`:** Resolve or revert **before** any broad commit; do not bundle accidentally.
- **`.gitignore` on `results/**`:** Risk that **`.fig` fix** is invisible to collaborators until force-add policy is decided.
- **Large untracked maintenance table set:** Stage **only** paths listed in the candidate CSV; avoid `git add` globs that scoop unrelated `tables/maintenance_*.csv`.

## 10. Exact next staging prompt recommendation

**Do not run these commands in automation without human confirmation.** Example **Option B** manual sequence (paths illustrative — trim to your final candidate CSV):

**Commit 1 (governance)** — add only governance rows from `maintenance_repo_figure_governance_bundle_review_01_candidate_paths.csv` where `classification=COMMIT_GOVERNANCE`, plus `tools/agent24h_render_figures_matlab_replacement.m`. Example shape:

```text
git add reports/maintenance/repo_language_figure_policy_INFRA_01B.md
git add reports/maintenance/repo_nonmatlab_inventory_conversion_plan_INFRA_02.md
git add reports/maintenance/repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B.md
git add tables/maintenance_repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B.csv
git add tables/maintenance_repo_nonmatlab_P0_figure_mandatory_conversion_queue_INFRA_03B.csv
git add tables/maintenance_repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B_status.csv
git add reports/maintenance/repo_agent24h_renderer_input_lineage_INFRA_04B.md
git add tables/maintenance_repo_agent24h_renderer_input_lineage_INFRA_04B_*.csv
git add reports/maintenance/repo_agent24h_matlab_replacement_INFRA_04C.md
git add tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_*.csv
git add reports/maintenance/repo_agent24h_infra04c_side_effect_cleanup.md
git add tables/maintenance_repo_agent24h_infra04c_side_effect_*.csv
git add reports/maintenance/repo_agent24h_cv07_canonical_only_decision_INFRA_04D.md
git add tables/maintenance_repo_agent24h_cv07_canonical_only_decision_INFRA_04D_*.csv
git add reports/maintenance/repo_agent24h_renderer_resolution_INFRA_04.md
git add tables/maintenance_repo_agent24h_renderer_resolution_INFRA_04_*.csv
git add reports/maintenance/switching_canonical_paper_figures_fig_export_INFRA_01.md
git add tables/maintenance_switching_canonical_paper_figures_fig_export_INFRA_01_*.csv
git add tools/agent24h_render_figures_matlab_replacement.m
```

*(Extend with any additional INFRA-02/03 supporting tables you intentionally include; omit unrelated `??` reports.)*

**Commit 2 (CV06):**

```text
git add scripts/run_switching_canonical_paper_figures.ps1
git add reports/switching_canonical_paper_figures.md
git add tables/switching_canonical_paper_figures_manifest.csv
git add results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.pdf
git add results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.png
git add results/switching/figures/canonical_paper/switching_supp_Xeff_components.pdf
git add results/switching/figures/canonical_paper/switching_supp_Xeff_components.png
```

**Optional `.fig` (policy decision):**

```text
git add -f results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.fig
git add -f results/switching/figures/canonical_paper/switching_supp_Xeff_components.fig
```

**Never include in these commits:** `matlab_error.log`, Relaxation ver3 paths, unrelated Switching/Aging backlog, `governor_summary_latest` / `maintenance_findings_latest` unless a separate decision.

---

**Review metadata:** Read-only inspection; no staging, commit, or push; no MATLAB/Python/Node/PowerShell execution; ASCII only.
