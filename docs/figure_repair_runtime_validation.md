# Figure Repair Runtime Validation

Date: March 11, 2026

## Environment

- MATLAB version: `23.2.0.2485118 (R2023b) Update 6`
- Release: `R2023b`
- Validation entry point: `tools/figure_repair/run_validation_suite.m`

## Runtime tests executed

The final post-schema-fix validation run executed these direct runtime checks:

- `inspect_fig_contents`
- `apply_fig_style_repair`
- `export_repaired_figure`
- `write_repair_metadata`
- `repair_fig_file`
- `repair_fig_directory`

Result: `6 / 6` runtime tests passed.

## Errors encountered during hardening

### Environment issues

Initial MATLAB startup failed in the sandbox due to:

- non-writable default MATLAB preferences directory
- required MathWorks service / licensing access outside the sandbox

Resolution:

- redirected `MATLAB_PREFDIR` into the workspace
- executed MATLAB validation runs outside the sandbox

### Code issues fixed

The validation pass surfaced and fixed these Figure Repair System issues:

1. `apply_fig_style_repair.m` allowed axis-state drift on real line figures.
   - Symptom: `aging_temperature_slices.fig` changed `XLim` from `[0 45]` to `[0 50]` during the style pass.
   - Fix: snapshot and restore protected axis state (`XLim`, `YLim`, `ZLim`, `CLim`, scale, and direction) after styling.

2. `inspect_fig_contents.m` did not cover all required inspection outputs.
   - Fix: added direct count fields, annotation detection, tiled-layout detection, unsupported-object detection, hidden-handle counting, and compact data signatures for guardrail comparison.

3. Validation logic was embedded only inside `repair_fig_file.m`.
   - Fix: extracted repository-level validation into `tools/figure_repair/validate_repair_integrity.m` so guardrail tests can call it directly.

4. Metadata schema needed hardening.
   - Fixes:
     - `source_figure` now always uses the source `.fig` basename
     - `style_guide_version` now captures only the `Last updated` line
     - `quality_check_result.issues` now serializes as a predictable JSON array
     - metadata now includes `source_run`, `inspection_summary`, and `repair_warnings`

5. `repair_fig_directory.m` needed rerun-safe output naming.
   - Fix: added collision-safe suffixed output directories such as `__02`, `__03`, ...

## Final runtime status

Post-fix, the validation suite completed successfully and produced:

- `tools/figure_repair/_validation_results.json`

No runtime exceptions were left in the final validation run.

## Notes on warnings

The final run produced warning-level messages, but not runtime failures:

- expected publication-quality warnings from `figure_quality_check.m` for source figures that still use forbidden colormaps or have missing labels
- MATLAB path-removal warnings when the validation harness deleted prior validation output directories during repeated reruns

These warnings did not block repair completion and did not invalidate the runtime validation results.
