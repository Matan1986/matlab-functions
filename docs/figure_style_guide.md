# Figure Style Guide

Last updated: March 10, 2026

This document is the authoritative publication-style reference for figures in `matlab-functions`.

It extends [docs/visualization_rules.md](/C:/Dev/matlab-functions/docs/visualization_rules.md) with stricter, measurable requirements for figures intended for papers, talks, thesis chapters, and publication-ready review bundles. It does not replace the existing repository visualization rules; it narrows them into a publication standard.

## Scope

- Apply [docs/visualization_rules.md](/C:/Dev/matlab-functions/docs/visualization_rules.md) to all analysis and diagnostic figures.
- Apply this guide to any figure claimed to be publication-ready.
- If a rule in this document is stricter than the general visualization rules, follow this document for publication figures.
- Do not modify pipelines or experiment logic to satisfy style choices; adjust only plotting and export behavior when publication work is performed.

## Core principles

- Clarity first: every panel must answer one physics question clearly.
- Consistency second: the same physical quantity must look the same across related figures.
- Density last: remove information before shrinking text or adding more panels.

## 1. Typography

### Font family

- Required default font family: `Helvetica`
- Acceptable fallback when `Helvetica` is unavailable: `Arial`
- Do not mix serif and sans-serif fonts within one figure.

### Required font sizes

| Element | Size |
| --- | ---: |
| Tick labels | 8 pt |
| Axis labels | 9 pt |
| Colorbar label | 9 pt |
| Colorbar ticks | 8 pt |
| Legend text | 8 pt |
| Standalone figure title | 9 pt |
| Panel title inside a multi-panel figure | 8 pt maximum |
| Panel label `a`, `b`, `c` | 11 pt, bold |
| Annotations / fit parameters | 8 pt |

Rules:

- No text smaller than 7 pt in the final exported figure.
- Do not use panel titles and a large figure title at the same time unless the figure is standalone outside a multi-panel layout.
- Multi-panel publication figures should prefer panel labels plus caption text over per-panel titles.

### Interpreter usage

- Default interpreter for labels, legends, and annotations: `tex`
- Use `latex` only when `tex` cannot express the required notation.
- Do not use `latex` for plain words such as `Temperature`, `time`, or `current`.
- Do not mix `tex` and `latex` for visually similar labels in the same panel unless required by notation.

### Label style

- Use sentence-style labels, not file names or variable names.
- Write units in parentheses: `Temperature (K)`, `Current (mA)`, `log_{10}(t_{rel} / s)`.
- Use roman units, italic variables, and explicit normalization when needed.
- Use one unit style per figure set. Publication mode uses parentheses, not square brackets.
- Use `\Delta`, subscripts, and superscripts only when physically necessary.

Recommended MATLAB defaults:

```matlab
set(groot, ...
    'defaultTextFontName', 'Helvetica', ...
    'defaultAxesFontName', 'Helvetica', ...
    'defaultAxesFontSize', 8, ...
    'defaultLegendFontSize', 8, ...
    'defaultAxesTickLabelInterpreter', 'tex', ...
    'defaultTextInterpreter', 'tex', ...
    'defaultLegendInterpreter', 'tex');
```

## 2. Figure Dimensions

Use centimeters for all publication figures.

### Standard sizes

| Figure class | Width | Recommended height | Typical use |
| --- | ---: | ---: | --- |
| Single-column | 8.6 cm | 5.5-7.0 cm | Single heatmap, single curve, 2 stacked small panels |
| Double-column | 17.8 cm | 6.5-11.5 cm | Side-by-side panels, map plus cuts, comparison figures |

### Aspect-ratio rules

- Single-panel line/scatter figures: width:height between `1.25` and `1.55`
- Single-panel heatmaps: width:height between `1.20` and `1.50`
- Tall mode-profile stacks: use vertical multi-panel layouts rather than shrinking one panel below 4.5 cm height
- Do not exceed 12.5 cm total figure height without a compelling journal-specific reason

### MATLAB sizing rule

Set both screen and paper size explicitly:

