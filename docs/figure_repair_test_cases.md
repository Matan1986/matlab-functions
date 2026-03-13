# Figure Repair Test Cases

Date: March 11, 2026

Representative repository FIG files were selected to cover heatmaps, line plots, tiled layouts, legends, colorbars, scatter content, and multi-panel figures.

| Case | Source figure path | Detected structure | Classification | Result |
| --- | --- | --- | --- | --- |
| `aging_heatmap` | `results/aging/runs/run_2026_03_10_112842_geometry_visualization/figures/aging_map_heatmap.fig` | `axes=1`, `images=1`, `colorbars=1` | `manual_review_required` | `pass` |
| `aging_line_stack` | `results/aging/runs/run_2026_03_10_112842_geometry_visualization/figures/aging_temperature_slices.fig` | `axes=1`, `lines=4`, `colorbars=1` | `style_only` | `pass` |
| `cross_experiment_tiled_layout` | `results/cross_experiment/runs/run_2026_03_10_233449_simple_switching_vs_relaxation_search/figures/candidate_overview_normalized.fig` | `axes=4`, `lines=17`, `legends=4`, `tiled_layouts=1` | `style_only` | `pass` |
| `switching_scatter_geometry` | `results/switching/runs/run_2026_03_09_230048_XI_Xshape_analysis/XI_Xshape_analysis/figures/mode_space_geometry.fig` | `axes=1`, `lines=1`, `scatters=1`, `colorbars=1`, `legends=1` | `style_only` | `pass` |
| `relaxation_spectrum` | `results/relaxation/runs/run_2026_03_10_143118_geometry_observables/figures/singular_value_spectrum.fig` | `axes=1`, `lines=2`, `legends=1` | `manual_review_required` | `pass` |

## Observations

- All `5 / 5` representative real-figure repairs produced repaired `PDF`, `PNG`, and `FIG` outputs.
- All `5 / 5` preserved the original source FIG checksum.
- Manual-review classifications came from source-figure issues, not repair failures.

## Manual-review reasons observed

- `aging_heatmap`: forbidden colormap warning (`jet`, `turbo`, or `hsv` detected by quality check)
- `relaxation_spectrum`: multiple y-axes present
