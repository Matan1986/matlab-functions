# Relaxation Tables Namespace README

## Namespace Role
`tables/relaxation/` is the durable Relaxation table namespace for promoted, indexable structured outputs.

This namespace is for durable tables only. Run-scoped working tables remain in run lineage containers.

## Durable Relaxation Table Namespace Contract
- Preserve RF3R and RF3R2 separation in table naming and metadata.
- Preserve repaired-replay vs canonical-candidate vs diagnostic status tags.
- Do not treat table presence alone as full Relaxation canonical readiness.
- Require lineage links for promoted tables.

## Expected Table Index Columns
Relaxation table indexes in this namespace must include:
- `table_name`
- `family`
- `source_run`
- `producer_script`
- `RF_family`
- `canonicality_status`
- `diagnostic_status`
- `transform_or_view_if_applicable`
- `lineage_link`

## Promotion and Preservation Rules
- No promotion without source lineage and producer-script metadata.
- No cleanup or relocation actions are authorized by this README.
- No collapse of view families in `transform_or_view_if_applicable`.

