# Visualization Systems

Last updated: 2026-03-21

## Scope
This file catalogs figure/plot/GUI/edit/export subsystems found across the repository.

## System 1: GUIs (modern + legacy GUI stack)

- Location: `GUIs/`
- Entry points:
  - `GUIs/FigureControlStudio.m`
  - `GUIs/FinalFigureFormatterUI.m`
  - `GUIs/FinalFigureFormatterGUI.m`
  - `GUIs/CtrlGUI.m`
  - `GUIs/SmartFigureEngine.m` (core engine class)
- Purpose:
  - interactive formatting and styling
  - figure composition and export
  - annotation/legend/typography controls
- Dependencies:
  - optional `github_repo/ScientificColourMaps8`
  - MATLAB figure/uifigure runtime
  - internal appdata and pref keys for UI state
- Module decision:
  - standalone snapshot candidate: **yes** (`visualization_stack` module)

## System 2: Shared canonical figure helpers

- Location: `tools/figures/`
- Entry points:
  - `tools/figures/create_figure.m`
  - `tools/figures/apply_publication_style.m`
  - `tools/figures/figure_quality_check.m`
- Purpose:
  - non-GUI standardized figure creation and quality checks
- Dependencies:
  - used by active science scripts and `tools/save_run_figure.m`
- Module decision:
  - keep in `core_infra` (required)

## System 3: Figure repair subsystem

- Location: `tools/figure_repair/`
- Entry points:
  - `tools/figure_repair/repair_fig_file.m`
  - `tools/figure_repair/repair_fig_directory.m`
  - `tools/figure_repair/run_validation_suite.m`
- Purpose:
  - repair/export/refit legacy figure assets with validation metadata
- Dependencies:
  - run helper and figure helper ecosystem in `tools/`
- Module decision:
  - include in `visualization_stack` (optional) or keep with `core_infra` when figure-repair workflows are required

## System 4: Legacy visualization utilities (repro only)

- Location:
  - `General ver2/appearanceControl/`
  - `General ver2/figureSaving/`
  - `General ver2/Plot Metadata API ver1/`
- Purpose:
  - historical formatting, colormap, figure saving, annotation policies
- Status:
  - `General ver2/README_LEGACY.md` marks this layer as legacy and non-canonical for new development
- Dependencies:
  - still reachable in broad-path executions and some historical pipelines
- Module decision:
  - include only in `legacy_science_archive` or `visualization_stack_legacy` for strict reproducibility

## System 5: Analysis-layer figure exports

- Locations:
  - `Aging/analysis/`, `Switching/analysis/`, `Relaxation ver3/diagnostics/`, `analysis/`
- Pattern:
  - mostly `save_run_figure` in active scripts
  - some transitional scripts still use direct `saveas`, `print`, or custom export logic
- Module decision:
  - not a separate module; covered by active science modules + `core_infra`

## Packaging Recommendation

- Recommended dedicated optional ZIP: `visualization_stack.zip`
- Suggested includes:
  - `GUIs/`
  - `tools/figures/`
  - `tools/figure_repair/`
  - optional `github_repo/ScientificColourMaps8/`
  - optional legacy supplement from `General ver2/` when reproducibility requires it
