# Relaxation Figures Namespace README

## Namespace Role
`figures/relaxation/` is the durable Relaxation figure and map namespace for promoted visual artifacts with explicit lineage and transform metadata.

## Figure and Map Family Separation
Relaxation figure/map families must remain explicitly separated, including:
- `raw`
- `normalized`
- `baseline-centered`
- `positive-display`
- `log-time`
- `linear-time`
- `end-aligned display`

RF3R and RF3R2 visual families must remain separated and independently tagged.

## Required Transform Metadata
Each promoted figure/map must include:
- source table or source run
- producer script
- transform label
- time axis type
- included temperatures
- excluded temperatures
- smoothing/normalization/baseline flags
- publication readiness

## Units Policy
- Axes and color quantities must include explicit physical units.
- Units metadata must be recorded alongside transform metadata.
- Display transforms do not alter source scientific values; they alter visualization only.

## Publication Figure Requirements
A Relaxation figure/map may be tagged publication-ready only when:
- lineage is documented
- transform is documented
- units are documented
- inclusion/exclusion rules are documented
- readiness caveat is explicitly stated where applicable

RF3R2 publication figures are durable only if lineage and transform metadata are documented.

## Promotion Gate
No promotion is allowed without source, transform, and inclusion metadata.
No cleanup, migration, or canonical-readiness conclusion is authorized by this README.

