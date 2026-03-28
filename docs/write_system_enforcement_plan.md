# Write-system enforcement plan (mapping only)

**Date:** 2026-03-24  
**Basis:** `docs/AGENT_RULES.md`, `docs/results_system.md`, `docs/output_artifacts.md`, `docs/repo_consolidation_plan.md`, `docs/repo_audit_report.md`, `docs/repo_state.json`.  
**Scope:** Inventory and **minimal fix proposals** only — **no code changes** in this task.

---

## 0. Compliance rubric

| Verdict | Meaning |
|--------|---------|
| **YES** | Outputs go only under `results/<experiment>/runs/run_<timestamp>_<label>/` with canonical subfolders; artifacts use **`save_run_figure` / `save_run_table` / `save_run_report`** (or **`export_observables`** / explicit **`observables.csv`** at run root per exception). Run metadata from **`createRunContext`** (or equivalent documented pipeline hook). |
| **PARTIAL** | Destination is under a canonical **run folder** and layout is mostly right, but **bypasses** mandated helpers (`writetable`, `saveas`, `fopen`+`fprintf` to artifact paths), **missing** standard run metadata from `createRunContext`, **wrong artifact subfolder** for ZIPs, or **duplicate** tables outside `tables/` (e.g. copies under `reports/`). |
| **NO** | Writes analysis/diagnostic **products** outside `results/.../runs/...` (e.g. repo-root **`reports/`**, **`tmp_debug_outputs/`**, module-tree outputs not under `results/`), or uses **forbidden parallel roots** for new science outputs. |

**Caveats**

- **Infrastructure** implementing helpers (`tools/save_run_table.m`, `tools/save_run_figure.m`, `tools/export_observables.m`, `Aging/utils/createRunContext.m`) is **YES** by definition.
- **GUI / interactive** tools (`FigureControlStudio`, export dialogs) often write **user-chosen paths** — not fully classified here; treat as **process risk**, not a single file verdict.
- This scan used **`writetable`**, **`saveas`**, **`imwrite`**, **`exportgraphics`**, **`fopen(...,'w')`**, and targeted **`reports/`** path patterns. It does **not** exhaust every `save(...)` or MEX I/O call in ~690+ `*.m` files.

---

## 1. Summary statistics (automated grep)

| Mechanism | Approx. file count (`*.m`) | Typical compliance |
|-----------|----------------------------|-------------------|
| `writetable(` | **48** (current grep) | Mixed: infra YES; many **NO/PARTIAL** |
| `saveas(` | **45** | Mostly **NO/PARTIAL** (legacy figure export) |
| `imwrite(` | **8** | **General ver2** / **Fitting ver1** — **NO** for new work per `AGENT_RULES` |
| `exportgraphics(` | **22** | Mixed: includes **`tools/save_run_figure.m`** (YES); GUIs/analysis **PARTIAL/ambiguous** |
| `fopen(...,'w'` / `'wt'` etc. | **~40+** | Mixed: run logs/metadata YES; ad-hoc writers **PARTIAL/NO** |

---

## 2. Confirmed **NO**: outputs outside `results/.../runs/...`

These scripts write (or create) **analysis-style artifacts under repo-root `reports/`** or other non-run roots:

| File | What is written | Where | Verdict |
|------|-----------------|-------|---------|
| `scripts/run_adversarial_observable_search.m` | Markdown report | `fullfile(repo_root, 'reports', 'adversarial_observable_report.md')` | **NO** |
| `reports/functional_form_test_analysis.m` | Markdown + CSV metrics | `fullfile(repo_root, 'reports', 'functional_form_test_report.md')`, `..._metrics.csv` | **NO** |
| `tools/survey_audit/audit_run_reviews.m` | Markdown audit | `fullfile(repoRoot, 'reports', 'run_review_audit.md')` (creates `reports/` if missing) | **NO** |

**Related (non-results tree, tooling/docs):**

| File | What is written | Where | Verdict |
|------|-----------------|-------|---------|
| `GenerateREADME.m` | Generated docs | `fullfile(rootDir, 'docs', 'reports', 'legacy', ...)` | **NO** vs *science* results policy (acceptable as **doc tooling** if scoped). |

**Test / debug sinks (not canonical run system):**

| File | What is written | Where | Verdict |
|------|-----------------|-------|---------|
| `Aging/tests/switching_stability/run_diagnostic_wrapped.m` | Diary log | `tmp_debug_outputs/switching_stability/` | **NO** (test harness; policy should be explicit) |
| `Aging/verification/verifyRobustBaseline_WithLogging.m` | Log | `tmp_debug_outputs/verification/` | **NO** (verification harness) |

