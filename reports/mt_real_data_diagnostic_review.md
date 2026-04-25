# MT real-data diagnostic review (Stage 1.3)

This document records the outcome of a **diagnostic-only** MT canonical run on real MPMS `.DAT` data. It does not certify production canonical release or full provenance closure.

## Run identity

| Field | Value |
|-------|-------|
| Run directory | `C:\Dev\matlab-functions\results\mt\runs\run_2026_04_25_011031_mt_real_data_diagnostic` |
| Run label | `mt_real_data_diagnostic` |
| Input directory | `L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M1 Out of plane MPMS\MT DC ZFC FCC FCW` |
| Wrapper | `.\tools\run_matlab_safe.bat "C:\Dev\matlab-functions\runs\run_mt_canonical.m"` |
| Wrapper exit code | `0` |
| Local config | `local\mt_canonical_config.m` (repo-local; not committed) |

## Scale and import

- **DAT files found:** 11
- **Imported OK / failed:** 11 / 0
- **System / parser (inventory):** MPMS / `importOneFile_MT_MPMS` for all files

## Runner-reported flags (from `mt_canonical_run_summary.csv` and report)

- `CONFIG_LOADED=YES`
- `MT_INPUT_FOUND=YES`
- `MT_IMPORT_STRICTNESS_OK=YES`
- `MT_CLEANING_AUDIT_WRITTEN=YES`
- `MT_SEGMENT_TABLE_WRITTEN=YES`
- `MT_TIME_AXIS_WARNINGS_PRESENT=YES` (all 11 files flagged in raw summary / inventory)
- `POINT_TABLES_WRITTEN=NO`
- `FULL_CANONICAL_DATA_PRODUCT=NO`
- `MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE=NO`
- `DIAGNOSTIC_ONLY=YES`

## Cleaning policy (from `mt_cleaning_audit.csv`)

Two branches appear, consistent with default `field_threshold` behavior:

| Branch | Files (1-based) | Field range (from filenames / audit) |
|--------|-----------------|--------------------------------------|
| `low_field_bypass` | 1-5 | 500 Oe through 10 kOe |
| `cleaned` | 6-11 | 20 kOe through 70 kOe |

All audited rows showed full non-NaN counts through smooth stage with zero masked counts in the diagnostic audit table for this run.

## Segmentation

- **Segment rows written:** 33 (increasing and decreasing segments across files; see `mt_segments.csv` in the run directory).

## Time axis warnings

Every file triggered the diagnostic time regularity check (`time_regular_warning` true). This indicates irregular or statistically variable sampling intervals relative to the runner threshold (not necessarily a failed import). **Follow-up:** review MPMS time base, logging gaps, and whether absolute epoch-style timestamps drive the coefficient-of-variance test before advanced analysis.

## Metadata and provenance (Stage 1.3 interpretation)

Filename-derived fields (`field_from_name_oe`, `mass_mg`), `system_detected`, `parser_selected`, and full `file_path` were present for all imports. **Explicit independent provenance closure** (e.g. sidecar manifest, measurement log cross-check, lab notebook linkage) is **not** claimed complete for this stage.

Therefore **`MT_METADATA_PROVENANCE_OK=PARTIAL`** (see verdicts table and status file).

## Verdict summary (canonical for this document)

See `tables/mt_real_data_diagnostic_verdicts.csv` and `status/mt_real_data_diagnostic_status.txt` for machine-readable copies.

**Not asserted:** `MT_READY_FOR_ADVANCED_ANALYSIS=YES`, `MT_METADATA_PROVENANCE_OK=YES`, `MT_FULL_CANONICAL_DATA_PRODUCT=YES`.

## Recommended next steps (no MATLAB in this task)

1. Resolve or document time-axis irregularity warnings with instrument/export context.
2. If advancing beyond diagnostic: define provenance artifacts and gates before raising `MT_METADATA_PROVENANCE_OK` beyond PARTIAL.
3. Keep advanced MT analysis **off** until point-level canonical tables and agreed gates exist.

## Artifact references (inside run directory)

- `execution_status.csv`
- `tables/mt_canonical_run_summary.csv`
- `tables/mt_file_inventory.csv`
- `tables/mt_raw_summary.csv`
- `tables/mt_cleaning_audit.csv`
- `tables/mt_segments.csv`
- `reports/mt_canonical_run_report.md`
