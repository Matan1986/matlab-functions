# MT Stage 8.5 — Trace / monotonic-leg derivative candidate redesign (planning only)

## Why Stage 8.5 is required

Stage 8.2 file-level derivative candidates sort **all** rows within each `file_id` by **`T_K`**. Stage 8.4R (`ec40520`) showed that, in the validated diagnostic run, **`T_K` sorting interleaves multiple row-order monotonic temperature legs** in every file, while **`mt_points_derived.csv`** offers **no segment fields that split traces** (`segment_id` constant, `segment_type` unknown, no `segment_source`). File-level sorted-`T_K` finite differences can therefore join points that were **not** adjacent along the acquisition timeline, producing **technically gated but non-trace-coherent** diagnostics.

Stage 8.5 defines a **replacement candidate scope**: derivatives computed **inside** acquisition-ordered **monotonic `T_K` legs** only, without implementing MATLAB or changing runners.

---

## Summary of Stage 8.4R blocking verdict

| Flag / verdict | Value |
|----------------|--------|
| `TRACE_MIXING_RISK` | **YES** |
| `SAFE_TO_INTERPRET_STAGE82_DERIVATIVES` | **NO** |
| `STAGE82_DERIVATIVE_SCOPE_STATUS` | **FILE_LEVEL_TECHNICAL_ONLY** |
| Prior `DERIVATIVE_SCOPE_SHOULD_BE` | **file_id_plus_trace_or_segment** |

Interpretation of Stage 8.2 file-level derivative **values** for scientific meaning remains **blocked** until candidates are restated at a scope that **does not stitch across legs**.

---

## Definition of temporary trace unit

Because DERIVED segment columns do not delineate protocols, **temporary trace units** are defined as **row-order monotonic `T_K` legs**:

- **Sort** rows by **`row_index`** within each **`file_id`** (acquisition / storage order).
- **Partition** into contiguous runs where **`T_K`** is **strictly monotonic** (non-decreasing **or** non-increasing), treating near-equal successive temperatures as jitter per the epsilon policy below.
- Assign **`trace_leg_id_candidate`** = **1 … L** within each **`file_id`**, in order of first appearance along **`row_index`**.

**Stable key for outputs:** **`(file_id, trace_leg_id_candidate)`**.

This identifier is **engineering-only**: it labels a **computational leg** derived from acquisition order and temperature slope changes, **not** an instrument vendor segment name or a physical phase label.

---

## Leg construction policy

1. **Ordering:** Within **`file_id`**, process rows sorted by **`row_index`** ascending. **Do not** use a global **`T_K`** sort to define legs or to compute derivatives across the whole file.
2. **Jitter:** Let **`epsilon_T_K`** default to **1e-6 K**. Treat **`abs(diff(T_K)) <= epsilon_T_K`** as **zero slope change** for leg-boundary detection only (carry raw `T_K` into differences for derivative denominators per implementation math rules). Optionally clamp or document column resolution if MPMS export implies a larger floor; **default remains 1e-6 K** unless calibration tables override.
3. **New leg:** When the **sign** of **`T_K[i] - T_K[i-1]`** (after jitter collapse for boundary detection) **changes** from strictly positive trend to strictly negative or vice versa, **close** the previous leg and **increment** **`trace_leg_id_candidate`**.
4. **No cross-leg stitches:** Derivatives **must not** use **`M_emu_clean`** samples from two different **`trace_leg_id_candidate`** values in the same finite-difference stencil.

---

## Leg eligibility gate

Per **`(file_id, trace_leg_id_candidate)`** leg:

| Gate | Rule |
|------|------|
| **Minimum length** | **`N_min >= 5`** finite samples after leg formation. |
| **Inputs** | **`T_K`** and **`M_emu_clean`** finite on every row used for that leg’s derivative vector. |
| **Monotonicity** | **`T_K`** strictly monotonic along **`row_index`** inside the leg after jitter policy (no reversals inside the leg). |
| **Denominator** | Successive **`T_K`** differences used in differences must be **nonzero** (after numerical policy). |
| **Transforms** | **No smoothing.** **No interpolation / regridding.** |

Legs failing any gate produce **no interpretive candidate row** (see outputs): **`quality_flag = BLOCKED`** (or equivalent) **and** a record in a **gate-failure table** analogous to Stage 8.2 DGC failures.

---

## Derivative method (per eligible leg)

- **Order:** Preserve **acquisition leg order** (subset of **`row_index`**).
- **Interior:** **Central finite difference** in **`T_K`** vs **`M_emu_clean`** along that order.
- **Edges:** **One-sided** finite differences at leg ends.
- **Global `T_K`:** **Never** reorder rows across **`trace_leg_id_candidate`** boundaries or merge legs for one derivative series.
- **Peaks:** Continue to expose **abs(dM/dT)** peak and its **`T_K`** location as **candidates** (sign-aware derivative may be retained internally or for diagnostics per implementation, but **primary** summary remains **abs-peak** naming as below).

---

## Output naming plan

Stage 8.2 **file-level** names remain **legacy technical diagnostics** only (see next section). **New** observable names **must** encode **trace-leg** scope:

| Planned name | Role |
|--------------|------|
| `dM_dT_peak_abs_trace_leg_candidate` | Max **abs(dM/dT)** within the leg |
| `T_at_max_abs_dM_dT_trace_leg_candidate` | **`T_K`** at that maximum (coordinate diagnostic only) |
| `dM_dT_quality_fraction_finite_trace_leg` | Fraction of finite recomputed dM/dT samples in leg |
| `dM_dT_quality_min_delta_T_K_trace_leg` | Minimum positive **`abs(delta T_K)`** along leg order |
| `dM_dT_quality_monotonic_T_trace_leg` | Flag that leg-internal **`T_K`** passed strict monotonic gate |

Each emitted row **must** include keys **`file_id`** and **`trace_leg_id_candidate`** (and **`observable_variant`** / notes patterns consistent with repo observables conventions).

---

## Stage 8.2 legacy / file-level status

- Stage 8.2 outputs remain **allowed as pipeline / regression artifacts** with explicit status **FILE_LEVEL_TECHNICAL_ONLY** and **NOT_SAFE_FOR_INTERPRETATION**.
- **Do not delete** Stage 8.2 file-level rows in a future implementation until maintainers agree deprecation timing.
- Preferred migration path: **emit trace-leg rows alongside** file-level rows, with **notes / summary flags** stating trace-leg vs file-level scope and linking to Stage 8.4R audit lineage.

Detail rows: `tables/mt_stage85_stage82_legacy_status_policy.csv`.

---

## Readiness boundary

Until trace-leg candidates are **implemented**, **validated**, and **reviewed**:

- **`FULL_CANONICAL_DATA_PRODUCT`** remains whatever the parent run records (**typically PARTIAL** for diagnostic tracks).
- **`MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE`** = **NO**
- **`MT_READY_FOR_ADVANCED_ANALYSIS`** = **NO**

Trace-leg planning **does not** lift readiness by itself.

---

## Statement

Stage 8.5 redesigns derivative-candidate scope only and does not implement features or make Tc, phase, hysteresis, memory, mechanism, or cross-module claims.

---

## Next allowed step

Stage 8.6 may implement trace-leg scoped derivative candidate outputs in `runs/run_mt_canonical.m`, but **only after this redesign is reviewed**.
