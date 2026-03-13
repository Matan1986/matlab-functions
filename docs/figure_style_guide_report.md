# Figure Style Guide Report

Last updated: March 10, 2026

## Main principles introduced

- The new guide converts the repository's broad readability rules into publication-grade requirements with fixed font sizes, fixed figure widths in centimeters, explicit axis styling, and a controlled export standard.
- It establishes a strict color policy: `parula` as the default sequential map, a documented diverging map only for zero-centered signed data, and a color-blind safe categorical palette for discrete curves.
- It formalizes the repo's common figure families into reusable publication patterns: heatmaps, temperature cuts, time cuts, observable-vs-temperature panels, and multi-panel comparison layouts.
- It adds a strict publication mode that forbids common diagnostic shortcuts such as `jet`, dense legends, 3D plots, dual y-axes, oversized titles, and ambiguous unit formatting.

## How it extends `visualization_rules.md`

- It preserves the existing repository rules around readability, `axis xy` heatmaps, labeled colorbars, and the legend-versus-colormap threshold at six curves.
- It adds measurable requirements that `visualization_rules.md` does not currently define: exact font sizes, standard publication widths, tick and box policy, marker and fit styling, panel-label placement, and final export requirements.
- It also upgrades the current export baseline. The repository helper [tools/save_run_figure.m](/C:/Dev/matlab-functions/tools/save_run_figure.m) already saves `300 dpi PNG + FIG`; the new guide keeps that archival behavior and adds vector PDF plus `600 dpi` PNG for final paper figures.

## Repository scan summary

Representative scan findings:

- Heatmaps are already a major pattern and are typically created with `imagesc`, explicit natural-axis orientation, and labeled colorbars in files such as [Aging/analysis/aging_geometry_visualization.m](/C:/Dev/matlab-functions/Aging/analysis/aging_geometry_visualization.m), [Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m](/C:/Dev/matlab-functions/Relaxation%20ver3/diagnostics/run_relaxation_geometry_observables.m), and several Switching analyses.
- Multi-panel layouts are already common and mostly use `tiledlayout` and `nexttile`, which makes the proposed panel-spacing and shared-axis rules compatible with current figure construction.
- The current figure culture is diagnostic-first: many scripts use large fonts, frequent grid lines, in-panel titles, and `300 dpi` PNG exports, which are readable for analysis but not yet a complete publication standard.
- Export behavior is already centralized enough to support future enforcement through [tools/save_run_figure.m](/C:/Dev/matlab-functions/tools/save_run_figure.m), even though that helper does not yet emit PDF.

## Recommendations for future figure auditing

- Audit all figures intended for manuscripts against the publication-mode checklist in [docs/figure_style_guide.md](/C:/Dev/matlab-functions/docs/figure_style_guide.md).
- Prioritize high-frequency figure families first: heatmaps, temperature-cut overlays, time-collapse overlays, and observable-vs-temperature panels.
- Flag these recurring issues explicitly during review: mixed unit styles, oversized titles, legends inside data regions, non-shared color limits across comparison maps, and diagnostic-only plots being promoted directly into manuscripts.
- Review figure sets as sets, not one file at a time, because the new guide treats cross-figure consistency as a compliance requirement.

## Suggested helper utilities

These are documentation-only recommendations. They are not implemented here.

- `apply_publication_style(fig_or_axes, mode)` to set fonts, tick direction, box rules, line widths, and publication-mode defaults
- `repo_colormap(kind, n)` to centralize approved sequential, diverging, and categorical palettes
- `add_panel_labels(fig, labels)` to place aligned `a`, `b`, `c` labels in figure coordinates
- `set_figure_size_cm(fig, width_cm, height_cm)` to standardize on the guide's dimensional rules
- `export_publication_figure(fig, base_name, run_dir)` to add PDF and `600 dpi` PNG export on top of the existing archival FIG behavior
