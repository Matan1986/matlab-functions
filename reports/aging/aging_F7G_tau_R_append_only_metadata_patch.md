# F7G — Aging tau/R append-only semantic metadata patch

**Date:** 2026-04-30  
**Scope:** Aging only. No Switching / Relaxation / MT edits.

## Summary

Introduced `Aging/utils/appendF7GTauRMetadataColumns.m`, which appends **twelve** fixed metadata columns to MATLAB tables **without** removing or renaming legacy numeric columns. Primary tau/R CSV writers now call this helper immediately before `save_run_table`.

**Append-only alias:** `aging_clock_ratio_temperature_scaling.m` adds **`R_age_clock_ratio`** as a duplicate of **`R`** (legacy **`R`** retained).

## Git HEAD

- **`HEAD`:** `0b3cddc00af6caf7997230cafb083eec83f90ae2` (at patch time).

## Git / staging

- **`git diff --cached --name-only`:** empty before and after work (no staged files).
- **Commits/push:** none performed.

## Files edited / added

| Path | Action |
|------|--------|
| `Aging/utils/appendF7GTauRMetadataColumns.m` | **Added** helper |
| `Aging/analysis/aging_timescale_extraction.m` | Patched |
| `Aging/analysis/aging_fm_timescale_analysis.m` | Patched |
| `Aging/analysis/aging_time_rescaling_collapse.m` | Patched |
| `Aging/analysis/aging_clock_ratio_temperature_scaling.m` | Patched (+ `R_age_clock_ratio`) |
| `Aging/analysis/aging_clock_ratio_analysis.m` | Patched |
| `Aging/analysis/aging_fm_using_dip_clock.m` | Patched |
| `Aging/validation/run_aging_F7G_metadata_contract_check.m` | **Added** contract check |

## Metadata columns (all writers)

1. `writer_family_id`  
2. `tau_or_R_flag`  
3. `tau_domain`  
4. `tau_input_observable_identities`  
5. `tau_input_observable_family`  
6. `source_writer_script`  
7. `source_artifact_basename`  
8. `source_artifact_path`  
9. `canonical_status`  
10. `model_use_allowed`  
11. `semantic_status`  
12. `lineage_status`  

## Writer family IDs used

| ID | Where |
|----|--------|
| `WF_TAU_DIP_CURVEFIT` | `tau_vs_Tp.csv`; `fm_collapse_using_dip_tau_metrics.csv` (collapse metrics table; `tau_or_R_flag` = `NONE`) |
| `WF_TAU_FM_CURVEFIT` | `tau_FM_vs_Tp.csv` |
| `WF_TAU_RESCALING_OPTIMIZER` | `tau_rescaling_estimates.csv` |
| `WF_CLOCK_RATIO_R_AGE` | `clock_ratio_data.csv`, fit metrics CSV, `table_clock_ratio.csv`, `correlation_summary.csv`, `source_run_manifest.csv` |

**Not patched in this change:** replay runners exporting `tau_proxy_seconds` (`WF_REPLAY_DIAGNOSTIC` reserved); pipeline pause-field CSV paths (`WF_PIPELINE_CLOCKS`) — see inventory CSV **PENDING** rows.

## Validation

- **MATLAB:** `run_aging_F7G_metadata_contract_check` executed via `-batch`; asserted PASS (`F7G_OK`).
- **Full pipeline runners** (e.g. full `aging_timescale_extraction`) not re-executed here; contract check covers schema only.

## Deliverables

- `tables/aging/aging_F7G_tau_R_metadata_patch_inventory.csv`
- `tables/aging/aging_F7G_tau_R_metadata_patch_validation.csv`
- `tables/aging/aging_F7G_tau_R_metadata_patch_status.csv`
- This report

## Rules confirmation

- **No physics / formula edits:** only table column append and one duplicate numeric column (`R_age_clock_ratio`).
- **Legacy `tau_effective_seconds`:** unchanged.
- **No breaking renames** of existing columns.