```matlab
set(fig, ...
    'Units', 'centimeters', ...
    'Position', [2 2 8.6 6.2], ...
    'PaperUnits', 'centimeters', ...
    'PaperPosition', [0 0 8.6 6.2], ...
    'PaperSize', [8.6 6.2], ...
    'Color', 'w');
```

## 3. Axes Formatting

Required defaults for line, scatter, and curve panels:

- `LineWidth = 0.8` to `1.0`
- `TickDir = 'out'`
- `Box = 'off'`
- `Layer = 'top'`
- `XMinorTick = 'off'`
- `YMinorTick = 'off'`

Required defaults for heatmaps and image-style panels:

- `LineWidth = 0.8` to `1.0`
- `TickDir = 'out'`
- `Box = 'on'`
- `Layer = 'top'`

Additional rules:

- Use at most 5 major ticks per axis unless dense ticks are physically necessary.
- Use minor ticks only for log axes or when a small number of minor ticks materially improves reading.
- Publication figures should not use full grid lines by default.
- If grid lines are necessary, use major grid only, light gray, and line width `<= 0.3 pt`.
- Do not use `yyaxis` in publication figures.
- Align shared axes exactly in multi-panel figures.
- Use identical axis limits when panels compare the same quantity.

## 4. Line and Marker Styling

### Data curves

- Primary measured curve: `LineWidth = 1.8` to `2.2`
- Secondary reference curve: `LineWidth = 1.2` to `1.6`
- Marker size for data points: `5` to `7`
- Error-bar cap size: `6` to `8`

### Fit curves

- Fit curves must differ from data by style, not only by color.
- Preferred fit styling: solid or dashed line, `LineWidth = 1.4` to `1.8`, no markers.
- If the data use markers, the fit must not use markers.
- If the fit overlays the same color family as the data, make the fit darker neutral gray or black.

### Marker policy

- Use markers for sparse measured points, not for dense sampled curves.
- For more than 50 points per curve, markers should be omitted or shown every `8` to `12` points.
- Filled markers must have a visible edge when printed.

### Print-visibility rules

- Never encode a key comparison using line color alone when the figure may be printed in grayscale.
- Distinguish key curves with a combination of color, line style, and marker choice.

## 5. Color Policy

### Approved continuous colormaps

- Default sequential map: `parula(256)`
- Grayscale reproduction: `gray(256)`
- Approved diverging map: blue-white-red with a white midpoint, only for signed data with a meaningful zero

### Categorical palette

Use a color-blind safe categorical palette. Preferred order:

| Name | Hex |
| --- | --- |
| Black | `#000000` |
| Blue | `#0072B2` |
| Orange | `#E69F00` |
| Bluish green | `#009E73` |
| Vermillion | `#D55E00` |
| Sky blue | `#56B4E9` |
| Reddish purple | `#CC79A7` |
| Yellow | `#F0E442` |

Rules:

- Keep the same variable mapped to the same color direction across a figure set.
- Low-to-high ordered quantities must keep a monotonic lightness progression.
- Use no more than 6 categorical colors in one panel before switching to a continuous encoding plus colorbar.

### Forbidden colormaps and practices

- `jet`
- `hsv`
- rainbow-style custom maps
- red-green pairings as the only distinction between compared curves
- arbitrary per-figure color choices that change the meaning of temperature, wait time, mode index, or current from panel to panel

Publication-mode note:

- `turbo` may appear in existing diagnostics, but it is not approved for final publication figures in this repository.

## 6. Heatmap Rules

Heatmaps are a primary figure type in this repository and must follow these rules.

### Construction

- Preferred MATLAB primitive: `imagesc` on a standard `axes`
- Do not use MATLAB `heatmap` charts for publication figures unless the data are categorical and image axes are not suitable.
- Set orientation explicitly with `axis(ax, 'xy')` or `set(ax, 'YDir', 'normal')`.

### Colorbar rules

- Every heatmap must have a colorbar.
- The colorbar must be labeled with quantity and units.
- Use 4 to 6 major colorbar ticks.
- Place the colorbar on the right unless a shared layout requires otherwise.

### Normalization and limits

- If zero is physically meaningful, use symmetric color limits around zero with a diverging map.
- If comparing the same observable across multiple panels, keep the same color limits across those panels.
- If color limits are data-driven, document the rule in the caption or report.
- Do not clip extreme values silently.

