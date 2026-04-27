# MT Stage 8.3 — File-level derivative candidate observable validation

## Validation source run

All checks below reference artifacts under:

`C:\Dev\matlab-functions\results\mt\runs\run_2026_04_27_223342_mt_real_data_diagnostic`

### Superseded run (do not use)

The earlier diagnostic run `run_2026_04_27_223133_mt_real_data_diagnostic` is **superseded** and **must not be used** for Stage 8.3 validation evidence. Stage 8.3 documents validation against `run_2026_04_27_223342_mt_real_data_diagnostic` only.

---

## Execution summary

| Artifact | Observation |
|----------|----------------|
| `execution_status.csv` | `EXECUTION_STATUS=SUCCESS`, `INPUT_FOUND=YES`, `N_T=11`, `MAIN_RESULT_SUMMARY` documents diagnostic artifacts with time-axis warnings |

---

## Stage 8.2 status summary (`tables/mt_canonical_run_summary.csv`)

| Metric | Value |
|--------|--------|
| MT_STAGE82_DERIVATIVE_CANDIDATES_IMPLEMENTED | YES |
| MT_STAGE82_FILE_LEVEL_ONLY | YES |
| MT_STAGE82_SEGMENT_LEVEL_IMPLEMENTED | NO |
| MT_STAGE82_WIDTH_MIDPOINT_IMPLEMENTED | NO |
| MT_STAGE82_RECOMPUTE_DERIVATIVE_DEFAULT | YES |
| MT_STAGE82_METHOD | CENTRAL_FINITE_DIFFERENCE_WITH_EDGE_ONE_SIDED |
| MT_STAGE82_INTERPOLATION_USED | NO |
| MT_STAGE82_SMOOTHING_USED | NO |
| MT_STAGE82_TC_CLAIMS_ALLOWED | NO |
| MT_STAGE82_PHASE_CLAIMS_ALLOWED | NO |
| MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE | NO |
| MT_READY_FOR_ADVANCED_ANALYSIS | NO |

---

## Observable row count summary (`tables/mt_observables.csv`)

Existing diagnostic basic-summary families (e.g. `row_count`, `T_K_summary`, `H_Oe_summary`, `M_emu_clean_summary`, `M_over_H_emu_per_Oe_summary`) remain present across all 11 files (spot-checked; row layout unchanged from prior diagnostic structure).

New Stage 8.2 derivative candidate observable names — expected **11** rows each (one per input file):

| Observable name | Expected | Observed |
|-----------------|----------|----------|
| dM_dT_peak_abs_candidate | 11 | 11 |
| T_at_max_abs_dM_dT_candidate | 11 | 11 |
| dM_dT_quality_fraction_finite | 11 | 11 |
| dM_dT_quality_min_delta_T_K | 11 | 11 |
| dM_dT_quality_monotonic_T | 11 | 11 |

---

## Derivative candidate validation summary (`tables/mt_derivative_candidate_validation.csv`)

| Check | Result |
|-------|--------|
| File scopes (data rows) | 11 |
| All `derivative_scope_status` | OK |
| All `strictly_monotonic_T_K` | 1 |
| All `dM_dT_fraction_finite` | 1 |
| All `block_reason` | empty |

---

## Gate failure summary

| Artifact | Rows |
|----------|------|
| `tables/mt_derivative_candidate_gate_failures.csv` | Header only (no failure rows) |
| `tables/mt_point_tables_gate_failures.csv` | Header only (no failure rows) |

### Point-table gates (`tables/mt_point_tables_validation_summary.csv`)

G01–G11 all **PASS**.

---

## Forbidden output summary

| Item | Evidence |
|------|----------|
| `transition_width_candidate` | Not present as an `observable_name` in `mt_observables.csv` |
| `transition_midpoint_candidate` | Not present |
| Segment-level derivative candidate observables | No Stage 8.2 candidate rows with non–file-level scope in this run |
| Affirmative Tc / phase-transition / critical-temperature identifiers in `observable_name` | None observed |

Notes fields for Stage 8.2 candidates use defensive wording (e.g. “not Tc claim”, “not a transition claim”) consistent with Stage 8.2 policy flags; this validation does not interpret physical meaning.

---

## Readiness boundary (`tables/mt_canonical_run_summary.csv`, `tables/mt_basic_summary_visualization_status.csv`)

| Metric | Value |
|--------|--------|
| FULL_CANONICAL_DATA_PRODUCT | PARTIAL |
| MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE | NO |
| MT_READY_FOR_ADVANCED_ANALYSIS | NO |

Production canonical release and advanced analysis remain **not** asserted for this diagnostic stage.

---

## Statement

Stage 8.3 documents validation only and does not implement new features or make physics claims.

---

## Next allowed step

Stage 8.4 may review candidate derivative values descriptively, still without Tc/phase/mechanism claims, or Stage 8.4 may design derivative visualization tables without figures.
