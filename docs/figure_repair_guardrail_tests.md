# Figure Repair Guardrail Tests

Date: March 11, 2026

The final validation pass executed explicit mutation tests against inspected figures and verified that `validate_repair_integrity.m` rejects forbidden structural changes.

## Results

| Test | Mutation | Detected issues | Pass |
| --- | --- | --- | --- |
| `axis_limits` | changed `XLim` | `axis_1_x_limits_changed` | `pass` |
| `line_data` | changed line `YData` | `axis_1_y_limits_changed`, `axis_1_line_1_data_changed` | `pass` |
| `line_visibility` | hid a line object | `axis_1_y_limits_changed`, `axis_1_line_1_visibility_changed` | `pass` |
| `object_count` | added a new line object | `line_count_changed`, `axis_1_y_limits_changed`, `axis_1_line_count_changed` | `pass` |
| `axis_scale` | changed `XScale` to `log` | `axis_1_x_limits_changed`, `axis_1_xscale_changed` | `pass` |
| `image_data` | changed image `CData` | `axis_1_color_limits_changed`, `axis_1_image_1_data_changed` | `pass` |
| `color_limits` | changed `CLim` | `axis_1_color_limits_changed` | `pass` |

## Guardrails confirmed

Confirmed by the final validation run:

- forbidden structural changes are detected before export is accepted
- data-array changes are detected for supported line and image primitives
- object visibility changes are detected
- object-count changes are detected
- axis-limit and scale changes are detected
- color-limit changes are detected

## Output-directory guardrail

`repair_fig_file.m` also enforces a path-level guardrail:

- repaired outputs must not be written into the original `figures/` directory
- repaired outputs must not be written into a child directory of the original source-figure directory

This rule was exercised indirectly during validation-harness development, where an invalid temp output location was rejected immediately.
