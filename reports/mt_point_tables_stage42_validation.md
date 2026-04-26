# MT Point Tables Stage 4.2 Validation

## Scope

This document records Stage 4.2 real-data validation for canonical MT point-table production. It is an audit artifact only and does not modify execution logic.

## Validation source

- Source commit: `b0d9bab` (`Add MT canonical point table outputs`)
- Source run id: `run_2026_04_26_112155_mt_real_data_diagnostic`
- Run location: `results/mt/runs/run_2026_04_26_112155_mt_real_data_diagnostic`
- Execution status evidence:
  - `EXECUTION_STATUS=SUCCESS`
  - `INPUT_FOUND=YES`
  - `N_T=11`

## Produced point-table files

Under `<run_dir>/tables/`:

- `mt_points_raw.csv`
- `mt_points_clean.csv`
- `mt_points_derived.csv`
- `mt_observables.csv`
- `mt_point_tables_validation_summary.csv`
- `mt_point_tables_gate_failures.csv`

## Row counts

- `RAW_ROWS=6719`
- `CLEAN_ROWS=6719`
- `DERIVED_ROWS=6719`
- `OBSERVABLE_ROWS=11`
- `VALIDATION_GATES_ROWS=11`
- `GATE_FAILURE_ROWS=0`

Interpretation:

- RAW/CLEAN/DERIVED parity is satisfied (`6719 == 6719 == 6719`).
- Observables table is present with a minimal non-empty payload (`11` rows).
- Gate failure table is header-only and records zero failures.

## Validation gates summary

Gate summary table (`mt_point_tables_validation_summary.csv`) reports:

- `G01` to `G11` all `PASS`
- total gate count: `11`
- failed gates: `0`

Gate failure table (`mt_point_tables_gate_failures.csv`) reports:

- failure rows: `0`

## Readiness interpretation

Run summary flags confirm:

- `MT_POINT_TABLES_GATE_SUMMARY=PASS`
- `POINT_TABLES_WRITTEN=YES`
- `RAW_CLEAN_DERIVED_SEPARATION=TABLE_LEVEL`
- `FULL_CANONICAL_DATA_PRODUCT=PARTIAL`
- `MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE=NO`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`

Conclusion:

Stage 4.2 successfully produced canonical MT point-table artifacts on real data and passed all defined point-table validation gates. This milestone improves canonical data-product completeness to `PARTIAL` but does **not** unlock production release or advanced physics analysis readiness.
