# MT Stage 8.4R — Trace / segment scope risk audit (derivative candidates)

## Why this audit was triggered

Stage 8.2 emits **file-level** derivative candidates after **sorting all derived rows within each `file_id` by `T_K`**. MPMS experiments often concatenate **multiple temperature protocols or traces** inside one source file. If more than one trace exists per `file_id`, a global `T_K` sort can **interleave** points that were never adjacent in acquisition order, reshaping finite-difference derivatives (including peaks in abs(dM/dT)) in ways that are **numerically defined but not trace-coherent**.

Repository interpretation policy holds **`SAFE_TO_INTERPRET_STAGE82_DERIVATIVES=NO`** until trace-scope risk is evaluated. This audit answers whether file-level sorting can mix distinct traces or acquisition legs using **only** the validated diagnostic run cited below.

## Evidence scope (Stage 8.4 descriptive review)

Any previously generated **MT Stage 8.4 descriptive review** artifacts were **deleted locally** and **must not be cited** as validation evidence. This Stage **8.4R** document stands on the run tables listed below.

## Source run

All quantitative checks reference:

`C:\Dev\matlab-functions\results\mt\runs\run_2026_04_27_223342_mt_real_data_diagnostic`

Primary evidence table: `tables/mt_points_derived.csv` (6719 rows). Supporting context: `tables/mt_observables.csv`, `tables/mt_derivative_candidate_validation.csv`, `tables/mt_canonical_run_summary.csv`, `tables/mt_point_tables_validation_summary.csv`.

---

## Per-file trace / segment summary

For every `file_id` **1–11**:

| Observation | Result |
|-------------|--------|
| Unique `segment_id` in DERIVED | **1** (`segment_id = 0` only) |
| Unique `segment_type` | **1** (`unknown` only) |
| Unique `segment_source` | **Not applicable** — **no `segment_source` column** appears in `mt_points_derived.csv` (`n_unique_segment_source = 0` for counting purposes). |
| Rows per `segment_id` | All rows belong to the single annotated segment bucket. |

**Row / time order**

- **`time_s` on consecutive `row_index` pairs:** strictly increasing for every file (no decreases); **`n_time_monotonic_blocks = 1`** under consecutive-row inspection.
- **Pause / gap heuristic:** consecutive `time_s` gaps are modest versus their local median (max/median \(\approx\) **5×** on spot checks); **`time_reset_or_gap_flag = NO`** for abrupt timeline resets between adjacent rows.

**Temperature along acquisition order**

- **`T_direction_change_flag = YES`** for every file: row-order `T_K` reverses slope multiple times (**5–9** monotonic legs depending on file).
- **`preliminary_trace_count_estimate`** (monotonic `T_K` legs in row order): **5–9** — used only as a **non-claiming** proxy for “how many distinct sweep legs appear before sorting,” not as a protocol name.

Detailed columns: `tables/mt_stage84R_trace_scope_by_file.csv`.

---

## Trace-mixing risk summary

### Segment annotation

Segment columns in **`mt_points_derived`** do **not** partition the table into multiple IDs or protocol labels. This yields **`INSUFFICIENT_TRACE_METADATA`** for distinguishing traces **from DERIVED alone**, independent of what other tables may contain elsewhere in the pipeline.

### Sorting-by-T_K vs row-order monotonic legs

For each file, rows were scanned in **`row_index`** order and split into **maximal monotonic `T_K` legs** (direction reversals increment a leg counter). The table was then sorted by **`T_K` (tie-break `row_index`)** as Stage 8.2 does for derivative preparation.

**Result:** for **all eleven files**, **consecutive rows in `T_K`-sorted order include pairs drawn from different row-order monotonic legs** (`sorting_by_T_K_interleaves_T_blocks = YES`). Equivalently, **`T_K`-sorted row order \(\neq\) acquisition row order** for every file in this run.

So **file-level `T_K` sorting can stitch across temperature-sweep legs** that were separated in time order.

### Duplicate temperature across legs

An exact-value scan (**G17 string key per `T_K`**) found **no** temperature value appearing in **more than one** monotonic-leg label within the same file (`duplicate_T_across_segments_or_blocks = NO`). Interleaving risk here is **ordering / adjacency**, not duplicated bucketed temperatures across legs.

### Segment-column interleaving

Because **`segment_id` never changes within a file**, the literal column **`sorting_by_T_K_interleaves_segments = NO`** — there is nothing to interleave **by segment_id**. The structural risk is captured under **`sorting_by_T_K_interleaves_T_blocks`**.

---

## Global derivative scope verdict

| Topic | Verdict |
|-------|---------|
| Technical Stage 8.2 pipeline | **`TECHNICALLY_VALID_FILE_LEVEL`** — `mt_derivative_candidate_validation.csv` reports `derivative_scope_status=OK` for all files (finite differences, monotonic `T_K` after sort). |
| Interpretation safety | **`NOT_SAFE_FOR_INTERPRETATION`** at file level given trace-leg interleaving. |
| Required engineering follow-up | **`NEEDS_TRACE_LEVEL_RECOMPUTE`** (or explicit trace/segment scope before interpretive use). |

Aggregated key/value rows: `tables/mt_stage84R_derivative_scope_verdicts.csv`.

**Global flags (see `status/mt_stage84R_trace_scope_risk_status.txt`):**

- **`TRACE_MIXING_RISK=YES`**
- **`SAFE_TO_INTERPRET_STAGE82_DERIVATIVES=NO`**
- **`STAGE82_DERIVATIVE_SCOPE_STATUS=FILE_LEVEL_TECHNICAL_ONLY`**
- **`DERIVATIVE_SCOPE_SHOULD_BE=file_id_plus_trace_or_segment`**

Point-table gates (including G09/G10) remain **PASS** in this run; they **do not** remove the trace-ordering concern above for **sorted-T_K** derivative construction.

---

## Interpretation boundary

This audit classifies **data alignment risk** for sorted-`T_K` derivatives. It does **not** assert failure of MPMS measurement, cleaning gates, or Stage 8.2 arithmetic — only that **file-level sorted curves may combine distinct acquisition legs**.

---

## Next allowed step

Because **`TRACE_MIXING_RISK=YES`**:

**Stage 8.5 must redesign derivative candidates at trace/segment scope before value interpretation.**

---

## Statement (required)

Stage 8.4R audits derivative scope safety only and does not make Tc, phase, mechanism, hysteresis, memory, or cross-module claims.
