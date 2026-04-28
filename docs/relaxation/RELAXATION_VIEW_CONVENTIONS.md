# Relaxation View Conventions

## Purpose
This document defines allowed Relaxation display/view labels and required metadata for Relaxation figures and maps.

This is an index-layer governance document only and does not authorize scientific rewrites or figure regeneration.

## Allowed View and Transform Labels
Only the following display/view labels are allowed in Relaxation figure/map metadata:
- `raw`
- `normalized`
- `baseline-centered`
- `positive-display`
- `log-time`
- `linear-time`
- `end-aligned display`

These labels are distinct families and must not be collapsed into one generic view label.

## Required Figure/Map Metadata
Each durable Relaxation figure/map entry must state:
- source table or source run
- producer script
- transform
- units
- time axis type
- included temperatures
- excluded temperatures
- smoothing/normalization/baseline flags
- publication readiness

Recommended metadata keys for indexes and captions:
- `source_table_or_run`
- `producer_script`
- `transform`
- `units`
- `time_axis_type`
- `included_temperatures`
- `excluded_temperatures`
- `smoothing_flag`
- `normalization_flag`
- `baseline_flag`
- `publication_readiness`

## Transform Semantics Rule
Visual display transforms (including normalization, baseline-centering, positive-display remapping, end-alignment, log-time axis display, and linear-time display) do not change source scientific values.

Transforms change representation only; source data lineage remains anchored to the original run/table values.

## Inclusion/Exclusion Documentation Rule
- Inclusion and exclusion of temperatures must be explicitly documented for every promoted figure/map family.
- If exclusions are applied for readability or diagnostics, this must be marked as a display policy decision, not a data-value rewrite.

## RF3R and RF3R2 View Handling
- RF3R and RF3R2 visuals must remain separately tagged.
- Shared transform names may be reused across RF families, but lineage and RF-family tags must stay explicit and separate.

