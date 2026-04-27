# MT Stage 8.0 — Derivative / Transition Candidate Implementation Plan

## Scope statement

Stage 8.0 defines **planning and design only** for derivative and transition **candidate** observables. No MATLAB execution, no code changes, and no new computed outputs are part of this stage.

**Stage 8.0 is planning only and does not implement derivative candidates or make physics claims.**

Upstream context:

- Stage 7.2 selected primary path: `DERIVATIVE_TRANSITION_CANDIDATE_IMPLEMENTATION` (commit `79391f7`).
- Existing Stage 5.1 derivative policy boundary (normative for implementation work when it begins): default independent variable `T_K`; default source `M_emu_clean`; `M_emu_smooth` exception-only with policy; `dM/dt` diagnostic-only; cross-segment derivatives forbidden; no interpolation without separate policy; transition outputs candidate-only; Tc and phase claims forbidden.

---

## 1. Implementation scope and exclusions

### In scope (future implementation, after this plan)

- Derivative-like quantities derived from **`M_emu_clean`** versus **`T_K`** on **point tables**, **per `file_id`**, using **local finite difference or robust local slope** (method TBD in code but constrained here).
- **Candidate-only** transition-shaped summaries (peaks, locations, widths, midpoints) with explicit non-claim labeling and gate failures recorded.
- Integration into **`mt_observables.csv`** with full provenance and `quality_flag` semantics.

### Out of scope / exclusions

- No implementation in Stage 8.0 (this document is design-only).
- No interpolation or regridding of `T_K` or `M_emu_clean`.
- No default smoothing; **`M_emu_smooth`** not used unless an explicit exception policy is activated (Stage 5.1 alignment).
- No cross-segment derivatives or stitching across segments.
- No mass-normalized observables; no segment/ZFC/FCC/FCW comparative science outputs (segment use only if segment pipeline is trustworthy and gates pass).
- No Tc, transition temperature, phase, or critical-behavior **claims**.
- No cross-module analysis or mechanism testing.

---

## 2. Required input tables and columns

### Primary source table

- Canonical point table(s) already produced by the MT pipeline (e.g. derived points as used for basic summaries), containing at minimum:

| Column | Role |
|--------|------|
| `file_id` | Scope for per-file derivatives |
| `row_index` | Stable row identity within file |
| `T_K` | Independent variable for dM/dT |
| `H_Oe` | Context; not used as default derivative axis |
| `M_emu_clean` | **Default** source for dM/dT |
| `segment_id`, `segment_type`, `segment_source` | Segment scoping **only if** segment gates certify trustworthy use |

### Pre-existing derivative columns (policy note)

Point tables may already contain `dM_dT_emu_per_K`, `dM_dt_emu_per_s`, `dT_dt_K_per_s`. Stage 8.0 implementation should either:

- **Reuse** stored `dM_dT_emu_per_K` **only if** it matches the declared method and passes gates, or
- **Recompute** dM/dT from `M_emu_clean` and `T_K` per this plan so method and provenance are single-sourced.

The plan requires **declared method** and **no hidden reuse** without provenance.

---

## 3. Candidate outputs to implement later

All names below are **candidates**, not physical transition parameters.

| Concept | Planned output role |
|--------|---------------------|
| dM/dT peak | `dM_dT_peak` candidate — maximum of abs(dM/dT) or signed peak per policy |
| T at max abs(dM/dT) | `T_at_max_abs_dM_dT` candidate — T_K at which abs(dM/dT) is maximum |
| Transition width | `transition_width_candidate` — width from a defined threshold or inflection proxy on dM/dT curve (policy TBD) |
| Transition midpoint | `transition_midpoint_candidate` — T_K at center of width definition (policy TBD) |
| Derivative quality | Per-file (and per-segment-if-enabled) metrics: fraction finite, spacing stats, monotonicity flag, gate pass/fail |

Detailed machine-readable rows: `tables/mt_stage80_derivative_candidate_outputs.csv`.

---

## 4. Recommended derivative method

