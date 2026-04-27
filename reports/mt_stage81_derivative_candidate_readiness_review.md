# MT Stage 8.1 — Derivative Candidate Implementation Readiness Review

## Purpose

This document closes **pre-implementation decisions** for derivative/transition **candidate** observables based on Stage 8.0 (`00c3aff`) and repository policy boundaries. No code changes are part of Stage 8.1.

**Stage 8.1 is planning/review only and does not implement derivative candidates or make physics claims.**

---

## Review of Stage 8.0 open decisions

Stage 8.0 established scope, exclusions, gate families (DG00–DG11), failure modes, and integration intent into `mt_observables.csv`. Items left explicitly open for numerical or product choices are closed below for **first implementation** only.

---

## Final policy table for first implementation

| Topic | Frozen decision |
|-------|-----------------|
| Peak policy | **Primary:** `dM_dT_peak_abs_candidate` (abs peak). **Signed** positive/negative peaks, if ever emitted, are **diagnostic-only** and secondary to abs peak. |
| Minimum points | **Per-file `N_min = 5`.** **Per-segment `N_min = 5`** when segment path exists; first implementation **does not** enable per-segment outputs. Below threshold: **BLOCKED**. |
| Source / reuse | **Default: recompute** dM/dT from `M_emu_clean` and `T_K` inside derivative-candidate logic. **Reuse** of existing `dM_dT_emu_per_K` only if **declared matching provenance** and gate equivalence is proven; otherwise recompute. |
| Derivative method | Sort by `T_K` within scope. **Central finite difference** on interior points; **one-sided** at edges. **No** smoothing by default. **No** interpolation/regridding. **Duplicate / non-monotonic `T_K`:** no derivative across disorder without an explicit **split/block** policy implementation (until then: **BLOCKED** for that scope). |
| Width / midpoint | **Deferred.** First code step emits **peak, location, and quality metrics only.** |
| Segment scope | **File-level only** for first implementation. **Per-segment derivative candidates blocked** until segment trust is validated under a separate gate. |
| Gate failure behavior | Always emit **quality** observable rows where applicable. Record derivative-specific failures in **gate failure table** and/or observable `notes`. **Numeric** peak/location rows: **`quality_flag=BLOCKED`** with **`NaN`** `value_numeric` when blocked; do not silently omit failure. |
| Readiness | Does **not** unlock production release, advanced analysis, Tc/phase claims, or cross-module claims. |

Machine-readable decisions: `tables/mt_stage81_derivative_candidate_decisions.csv`.

---

## Explicit first implementation scope

First implementation should add **only** these `mt_observables.csv` rows (plus optional clearly labeled diagnostics):

| Observable name (first implementation) | Role |
|----------------------------------------|------|
| `dM_dT_peak_abs_candidate` | Maximum abs(dM/dT) per file scope |
| `T_at_max_abs_dM_dT_candidate` | T_K at argmax abs(dM/dT) per file scope |
| `dM_dT_quality_fraction_finite` | Fraction of points with finite dM/dT after method application |
| `dM_dT_quality_min_delta_T_K` | Minimum positive delta T_K along sorted curve in scope |
| `dM_dT_quality_monotonic_T` | Boolean or coded flag: T_K strictly increasing after sort/split policy |

Optional diagnostic rows (e.g. signed peak pairs) **only** if `observable_name`/`definition`/`notes` state **diagnostic-only** and **not** primary science output.

Full scope table: `tables/mt_stage81_first_implementation_scope.csv`.

---

## Explicit blocked / deferred items

Deferred until after peak/location/quality validation or separate gates:

- `transition_width_candidate`, `transition_midpoint_candidate`
- Per-segment derivative candidates and per-segment quality keyed by `segment_id`
- Any reuse of stored `dM_dT_emu_per_K` without provenance match
- Interpolation, regridding, default smoothing

List: `tables/mt_stage81_blocked_items.csv`.

---

## Readiness boundary (Stage 8.1)

Stage 8.1 **does not** unlock:

- `MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE`
- `MT_READY_FOR_ADVANCED_ANALYSIS`
- Tc, transition temperature, phase, or critical-behavior claims
- Cross-module analysis or mechanism conclusions

`FULL_CANONICAL_DATA_PRODUCT` remains **PARTIAL**.

---

## Next allowed step

**Stage 8.2 may implement file-level derivative peak/location/quality candidate outputs in `runs/run_mt_canonical.m`, but only within the scope frozen here.**

---

## Artifacts

| File | Purpose |
|------|---------|
| `tables/mt_stage81_derivative_candidate_decisions.csv` | Closed decisions |
| `tables/mt_stage81_first_implementation_scope.csv` | First implementation inclusion matrix |
| `tables/mt_stage81_blocked_items.csv` | Blocked/deferred items |
| `status/mt_stage81_derivative_candidate_readiness_status.txt` | Stage 8.1 flags |
