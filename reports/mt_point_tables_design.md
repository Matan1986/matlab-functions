# MT Stage 4.0 - Canonical Point Tables Design

## Purpose

This document defines the design-only canonical MT point-table product before implementation. It specifies hierarchy, row identity, schemas, alignment rules, cleaning traceability, derived isolation, segmentation, units contract, observables structure, and risk controls.

Scope constraints for this stage:

- no MATLAB execution
- no `.m` file changes
- no writes under `results/`
- design artifacts only

## 1) Canonical hierarchy

The canonical data product is strictly layered:

1. `mt_points_raw.csv`
   - Direct import representation only.
   - No cleaning, interpolation, smoothing, segmentation, fitting, or physics transforms.

2. `mt_points_clean.csv`
   - Deterministic transform of RAW rows.
   - Same row identity space as RAW.
   - Contains explicit traceability fields linking clean values to original raw values.

3. `mt_points_derived.csv`
   - Pure function of CLEAN only.
   - No direct RAW dependencies.
   - No hidden metadata dependence; every derived value must list direct clean inputs.

4. `mt_observables.csv`
   - Aggregated/reduced quantities over CLEAN and/or DERIVED points.
   - Includes method metadata and source-column provenance.

Data-flow contract:

`RAW -> CLEAN -> DERIVED -> OBSERVABLES`

No backward dependency is allowed (for example, OBSERVABLES cannot alter DERIVED or CLEAN).

## 2) Canonical row identity (primary key)

Immutable join key across all point tables:

- `file_id`
- `row_index`

Physical coordinate and validation columns carried with each row:

- `T_K`
- `H_Oe`
- `time_s`

### Why this key is sufficient

- `file_id + row_index` provides deterministic per-file row identity even if repeated sensor values occur.
- `T_K`, `H_Oe`, `time_s` add physical coordinate context for diagnostics and validation checks.
- Joins are machine-stable on `file_id,row_index`; coordinates are for sanity validation and traceability, not join identity.

### Alignment guarantee

- RAW establishes canonical ordering and identity.
- CLEAN and DERIVED must preserve `file_id,row_index`.
- `T_K,H_Oe,time_s` are carried forward as physical coordinate/validation columns for consistency checks.
- Floating-point coordinate values must never be required join keys.

### Debug and traceability

- Any suspicious value can be traced from OBSERVABLES to DERIVED/CLEAN point subsets, then to exact RAW source row via `file_id,row_index`.
- Identity enables reproducible audits and per-row discrepancy reports.

## 3) Schema design summary

The normative schema is provided in `tables/mt_point_tables_schema.csv` with columns:

- `table_name`
- `column_name`
- `type`
- `unit`
- `definition`
- `source`
- `required`

Key design notes:

- every numeric column has a unit (`K`, `Oe`, `s`, `emu`, `emu_per_Oe`, `emu_per_g`, `emu_per_g_per_Oe`, `K_per_s`, or `1`)
- all tables include explicit provenance and identity fields
- nullable physics fields use `required=NO` rather than row dropping

## 4) Alignment rules (critical)

### RAW to CLEAN alignment

- CLEAN is row-preserving with respect to RAW identity.
- `row_index` is preserved from RAW and is never recomputed in CLEAN.
- CLEAN may modify value content (for example structural cleaning outputs) but not row identity.
- Joins must use `file_id,row_index` only; floating coordinates are validation-only.

### CLEAN to DERIVED alignment

- DERIVED is one-row-per-clean-row for pointwise derived quantities.
- `row_index` is preserved.
- If a derived value cannot be computed, row is retained and derived fields are `NaN` plus reason flags.

### Ordering guarantees

Stable sort policy for all point tables:

1. `file_id` ascending
2. `row_index` ascending

Optional validation columns (`time_s`, `T_K`) are not used to reorder canonical rows.

### Missing/invalid rows policy

- no row dropping allowed in RAW, CLEAN, or DERIVED
- invalid/missing values are represented as `NaN` (numeric) or explicit status code (string)
- masking/interpolation decisions are encoded via traceability/status columns

## Time channel contract

- `time_s` is defined as the imported time channel in seconds.
- `time_s` is not assumed to be elapsed/relative time by definition.
- If elapsed or relative time is needed, it must be represented in DERIVED as a separate field such as `time_rel_s`.

## 5) Cleaning traceability contract

`mt_points_clean.csv` must include:

