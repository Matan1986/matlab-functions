# Run Snapshot Coverage Guard

## Summary

- Registry rows read: **523**
- Run ID column used: **run_id**
- Module column used: **experiment**
- Snapshot linkage columns: **snapshot_has_entry, snapshot_source_run_path, snapshot_runpack_path, snapshot_analysis_ids, snapshot_report_ids**
- Rows with linkage present (COVERED): **10**
- Rows missing linkage (MISSING): **513**
- Rows UNKNOWN_SCHEMA: **0**
- Coverage (linkage present / total): **1.91%**
- `RUN_SNAPSHOT_COVERAGE_HEALTH` classification: **WEAK**

## Inputs

| Path | Role |
|------|------|
| `C:\Dev\matlab-functions\analysis\knowledge\run_registry.csv` | Run registry (read-only) |
| `C:\Dev\matlab-functions\snapshot_scientific_v3\30_runs_evidence\run_index.json` | Optional scientific snapshot run index |
| `C:\Dev\matlab-functions\snapshot_scientific_v3\00_entrypoints\consistency_check.json` | Optional consistency check artifact |

## Coverage Metrics

| Metric | Value |
|--------|-------|
| Total registry rows | 523 |
| Linkage columns detected | 5 |
| COVERED | 10 |
| MISSING | 513 |
| UNKNOWN_SCHEMA | 0 |
| Coverage % | 1.91% |

## Missing Coverage Sample

Up to 20 `run_id` values with `MISSING` status:

- `run_2026_03_09_014130_MG119_3sec`
- `run_2026_03_09_124648_geometry_visualization`
- `run_2026_03_09_130918_geometry_visualization`
- `run_2026_03_09_132236_switching_alignment_audit`
- `run_2026_03_09_140848_geometry_visualization`
- `run_2026_03_09_141041_switching_alignment_audit`
- `run_2026_03_09_141328_geometry_visualization`
- `run_2026_03_09_145524_switching_alignment_audit`
- `run_2026_03_09_205312_derivative_smoothing`
- `run_2026_03_09_205525_helper_adoption`
- `run_2026_03_09_212439_repository_compliance_audit`
- `run_2026_03_09_213137_repository_duplication_survey`
- `run_2026_03_09_221205_switching_helper_refactor`
- `run_2026_03_09_222702_alignment_audit`
- `run_2026_03_09_223621_mechanism_survey`
- `run_2026_03_09_224017_mechanism_followup`
- `run_2026_03_09_224359_mode23_analysis`
- `run_2026_03_09_224738_observable_basis_test`
- `run_2026_03_09_225131_second_coordinate_duel`
- `run_2026_03_09_225513_second_observable_search`

## Interpretation

This guard is **detection-only**. It does not modify the registry, snapshots, or knowledge exports.

Coverage 1.91% (10 of 523 rows with linkage). Registry newer than run_index.json (UTC); snapshot index may be stale relative to registry.

## Final Verdicts

```text
RUN_REGISTRY_READABLE = YES
SNAPSHOT_LINKAGE_COLUMNS_FOUND = YES
SNAPSHOT_INDEX_EXISTS = YES
CONSISTENCY_CHECK_EXISTS = YES
RUN_SNAPSHOT_COVERAGE_HEALTH = WEAK
GUARD_COMPLETED = YES
```