| Parameter | Choice |
|-----------|--------|
| Default source | **`M_emu_clean`** |
| Independent variable | **`T_K`** |
| Method | **Local finite difference** or **robust local slope** (e.g. windowed slope with fixed small odd window); **declared in provenance** |
| Smoothing | **Default NO** (`M_emu_smooth` exception-only per Stage 5.1) |
| Interpolation / regridding | **NO** |
| Scope | **Per `file_id`**; **per valid segment only** if and only if segment implementation is certified by gates |
| Cross-segment | **Forbidden** — no derivative across segment boundaries |

Ordering: sort by `T_K` within each scope before differencing; if `T_K` is not strictly monotonic, apply a **split/block policy** (explicit blocks with no cross-block derivative).

---

## 5. Required gates

Gates must align with Stage 5.1 and Stage 8.0 readiness. Summary (full list in `tables/mt_stage80_derivative_candidate_gates.csv`):

- Point-table gates (e.g. G01–G11) **PASS** for the run.
- Only **allowed** observable inputs for this feature family (no forbidden groups).
- **Minimum points** per `file_id` / scope (N ≥ policy threshold, TBD numerically at implementation).
- **Finite** `T_K` and `M_emu_clean` where derivatives are computed.
- **`T_K` monotonic** within scope or **split/block** applied; no derivative across gaps.
- **Nonzero, non-degenerate** `T_K` spacing (no duplicate T at same logical step without policy).
- **No cross-segment derivative** if multiple segments exist in one file.
- **Derivative method declared** and recorded in observables provenance.
- **No interpolation** — blocked if regridding requested.
- **Candidate-only labeling** on all transition-shaped outputs.
- **Forbidden claims blocked** — observables and reports must not emit Tc/phase/critical language.

---

## 6. Output integration plan

### Where outputs appear

- New rows in **`mt_observables.csv`** (same schema family as existing observables):

  - `observable_name` — e.g. `dM_dT_candidate`, `transition_width_candidate`, etc.
  - `observable_variant` — e.g. `file_level_peak`, `file_level_T_at_peak`, `segment_level_*` if enabled.
  - `source_table` — e.g. `mt_points_derived`
  - `source_columns` — explicit list (e.g. `M_emu_clean,T_K` plus method tag)
  - `definition` — human-readable, includes **candidate-only** and **no Tc/phase claim**
  - `aggregation_method` — e.g. `max_abs`, `argmax_T`, `width_from_threshold`
  - `value_numeric`, `value_unit`, `n_points_used`, **`quality_flag`**, **`notes`**

### Required provenance fields

- Method name and version (finite-difference stencil or robust slope parameters).
- Scope: `file_id` and optionally `segment_id` if segment path is enabled.
- Policy references: Stage 5.1 boundary; Stage 8.0 plan id.
- Explicit statement: **candidate-only**, **no interpolation**.

### Quality flag behavior

- `OK` — all gates passed for that scope.
- `BLOCKED` or policy-specific codes — one or more gates failed; numeric values may be absent or NaN with notes.
- Never map quality to “transition occurred” language.

### Gate failure recording

- Failures logged in dedicated gate failure table(s) (pattern: `mt_point_tables_gate_failures.csv` style) and/or per-observable `notes`.
- Derivative-specific failures should be traceable without re-running MATLAB (for auditors).

---

## 7. Readiness policy

After future implementation:

- May unlock **derivative-candidate observables** in **`mt_observables.csv`** only when gates pass.
- Must **not** set `MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE=YES`.
- Must **not** set `MT_READY_FOR_ADVANCED_ANALYSIS=YES` solely from derivative candidates.
- Must **not** enable Tc/transition/phase claims; `FULL_CANONICAL_DATA_PRODUCT` remains **PARTIAL** until broader product definition is satisfied.

---

## 8. Explicit Stage 8.0 statement

**Stage 8.0 is planning only and does not implement derivative candidates or make physics claims.**

---

## Artifacts

| File | Purpose |
|------|---------|
| `tables/mt_stage80_derivative_candidate_outputs.csv` | Planned output definitions |
| `tables/mt_stage80_derivative_candidate_gates.csv` | Gate definitions |
| `tables/mt_stage80_derivative_candidate_failure_modes.csv` | Failure modes and safe behavior |
| `status/mt_stage80_derivative_candidate_plan_status.txt` | Stage 8.0 flags |
