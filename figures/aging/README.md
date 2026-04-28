# figures/aging README

## Durable Aging figure namespace
- `figures/aging/` is the durable promoted figure layer for Aging.
- It is for promoted figures only, not raw transient run dumps.

## Required metadata for every promoted figure
- `source run`: exact run container path/id (or explicitly documented non-run source)
- `producer script`: Aging script that produced the figure
- `transform`: processing/view transform used to derive the plotted quantity
- `units`: units for plotted axes/quantities
- `inclusion/exclusion`: domain filters and row/condition inclusion rules
- `canonicality`: `canonical_candidate`, `replay`, `diagnostic`, or `legacy_reference`

## Promotion and lineage policy
- No figure promotion without complete lineage metadata.
- Promoted figure metadata must link back to run/tables/reports evidence.
- Cross-module or ambiguous provenance blocks Aging-only promotion.

## Current state note
- If this directory is empty, it remains the reserved durable destination for future Aging figure promotions.
