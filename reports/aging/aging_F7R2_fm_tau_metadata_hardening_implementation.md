# Aging F7R2 — FM tau metadata hardening (implementation)

## Scope

This deliverable implements **F7R** lineage-aware hardening for **`tau_FM_vs_Tp.csv`** emitted by `aging_fm_timescale_analysis`. It is **not** a physics, ratio, R_age, or clock-ratio task.

## Code changes

### `Aging/analysis/aging_fm_timescale_analysis.m`

1. **F7G metadata** (`appendF7GTauRMetadataColumns`): `lineage_status` is set to **`LINEAGE_METADATA_HARDENED_PENDING_F7S`** so downstream readers see hardened CSV rows while global model use remains blocked pending **F7S**.

2. **`loadFailedDipClockMetrics(metricsPath, cfg)`**
   - Records **`metrics_path_resolved`** on the returned struct.
   - **`failed.run_id`**: from **`cfg.failedDipClockRunId`** when nonempty (**`CFG_FAILED_DIP_CLOCK_RUN_ID`**), else derived from the path token **`run_YYYY_MM_DD_HHMMSS_...`** (**`DERIVED_FROM_METRICS_PATH_TOKEN`**), else **`RUN_ID_UNKNOWN_FROM_PATH_NOT_MODEL_SAFE`**.
   - No silent model-safe claim when the token is missing.

3. **`appendFmTauLineageHardeningColumns`** (after F7G columns, before `save_run_table`):
   - **Branch / path provenance (row-level):** `branch_id`, `datasetPath`, `dipTauPath`, `failedDipClockMetricsPath`.
   - **`branch_id`**: `cfg.branch_id` when nonempty; otherwise **`UNKNOWN_BRANCH_REQUIRE_EXPLICIT_CFG`** (conservative; blocks treating outputs as branch-resolved).
   - **`source_run_id`**: aligned with legacy **`source_run`** (dataset row provenance).
   - **Global ratio block:** `ratio_use_allowed` = **`NO`** on every row.
   - **FM convention (explicit, conservative):** `FM_abs_convention`, `FM_input_column`, `FM_signed_source_column`, `absolute_transform_applied_in_writer` = **`NO`** (no silent `abs()` in this writer).
   - **Failed-clock reference:** `failed_dip_clock_run_id_report_ref`, `failed_dip_clock_run_id_source` mirror the resolved failed-metrics lineage.
   - **Row use:** `row_model_use_allowed`, `row_ratio_use_allowed`, `row_exclusion_reason` per F7R-style rules (`has_fm==0`, bad tau, fragile sparse points, else global policy pending F7S).

Conservative global flags from F7G remain: **`model_use_allowed`** = **`NO_UNLESS_LINEAGE_RESOLVED`**, **`canonical_status`** = **`non_canonical_pending_lineage`**.

### Smoke harness

- **`Aging/diagnostics/run_F7R2_fm_metadata_smoke.m`** — minimal **`aging_fm_timescale_analysis`** call with explicit **`branch_id`** and F7O-style input paths; writes **`execution_status.csv`** to the analysis run directory.

## Smoke verification (schema only)

| Item | Value |
|------|--------|
| Command | `cmd /c "tools\run_matlab_safe.bat \"C:\Dev\matlab-functions\Aging\diagnostics\run_F7R2_fm_metadata_smoke.m\""` (from repo root; PowerShell: `Set-Location` then `cmd /c ...`) |
| Run root | `C:\Dev\matlab-functions\results\aging\runs\run_2026_05_03_095534_F7R2_FM_METADATA_SMOKE_30ROW` |
| Hardened CSV | `...\tables\tau_FM_vs_Tp.csv` |
| `execution_status.csv` | `EXECUTION_STATUS=SUCCESS`, `N_T=8` (rows in `tau_FM_vs_Tp.csv`) |

Verified: hardened columns present; paths populated; **`has_fm=0`** rows blocked at row level; global **`ratio_use_allowed`** = NO; global model use remains blocked; no R_age / clock-ratio artifacts in this run directory beyond normal FM analysis outputs (see tables for explicit checks).

## Column naming note

The plan listed **`source_run_id`**. The writer keeps legacy **`source_run`** and adds **`source_run_id`** as the same lineage string for clarity in consumers that search for `*_id`.

## Out of scope (unchanged)

- Switching, Relaxation, MT modules — **not modified**.
- R_age / clock-ratio writers — **not invoked** by this smoke.

## Next safe step

**F7S — Aging module post-repair readiness audit** (per `aging_F7R2_status.csv`).