### Surface appearance

- No overlaid grid on dense heatmaps.
- No smoothing at display time unless the processing step is physically justified and documented.
- Use nearest-neighbor display of the actual matrix by default.
- If contour overlays are added, use at most 3 contour levels and ensure they remain readable over the colormap.

### Labeling

- Label both axes with quantity and units.
- State the color quantity in the colorbar label, not only in the title.
- Use concise titles for standalone diagnostics only. Final paper figures should move heatmap explanation into the caption.

## 7. Legend Policy

### When to use legends

- Use a legend for `2` to `4` discrete curves when direct labels would clutter the panel.
- Prefer direct labeling for `2` to `4` clearly separated curves.
- For `5` to `6` curves, use a legend only if it fits outside the data region.
- For `> 6` ordered curves, replace the legend with a colorbar keyed to the ordering variable.

### Legend formatting

- Maximum legend entries per panel: `6`
- Maximum legend footprint: `15%` of the panel area
- Preferred placement: outside the plotting area
- Legend box: `off`

### Do not use legends when

- A continuous variable such as temperature, time, or wait time is encoded by color
- The same information is better expressed by panel labels or direct annotations
- The legend would cover extrema, crossings, or fit residuals

## 8. Panel Layout

### Single-panel figures

- Use one panel when the figure communicates one observable or one map clearly.
- Do not add decorative inset panels unless they carry necessary physical information.

### Two-panel figures

Preferred uses:

- map plus representative cuts
- observable plus residual or fit comparison
- temperature-side and time-side views of the same quantity

Rules:

- Horizontal two-panel layout: use double-column width (`17.8 cm`) unless both panels remain readable at single-column width
- Gap between aligned panels: `0.18` to `0.30 cm`
- Share axes where comparison is direct

### Three-panel figures

Preferred uses:

- low / transition / high temperature comparison
- map, temperature cut, and time cut
- observable, fit, and residual

Rules:

- Use double-column width
- Keep all panels equal width unless one panel is explicitly designated as the primary panel
- Use one shared legend or one shared colorbar whenever possible

### Panel labels

- Required for any figure with more than one data panel
- Use bold lowercase letters: `a`, `b`, `c`
- Place at the upper-left outside the plotting region, aligned across the row
- Panel labels must not overlap tick labels or data

Recommended MATLAB approach:

- Use `text(ax, ...)` in normalized coordinates for axis-tied labels
- Use `annotation` only when panel labels must align at figure level

## 9. Export Rules

### Required archival exports

The repository already uses editable `.fig` plus raster `.png` exports through [tools/save_run_figure.m](/C:/Dev/matlab-functions/tools/save_run_figure.m). Publication work must preserve that editable archive behavior.

Required archival files:

- `.fig`
- `.png`

### Required publication exports

For final paper figures, also export:

- `.pdf` as the primary vector file
- `.png` at high resolution for quick review

Optional only when a journal requires raster delivery:

- `.tif` at `600 dpi` or higher

### Resolution rules

- Review PNG: `300 dpi` minimum
- Publication PNG: `600 dpi`
- Do not rasterize line art unnecessarily
- Use vector PDF for line plots, scatter plots, and mixed vector figures whenever possible

### Repository-wide strict naming linkage

The STRICT figure-window naming convention is defined in [docs/visualization_rules.md](/C:/Dev/matlab-functions/docs/visualization_rules.md) under Figure Window Naming (STRICT) and is mandatory for publication figures as well.

### Naming convention

- Use lowercase snake_case
- Keep one base name across all export formats
- Include experiment and figure content
- Append `_pub` for final paper figures

Example:

- `aging_deltaM_map_pub.pdf`
- `aging_deltaM_map_pub.png`
- `aging_deltaM_map_pub.fig`

### MATLAB export guidance

```matlab
exportgraphics(fig, 'aging_deltaM_map_pub.pdf', 'ContentType', 'vector');
exportgraphics(fig, 'aging_deltaM_map_pub.png', 'Resolution', 600);
savefig(fig, 'aging_deltaM_map_pub.fig');
```

If transparency or painter issues appear, document the fallback and keep the vector-first export attempt in the workflow.

