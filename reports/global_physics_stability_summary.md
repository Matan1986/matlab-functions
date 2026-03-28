# Global Physics Stability Summary

## Consolidated Metric Table

| metric | value | threshold | verdict |
|---|---:|---|---|
| phi_shape_corr | 0.999794275225 | >= 0.90 | YES |
| kappa_corr | 0.999953848545 | >= 0.90 | YES |

## Category Verdicts

| category | definition | verdict |
|---|---|---|
| PHYSICS_STRUCTURE_STABLE | map_corr + ridge_alignment_fraction + I_peak_agreement + width_correlation | NO |
| PHYSICS_AMPLITUDE_STABLE | kappa_corr | YES |
| PHYSICS_SHAPE_STABLE | phi_shape_corr + residual_structure_corr | NO |
| PHYSICS_COLLAPSE_STABLE | collapse_rmse_ratio | NO |
| PHYSICS_INVARIANT_TO_READOUT | ALL categories above are YES | NO |

## Notes

- This report performs aggregation only from existing table artifacts.
- Missing required inputs: tables/map_pair_metrics.csv, tables/observable_pair_by_temperature.csv, tables/collapse_kappa_phi_pair_metrics.csv.
- Missing metrics were not synthesized and therefore produce NO in dependent category verdicts.
