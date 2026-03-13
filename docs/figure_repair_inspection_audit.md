# Figure Repair Inspection Audit

Date: March 11, 2026

## Audit goal

Confirm that `inspect_fig_contents.m` reports the figure structure required by the Figure Repair System:

- axes
- line objects
- scatter objects
- image objects
- colorbars
- legends
- annotations
- tiled layouts

## Final inspection fields

The final inspection struct now includes direct top-level count fields:

- `figure_size`
- `axes_count`
- `line_count`
- `scatter_count`
- `image_count`
- `colorbar_count`
- `legend_count`
- `annotation_count`
- `tiled_layout_count`

It also includes:

- `annotations`
- `tiled_layouts`
- `unsupported_objects`
- `summary.hidden_handle_count`

## Validation evidence

### Real repository figures

| Case | Axes | Lines | Scatters | Images | Colorbars | Legends | Annotations | Tiled layouts |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `aging_heatmap` | 1 | 0 | 0 | 1 | 1 | 0 | 0 | 0 |
| `aging_line_stack` | 1 | 4 | 0 | 0 | 1 | 0 | 0 | 0 |
| `cross_experiment_tiled_layout` | 4 | 17 | 0 | 0 | 0 | 4 | 0 | 1 |
| `switching_scatter_geometry` | 1 | 1 | 1 | 0 | 1 | 1 | 0 | 0 |
| `relaxation_spectrum` | 1 | 2 | 0 | 0 | 0 | 1 | 0 | 0 |

### Annotation coverage

Real validation figures contained annotation panes but not explicit textbox/arrow annotation shapes.

A separate synthetic annotation fixture was created and inspected after the final suite run:

- synthetic fixture result: `annotation_count = 1`

This confirms that explicit annotation objects are now detected by `inspect_fig_contents.m`.

### Tiled-layout coverage

`candidate_overview_normalized.fig` was detected with:

- `tiled_layout_count = 1`
- `tile_spacing = compact`
- `padding = compact`
- `grid_size = [2 2]`

## Conclusion

Inspection coverage is now adequate for the current repair workflow.

Confirmed coverage:

- axes
- lines
- scatters
- images
- colorbars
- legends
- annotations
- tiled layouts

Remaining note:

- actual annotation-heavy repository figures are still uncommon, so annotation detection has been validated partly with a synthetic fixture rather than only with tracked repository artifacts.