---

## 3. Special cases (requested)

### 3.1 `analysis/run_unified_barrier_mechanism.m`

| Aspect | Current behavior | Verdict |
|--------|------------------|---------|
| Run root | `results/cross_experiment/runs/run_<ts>_unified_barrier_mechanism/` | **PARTIAL** (path OK) |
| Layout | Creates `figures/`, `tables/`, `reports/`, `review/` | **PARTIAL** (folders OK) |
| Factory | Local **`createRun`** — **not** `createRunContext` → **no** standard `run_manifest.json` / `config_snapshot.m` / `log.txt` parity with `run_system.md` | **PARTIAL** |
| I/O | **`writetable`** to `tables/`; **`saveas`/figure export** patterns in same file family; **`writeText`** for `run_notes.txt` | **PARTIAL** (bypasses `save_run_*`) |

**Minimal fix (when touched):** Call **`createRunContext('cross_experiment', runCfg)`** at startup; replace **`writetable(..., projectionCsv)`** with **`save_run_table(..., runDir)`**; use **`save_run_report`** for markdown; ensure **`review/`** ZIP via same helpers or documented zip utility.

### 3.2 `scripts/run_adversarial_observable_search.m`

| Aspect | Current behavior | Verdict |
|--------|------------------|---------|
| Output | Report under **`repo_root/reports/`** | **NO** |

**Minimal fix:** `createRunContext('cross_experiment', ...)` → **`save_run_report(..., runDir)`** (and optional **`save_run_table`** if tabular outputs are added). Target: `results/cross_experiment/runs/run_<ts>_adversarial_observable_search/reports/...`.

### 3.3 `run_threshold_distribution_model.m`

| Aspect | Current behavior | Verdict |
|--------|------------------|---------|
| Run directory | Manually builds `results/switching/runs/run_<timestamp>_threshold_distribution_model/` + subfolders | **PARTIAL** |
| Tables/figures | Uses **`save_run_table`**, **`save_run_figure`** | **PARTIAL** (good) |
| Report | **`write_text_file`** + **`fopen(...,'w')`** to `.../reports/analysis_summary.md` | **PARTIAL** (should be **`save_run_report`**) |
| Metadata | Does **not** use **`createRunContext`** | **PARTIAL** |
| Inputs | Hard-coded legacy path under `.../alignment_audit/` inside a run | **PARTIAL** (fragile provenance; separate from write-location rule) |

---

## 4. Full write-path map (by mechanism)

### 4.1 `writetable` — file list and classification

**Infrastructure (YES)**

- `tools/save_run_table.m`
- `tools/export_observables.m` (if used for CSV index)

**Policy exception at run root (YES)**

- `Switching/analysis/switching_effective_observables.m` — `observables.csv` at run root (`AGENT_RULES` exception).
- `Aging/analysis/aging_structured_results_export.m` — run-root `observables.csv` (verify alongside `createRunContext`).

**Under canonical run tree but raw API (PARTIAL)** — prefer `save_run_table`

- `analysis/run_unified_barrier_mechanism.m`
- `Switching/analysis/switching_alignment_audit.m` (if any direct `writetable` remains alongside helpers)
- `Switching/analysis/switching_mechanism_survey.m`, `switching_mechanism_followup.m`, `switching_shape_rank_analysis.m`, `switching_observable_stability_survey.m`, `switching_second_structural_observable_search.m`, `switching_second_coordinate_duel.m`, `switching_observable_basis_test.m`

**Legacy / diagnostic / non-run outputs (NO or PARTIAL)**

- **Aging:** `Aging/diagnostics/*.m` (many files), `Aging/pipeline/stage9_export.m`, `Aging/pipeline/runPhaseC_leaveOneOut.m`, `Aging/pipeline/stageC2_sweepDipWindow.m`, `Aging/analysis/debugAgingStage4.m`, `Aging/verification/verifyRobustBaseline_RealData.m`
- **Relaxation:** `Relaxation ver3/diagnostics/survey_relaxation_observables.m`, `visualize_relaxation_*.m`, `validate_relaxation_band_boundaries.m`, `relaxation_corrected_geometry_analysis.m`, `analyze_relaxation_derivative_smoothing.m`, `render_relaxation_derivative_interpretable.m`
- **Fitting / instrument:** `Fitting ver1/*.m`, `zfAMR ver11/appended_dat_files.m`
- **Reports folder script:** `reports/functional_form_test_analysis.m` (**NO**)
- **Cross-experiment:** `analysis/cross_experiment_observables.m` (confirm destination; likely run-scoped or **PARTIAL**)

