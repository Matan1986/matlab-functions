# Invalid Runs Triage

## Scope
This triage covers the rows in [tables/drift_audit.csv](tables/drift_audit.csv) where `run_status = INVALID`.

## Rules Used
- A run can be `ACTIVE_FIX` only if it is relevant to the current active system and was generated from a canonical pipeline.
- If pipeline status is non-canonical or unclear, the run is not `ACTIVE_FIX`.
- `UNKNOWN` is not active.
- Prefer `QUARANTINE` over risky promotion.
- Prefer `MANUAL_REVIEW` over guessing when lineage or active usage is ambiguous.

## Active Definition
`ACTIVE` means the run belongs to the current corrected canonical switching system and is relevant to the active workflow, not merely historically referenced.

## Classification Counts
- `ACTIVE_FIX`: 0
- `QUARANTINE`: 4
- `MANUAL_REVIEW`: 2

## Pipeline Status Counts
- `CANONICAL`: 0
- `NON_CANONICAL`: 4
- `UNKNOWN`: 2

## Interpretation By Group
### QUARANTINE
These runs are excluded from the active system. They are historical or exploratory cross_experiment runs with no clear canonical-switching status.

### MANUAL_REVIEW
These runs may matter to the current workflow, but the invalid instance itself does not have enough evidence to prove canonical lineage safely.

## Notes By Family
- The `unified_barrier_mechanism` runs are exploratory cross_experiment barrier analyses, so they are quarantined.
- The `x_single_observable_residual_test` invalid run is related to current switching-side work, but the exact invalid instance is not safely canonical.
- The `dimensionless_constrained_basin_scan` invalid run has a later corrected sibling and audit evidence, but the invalid instance itself remains lineage-ambiguous.
- The generic `basin_scan` invalid runs have no active workflow evidence and are quarantined.

## Explicit Exclusions
- `QUARANTINE` runs are excluded from the active system.
- `UNKNOWN` is not active.
- No MATLAB execution was performed for this triage.
- No runs were modified.

## Summary
The invalid set contains no safe `ACTIVE_FIX` candidates under the canonical-pipeline rule. The only rows retained for further attention are the two `MANUAL_REVIEW` cases where active relevance exists but canonical lineage is not proven.