# MT Stage 5.0 — Minimal observables design and claims boundary

## Purpose and scope

This document defines the **first minimal MT observable layer** as a **design-only contract**. It does **not** compute observables, does **not** assert new physics, and does **not** change pipeline code. It binds what may be aggregated later, from which tables and columns, under which quality gates, and what language is permitted when interpreting outputs.

**Validated reference context (evidence only, not re-run here):** canonical real-data diagnostic run `results/mt/runs/run_2026_04_26_125110_mt_real_data_diagnostic`, with point tables present and hardened gates **G01–G11** passing on that trajectory, while full product and advanced-analysis readiness remain explicitly negative per run summary policy.

## Source policy (normative)

| Rule | Statement |
|------|-----------|
| Default source layer | **`mt_points_derived.csv` (DERIVED)** is the default and required source for all row-level inputs to Stage 5.0 observables. |
| CLEAN direct use | **Explicit exception only.** No Stage 5.0 minimal observable is registered as CLEAN-direct; the exception channel remains **empty** until a named observable is added to `tables/mt_minimal_observables_registry.csv` with `source_table=mt_points_clean.csv` and a documented audit rationale. |
| Row identity | All aggregations MUST respect immutable row identity (`file_id`, `row_index`) and parity assumptions already enforced by **G03–G04**. |
| Observables table | Run-scoped `mt_observables.csv` (when implemented) MUST echo the same `source_table`, `source_columns`, and `aggregation_method` strings declared here (see **G11** alignment). |

## Observable bundles (conceptual)

### 1) Basic per-file / per-segment summaries

Counts and simple extrema over temperature, field, cleaned moment carried on the derived table, and field-scaled moment where valid. These support **coverage**, **protocol sanity**, and **internal QA** only.

### 2) Transition-shape diagnostics (candidate only)

Any quantity derived from **`dM_dT_emu_per_K`** or from slopes of **`M_emu_clean`** versus **`T_K`** is a **candidate diagnostic**, not a phase boundary. Implementation MUST wait on a published **derivative policy** (finite differences, windowing, smoothing scope, and whether **`T_K`** or **`time_s` / `time_rel_s`** is the independent variable for a given diagnostic). **Time-axis caution:** where sample ordering is not uniform in temperature, **`dM_dt`** or time-ordered finite differences are **not** interchangeable with **`dM_dT`** without an explicit remap policy.

### 3) ZFC / FCC / FCW comparison placeholders

Cross-segment comparisons depend on **`segment_id`**, **`segment_type`**, and overlap of temperature support across **ZFC**, **FCC**, and **FCW** labels when present. Stage 5.0 registers **placeholders** only: allowed outputs are **labeled candidates** with overlap metrics; **no** thermodynamic path or history claim is authorized.

### 4) Normalization-dependent observables

**`M_norm_emu_per_g`** and **`chi_mass_emu_per_g_per_Oe`** exist as derived columns in schema but are **blocked for interpretable use** unless **`sample_mass_g`** is present with verifiable provenance on the same rows (non-NaN, consistent per sample, and aligned with inventory metadata when available). **`chi_mass`** additionally requires a **nonzero-field guard**.

## Quality and readiness (normative summary)

- **Point-table gates G01–G11** MUST pass before any Stage 5.0 observable is published as non-`BLOCKED`.
- **Nonzero field:** **`M_over_H_emu_per_Oe`**, **`chi_mass_emu_per_g_per_Oe`**, and any **`M/H` ratio** summary MUST be computed only on rows with **`abs(H_Oe) > H_ABS_GT_EPS_Oe`** (threshold fixed at implementation time and recorded in run metadata).
- **Mass provenance:** mass-normalized observables remain **`BLOCKED_PENDING_PROVENANCE`** until mass rules pass.
- **Segment annotation quality:** ZFC/FCC/FCW placeholders require non-unknown `segment_type`, trusted `segment_source`, and overlap fraction gates (see registry and quality-gate table).
- **Derivative policy:** slope and transition observables are **`CANDIDATE_BLOCKED_PENDING_POLICY`** until a derivative policy artifact is versioned and gated.
- **Minimum points:** each aggregation scope (file, segment, comparison window) MUST enforce **`N_points >= N_min`**; otherwise emit `INSUFFICIENT_POINTS` quality class and do not treat the numeric as stable.

## Claims boundary (global)

| Claim class | Stage 5.0 |
|-------------|-----------|
| Phase transition | **FORBIDDEN** |
| Critical behavior / scaling exponents | **FORBIDDEN** |
| **`T_c` or transition temperature** | **FORBIDDEN** |
| Cross-module (Switching / Relaxation / Aging) inference | **FORBIDDEN** |
| Production release suitability | **NOT AUTHORIZED** by this stage |
| Advanced analysis unlock | **NOT AUTHORIZED**; every observable in the minimal registry carries a readiness level that **does not** satisfy advanced-analysis promotion rules |

## Readiness impact

Completing Stage 5.0 **documentation** sets **`MT_MINIMAL_OBSERVABLES_DEFINED=YES`** and clarifies implementation prerequisites. It **does not** set **`MT_READY_FOR_OBSERVABLE_IMPLEMENTATION`** or **`MT_READY_FOR_ADVANCED_ANALYSIS`** to YES. Implementation work remains blocked on derivative policy versioning, mass provenance closure, and observables-row contract wiring (`mt_observables.csv` producer), none of which are asserted complete here.

## Artifact map

| Artifact | Role |
|----------|------|
| `tables/mt_minimal_observables_registry.csv` | Authoritative per-observable contract rows |
| `tables/mt_minimal_observables_claims_boundary.csv` | Global interpretability and forbidden-claim rules |
| `tables/mt_minimal_observables_quality_gates.csv` | Gate and policy IDs mapped to observables |
| `status/mt_minimal_observables_design_status.txt` | Machine-readable Stage 5.0 flags |

## References (existing repo tables)

- `tables/mt_point_tables_schema.csv` — column-level definitions for RAW / CLEAN / DERIVED / observables.
- `tables/mt_point_tables_failure_modes.csv` — **G01–G11** definitions.
- `tables/mt_point_tables_producer_steps.csv` — producer ordering (**S08–S09** observables default vs CLEAN exception).
- `tables/mt_time_axis_policy_fields.csv` — time-axis diagnostics fields influencing derivative caution.
- `tables/mt_variable_definition.csv` — conceptual variable roles (M_clean, M_over_H, segmentation labels).