**Interactive / ambiguous**

- `Relaxation ver3/showRelaxationFitTable.m` — user-facing path.

### 4.2 `saveas` — file list (all **PARTIAL** or **NO** for new agent work)

Present in **45** files, concentrated in:

- `Aging/diagnostics/*.m`, `Aging/models/analyzeAFM_FM_derivative.m`, `Aging/verification/*.m`
- `Relaxation ver3/diagnostics/*.m`, `Relaxation ver3/aging_geometry_visualization.m`
- `Fitting ver1/*.m`
- `Switching/analysis/switching_*survey*.m`, `switching_mechanism_followup.m`, `switching_shape_rank_analysis.m`, `switching_ridge_curvature_analysis.m`, `switching_second_*.m`, `switching_observable_basis_test.m`
- `analysis/cross_experiment_observables.m`, `analysis/switching_observable_summary.m`

**Minimal fix pattern:** create/reuse run dir → **`save_run_figure(fig, baseName, runDir)`**; enforce `docs/visualization_rules.md` naming.

### 4.3 `imwrite`

All **8** occurrences live under **`General ver2/figureSaving/`** and **`Fitting ver1/fit_script_ver_sinN.m`**. For **new** work this is **NO** per `AGENT_RULES` (no new `General ver2` figure utilities).

### 4.4 `exportgraphics`

Includes **`tools/save_run_figure.m`** (**YES**). Other call sites (e.g. `GUIs/FigureControlStudio.m`, `ARPES ver1/run_arpes_dual.m`, several `analysis/switching_a1_*.m`, `analysis/barrier_landscape_reconstruction.m`, `analysis/creep_activation_scaling.m`) need **per-call** review: if the path is not routed through **`save_run_figure`**, treat as **PARTIAL** unless output is explicitly user-selected.

### 4.5 `fopen` / `fprintf` writers

- **YES** when appending to **`run.log_path`**, **`run_notes.txt`**, or paths created by **`createRunContext`** (pattern used across many analyses).
- **PARTIAL** when writing **`reports/*.md`** via custom helpers instead of **`save_run_report`** (e.g. `run_threshold_distribution_model.m` `write_text_file`).
- **NO** for repo-level audit output (`audit_run_reviews.m`).

---

## 5. Hotspot identification (small set, most violations)

| Hotspot | Role | Est. impact |
|---------|------|-------------|
| **`Aging/diagnostics/*.m`** | High volume of **`writetable` + `saveas`** to diagnostic output trees | Largest legacy cluster |
| **`Relaxation ver3/diagnostics/*`** (non–`run_relaxation_*` runners) | Survey / visualization scripts with variable `outDir` | Second largest |
| **`Fitting ver1/*.m`** | Fitting exports | Isolated cluster |
| **`Switching/analysis/switching_*survey*.m` + mechanism/shape scripts** | Mixed modern + raw saves | High visibility |
| **Repo-root `reports/` writers** (`run_adversarial`, `functional_form_test_analysis`, `audit_run_reviews`) | **Clear policy violations** | Few files, **high priority** |
| **`analysis/run_unified_barrier_mechanism.m`** | Parallel run factory + raw `writetable` | Single file, **high structural impact** |
| **`General ver2/figureSaving`** | `imwrite` stack | Legacy attractor for wrong pattern |

---

## 6. Minimal fix plan (per hotspot)

### 6.1 Repo-root `reports/` (three files)

| File | Exact change | `createRunContext` hook | Target path |
|------|--------------|-------------------------|-------------|
| `scripts/run_adversarial_observable_search.m` | Replace `report_path` construction with `save_run_report` after run creation | `createRunContext('cross_experiment', struct('runLabel', ...))` at start | `results/cross_experiment/runs/run_<ts>_adversarial_observable_search/reports/adversarial_observable_report.md` |
| `reports/functional_form_test_analysis.m` | Same pattern for `.md` and any CSV via `save_run_table` | `createRunContext('cross_experiment', ...)` | `.../reports/`, `.../tables/` under that run |
| `tools/survey_audit/audit_run_reviews.m` | Write with `save_run_report` **or** document as tooling exception; if science-facing, use `results/repository_audit/runs/` or `cross_experiment` per `results_system.md` rule 5–7 | Optional `createRunContext` with experiment `cross_experiment` or dedicated folder policy | Prefer `results/cross_experiment/runs/run_<ts>_run_review_audit/reports/run_review_audit.md` |

