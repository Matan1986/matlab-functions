# Figure Repair Metadata Schema

Date: March 11, 2026

The final `repair_metadata.json` schema after the metadata hardening pass is:

## Required fields

| Field | Type | Notes |
| --- | --- | --- |
| `source_figure` | string | basename of the source `.fig` file |
| `source_path` | string | original figure path |
| `source_run` | string | run root containing the source figure, when resolvable |
| `repair_date` | string | ISO-like timestamp |
| `style_guide_version` | string | currently the `Last updated` value from `docs/figure_style_guide.md` |
| `repair_actions` | array of strings | actions applied during repair |
| `repair_classification` | string | `style_only`, `layout_only`, or `manual_review_required` |
| `repair_requested_by` | string | user name from environment when available |
| `output_files` | object | paths to repaired `pdf`, `png`, and `fig` |
| `validation` | object | guardrail validation status and issues |
| `inspection_summary` | object | compact before/after inspection summary |
| `quality_check_result` | object | issue count plus JSON array of issue objects |
| `repair_warnings` | array of strings | warning-level summary strings |
| `classification_reasons` | array of strings | structured reasons for the final classification |

## `validation`

```json
{
  "is_valid": true,
  "issues": []
}
```

## `inspection_summary`

```json
{
  "before": {
    "figure_size": [2.09, 2.08, 24.34, 16.40],
    "axes_count": 1,
    "line_count": 0,
    "scatter_count": 0,
    "image_count": 1,
    "colorbar_count": 1,
    "legend_count": 0,
    "annotation_count": 0,
    "tiled_layout_count": 0,
    "unsupported_object_count": 0,
    "has_3d_axes": false,
    "has_multiple_yaxes": false,
    "missing_xlabel": false,
    "missing_ylabel": false,
    "colorbar_labels_missing": false,
    "hidden_handle_count": 151
  },
  "after": {
    "figure_size": [2.09, 2.08, 17.8, 11.5],
    "axes_count": 1,
    "line_count": 0,
    "scatter_count": 0,
    "image_count": 1,
    "colorbar_count": 1,
    "legend_count": 0,
    "annotation_count": 0,
    "tiled_layout_count": 0,
    "unsupported_object_count": 0,
    "has_3d_axes": false,
    "has_multiple_yaxes": false,
    "missing_xlabel": false,
    "missing_ylabel": false,
    "colorbar_labels_missing": false,
    "hidden_handle_count": 151
  }
}
```

## `quality_check_result`

```json
{
  "issue_count": 1,
  "issues": [
    {
      "id": "forbidden_colormap",
      "message": "Axis 1 uses a forbidden colormap (jet, turbo, or hsv)."
    }
  ]
}
```

## Example metadata excerpt

Observed in the final post-schema-fix validation output:

- `source_figure = "aging_map_heatmap"`
- `source_run = "results/aging/runs/run_2026_03_10_112842_geometry_visualization"`
- `style_guide_version = "March 10, 2026"`

## Schema stability note

The metadata hardening pass specifically fixed:

- `source_figure` no longer falling back to `unsaved_figure` when the repair code operates on an already-open figure handle
- `quality_check_result.issues` now serializing as a stable JSON array
- `style_guide_version` no longer capturing the entire style-guide document body