- raw source value (`M_emu_raw`)
- structural cleaned value (`M_emu_clean`)
- optional smoothed analysis/diagnostic channel (`M_emu_smooth`)
- `cleaning_branch`
- `cleaning_reason_code`
- `points_changed_flag`

Channel semantics:

- `M_emu_clean` is the structural cleaned channel and canonical cleaning truth for downstream derivation.
- `M_emu_smooth` is optional analysis/diagnostic smoothing and must not replace raw/clean truth unless a downstream method explicitly declares it in `source_columns`.

Trace rule for any clean value:

1. identify row by `file_id,row_index` in CLEAN
2. read `M_emu_raw`, `M_emu_clean`, `M_emu_smooth`, `points_changed_flag`, `cleaning_reason_code`
3. join to RAW on the same identity to recover full original point context
4. use `cleaning_branch` and reason code to explain policy path

## 6) Derived isolation rules

Derived rules:

- derived variables consume only columns from CLEAN
- no direct RAW use is allowed
- no implicit dependency on external metadata; all required metadata must appear as explicit clean columns

Planned derived variables (initial list):

- `M_over_H_emu_per_Oe` = `M_emu_clean / H_Oe` (guard when `H_Oe=0`)
- `M_norm_emu_per_g` = mass-normalized clean magnetization
- `chi_mass_emu_per_g_per_Oe` = `M_norm_emu_per_g / H_Oe`
- `dM_dT_emu_per_K` = local temperature derivative from clean channel
- `dM_dt_emu_per_s` = local time derivative from clean channel
- `dT_dt_K_per_s` = local temperature rate
- `segment_progress_01` = normalized position in segment, dimensionless
- `segment_direction_sign` = +1 increasing, -1 decreasing, 0 unknown

## 7) Segment definition (ZFC/FCC/FCW ready)

Segmentation columns are explicit in point tables and are not inferred in plotting code.
Segmentation is an annotation/derived-semantic layer and is not part of cleaning transforms.

- `segment_id` : reproducible integer segment label within file
- `segment_type` : one of `increasing`, `decreasing`, `zfc`, `fcc`, `fcw`, `unknown`
- `segment_source` : one of `time_temp_algorithm`, `metadata_label`, `hybrid`

Segmentation source policy:

- default source is algorithmic time/temperature segmentation
- metadata labels may augment classification (for zfc/fcc/fcw) when available
- final segment labels must be reproducible from persisted inputs and policy
- segment columns in `mt_points_clean.csv` are annotations for row-level context and do not imply cleaning logic ownership.

## 8) Units contract

Unit system:

- temperature: `K`
- magnetic field: `Oe`
- time: `s`
- moment: `emu`
- mass: `g`
- rates/slopes: explicit compound units
- dimensionless quantities: unit `1`

Normalization rules:

- mass normalization uses `M_emu_clean / sample_mass_g`
- if mass is unavailable, normalized outputs remain `NaN` and status codes indicate missing mass provenance
- no implicit unit conversions; all converted units must be explicit in column names and definitions

## 9) Observables structure (initial)

`mt_observables.csv` is an aggregation table with explicit provenance columns.
Default dependency is DERIVED. Direct CLEAN-based observables are allowed only as explicit exceptions with full `source_columns` and `aggregation_method` provenance.

Required structure:

- observable identity: `observable_name`, `observable_variant`
- scope: `file_id` (nullable for run-level), `segment_id` (nullable), `segment_type` (nullable)
- definition metadata: `definition`, `source_columns`, `aggregation_method`, `temperature_dependence`
- value payload: `value_numeric`, `value_unit`
- quality/provenance: `quality_flag`, `n_points_used`, `notes`

Examples of initial observables:

- segment mean `M_norm_emu_per_g`
- segment max absolute `dM_dT_emu_per_K`
- file-level median `chi_mass_emu_per_g_per_Oe`
- run-level summary statistics for trust/risk reporting

## 10) Risk analysis summary

Normative risk register is in `tables/mt_point_tables_risks.csv`.

Mandatory risks covered:

- RAW/CLEAN misalignment
- cleaning branch inconsistency
- time-axis nonuniformity propagation
- metadata provenance incompleteness
- segment misclassification

Each risk includes severity and mitigation.

## Design verdict

- point-table hierarchy: defined
- row identity: defined
- alignment and traceability: defined
- derived isolation: defined
- segmentation structure: defined
- units contract: defined
- observables structure: defined
- risk register: defined

Implementation remains intentionally blocked in this stage (`MT_READY_FOR_IMPLEMENTATION=NO`) until schema/design review approval.
