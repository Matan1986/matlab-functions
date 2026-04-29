# Switching — Corrected-old reconstruction quality / residual-decomposition metrics closure (post–TASK_001)

## Purpose

Close the **reconstruction-quality and residual-decomposition metrics layer** for the **corrected-old authoritative** path after TASK_001 finite-grid closure, without changing builder physics or authoritative map tables. Provide **diagnostic QA figures** (PNG only, non-publication) for human review.

**Note on task IDs:** In `tables/switching_missing_reconstruction_tasks.csv`, **TASK_002** is named *Authoritative old-vs-corrected backbone parity bridge*. This deliverable uses the user’s **TASK_002** label for **quality-metrics closure + visual QA**. The program’s parity-bridge task is unchanged and should still be run when ready; see `PROGRAM_TASK_ID_NOTE` in `tables/switching_corrected_old_quality_metrics_closure_status.csv`.

## Inputs inspected

- Reconstruction program: `reports/switching_corrected_canonical_reconstruction_program.md`, `tables/switching_missing_reconstruction_tasks.csv`, `tables/switching_corrected_canonical_reconstruction_program_status.csv`.
- TASK_001: `reports/switching_corrected_old_finite_grid_interpolation_audit.md` and associated finite-grid tables.
- Authoritative outputs: `reports/switching_corrected_old_authoritative_builder.md`, `tables/switching_corrected_old_authoritative_*` (backbone, residual, mode1, residual_after_mode1, phi1, kappa1, quality_metrics, builder_status).
- **Legacy artifact presence:** `residual_decomposition_quality.csv` was **not** found under this workspace’s `results_old` / `results` trees at audit time. Old metric names were recovered from **`Switching/analysis/switching_residual_decomposition_analysis.m`** (quality table columns) and **`analysis/knowledge/run_registry.csv`** references.

## Driver script (metrics + figures)

- `Switching/diagnostics/run_switching_corrected_old_task002_quality_QA_and_closure.m`  
  - Reads authoritative CSVs only.  
  - Writes `tables/switching_corrected_old_quality_metrics_consistency_check.csv`, `tables/switching_corrected_old_quality_metrics_by_T.csv`, and diagnostic PNGs.  
  - **PNG only** (no `.fig` / `.pdf`) per task override; figure `Name` matches saved basename per `docs/visualization_rules.md` naming rule.  
  - Uses `parula`, `axis xy` on heatmaps, `FontSize` 14 and `LineWidth` 2 defaults for readability.

## Required questions — answers

1. **What old metrics existed?**  
   From `switching_residual_decomposition_analysis`: `rank1_energy_fraction`, `rank12_energy_fraction`, `dominance_ratio_1_over_2`, `low_window_rows`, `low_window_rmse`, `low_window_relative_error`, `low_window_median_curve_corr`, `low_window_p10_curve_corr`, `cdf_rows_from_pt`, `cdf_rows_from_fallback` (exported in `residual_decomposition_quality.csv` per run).

2. **Which are replaced by authoritative corrected-old outputs?**  
   Global fit summaries: **`switching_corrected_old_authoritative_quality_metrics.csv`** (`rmse_backbone_only`, `rmse_after_mode1`, `improvement_factor_backbone_to_mode1`, `svd_mode1_explained_variance`, `fraction_finite_aligned_residual`, `interpolation_failures_count`, coverage keys). **Maps** in authoritative backbone/residual/mode1/residual_after_mode1 tables subsume legacy collapse/reconstruction views for the corrected-old recipe.

3. **What needs canonical recomputation from authoritative tables?**  
   **Per-T RMSE / mean abs residual** (this task) — `tables/switching_corrected_old_quality_metrics_by_T.csv`. Optional relative-error or correlation-style metrics **if** manuscript later requires them — define narrowly first (`needs_decision` in matrix).

