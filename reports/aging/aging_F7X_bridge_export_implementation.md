# Aging F7X — Bridge export implementation report

## Scope

Implementation of the **F7W bridge/export contract** as **neutral, lineage-preserving tables** from **existing artifacts only**. No decomposition rerun, no fitting, no tau extraction, no clock-ratio execution, no physics interpretation.

**Anchor:** F7W charter commit `4e7bba8`.

## Sources used

| Source | Status |
|--------|--------|
| `results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv` | **Present** — five-column style consolidation: `Tp`, `tw`, `Dip_depth`, `FM_abs`, `source_run`. **30** data rows (8 distinct `Tp`, 4 distinct `tw`). |
| `results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset_sidecar.csv` | **Missing** on disk — disclosed in `aging_F7X_bridge_source_inventory.csv`. |
| Track A (`AFM_like`, `FM_like`, `Dip_area_selected` / stage5–6 vectors) for the same run | **Not located** in this implementation pass — **no fabricated rows**. Indexed streams `STREAM_C_AFM_LIKE_A`, `STREAM_C_FM_LIKE_A`, `STREAM_C_DIP_AREA_FIT` carry **n_rows_available = 0** and explicit blockers. |

## Outputs written

| Artifact | Description |
|----------|-------------|
| `tables/aging/aging_F7X_bridge_component_long.csv` | **60** rows: each source row × (`C_DIP_DEPTH_B`, `C_FM_ABS_B`). `branch_family = TRACK_B_CONSOLIDATION`, `fit_direct_class = CONSOL_EXPORT`, `grid_type = TW_CURVE_PER_TP`. Empty `value` where `FM_abs` is `NaN` in source (**8** cells), `metadata_status = DEGRADED`, `blocked_reason = MISSING_NUMERIC_VALUE_IN_SOURCE`. |
| `tables/aging/aging_F7X_bridge_component_index.csv` | One row per **materialized or disclosed-missing** component stream (including Track A / stage4 placeholders with zero rows). |
| `tables/aging/aging_F7X_bridge_pairing_policy.csv` | Machine-readable pairings echoing **F7V** `pairing_id` semantics; **no** substitution into shared columns. |
| `tables/aging/aging_F7X_bridge_source_inventory.csv` | Source existence, columns detected, row counts, `used_in_bridge` flags. |
| `tables/aging/aging_F7X_bridge_validation_results.csv` | Gate pass/fail with evidence (see `F7X_SIGN_CONVENTIONS_POPULATED = PARTIAL` rationale). |
| `tables/aging/aging_F7X_bridge_status.csv` | Verdict keys for downstream automation. |

## Pairings allowed / blocked

- **FORBIDDEN / NOT_COMPARABLE:** `P_DIP_SUMMARY`, `P_FM_SUMMARY` — freeze-aligned; Track A streams absent from input artifact.
- **BLOCKED (missing fit stream):** `P_DIP_AREA_VS_DEPTH`, `P_EXTREMA_VS_DIRECT` — requires additional exports, not invented here.
- **DIAGNOSTIC_ONLY:** `P_TRACKA_EXPORT_VS_CONSOL` — side-by-side policy only; not ratio input.
- **Not applicable from consolidation-only input:** `P_STAGE4_MODES` — `pauseRuns` / mode-compare not read in this F7X scope.

## Why no tau or ratio

Tau extraction and **R_age** / multipath ratio execution are **explicitly out of scope** for F7X per task charter. The long table includes **eligibility flags only** (`eligible_for_ratio_robustness = NO`).

## Implementation outcome

**Succeeded for Track B consolidation slice:** real numeric rows exported with full metadata columns. **Track A** and **sidecar** paths are **disclosed as missing**, not fabricated.

## Next safe step

Per `aging_F7X_bridge_status.csv` → **`TRACK_A_TAU_CHARTER_OR_DIRECT_TAU_CHARTER`**: extend inputs (materialize Track A streams and/or `pauseRuns`-backed stage4 fields) under a separate chartered task; then refresh bridge tables and pairing gates before multipath ratio work.

## Implementation method

PowerShell `Import-Csv` / file write (Python unavailable in this environment). **No MATLAB** run. **No** new `.m` script added to the repo in this task.
