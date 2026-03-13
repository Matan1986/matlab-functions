# Figure Repair System

## Purpose

The Figure Repair System provides a safe, explicit, opt-in workflow for turning existing `.fig` artifacts into publication-oriented exports without changing experiment pipelines or modifying the original figures in place.

The system is intended for final review and publication preparation when a run already contains archived editable FIG files under:

`results/<experiment>/runs/<run_id>/figures/`

## Architecture overview

All repair helpers live under:

`tools/figure_repair/`

Core functions:

- `inspect_fig_contents.m`: loads a FIG or figure handle and extracts a structured description of axes, lines, scatter objects, images, legends, colorbars, limits, interpreters, and figure sizing.
- `apply_fig_style_repair.m`: applies safe publication-style repairs to typography, interpreters, line widths, legend formatting, colorbar formatting, and figure sizing.
- `export_repaired_figure.m`: exports repaired outputs as PDF, PNG at 600 dpi, and FIG.
- `write_repair_metadata.m`: writes `repair_metadata.json` describing the source figure, requested repair, applied actions, and classification.
- `repair_fig_file.m`: the main explicit entry point for repairing one FIG file.
- `repair_fig_directory.m`: scans a figures directory and repairs each FIG into a sibling `repaired_figures/` tree.
- `demo_repair_example.m`: demonstration helper for intentionally running the workflow on an existing run artifact.

## Safety rules

- Original figures are immutable artifacts.
- Repairs are never automatic; they only run when a user explicitly calls a repair function.
- Repaired outputs must never overwrite the source FIG or write back into the original `figures/` directory.
- Automated repair is limited to style and layout-safe edits. It must not change plotted data, axis limits, scaling, normalization, or trace visibility.
- Structural validation runs after repair; if forbidden changes are detected, the repair fails before export.
- `figure_quality_check.m` is used as a warning-producing review pass, not as a destructive gate.

## Typical workflow

1. Identify a run with archived FIG artifacts in `results/<experiment>/runs/<run_id>/figures/`.
2. Choose either a single figure or the whole figures directory.
3. Run `repair_fig_file(source_fig_path, output_directory)` or `repair_fig_directory(run_or_figures_dir)`.
4. Review the outputs in `repaired_figures/<figure_name>/`.
5. Inspect `repair_metadata.json` and the repaired exports before using them for publication.

## Output layout

Recommended repaired layout:

```text
results/<experiment>/runs/<run_id>/
    figures/
        original_figure.fig
    repaired_figures/
        original_figure/
            repaired.fig
            repaired.pdf
            repaired.png
            repair_metadata.json
```

## Example usage

Repair one figure:

```matlab
result = repair_fig_file(
    'results/aging/runs/run_2026_03_10_112842_geometry_visualization/figures/aging_map_heatmap.fig', ...
    'results/aging/runs/run_2026_03_10_112842_geometry_visualization/repaired_figures/aging_map_heatmap');
```

Repair all FIG files in a run:

```matlab
results = repair_fig_directory('results/aging/runs/run_2026_03_10_112842_geometry_visualization');
```

Run the demonstration helper:

```matlab
demo_repair_example
```

## Relationship to existing visualization helpers

The repair system is separate from analysis pipelines, but it reuses the repository publication helper layer where appropriate:

- `tools/figures/apply_publication_style.m`
- `tools/figures/figure_quality_check.m`

This keeps repair behavior aligned with the repository publication standard while preserving the opt-in and non-destructive repair model.