## 10. Figure Types Used in This Repository

### Heatmaps

Recommended layout:

- Single panel for one map
- Two-panel figure for map plus representative cuts

Rules:

- `x` and `y` axes must be physical variables with units
- Colorbar label must name the mapped observable
- Use `parula` for unsigned maps
- Use a symmetric diverging map only for signed deviations around zero
- No grid over the map

Example structure:

- Panel `a`: `\Delta M(T, log_{10} t)`
- Panel `b`: representative fixed-`T` or fixed-`t` cuts extracted from the same map

### Temperature cuts

Recommended layout:

- Single-panel overlay when `<= 6` curves
- Map-plus-cuts layout when temperature cuts are derived from a heatmap

Rules:

- `x` axis: `Temperature (K)`
- Curves ordered by the secondary parameter
- Use legend or direct labels for `<= 6` curves
- Use colorbar for `> 6` ordered curves
- Mark physically important reference temperatures with thin vertical guide lines only when necessary

Example structure:

- `\Delta M(T)` for selected wait times
- `A(T)` with peak marker and half-maximum guide

### Time cuts

Recommended layout:

- Single panel with `x` as `log_{10}(t / s)` when the range spans more than one decade
- Two-panel figure when both linear-time and log-time views are required

Rules:

- Use logarithmic time axes for broad relaxation windows
- Use temperature as the color-encoding variable when many curves are shown
- Keep master-curve or fit overlays in black or dark gray
- Avoid legends for dense temperature stacks

Example structure:

- normalized collapse curves colored by temperature
- dominant mode `v_1(t)` with fit overlays

### Observable vs temperature plots

Recommended layout:

- Single panel per observable
- Stacked aligned panels for multiple observables with a shared temperature axis

Rules:

- Do not use dual y-axes
- Measured values: markers or marker-line combination
- Fits or trends: thinner line without markers
- Use the same temperature limits across related observables

Example structure:

- `I_{peak}(T)`
- `width_I(T)`
- `Relax_peak_width(T)`

### Multi-panel comparison figures

Recommended layout:

- Two aligned panels for direct pairwise comparisons
- Three aligned panels for map / cut / summary combinations

Rules:

- Use shared legends or shared colorbars wherever possible
- Align plotting regions, not just outer axes boxes
- Keep panel labels mandatory
- Remove repeated y-axis labels when axes are shared
- 3D plots are diagnostic-only and should be converted to 2D projections for publication mode

Example structure:

- `a`: heatmap
- `b`: temperature cuts
- `c`: extracted observable versus temperature

## 11. Publication Mode

Publication mode is the strictest compliance level for final paper figures.

### Required settings

- Font family fixed to `Helvetica`
- Tick labels `8 pt`, axis labels `9 pt`, panel labels `11 pt bold`
- Figure size fixed to one of the standard single-column or double-column widths
- Only approved colormaps from this guide
- No `jet`, no `turbo`, no rainbow maps
- No titles inside multi-panel figures unless absolutely necessary
- No full-grid backgrounds
- No dual y-axes
- No 3D axes
- Use PDF vector export plus `600 dpi` PNG plus editable FIG

### Minimal-clutter rules

- Remove redundant legends, titles, and repeated axis labels
- Remove decorative boxes and unnecessary grid lines
- Use one visual emphasis method at a time: either color, or marker, or line style hierarchy
- Keep annotation text to essential physical information only

### Publication-mode acceptance checklist

A figure is publication-ready only if all of the following are true:

- The figure width is `8.6 cm` or `17.8 cm`
- All text is at least `7 pt`
- Axes labels include units
- Panel labels are present for multi-panel figures
- Color meaning is consistent with related figures
- Legends are absent, direct, or outside the data region
- Heatmaps use explicit orientation and labeled colorbars
- Exports include PDF, PNG, and FIG with a shared base name

## Audit checklist

When reviewing a figure set for compliance, verify:

- typography matches the required sizes and font family
- units use parentheses consistently
- line widths and marker sizes are print-visible
- curve-count rules match legend vs colorbar decisions
- heatmaps use consistent color limits across comparisons
- panel spacing and labels are aligned
- final exports include vector PDF and high-resolution PNG

