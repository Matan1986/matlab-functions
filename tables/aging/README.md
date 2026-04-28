# tables/aging README

## Durable Aging table namespace
- `tables/aging/` is the durable Aging table layer.
- It stores promoted, indexed Aging tables and governance inventories.
- Run-temporary tables should stay in run containers until promoted.

## Required index columns
- Aging table index artifacts must include these columns:
  - `table_name`
  - `family`
  - `producer_script`
  - `source_run`
  - `canonicality_status`
  - `diagnostic_status`
  - `lineage_link`
  - `aging_only_scope`

## Column intent
- `table_name`: durable table filename.
- `family`: family taxonomy label (for example `F6_lineage`, `trackA`, `tau`).
- `producer_script`: Aging script path that generated the table.
- `source_run`: originating run container id/path when run-coupled.
- `canonicality_status`: canonical candidate vs replay vs diagnostic vs legacy reference.
- `diagnostic_status`: diagnostic classification and review state.
- `lineage_link`: explicit link to source run/report/evidence container.
- `aging_only_scope`: `YES/NO` scope admissibility for Aging-only claims.

## Cross-module exclusion rule
- Tables with cross-module or ambiguous provenance are excluded from Aging-only claims.
- Exclusion registry: `tables/aging/aging_artifact_excluded_cross_module_candidates.csv`.
- Do not use Switching/Relaxation/bridge evidence as Aging-only table evidence.
