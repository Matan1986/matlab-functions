# Figure Export Infrastructure

Date: March 10, 2026

## Purpose

This document converts the figure audit into a minimal, pipeline-safe plan for publication figure repairs.

It focuses on:

- current export behavior in the repository
- the smallest safe upgrade to [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m)
- the reference repair pattern for [`Switching/analysis/switching_alignment_audit.m`](/C:/Dev/matlab-functions/Switching/analysis/switching_alignment_audit.m)

This is a planning document only. No MATLAB code is changed here.

## Repository Constraints

Relevant repository rules from the governing docs:

- outputs must remain under `results/<experiment>/runs/<run_id>/...`
- artifact generation should use repository helpers where possible
- figure repairs must not change physics logic or pipeline flow
- publication rules come from [docs/figure_style_guide.md](/C:/Dev/matlab-functions/docs/figure_style_guide.md)

Implication for repair planning:

- the safest path is to preserve existing analysis logic and data flow
- repairs should happen after plotting, just before export
- run-root resolution and file naming should stay centralized in one helper

## Current Export Stack

### 1. Run-context creation

Current run-aware infrastructure already exists:

- [`Aging/utils/createRunContext.m`](/C:/Dev/matlab-functions/Aging/utils/createRunContext.m)
- [`Aging/utils/getResultsDir.m`](/C:/Dev/matlab-functions/Aging/utils/getResultsDir.m)
- [`tools/getRunOutputDir.m`](/C:/Dev/matlab-functions/tools/getRunOutputDir.m)
- [`tools/init_run_output_dir.m`](/C:/Dev/matlab-functions/tools/init_run_output_dir.m)

Current behavior:

- `createRunContext` creates canonical run roots such as `results/switching/runs/run_<timestamp>_<label>/`
- `getResultsDir` is run-aware: if an active run exists, it returns `results/<experiment>/runs/<run_id>/<analysis>/...`
- `init_run_output_dir` currently returns an analysis subdirectory like `results/switching/runs/<run_id>/alignment_audit/`

Assessment:

- run-context rules are already largely respected
- figure export is not yet normalized to the canonical `figures/` subfolder when scripts bypass the helper layer

### 2. Canonical figure helper

Current helper:

- [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m)

Current behavior:

- accepts `(figure_handle, figure_name, run_output_dir)`
- resolves the nearest `run_*` root from the provided path
- creates `<run_root>/figures/` if needed
- exports:
  - `figure_name.png` via `exportgraphics(..., 'Resolution', 300)`
  - `figure_name.fig` via `savefig(...)`
- returns `paths.png` and `paths.fig`

What it gets right:

- central run-root resolution
- canonical `figures/` directory creation
- stable base-name export
- editable FIG archival behavior

Gaps versus the publication guide:

- no vector PDF export
- PNG locked at `300 dpi`, not `600 dpi`
- no publication/export options struct
- no style hook before export
- returned struct has no PDF path field

### 3. Supplemental legacy helpers

There are older formatting/export utilities, but they are not the canonical run-helper path:

- [`General ver2/figureSaving/save_PDF.m`](/C:/Dev/matlab-functions/General ver2/figureSaving/save_PDF.m)
- [`General ver2/appearanceControl/CommonFormatting/formatAllFigures.m`](/C:/Dev/matlab-functions/General ver2/appearanceControl/CommonFormatting/formatAllFigures.m)
- [`General ver2/appearanceControl/CommonFormatting/postFormatAllFigures.m`](/C:/Dev/matlab-functions/General ver2/appearanceControl/CommonFormatting/postFormatAllFigures.m)
- [`General ver2/appearanceControl/CommonFormatting/formatThreeFiguresForPaper.m`](/C:/Dev/matlab-functions/General ver2/appearanceControl/CommonFormatting/formatThreeFiguresForPaper.m)

Assessment:

- useful formatting logic already exists and should be reused where practical
- current presets are not publication-guide compliant for this repository
- they operate on all open figures or use older paper presets, so they are not yet suitable as the repository-wide single-figure publication entry point

## Current Behavior of `switching_alignment_audit.m`

Target script:

- [`Switching/analysis/switching_alignment_audit.m`](/C:/Dev/matlab-functions/Switching/analysis/switching_alignment_audit.m)

### Output-path behavior

The script initializes output with:

- `init_run_output_dir(repoRoot, 'switching', 'alignment_audit', parentDir)`

Current consequence:

- tables and figures are written into `results/switching/runs/<run_id>/alignment_audit/`
- review ZIPs are written into the run root `review/` folder

Assessment:

- this is run-scoped and pipeline-safe
- it is not yet canonical figure storage, because figure PNGs are written straight into the analysis subfolder rather than `<run_root>/figures/`

### Figure/export footprint

Static counts from the current script:

- figure handles created: **68**
- `tiledlayout` blocks: **17**
- `imagesc` heatmaps: **23**
- `plot` calls: **73**
- scatter/scatter3 calls: **5**
- colorbars: **27**
- legends: **21**
- `saveas` calls: **64**
- `save_run_figure` calls: **0**
- `exportgraphics` calls: **0**

### Style behavior

Observed publication-style mismatches:

- figure sizes are set in pixels, not centimeters
- fonts are not centralized; labels/ticks rely on defaults or ad hoc sizes
- `grid on` is used broadly across line plots and many panel figures
- `legend(..., 'Location', 'best')` appears in several important figures
- `turbo` is used repeatedly for unsigned heatmaps and reconstructions
- no shared post-plot style pass exists
- no panel-label overlay exists for multi-panel publication figures

### Figure categories inside the script

The script already has a natural grouping that supports a non-invasive overlay approach:

1. Sequential heatmaps
   - switching map
   - normalized map
   - SVD/NMF reconstructions
   - map with ridge
   - ridge-collapse map

2. Diverging heatmaps
   - residual maps
   - `dS/dI`
   - `d^2S/dI^2`
   - background-subtracted map
   - curvature map

3. Single-panel line/scatter figures
   - scree / explained variance
   - ridge curves
   - width / peak / susceptibility observables
   - stability plots

4. Multi-panel diagnostic figures
   - mode observables
   - ridge laws
   - derivative panels
   - grouped observables
   - two-panel summary layouts

That grouping makes it realistic to apply a style profile at export time without rewriting plotting code.

## Minimal Upgrade Plan for `save_run_figure.m`

### Goal

Turn [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m) into the central publication export point while keeping all existing callers valid.

### Recommended minimal behavior change

Keep the current signature valid:

```matlab
paths = save_run_figure(fig, figure_name, run_output_dir)
```

Recommended backward-compatible extension:

```matlab
paths = save_run_figure(fig, figure_name, run_output_dir, opts)
```

Where `opts` is optional and defaults preserve existing call sites.

### Proposed default behavior

For all callers, keep these guarantees:

- save editable `.fig`
- save reviewable `.png`
- keep the same base filename
- write into `<run_root>/figures/`

Upgrade the defaults to publication-safe archival output:

- `.png` at `600 dpi`
- `.fig` retained
- `.pdf` vector export attempted by default

Recommended return struct:

```matlab
paths.png
paths.fig
paths.pdf
```

### Proposed options struct

Minimal options only:

```matlab
opts.png_resolution   % default 600
opts.export_pdf       % default true
opts.pdf_content_type % default 'vector'
opts.save_fig         % default true
opts.background_color % default 'white'
```

### Backward-compatibility rules

- existing 3-argument calls must keep working unchanged
- existing consumers of `paths.png` and `paths.fig` must not break
- adding `paths.pdf` must be additive only
- if PDF export fails, warn and still write PNG + FIG
- run-root resolution logic should remain unchanged

### Recommended code changes for `tools/save_run_figure.m`

Do not implement yet; these are the planned changes.

1. Keep the current input contract and root-resolution logic.
2. Add optional `opts` parsing with safe defaults.
3. Change PNG export from `300` to `600` dpi.
4. Add vector PDF export:

```matlab
exportgraphics(fig, paths.pdf, 'ContentType', 'vector', 'BackgroundColor', 'white');
```

5. Preserve `savefig(fig, paths.fig)`.
6. Print all produced artifact paths.
7. Keep failure handling non-fatal for PDF so older workflows do not collapse on renderer edge cases.

### Why this is minimal

- one helper change upgrades every caller that already uses `save_run_figure`
- no analysis logic changes
- no artifact-location policy changes
- no new dependency on GUI tools or manual formatting

## Minimal Style Overlay Design

### Goal

Apply publication formatting after plotting, on an existing figure handle, without changing how data are computed or drawn.

Conceptual usage:

```matlab
apply_publication_style(fig, profile)
```

### Reuse-first strategy

Do not build a parallel formatting system from scratch.

Recommended reuse path:

- reuse ideas from [`General ver2/appearanceControl/CommonFormatting/postFormatAllFigures.m`](/C:/Dev/matlab-functions/General ver2/appearanceControl/CommonFormatting/postFormatAllFigures.m)
- reuse margin/alignment logic from [`General ver2/appearanceControl/publicationCore/normalizeAxesMarginsUnified.m`](/C:/Dev/matlab-functions/General ver2/appearanceControl/publicationCore/normalizeAxesMarginsUnified.m)
- expose a repository-facing single-figure wrapper under `tools/` or extend an existing formatter to accept an explicit figure handle and publication profile

### What the overlay should enforce

For all publication-targeted figures:

- font family `Helvetica` with `Arial` fallback
- tick labels `8 pt`
- axis labels `9 pt`
- colorbar ticks `8 pt`
- colorbar label `9 pt`
- legends `8 pt`, box off, outside when used
- figure units/paper units in centimeters
- standard single-column or double-column size
- line/scatter axes: `TickDir='out'`, `Box='off'`, `LineWidth=0.8-1.0`
- heatmaps: `YDir='normal'` or `axis xy`, `Box='on'`
- line objects normalized to publication-visible widths
- interpreters default to `tex`

### What the overlay should not change

- no recomputation of observables
- no changes to data selection or smoothing
- no axis-limit changes unless explicitly passed in
- no automatic relabeling of scientific variables beyond typography/unit formatting cleanup
- no mandatory colormap remapping unless the caller requests a sequential or diverging publication profile

### Recommended style profiles

Use a small explicit profile set rather than one giant auto-detector:

- `curve_single`
- `curve_multi`
- `heatmap_sequential`
- `heatmap_diverging`
- `panel_multi`

That keeps call sites readable and avoids hidden style decisions.

## Recommended Minimal Code Changes for `switching_alignment_audit.m`

Do not implement yet; these are the planned changes.

### 1. Add one local export wrapper near the bottom of the script

Planned wrapper behavior:

```matlab
function paths = export_alignment_figure(fig, base_name, outDir, style_profile)
    runRoot = outDir;
    apply_publication_style(fig, style_profile);
    paths = save_run_figure(fig, base_name, runRoot);
end
```

Why this is minimal:

- keeps plotting blocks intact
- centralizes the style + export handoff in one place
- lets the script continue to assign PNG paths for logs and ZIP assembly

### 2. Replace `saveas(fig, fullfile(outDir, 'name.png'))` with wrapper calls

Pattern change only, for example:

```matlab
paths = export_alignment_figure(figSvdScree, 'switching_alignment_svd_scree', outDir, 'curve_single');
svdScreeOut = paths.png;
```

For heatmaps:

```matlab
paths = export_alignment_figure(figHeat, 'switching_alignment_heatmap', outDir, 'heatmap_sequential');
heatOut = paths.png;
```

For residual maps:

```matlab
paths = export_alignment_figure(figRes2, 'switching_alignment_residual_rank2', outDir, 'heatmap_diverging');
residualRank2Out = paths.png;
```

### 3. Do not touch data generation or figure-construction order

Leave unchanged:

- observables/tables/CSV generation
- SVD/NMF logic
- existing figure handles and base filenames
- ZIP assembly logic except for adding PDF files later if desired

### 4. Publication subset first, then broad rollout

For minimal risk, repair the high-value publication-facing figures in this order:

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

After those work cleanly, the same wrapper can be applied to the remaining diagnostic outputs mechanically.

### 5. Specific style goals for the target script

For heatmaps in this script:

- replace `turbo` sequential maps with `parula`
- keep diverging maps only for signed residual/derivative views
- keep colorbar labels, but move formatting into the overlay
- preserve explicit ridge overlays and shared axis semantics

For line/multi-curve figures:

- remove `legend(...,'best')` in publication-facing outputs
- move legends outside when `<= 6` curves
- preserve colorbar-based encodings for dense temperature/current stacks
- remove default full-grid backgrounds unless a specific panel truly needs them

For multi-panel figures:

- keep the existing `tiledlayout`
- add panel labels through the overlay, not through plotting rewrites
- avoid using both large panel titles and a large figure title at once

## Recommended Reusable Repair Pattern

This should become the reference pattern for later scripts.

1. Identify the figure block and assign a stable base filename.
2. Build the figure exactly as the current script already does.
3. Apply a thin publication overlay to the completed figure handle.
4. Export through the upgraded [`save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m).
5. Use the returned `paths.png` / `paths.pdf` / `paths.fig` for reports and review packaging.

Conceptually:

```matlab
fig = build_existing_figure(...);
apply_publication_style(fig, 'panel_multi');
paths = save_run_figure(fig, 'switching_alignment_two_panel', outDir);
```

This pattern is reusable because it:

- does not alter analysis logic
- does not require figure-by-figure replotting logic changes
- preserves run-root rules automatically
- centralizes style and export in two helper calls

## Recommended Implementation Order

1. Upgrade [`tools/save_run_figure.m`](/C:/Dev/matlab-functions/tools/save_run_figure.m).
2. Add the single-figure publication overlay by extending existing formatting logic rather than inventing a separate style stack.
3. Convert [`Switching/analysis/switching_alignment_audit.m`](/C:/Dev/matlab-functions/Switching/analysis/switching_alignment_audit.m) to the wrapper pattern.
4. Reuse the exact same pattern in:
   - [`Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m`](/C:/Dev/matlab-functions/Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m)
   - [`Aging/analysis/aging_geometry_visualization.m`](/C:/Dev/matlab-functions/Aging/analysis/aging_geometry_visualization.m)

That sequence gives the smallest safe path to publication-quality figures without repository-wide refactoring.