4. **What should be deprecated?**  
   Metrics tied to **fallback CDF rows** or **non–corrected-old alignment/scaling** are **deprecated for the manuscript path** (`FALLBACK_USED=NO` gates). **Mixed canonical diagnostic** PT/CDF/mode columns remain forbidden as corrected-old evidence (unchanged governance).

5. **Internal consistency?**  
   Yes: backbone–residual and mode-1 / residual-after identities hold at **machine epsilon** on stacked rows where mode1 is finite; RMSE scalars **replay** from maps within **relative tolerance** of the shortened strings stored in `quality_metrics.csv`. **SVD explained variance** is **not** recomputed without the aligned residual matrix export (**CHK007** `not_applicable`).

6. **Per-T metrics needed?**  
   **Not strictly blocking** global downstream tasks; **recommended** for T-heterogeneity review (e.g. **30 K** shows higher `rmse_after_mode1` in `by_T` table). **FIG_QA_004** visualizes them.

7. **Residual-after-mode documentation for rank-1 closure?**  
   Sufficient for **rank-1**: identity verified; `rmse_after_mode1` and improvement factor documented; TASK_001 explains NaN pattern on mode1 maps. **Rank-2+** remains explicitly **out of scope** here (see program **TASK_007**).

8. **Safe to proceed?**  
   **Yes** for further reconstruction families that depend on understanding quality (asphalt: not blocked by this layer). Program **publication** gate remains **PARTIAL**.

9. **What to inspect visually?**  
   See § Visual QA below and `tables/switching_corrected_old_quality_metrics_visual_QA_manifest.csv`.

## Visual QA (what to look for)

| Figure | What to check |
|--------|----------------|
| **FIG_QA_001** backbone / residual / mode1 / residual-after heatmaps | Overall coherence; NaN bands on mode1/residual-after at same `(T,I)` as expected from phi support (TASK_001). |
| **FIG_QA_002** Phi1 + kappa1 | Single-humped Phi1 on finite `x`; kappa1 trend vs `T` including small magnitude at 30 K. |
| **FIG_QA_003** residual before vs after | Reduction of large-scale structure in the interior currents where mode1 is finite. |
| **FIG_QA_004** quality by T | Whether fit degradation concentrates at warm `T` (e.g. 22–30 K) for planning crossover/asymmetry work. |

## Deliverables list

- `reports/switching_corrected_old_quality_metrics_closure.md` (this file).  
- `tables/switching_corrected_old_quality_metrics_closure_status.csv`  
- `tables/switching_corrected_old_quality_metrics_inventory.csv`  
- `tables/switching_corrected_old_quality_metrics_reconstruction_matrix.csv`  
- `tables/switching_corrected_old_quality_metrics_consistency_check.csv`  
- `tables/switching_corrected_old_quality_metrics_visual_QA_manifest.csv`  
- `tables/switching_corrected_old_quality_metrics_by_T.csv`  
- `tables/switching_corrected_old_quality_metrics_recommended_actions.csv`  
- PNGs under `figures/switching/diagnostics/corrected_old_task002_quality_QA/`  
- Script `Switching/diagnostics/run_switching_corrected_old_task002_quality_QA_and_closure.m`  

## Next reconstruction task (program order)

Per `tables/switching_missing_reconstruction_tasks.csv`, after TASK_001 the next **program-listed** dependency for several branches is the **authoritative old-vs-corrected backbone parity bridge** (still labeled **TASK_002** in that CSV). This **quality closure** does not replace that parity task; run it when ready using authoritative tables plus **legacy backbone reference paths** defined there (not mixed canonical diagnostics).

## Publication figures

**Not yet fully authorized:** `SAFE_TO_CREATE_PUBLICATION_FIGURES` remains **PARTIAL** per reconstruction program. Diagnostic QA PNGs here are **explicitly not** publication-ready and must not satisfy the publication gate.

---

*Closure completed under Switching-only, metrics-only constraints; no authoritative artifacts modified.*
