# Figure Style Audit Report

Date: March 10, 2026

## Scope

This audit reviewed MATLAB figure-generation code against [docs/figure_style_guide.md](/C:/Dev/matlab-functions/docs/figure_style_guide.md) and [docs/visualization_rules.md](/C:/Dev/matlab-functions/docs/visualization_rules.md).

Included scope:

- `Aging/`
- `Relaxation ver3/`
- `Switching/`
- `Switching ver12/` where current Switching analysis still depends on legacy plotting/output code
- `analysis/` cross-experiment figure scripts
- shared figure/export helpers in `tools/` and `General ver2/`

Excluded from detailed scoring:

- generated `results/`
- docs
- most test-only GUI validation code

Method:

- static scan of MATLAB source for figure creation, layout, typography, axes, colormap, legend, sizing, and export patterns
- no MATLAB scripts were modified
- no figures were regenerated

Static-analysis caveat:

- some scripts may receive manual post-formatting after export
- this audit still marks them non-compliant unless publication settings are encoded in the script/helper path itself

## Executive Summary

Repository visualization health is **poor for publication mode but salvageable with shared-helper work**.

- Audited files in scope: **119**
- Direct figure-producing scripts: **99**
- Shared helper/export utilities: **20**
- No audited direct figure script met the publication standard end-to-end from source alone.

Dominant figure types in the audited set:

| Figure type | Count |
| --- | ---: |
| Multi-panel comparison | 46 |
| Temperature cuts | 34 |
| Observable curves | 12 |
| Heatmap | 5 |
| Time cuts | 2 |
| Helper utility | 20 |

The biggest systemic issue is export compliance: every audited file has at least one export-rule gap, and the canonical helper [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m) still stops at `300 dpi` PNG + FIG, so publication PDF export is not available through the main repository path.

## Violation Counts

| Category | Count | What the count means |
| --- | ---: | --- |
| Export rules | 119 | Missing PDF/vector export, `saveas`/`print` usage, helper limitations, or non-canonical artifact flow |
| Typography | 99 | All direct figure scripts lack explicit publication typography compliance |
| Figure dimensions | 99 | All direct figure scripts lack explicit centimeter + paper-size control |
| Axes / line styling | 95 | Line widths are implicit or outside publication targets |
| Legend policy | 61 | Legends are inside data regions, left on `best`, or used in dense curve stacks |
| Color policy | 17 | `jet` or `turbo` appears in publication-adjacent scripts |
| Panel layout | 45 | Multi-panel layouts lack explicit `a/b/c` panel labels |
| Heatmap orientation | 20 | Heatmap/image panels do not explicitly enforce `axis xy` or `YDir='normal'` |

Additional recurring notes:

- tick direction not explicitly set to `out`: **98**
- full grid backgrounds enabled: **70**
- square-bracket unit formatting instead of publication parentheses: **30**
- heatmap scripts with no explicit colorbar call: **3**

## Most Common Problems

### 1. Export stack is not publication-ready

- `saveas` is still used in **38** audited scripts.
- `save_run_figure` is used in **8** scripts, but it only writes PNG + FIG and does not emit PDF or `600 dpi` PNG.
- **21** scripts still show legacy flat-results behavior instead of a run-scoped helper flow.

Representative files:

- [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m)
- [`Aging/analysis/aging_geometry_visualization.m`](/C:/Dev/matlab-functions/Aging/analysis/aging_geometry_visualization.m)
- [`Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m`](/C:/Dev/matlab-functions/Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m)
- [`Switching/analysis/switching_alignment_audit.m`](/C:/Dev/matlab-functions/Switching/analysis/switching_alignment_audit.m)

### 2. Publication typography is almost entirely absent at script level

- no direct figure script explicitly sets Helvetica/Arial defaults consistently
- font sizes are usually review-scale (`12-16 pt`) rather than publication-scale (`8/9/11 pt`)
- unit formatting frequently uses square brackets rather than the required parentheses style

### 3. Figure size is controlled in pixels, not publication centimeters

- most scripts set screen `Position` only
- centimeter `Units`, `PaperUnits`, `PaperPosition`, and `PaperSize` are almost never encoded
- this makes journal-width reproducibility impossible from the script alone

### 4. Axes defaults drift from the guide

- `TickDir='out'` is usually missing
- `grid on` is common, despite the guide discouraging full-grid backgrounds
- axes `LineWidth` is often implicit or oversized for publication layouts

### 5. Multi-panel scripts are visually under-specified

- panel labels are absent in **45** multi-panel scripts
- legends frequently sit inside data regions
- panel spacing/layout may be compact, but the publication identity of each panel is often unclear

### 6. Forbidden colormaps still appear in publication-adjacent figures

Observed colormap violations:

- `turbo`: mostly Relaxation and Switching diagnostics
- `jet`: Aging memory plots and older Relaxation/Aging scripts

Representative files:

- [`Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m`](/C:/Dev/matlab-functions/Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m)
- [`Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m`](/C:/Dev/matlab-functions/Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m)
- [`Switching/analysis/switching_alignment_audit.m`](/C:/Dev/matlab-functions/Switching/analysis/switching_alignment_audit.m)
- [`Aging/plotAgingMemory.m`](/C:/Dev/matlab-functions/Aging/plotAgingMemory.m)

## Modules Most Affected

By script volume:

| Module | Audited scripts |
| --- | ---: |
| Aging | 41 |
| Relaxation | 24 |
| Switching legacy layer | 22 |
| Shared helpers | 20 |
| Switching active analysis | 10 |
| Cross-experiment | 2 |

By total issue marks:

- Aging: **157**
- Switching ecosystem (`Switching/` + `Switching ver12/`): **116**
- Relaxation: **91**

Interpretation:

- **Aging** has the broadest cleanup surface area.
- **Switching** has the highest publication risk concentration because its main audit/survey scripts generate many manuscript-style composites but still rely on `saveas`, `turbo`, and in-panel legends.
- **Relaxation** has fewer scripts than Aging, but several of its most visible figure producers are already close to publication use and therefore deserve early repair.

## Representative High-Risk Scripts

### Aging

- [`Aging/analysis/aging_geometry_visualization.m`](/C:/Dev/matlab-functions/Aging/analysis/aging_geometry_visualization.m)
  - good run-helper integration, but still uses non-publication sizing, mixed color policies, bracket-style units, full grids, and inherits the PNG/FIG-only export helper
- [`Aging/diagnostics/diagnose_mode1_separability.m`](/C:/Dev/matlab-functions/Aging/diagnostics/diagnose_mode1_separability.m)
  - likely publication-adjacent decomposition figure set with heatmaps, collapse plots, legends, and forbidden `turbo`

### Relaxation

- [`Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m`](/C:/Dev/matlab-functions/Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m)
  - structurally well organized, but still lacks publication font family, cm sizing, panel labeling, and PDF export
- [`Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m`](/C:/Dev/matlab-functions/Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m)
  - highly visible derivative/map figure generator with repeated `turbo`, `saveas`, internal legends, and no publication geometry control

### Switching

- [`Switching/analysis/switching_alignment_audit.m`](/C:/Dev/matlab-functions/Switching/analysis/switching_alignment_audit.m)
  - the single highest-leverage switching target; generates maps, observables, SVD figures, and comparison panels but keeps legacy export/style behavior
- [`Switching/analysis/switching_mechanism_survey.m`](/C:/Dev/matlab-functions/Switching/analysis/switching_mechanism_survey.m)
  - likely to be reused in talks/manuscripts, yet still uses `saveas`, internal legends, full grids, and no publication sizing

## Helper-Layer Findings

The repository already has the right conceptual hook points, but they are not yet aligned with the publication guide.

Key helper gaps:

- [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m)
  - should be the canonical path, but currently blocks PDF-first publication export
- [`General ver2/figureSaving/save_PDF.m`](/C:/Dev/matlab-functions/General ver2/figureSaving/save_PDF.m)
  - emits PDF through `print`, but sits outside the run-helper path and forces Arial rather than the repository’s Helvetica-first standard
- [`General ver2/appearanceControl/CommonFormatting/formatThreeFiguresForPaper.m`](/C:/Dev/matlab-functions/General ver2/appearanceControl/CommonFormatting/formatThreeFiguresForPaper.m)
  - provides “paper” formatting, but its font sizes and PNG-only export pattern do not match the stricter publication guide

## Suggested Infrastructure Improvements

Do not implement these in this audit; they are recommended next steps.

1. Extend [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m) into a publication-capable helper that can emit `PDF + 600 dpi PNG + FIG` with one base name.
2. Add a shared `apply_publication_style(ax, mode)` helper that enforces Helvetica/Arial fallback, `8/9/11 pt` typography, tick direction, box policy, and axis line widths.
3. Add a heatmap wrapper that always enforces `axis xy`, approved colormaps, labeled colorbars, and optional shared color limits.
4. Add a multi-curve policy helper that switches automatically between outside legends and colorbars based on curve count.
5. Add a lightweight repository audit/lint script that flags `jet`, `turbo`, `saveas`, missing PDF export, and missing cm sizing before figures are declared publication-ready.

## Bottom Line

The repository already contains many useful scientific figure scripts, but publication styling is mostly being handled ad hoc. The fastest way to improve repository-wide figure quality is not one-by-one script cleanup alone; it is to first repair the shared export/style path, then update the highest-visibility Aging, Relaxation, and Switching scripts that feed publication-facing heatmaps and summary panels.