**Risk:** Low for first two (pure path change). **Medium** for `audit_run_reviews` if downstream consumers expect the old fixed path.

### 6.2 `analysis/run_unified_barrier_mechanism.m`

| Change | Detail |
|--------|--------|
| Replace **`createRun`** | Call **`createRunContext('cross_experiment', runCfg)`**; map returned `run.run_dir` to existing variable names. |
| Replace **`writetable`** | **`save_run_table(T, 'observable_barrier_projections.csv', runDir)`** (and second table likewise). |
| Figures | Route any **`saveas`** through **`save_run_figure`**. |
| Metadata / ZIP | Use standard **`review/`** zip pattern consistent with other analyses. |

**Risk:** **Medium** — must verify manifest fields and any tooling that assumes this run’s folder shape.

### 6.3 `run_threshold_distribution_model.m`

| Change | Detail |
|--------|--------|
| Run creation | **`createRunContext('switching', runCfg)`** instead of manual `mkdir` chain. |
| Report | Replace **`write_text_file`** with **`save_run_report(report_text, 'analysis_summary.md', runDir)`**. |

**Risk:** Low–medium (timestamp format / run id naming must stay consistent with other switching runs).

### 6.4 `Aging/diagnostics` and `Relaxation ver3/diagnostics` (bulk legacy)

**Per-file minimal pattern when touched:**

1. If outputs are meant to be **persistent science artifacts:** wrap in **`createRunContext('aging'|'relaxation', ...)`** and replace **`writetable`/`saveas`** with **`save_run_*`**.
2. If **scratch diagnostics:** either document as **non-run** debug (explicit policy) or write under **`results/<experiment>/runs/...`** anyway for traceability.

**Risk:** **High** if batch-converted without running tests (paths, `cfg` plumbing).

### 6.5 ZIP location mistakes

Example: **`x_necessity_and_pairing_tests.m`** builds **`reports/x_necessity_tests_bundle.zip`**. **`docs/output_artifacts.md`** requires ZIPs under **`review/`**.

| Change | Move bundle to `fullfile(runDir, 'review', ...)` and adjust `zip()` root list. |
|--------|-----|
| Risk | Low if only path + bundle list updated. |

---

## 7. Risk assessment

| Fix area | Safety | Breakage risk |
|----------|--------|----------------|
| Repo-root `reports/` → run-scoped | **High** | Consumers grep-opening fixed paths |
| `run_unified_barrier_mechanism` → `createRunContext` | **Medium** | Manifest/run listing tools; missing fields |
| `run_threshold_distribution_model` metadata alignment | **Medium** | Scripts that glob only `createRunContext`-style run ids |
| Mass update of `Aging/diagnostics` | **Low** if done blindly | **High** — breaks working diagnostics |
| GUI `exportgraphics` | **N/A** in bulk | User workflows / arbitrary paths |
| Retire `General ver2` saves in old scripts | **Low touch** | Old scripts stop exporting if dependencies removed |

---

## 8. Recommended execution order (when coding is allowed)

1. **Fix the three repo-root `reports/` writers** (small, unambiguous **NO** cases).  
2. **`run_adversarial_observable_search.m`** + **`functional_form_test_analysis.m`** first (science outputs).  
3. **`audit_run_reviews.m`** after deciding experiment label and whether output is “tooling” vs “run.”  
4. **`run_unified_barrier_mechanism.m`** and **`run_threshold_distribution_model.m`**.  
5. Opportunistic per-file cleanup in **Switching/analysis** surveys, then **Relaxation/Aging diagnostics** when those files are already edited.

---

## 9. Appendix — `writetable(` file paths (48, alphabetically)

