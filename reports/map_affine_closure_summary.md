# Affine RMSE Closure (Canonical Metrics)

## Verdict
- AFFINE_CLOSURE: NO
- STRUCTURE_PRESERVED: YES

## Criteria Used (Proxy)
AFFINE_OK when all are true:
- map_corr > 0.995
- normalized_rmse < 0.15
- ridge_alignment_fraction > 0.9

## Results
- Total variant pairs: 3
- AFFINE_OK (YES): 1
- AFFINE_OK (NO): 2
- Non-affine pairs: raw_xy_delta|xy_over_xx, raw_xy_delta|baseline_aware

## Interpretation
If AFFINE_CLOSURE is YES, observed differences are consistent with mostly scale+offset behavior under this proxy.
If AFFINE_CLOSURE is NO, at least one pair departs from this affine-like pattern.
STRUCTURE_PRESERVED reflects whether ridge alignment indicates any structural mismatch.
