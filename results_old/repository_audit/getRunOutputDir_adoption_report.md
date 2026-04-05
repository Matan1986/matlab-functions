# getRunOutputDir Adoption Report

## Files Scanned

- `Aging/analysis/aging_geometry_visualization.m`
- `Relaxation ver3/aging_geometry_visualization.m`
- `Switching/analysis/switching_alignment_audit.m`

## Classification

### SAFE TO REPLACE

- `Aging/analysis/aging_geometry_visualization.m`
- `Relaxation ver3/aging_geometry_visualization.m`

Reason:
These scripts only read `runContext.run_dir` for console status printing. Their output directory logic already comes from `getResultsDir(...)`, so replacing the printed `run_dir` lookup with `getRunOutputDir()` does not change artifact paths.

### LIKELY SAFE BUT NEED REVIEW

- None in this pass.

### DO NOT MODIFY

- `Switching/analysis/switching_alignment_audit.m`

Reason:
This script uses the active run context inside helper logic that decides which run directory to reuse. That is more than a display-only replacement, so it was intentionally left unchanged in this pass.

## Files Modified

- `Aging/analysis/aging_geometry_visualization.m`
- `Relaxation ver3/aging_geometry_visualization.m`

## Files Intentionally Skipped

- `Switching/analysis/switching_alignment_audit.m`

## Validation

- The modified scripts now call `getRunOutputDir()` instead of reading `activeRunCtx.run_dir` directly.
- Remaining direct `run_dir` extraction is limited to `Switching/analysis/switching_alignment_audit.m`, which was intentionally skipped.
- No pipeline files were modified.
- No artifact path construction logic changed in the modified scripts; only status printing changed.