```
Aging/analysis/aging_structured_results_export.m
Aging/analysis/debugAgingStage4.m
Aging/diagnostics/auditDecompositionStability.m
Aging/diagnostics/diagnose_baseline_subtracted_FM.m
Aging/diagnostics/diagnose_deltaM_svd_pca.m
Aging/diagnostics/diagnose_decomposition_audit_waittimes.m
Aging/diagnostics/diagnose_fit_vs_derivative_audit.m
Aging/diagnostics/diagnose_FM_construction_audit.m
Aging/diagnostics/diagnose_FM_sign_stability.m
Aging/diagnostics/diagnose_highT_basis_comparison.m
Aging/diagnostics/diagnose_linear_combo_switching.m
Aging/diagnostics/diagnose_mode1_separability.m
Aging/diagnostics/diagnose_shifted_basis_fit.m
Aging/diagnostics/diagnose_switching_regime_features.m
Aging/diagnostics/diagnose_waittime_to_current_mapping.m
Aging/pipeline/runPhaseC_leaveOneOut.m
Aging/pipeline/stage9_export.m
Aging/pipeline/stageC2_sweepDipWindow.m
Aging/verification/verifyRobustBaseline_RealData.m
analysis/cross_experiment_observables.m
analysis/run_unified_barrier_mechanism.m
analysis/switching_observable_summary.m
Fitting ver1/fit_script_sin2.m
Fitting ver1/fit_script_sin3.m
Fitting ver1/fit_sinxsin.m
Fitting ver1/fitSin2Folding.m
Fitting ver1/TwoSinMult.m
Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m
Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m
Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m
Relaxation ver3/diagnostics/survey_relaxation_observables.m
Relaxation ver3/diagnostics/validate_relaxation_band_boundaries.m
Relaxation ver3/diagnostics/visualize_relaxation_band_maps.m
Relaxation ver3/diagnostics/visualize_relaxation_geometry.m
Relaxation ver3/showRelaxationFitTable.m
reports/functional_form_test_analysis.m
Switching/analysis/switching_alignment_audit.m
Switching/analysis/switching_effective_observables.m
Switching/analysis/switching_mechanism_followup.m
Switching/analysis/switching_mechanism_survey.m
Switching/analysis/switching_observable_basis_test.m
Switching/analysis/switching_observable_stability_survey.m
Switching/analysis/switching_second_coordinate_duel.m
Switching/analysis/switching_second_structural_observable_search.m
Switching/analysis/switching_shape_rank_analysis.m
tools/export_observables.m
tools/save_run_table.m
zfAMR ver11/appended_dat_files.m
```

*(Classify each row using §4.1 when implementing.)*

---

## 10. Appendix — `saveas(` file paths (45)

```
Aging/analysis/debugAgingStage4.m
Aging/diagnostics/auditDecompositionStability.m
Aging/diagnostics/diagnose_baseline_subtracted_FM.m
Aging/diagnostics/diagnose_deltaM_shifted_byTp_waittimes.m
Aging/diagnostics/diagnose_deltaM_svd_pca.m
Aging/diagnostics/diagnose_decomposition_audit_waittimes.m
Aging/diagnostics/diagnose_decomposition_audit_waittimes_clean.m
Aging/diagnostics/diagnose_fit_vs_derivative_audit.m
Aging/diagnostics/diagnose_FM_construction_audit.m
Aging/diagnostics/diagnose_FM_sign_stability.m
Aging/diagnostics/diagnose_highT_basis_comparison.m
Aging/diagnostics/diagnose_linear_combo_switching.m
Aging/diagnostics/diagnose_mode1_separability.m
Aging/diagnostics/diagnose_shifted_basis_fit.m
Aging/diagnostics/diagnose_switching_regime_features.m
Aging/diagnostics/diagnose_waittime_to_current_mapping.m
Aging/models/analyzeAFM_FM_derivative.m
Aging/pipeline/runPhaseC_leaveOneOut.m
Aging/verification/verifyRobustBaseline_RealData.m
Aging/verification/verifyRobustBaseline_RealData_Main.m
analysis/cross_experiment_observables.m
analysis/switching_observable_summary.m
Fitting ver1/fit_script_sin3.m
Fitting ver1/fit_script_sin3_with_amp_force.m
Fitting ver1/fit_sin3_smooth_step.m
Fitting ver1/fit_sinxsin.m
Fitting ver1/fitSin2Folding.m
Fitting ver1/TwoSinMult.m
Relaxation ver3/aging_geometry_visualization.m
Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m
Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m
Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m
Relaxation ver3/diagnostics/survey_relaxation_observables.m
Relaxation ver3/diagnostics/validate_relaxation_band_boundaries.m
Relaxation ver3/diagnostics/visualize_relaxation_band_maps.m
Relaxation ver3/diagnostics/visualize_relaxation_geometry.m
Switching/analysis/switching_mechanism_followup.m
Switching/analysis/switching_mechanism_survey.m
Switching/analysis/switching_observable_basis_test.m
Switching/analysis/switching_observable_stability_survey.m
Switching/analysis/switching_ridge_curvature_analysis.m
Switching/analysis/switching_second_coordinate_duel.m
Switching/analysis/switching_second_structural_observable_search.m
Switching/analysis/switching_shape_rank_analysis.m
```

---

*End of enforcement plan (mapping only).*
