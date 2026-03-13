# Figure Repair Priority

Date: March 10, 2026

This document turns the audit into a concrete, minimal repair plan.

Repair principles:

- keep analysis logic unchanged
- keep run/output rules unchanged
- apply publication formatting after plotting, not during physics computation
- route exports through a single upgraded helper
- use the Switching alignment audit as the reference pattern for later scripts

## Reference Pattern

Reusable repair sequence for publication upgrades:

1. identify the existing figure block and keep its base filename
2. finish plotting with the current logic unchanged
3. apply a post-plot publication overlay to the completed figure handle
4. export through the upgraded [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m)
5. keep report/ZIP logic pointed at the returned artifact paths

Conceptual usage:

```matlab
fig = ... existing plotting code ...;
apply_publication_style(fig, 'heatmap_sequential');
paths = save_run_figure(fig, 'switching_alignment_heatmap', outDir);
```

Why this is the preferred pattern:

- no data-flow changes
- no pipeline refactor
- no figure recreation in a second script
- publication rules become centralized and reusable

## Repair Queue

### Tier 1: reference implementation and immediate reuse

| Priority | Script | Figure types produced | Why it is first |
| --- | --- | --- | --- |
| 1 | [`Switching/analysis/switching_alignment_audit.m`](/C:/Dev/matlab-functions/Switching/analysis/switching_alignment_audit.m) | heatmaps, cuts, observables, multi-panel comparison, decomposition diagnostics | best reference script for establishing the repair pattern |
| 2 | [`Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m`](/C:/Dev/matlab-functions/Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m) | heatmaps, scree/observable curves, stacked panels | already structured around helper-based exports |
| 3 | [`Aging/analysis/aging_geometry_visualization.m`](/C:/Dev/matlab-functions/Aging/analysis/aging_geometry_visualization.m) | heatmaps, temperature cuts, time/wait-time cuts, normalized overlays | already uses the run helper and needs mostly style/export repair |

### Tier 2: publication-adjacent follow-ups

- [`Switching/analysis/switching_mechanism_survey.m`](/C:/Dev/matlab-functions/Switching/analysis/switching_mechanism_survey.m)
- [`Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m`](/C:/Dev/matlab-functions/Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m)
- [`Aging/diagnostics/diagnose_mode1_separability.m`](/C:/Dev/matlab-functions/Aging/diagnostics/diagnose_mode1_separability.m)

### Tier 3: helper-layer cleanup that amplifies all later repairs

- [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m)
- formatting logic already present in:
  - [`General ver2/appearanceControl/CommonFormatting/postFormatAllFigures.m`](/C:/Dev/matlab-functions/General ver2/appearanceControl/CommonFormatting/postFormatAllFigures.m)
  - [`General ver2/appearanceControl/publicationCore/normalizeAxesMarginsUnified.m`](/C:/Dev/matlab-functions/General ver2/appearanceControl/publicationCore/normalizeAxesMarginsUnified.m)

## Concrete Repair Plan

### 1. [`Switching/analysis/switching_alignment_audit.m`](/C:/Dev/matlab-functions/Switching/analysis/switching_alignment_audit.m)

Reference-repair status:

- creates roughly **68** figure handles
- exports roughly **64** PNG files via `saveas`
- uses **0** calls to `save_run_figure`
- mixes heatmaps, line plots, tiled multi-panel figures, and color-encoded curve stacks

Detected style issues:

- `saveas` bypasses the canonical figure helper
- outputs land in the analysis subdirectory instead of canonical `figures/`
- repeated `turbo` usage for publication-facing heatmaps
- no centimeter/paper-size control
- no centralized typography
- many `grid on` line plots
- multiple legends use `Location='best'`
- multi-panel figures have no panel-label overlay

Minimal repair strategy:

- do not touch SVD/NMF/observable calculations
- do not rewrite plotting blocks
- add one local wrapper near the bottom of the script:
  - `export_alignment_figure(fig, base_name, outDir, style_profile)`
- wrapper responsibilities:
  - call `apply_publication_style(fig, style_profile)`
  - call `save_run_figure(fig, base_name, outDir)`
  - return `paths.png` so existing ZIP/report code can keep working
- replace `saveas(fig, fullfile(outDir, 'name.png'))` with the wrapper call at each figure endpoint

Style profiles to use:

- `heatmap_sequential`: main switching maps, normalized maps, ridge map, non-signed reconstructions
- `heatmap_diverging`: residual maps, `dS/dI`, `d^2S/dI^2`, background-subtracted map, curvature map
- `curve_single`: scree, ridge curve, width vs temperature, stability curves
- `curve_multi`: temperature cuts, current cuts, susceptibility cuts, scaling collapses
- `panel_multi`: tiled summary figures and grouped observable panels

Recommended first-pass figure subset:

