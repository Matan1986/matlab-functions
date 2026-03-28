# Relaxation Dataset Validation

Script: `C:/Dev/matlab-functions/Switching/analysis/run_validate_relaxation_dataset.m`
Input: `C:/Dev/matlab-functions/tables/relaxation_full_dataset.csv`

## Basic Integrity
- Rows: 6840
- Columns: 5
- Required columns found: YES
- HAS_NAN: NO

## Temperature Consistency
- N_TEMPERATURES: 19 (expected near 19)
- POINTS_PER_T (unique): 360
- Same points per temperature: YES

## logt Grid
- Strictly increasing per T: YES
- Max grid deviation across T: 0
- GRID_CONSISTENT: YES

## Signal Sanity (M)
- Oscillatory curves flagged: 0
- Discontinuity flags: 0
- Shape flips vs reference: 1
- Near-monotonic curves: 16/19

## Derivative Sanity (R_relax)
- median positive fraction: 1
- max spike ratio: 15.7823
- |R| max / median / std: 0.00013279 / 2.2837e-05 / 2.6925e-05
- DERIVATIVE_STABLE: YES

## Curvature Sanity (C)
- max spike ratio: 17.9091
- max median(|C|)/median(|R|) scale: 92.5539
- |C| max / median / std: 0.0042668 / 0.00028066 / 0.00053257
- CURVATURE_STABLE: YES

## Cross-Temperature Consistency
- R_relax peak-location outliers: 0
- R_relax width outliers: 6

## Normalization Check
- Consistent M scale/baseline across T: YES

## Physical Plausibility Verdict
- HAS_OUTLIERS: YES
- DATA_VALID_FOR_ANALYSIS: NO
