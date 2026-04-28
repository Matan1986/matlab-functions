# Switching gauge atlas preview (diagnostic only)

This preview compares baseline G001 against stabilized diagnostic candidates G254 and G014.
Interpretation boundary: G254/G014 are diagnostic stabilized effective gauges only. Canonical P0 gauge is unchanged.

## Required comparisons
- G001 = I_peak_old + W_FWHM_crossing + S_peak_old
- G254 = I_peak_smoothed_across_T + W_sigma_positive + S_area_positive
- G014 = I_peak_old + W_sigma_positive + S_area_positive

## Best-by-regime reference
- best_primary: G254
- best_high_primary: G254
- best_balanced: G254

## Top15 finite summary
- rows: 15
- S_area_positive dominates top15: YES

## Verdicts
- GAUGE_ATLAS_PREVIEW_COMPLETE=YES
- G001_BASELINE_INCLUDED=YES
- G254_BEST_INCLUDED=YES
- G014_LESS_SMOOTHED_COMPARATOR_INCLUDED=YES
- S_AREA_POSITIVE_DOMINATES_TOP15=YES
- PREVIEW_FIGURE_WRITTEN=YES
- G254_CANONICAL_COORDINATE_CLAIMED=NO
- G014_CANONICAL_COORDINATE_CLAIMED=NO
- X_CANON_CLAIMED=NO
- UNIQUE_W_CLAIMED=NO
- UNIQUE_S0_CLAIMED=NO
- SAFE_TO_WRITE_SCALING_CLAIM=NO
- CROSS_MODULE_SYNTHESIS_PERFORMED=NO
