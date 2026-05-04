# REPO-FIG-INFRA-04C-CLEAN — Side effects from failed INFRA-04C attempt

## 1. Executive summary

The failed INFRA-04C run left **invalid placeholder** outputs from `Switching/analysis/run_phi2_shape_physics_test.m` (catch-block writes after `switching_residual_decomposition_analysis` failed for a missing legacy alignment MAT). **Four** untracked, git-ignored files with **all-NaN** or **FAIL** content were **removed from the working tree** as clearly invalid failed-generator artifacts, after inventory and timestamp confirmation (2026-05-04, aligned with the documented run). **No** legacy CV07 PNGs, **no** tracked files, and **no** INFRA-04C maintenance report or table were edited or removed. **`matlab_error.log`** (new, append-style diagnostic) was **preserved** as optional forensic evidence; optional manual deletion is a separate choice. **Pre-existing** `reports/alpha_structure_report.md` and `figures/alpha_vs_T.png` (2026-03-25 timestamps) were **not** produced by the May 2026 blocked alpha run in INFRA-04C and were **not** modified by this cleanup.

## 2. INFRA-04C failed and blocked recap

Per `reports/maintenance/repo_agent24h_matlab_replacement_INFRA_04C.md`, input materialization failed on missing `results/switching/runs/**` legacy artifacts. `run_alpha_structure_agent19f` failed before writing `tables/alpha_structure.csv`. The phi2 test exited 0 but wrote **placeholder** tables. **20A** and the MATLAB replacement **failed**; no `figures/infra_04_agent24h_replacement/**` and no `tables/infra_04_agent24h_replacement_correlations.csv`. Legacy CV07 PNGs at `figures/*.png` were not touched by INFRA-04C.

## 3. Side-effect inventory

| Path | State | Classification |
| --- | --- | --- |
| `tables/phi2_structure_metrics.csv` | Was present (ignored untracked), NaN row | Invalid placeholder from failed generator |
| `tables/phi2_kernel_comparison.csv` | Was present (ignored untracked), NA/NaN | Invalid placeholder |
| `tables/phi2_regime_stability.csv` | Was present (ignored untracked), NA/NaN | Invalid placeholder |
| `reports/run_phi2_shape_physics_test.md` | Was present (ignored untracked), body `FAIL` | Invalid failed-run marker |
| `matlab_error.log` | Present (ignored), 582 bytes, LastWrite 2026-05-04 | Diagnostic append/create from phi2 failure stack |
| `tables/alpha_structure.csv` | Absent | No side effect |
| `tables/kappa1_from_PT.csv` | Absent | No side effect |
| `figures/infra_04_agent24h_replacement/` | Absent | No side effect |
| `tables/infra_04_agent24h_replacement_correlations.csv` | Absent | No side effect |
| `figures/alpha_vs_T.png` | Present, March 2026 mtime | Pre-existing local artifact (ignored); not INFRA-04C May output |
| `reports/alpha_structure_report.md` | Present, March 2026 mtime | Pre-existing local artifact (ignored); not INFRA-04C May output |
| INFRA-04C maintenance `reports/maintenance/repo_agent24h_matlab_replacement_INFRA_04C.md` + tables | Untracked | Valid maintenance evidence — preserved |

## 4. Invalid placeholder artifacts

The phi2 script catch block wrote **one-row NaN** metrics and companion kernel/regime stubs; the report file contained only **`FAIL`**. These could be mistaken for science outputs if left in place. **Git** does not track these paths (ignore rules: `tables/*metrics*`, `reports/**`, etc.).

## 5. What was preserved

- All INFRA-04C maintenance markdown and CSV artifacts under `reports/maintenance/` and `tables/maintenance_repo_agent24h_matlab_replacement_INFRA_04C_*`.
- Legacy CV07 PNGs (unchanged by this task).
- `matlab_error.log` (failure stack trace for phi2 run — diagnostic, not a numeric table placeholder).
- Pre-existing March 2026 `figures/alpha_vs_T.png` and `reports/alpha_structure_report.md`.
- No edits to `tools/agent24h_render_figures.ps1`, `tools/agent24h_render_figures_matlab_replacement.m`, or any analysis script.

## 6. What was removed

**Deleted (working tree only), explicit paths:**

1. `tables/phi2_structure_metrics.csv`
2. `tables/phi2_kernel_comparison.csv`
3. `tables/phi2_regime_stability.csv`
4. `reports/run_phi2_shape_physics_test.md`

**Rationale:** Each satisfied the task gate — newly written on the INFRA-04C attempt date, clearly invalid placeholder or FAIL-only content, untracked (ignored), not INFRA maintenance evidence.

## 7. What still requires manual decision

- **`matlab_error.log`:** Keep for debugging or delete/truncate locally if a clean log is desired; not classified as a numeric placeholder.
- **Overwrite concern:** If an operator had **non-placeholder** local phi2 tables **before** 2026-05-04, they may have been overwritten by the failed run; deletion of placeholders does **not** restore prior content — restore only from backup if needed.
- **Canonical pipeline:** No repair of legacy runs or generators per charter; see INFRA-04D canonical-only routing.

## 8. Canonical-only scope confirmation

This cleanup **did not** repair missing `switching_alignment_core_data.mat`, old PT runs, or stale generator paths. It only **removed misleading NaN/FAIL** artifacts and documented the rest.

## 9. Recommended next step

If CV07 MATLAB replacement is revisited, follow **reader-hub / canonical** governance (see INFRA-04D) rather than regenerating legacy March-2026 run folders solely to refill phi2 tables. Locally, optionally remove `matlab_error.log` after copying the stack trace if desired.

---

**Audit metadata:** No MATLAB, Python, Node, or PowerShell execution; no `git clean`; no stage, commit, or push; ASCII only.
