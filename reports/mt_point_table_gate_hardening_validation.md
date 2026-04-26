# MT Point-Table Gate Hardening Validation (Stage 4.6)

## Scope

This document records validation of Stage 4.5 point-table gate hardening on real MT data. It is a documentation artifact only and does not modify execution logic.

## Validation source

- Source commit: `3cb2c0e` (`Harden MT point table validation gates`)
- Source run id: `run_2026_04_26_125110_mt_real_data_diagnostic`
- Run location: `results/mt/runs/run_2026_04_26_125110_mt_real_data_diagnostic`

## Wrapper execution status

- `EXECUTION_STATUS=SUCCESS`
- `INPUT_FOUND=YES`
- `N_T=11`

## Hardened gate evidence summary

The Stage 4.5 run-level gate details show evidence-backed validation (not declarative-only text) for the hardening targets:

- `G02`: required-fields check uses a per-table required-column map and validates required field population.
- `G03`: verifies both row parity and immutable key-set equality (`file_id,row_index`) across RAW/CLEAN/DERIVED.
- `G05`: records `join_key_policy=file_id,row_index_only` and `float_coordinate_join_used=false`.
- `G07`: records `derived_uses_clean_channel=true` and `smooth_used_as_clean_truth=false`.
- `G08`: records `derived_source_table=mt_points_clean` and `derived_uses_raw_only_column=false`.
- `G09`: records `time_s_assumed_elapsed=false`, `time_rel_s_explicit=true`, `time_rel_s_consistent=true`.
- `G10`: records `segmentation_is_cleaning=false`, `segment_source_populated=true`.

## Validation outcome

- Gates `G01`-`G11`: all `PASS`
- Gate failures table: header-only, failure rows `0`

## Readiness interpretation

Readiness remains intentionally unchanged after hardening validation:

- `FULL_CANONICAL_DATA_PRODUCT=PARTIAL`
- `MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE=NO`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`

Conclusion:

Stage 4.5 successfully closes the Stage 4.4 gate-hardening blockers for moving toward observables design, while still not authorizing production release, advanced analysis readiness, or new physics claims by itself.
