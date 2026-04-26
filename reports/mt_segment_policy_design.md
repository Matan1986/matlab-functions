# MT Stage 5.3 - Segment and ZFC/FCC/FCW policy design

## Purpose and scope

This Stage 5.3 artifact defines the segment annotation and ZFC/FCC/FCW comparison policy boundary for MT observables. It is design-only and does not implement computation.

## Segment identity semantics

1. `segment_id` is an analysis annotation scope only and is not part of RAW/CLEAN measurement identity.
2. Segment assignment must never alter immutable row identity (`file_id`, `row_index`) in RAW/CLEAN/DERIVED tables.
3. Segment assignment must be reproducible from a documented source class and policy version.

## Segment source classes

Allowed segment source classes:

- algorithmic_ramp: algorithmic segmentation using T/time ramp behavior.
- metadata_label: protocol label from metadata/header.
- curated_registry: manually curated segment registry.
- hybrid: algorithmic segmentation constrained or confirmed by metadata/registry.
- placeholder_not_implemented: temporary class permitted only before full segment-policy implementation gates pass.

## segment_type and segment_direction vocabulary

Controlled `segment_type` vocabulary:

- `zfc`
- `fcc`
- `fcw`
- `increasing_T`
- `decreasing_T`
- `constant_T`
- `unknown`

Policy field design:

1. `segment_type` stores protocol label when protocol is known (`zfc`, `fcc`, `fcw`).
2. Ramp direction is tracked in a separate required field `segment_direction` with controlled vocabulary:
   - `increasing_T`
   - `decreasing_T`
   - `constant_T`
   - `unknown`
3. Ramp-direction values may appear in `segment_type` only when protocol is unknown, but this does not imply protocol assignment.

## ZFC/FCC/FCW labeling policy

1. ZFC/FCC/FCW labels require metadata/header evidence or curated registry evidence.
2. Ramp direction alone is not sufficient to infer ZFC/FCC/FCW.
3. `segment_type=unknown` must never be promoted to ZFC/FCC/FCW for comparison outputs.

## Overlap and pairing policy for comparisons

For ZFC-FCW splitting, hysteresis-like differences, and related pairwise comparisons:

1. Require overlapping `T_K` support.
2. Require minimum overlap fraction threshold.
3. Require minimum overlap-point count.
4. Require same or compatible `H_Oe` scope.
5. Require same sample/file context or explicit pairing policy identifier.
6. Require declared comparison method and declared binning or interpolation policy before numeric comparison.
7. No interpolation/regridding unless interpolation policy is separately approved.

## Unknown segment behavior

1. Unknown segments may be used for coverage and diagnostic summaries only.
2. Unknown segments cannot be used for ZFC/FCC/FCW comparison metrics.
3. Unknown segments cannot support hysteresis/irreversibility physics claims.

## Allowed outputs at Stage 5.3

Allowed outputs are restricted to:

- segment coverage summaries;
- ramp-direction diagnostic summaries;
- ZFC/FCC/FCW comparison candidates;
- overlap metrics.

All comparison outputs remain diagnostic/candidate only.

## Forbidden interpretation boundary

Stage 5.3 forbids direct claims of:

- thermodynamic irreversibility;
- memory effect;
- equilibrium path difference;
- first-order hysteresis;
- metastability;
- cross-module coupling claims (Aging/Relaxation/Switching).

## Readiness impact

Stage 5.3 defines policy only and does not unlock implementation or advanced analysis:

- `MT_READY_FOR_SEGMENT_IMPLEMENTATION=NO`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`
- ZFC/FCC/FCW comparison remains candidate-only.

## Artifact map

- `tables/mt_segment_policy_rules.csv`
- `tables/mt_segment_quality_gates.csv`
- `tables/mt_segment_forbidden_claims.csv`
- `status/mt_segment_policy_status.txt`
