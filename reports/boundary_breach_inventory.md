# Boundary breach inventory — Switching canonicalization incident

## Incident window inspected

- **Committed baseline:** commit `e1506a4` — `repo: cleanup + canonical stabilization` (2026-04-02 08:25 +0300). This commit message explicitly references cleanup, Switching stabilization, and execution rules; Switching paths in that commit are included in the inventory (including files only added there, e.g. `switching_a1_vs_curvature_test.m`, `switching_ridge_susceptibility_test.m`, with `git status=A`).
- **Working tree (uncommitted):** snapshot at inventory generation time, filtered to Switching canonicalization–related paths (see below). **Not** re-derived from scratch: classifications use **`tables/canonical_boundary_truth.csv`**, **`tables/canonical_boundary_violations_truth.csv`**, **`tables/canonical_boundary_truth_status.csv`**, and **`reports/canonical_boundary_truth.md`** as the source of truth for in/out-of-boundary.

## How files were identified

1. **`git status --porcelain`** with a **scope filter** aligned to this incident:
   - `Switching/` and `Switching ver12/`
   - `Aging/utils/createRunContext.m` (only Aging path allowed by boundary policy)
   - `tools/`
   - `docs/`
   - `tables/` rows whose paths match governance / canonical / switching / preflight / infra audit tokens (same filter as the scoped `git status` run used for the breach list)
2. **`git show e1506a4`** — any **`Switching/`** path in that commit not already present in the working-tree set (added with status `A`).
3. **`reports/canonical_boundary_truth.md`** and **`reports/leakage_cleanup.md`** if present and showing as untracked/modified.
4. **One aggregate row** for **bulk tracked deletions** under `tables/` (~150+ paths) that fall outside the governance filter; individual paths are in full `git status` but are not duplicated line-by-line here to avoid false precision on attribution.

**Confidence:** Per-file **`CHANGE_CONFIDENCE`** is **HIGH** for normal scoped paths; **MEDIUM** for deleted rows and for the bulk summary row.

## Files clearly outside the canonical boundary

Per **`canonical_boundary_truth.csv`**, anything **not** in the **16-file MATLAB dependency closure** is **not** canonical runtime. This inventory marks **`IN_BOUNDARY = NO`** when the file is not that closure (with explicit **YES** for the listed closure files that changed: `run_switching_canonical.m`, `createRunContext.m`, `write_execution_marker.m`, `Switching ver12/main/Switching_main.m`).

Typical **OUT_OF_SCOPE** groups:

- **`Switching/analysis/*.m`** except the canonical entrypoint — secondary / experimental / robustness scripts (still **Switching** work, but **not** the canonical closure).
- **`Switching ver12/plots/plotSwitchingPanelF.m`** — legacy backend, not in the 16-file closure.
- **Non-wrapper `tools/*.m` / `.ps1`** — not in the MATLAB closure (automation / scanning / helpers).
- **Bulk `tables/` deletions** — artifact cleanup, not runtime boundary.

**Relaxation-named scripts under `Switching/analysis/`** (`run_relaxation_*`, `run_PT_*` relaxation mapping) are classified **`CHANGE_SCOPE_VERDICT = OUT_OF_SCOPE`** and **`RECOMMENDED_ACTION = REVERT`** relative to a **Switching-only** canonicalization scope (cross-pipeline drift), per task instructions.

## Files safe to keep (governance and in-boundary runtime)

- **Canonical runtime / allowed infra (KEEP, IN_SCOPE_ALLOWED):**  
  `Switching/analysis/run_switching_canonical.m`, `Aging/utils/createRunContext.m`, `tools/write_execution_marker.m`, `Switching ver12/main/Switching_main.m` (legacy path donor), and execution **`tools/`** entries (`run_matlab_safe.bat`, `pre_execution_guard.ps1`, `validate_matlab_runnable.ps1`) as policy-aligned tooling.
- **Governance docs and tables (KEEP as control artifacts):**  
  `docs/*` matching execution / Switching boundary policy, **`tables/switching_*.csv`**, **`tables/canonical_*.csv`**, preflight / infra audit tables in scope, and **`reports/canonical_boundary_truth.md`**. These are **not** runtime contamination; they document and enforce boundaries.

## Files requiring manual review

- **`CHANGE_SCOPE_VERDICT = UNCERTAIN`** or **`RECOMMENDED_ACTION = MANUAL_REVIEW`**: includes `docs/repo_map.md`, `docs/repo_context_infra.md`, `docs/templates/`, most noncanonical **`Switching/analysis`** scripts, **`plotSwitchingPanelF.m`**, non-wrapper **`tools`**, and the **bulk `tables/` deletions** summary row.
- **Do not** treat “good science” as in-scope: out-of-closure Switching scripts remain **OUT_OF_SCOPE** for the canonical boundary even if scientifically useful.

## Completeness for controlled rollback planning

- **`BREACH_INVENTORY_COMPLETE = YES`** for the **defined scope filter** and **aggregate** bulk deletion row.
- **Caveat:** The inventory is **complete** for filtered paths; it does **not** enumerate every deleted `tables/*.csv` line-by-line. Rollback of mass deletions must use **`git diff` / `git checkout`** on full paths or a full-tree restore — see **`EVIDENCE_BASIS`** in `tables/boundary_breach_inventory.csv`.

Machine-readable outputs: **`tables/boundary_breach_inventory.csv`**, **`tables/boundary_breach_status.csv`**.