1. `switching_alignment_heatmap`
2. `switching_alignment_map_with_ridge`
3. `switching_alignment_observables`
4. `switching_alignment_susceptibility_observables`
5. `switching_alignment_temperature_cuts`
6. `switching_alignment_current_cuts`
7. `switching_alignment_ridge_curve`
8. `switching_alignment_peak_width_vs_T`
9. `switching_alignment_derivative_tests`
10. `switching_alignment_two_panel`

These are the most publication-likely outputs and should define the reference pattern for the repository.

### 2. [`Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m`](/C:/Dev/matlab-functions/Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m)

Current status:

- already run-scoped
- already uses `save_run_figure`
- produces heatmaps, scree curve, stacked temperature-mode panels, and amplitude curves

Detected style issues:

- publication fonts and sizes are too large and not Helvetica-first
- figure size uses pixel `Position` only
- labels still use square-bracket time units in at least one map label
- grids remain enabled on publication-facing line plots
- no panel-label support for stacked panel layouts
- helper export still lacks PDF and `600 dpi` PNG

Minimal repair strategy:

- keep all plotting functions intact
- add `apply_publication_style(fig, profile)` immediately before each `save_run_figure` call inside:
  - `saveMapFigure`
  - `saveScreeFigure`
  - `saveTemperatureModesFigure`
  - `saveAmplitudeFigure`
- after helper upgrade, all outputs gain PDF + `600 dpi` PNG automatically without changing filenames or calling code

Specific cleanup targets:

- map profile: `heatmap_sequential` for unsigned maps, `heatmap_diverging` for residuals
- scree/amplitude profile: `curve_single`
- stacked mode profile: `panel_multi`
- convert `log_{10}(t_{rel} [s])` to publication parentheses style

### 3. [`Aging/analysis/aging_geometry_visualization.m`](/C:/Dev/matlab-functions/Aging/analysis/aging_geometry_visualization.m)

Current status:

- run-scoped
- already exports exclusively through `save_run_figure`
- produces heatmaps and curve overlays for aging dip analysis

Detected style issues:

- publication sizing still uses pixel `Position`
- typography is review-scale (`FontSize = 14`) rather than publication-scale
- heatmap/cut labels still use square-bracket unit style in places like `log_{10}(t_w [s])`
- full grids are enabled across the figure set
- helper colormap fallback still allows `turbo` and ultimately `jet`
- no centralized axis/legend/colorbar formatting

Minimal repair strategy:

- keep the existing figure blocks and filenames intact
- apply a publication overlay to each figure just before `save_run_figure`
- narrow `getPerceptualColormap` usage for publication outputs to approved maps only
- let the upgraded helper handle PDF + `600 dpi` PNG

Specific cleanup targets:

- `aging_map_heatmap` and `aging_dMdT_heatmap`: sequential/diverging heatmap profile as appropriate
- `aging_temperature_slices`, `aging_waittime_slices`, `aging_centered_temperature_slices`, `aging_normalized_dip_shape`: `curve_multi`
- keep legend/colorbar decision logic, but format the result centrally

## Minimal Style Overlay Specification

The overlay should operate on a figure handle after plotting and before export.

It should enforce:

- `Helvetica` default with `Arial` fallback
- tick labels `8 pt`
- axis labels `9 pt`
- legend text `8 pt`
- panel labels `11 pt` bold where requested
- `TickDir='out'`
- line/scatter axes `Box='off'`
- heatmaps `Box='on'` and `YDir='normal'`
- line widths adjusted into publication ranges
- legend moved outside when used
- figure size set in centimeters with matching `PaperPosition` and `PaperSize`
- colorbar tick and label formatting

It should not:

- recompute data
- change observables
- change axis limits unless explicitly requested
- replace the plot type itself

## Minimal Helper Upgrade Dependency

The plan depends on upgrading [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m) in a backward-compatible way so that all repaired scripts automatically gain:

- vector PDF export
- `600 dpi` PNG export
- retained FIG archive
- canonical `figures/` storage under the run root
- consistent shared base names across export formats

## Reusable Rollout Sequence

1. upgrade `save_run_figure`
2. add the single-figure publication overlay by extending existing formatting logic
3. convert `switching_alignment_audit.m` to the wrapper/export pattern
4. apply the same pattern to `run_relaxation_geometry_observables.m`
5. apply the same pattern to `aging_geometry_visualization.m`
6. reuse the exact pattern for later Tier 2 scripts

## Minimal End State

After the Tier 1 work, the repository should have a stable publication path that looks like this:

- figure is created by the existing analysis script
- publication overlay standardizes appearance
- upgraded helper writes `PDF + PNG + FIG` into the canonical run `figures/` folder

That is the smallest safe path to publication-quality output without repository-wide refactoring.
