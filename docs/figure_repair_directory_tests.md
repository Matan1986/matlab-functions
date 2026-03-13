# Figure Repair Directory Tests

Date: March 11, 2026

## Test target

- Source directory: `results/aging/runs/run_2026_03_10_112842_geometry_visualization`
- Source figure count: `6`

## Validation results

- `repair_fig_directory(...)` produced `6` repaired outputs
- each source figure received its own repair directory
- each repaired figure directory contained its own `repair_metadata.json`
- all metadata paths were unique

## Naming-collision behavior

The final implementation now resolves collisions by appending numeric suffixes when a repaired output directory already exists.

Observed examples from repeated validation reruns:

- `aging_map_heatmap__05`
- `aging_dMdT_heatmap__05`
- `aging_centered_temperature_slices__06`

This confirms that reruns do not overwrite earlier repaired outputs.

## Conclusion

Directory repair behavior is correct for the current repository run layout:

- one source figure maps to one repaired output directory
- metadata remains unique per repaired figure
- repeated reruns remain non-destructive because collisions are resolved by suffixing
