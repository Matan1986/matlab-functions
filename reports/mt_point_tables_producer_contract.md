# MT Stage 4.1 - Canonical Point Tables Producer Contract

## Purpose

This contract defines how canonical MT point tables will be produced in implementation stage(s), without implementing code in this stage. It binds producer location, output location, table requirements, validation gates, and failure policy.

## 1) Producer location contract

- Canonical entrypoint remains `runs/run_mt_canonical.m`.
- No alternate runnable entrypoint is allowed for canonical MT point products.
- Helper usage is allowed only as an internal call path from `runs/run_mt_canonical.m` and must be documented as a producer helper (for example, table-builder helper) without changing entrypoint ownership.

Decision:

- **Entrypoint owner**: `runs/run_mt_canonical.m`
- **Helper policy**: optional, documented, subordinate
- **Alternate entrypoint**: forbidden

## 2) Output location contract

- Point-table products must be written into the canonical run directory under:
  - `<run_dir>/tables/mt_points_raw.csv`
  - `<run_dir>/tables/mt_points_clean.csv`
  - `<run_dir>/tables/mt_points_derived.csv`
  - `<run_dir>/tables/mt_observables.csv`
- Repo-level `tables/` is reserved for design/docs/audit summaries only, not run point products.

## 3) Required products

Required run products:

1. `mt_points_raw.csv`
2. `mt_points_clean.csv`
3. `mt_points_derived.csv`
4. `mt_observables.csv`

Optional run products (only if explicitly documented in producer implementation notes):

- validation summary table (for example `mt_point_tables_validation_summary.csv`)
- gate-failure detail table (for example `mt_point_tables_gate_failures.csv`)

## 4) Row identity enforcement contract

Immutable row key:

- `file_id + row_index`

Rules:

- joins must use only `file_id,row_index`
- `T_K,H_Oe,time_s` are validation/physics coordinates, not join keys
- no joins on floating-point coordinates

Required checks for each produced run:

- key uniqueness per point table (`mt_points_raw`, `mt_points_clean`, `mt_points_derived`)
- row parity:
  - `N(mt_points_raw) == N(mt_points_clean)`
  - `N(mt_points_clean) == N(mt_points_derived)`
- key-set equality across RAW/CLEAN/DERIVED

## 5) RAW contract

`mt_points_raw.csv` must satisfy:

- direct imported rows only
- no cleaning, smoothing, segmentation transforms, or derived variables
- imported time channel is stored as `time_s` in seconds
- `time_s` is not assumed elapsed/relative

## 6) CLEAN contract

`mt_points_clean.csv` must satisfy:

- deterministic row-preserving transform of RAW
- includes required channels:
  - `M_emu_raw`
  - `M_emu_clean`
  - `M_emu_smooth`
- `M_emu_smooth` must not replace `M_emu_clean` as structural clean truth
- includes required cleaning diagnostics fields:
  - `cleaning_branch`
  - `cleaning_reason_code`
  - `points_changed_flag`
  - `raw_clean_abs_delta`
  - `raw_smooth_abs_delta`
  - `cleaning_effect_class`
  - `cleaning_warning_class`
  - `cleaning_trust`

Segmentation in CLEAN:

- segment columns in CLEAN are annotation context only
- segmentation is not part of cleaning semantics

## 7) DERIVED contract

`mt_points_derived.csv` must satisfy:

- computed from CLEAN only
- no direct RAW reads during derived computation
- supports optional `time_rel_s` for elapsed/relative analysis time
- missing derived outputs are allowed as `NaN` with reason columns (for example `derived_missing_reason`) and validity flags

## 8) OBSERVABLES contract

`mt_observables.csv` must satisfy:

- default source is DERIVED columns
- direct CLEAN usage is allowed only as explicit exception
- each observable row must provide:
  - `source_columns`
  - `aggregation_method`
  - `definition`
  - `temperature_dependence`
- observables alone do not unlock physics readiness gates

## 9) Validation gates (contract-level)

The producer must run and report at least these gates:

1. schema columns present per table
2. required columns nonmissing where required
3. row parity RAW/CLEAN/DERIVED
4. key uniqueness per table
5. no float-coordinate joins
6. clean/raw traceability completeness
7. smooth channel not used as clean replacement
8. derived source isolation (CLEAN-only)
9. time channel assumption check (`time_s` not treated as automatically elapsed)
10. segmentation annotation check (not cleaning logic)
11. observables provenance check (`source_columns`, `aggregation_method`, `definition`)

Gate definitions and blocking effects are normalized in:

- `tables/mt_point_tables_validation_gates.csv`
- `tables/mt_point_tables_failure_modes.csv`

## 10) Failure policy and readiness blocking

Blocking principle:

- Any HIGH-severity contract violation blocks full canonical product readiness.
- Repeated or unresolved MEDIUM-severity core-contract violations also block readiness.

Readiness fields affected by blocking failures:

- `FULL_CANONICAL_DATA_PRODUCT`
- `MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE`
- `MT_READY_FOR_ADVANCED_ANALYSIS`

Default policy in Stage 4.1:

- readiness remains blocked until implementation exists and gates pass on real runs.
- contract definition does not itself change readiness status.

## Implementation readiness statement

Stage 4.1 delivers producer contract and gate/failure planning only.

- `MT_POINT_TABLE_IMPLEMENTATION_READY=NO`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`

