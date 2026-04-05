# Execution Cleanup Results

**Execution Date**: 2026-03-30 21:46:52

## Summary

| Category | Count |
| --- | --- |
| Canonical Artifacts Protected | 51 |
| Stale Artifacts Archived | 21 |
| Invalid Artifacts Archived | 48 |
| Partial Artifacts Isolated | 22 |
| Move/Mark Errors | 0 |

**TOTAL PROCESSED**: 142

## Actions Taken

### Canonical Artifacts (PROTECTED)
- Repository state maintained
- 51 artifacts verified in active state
- No modifications applied

### Invalid Artifacts (ARCHIVED)
- Destination: archive/invalid/
- Count Archived: 48
- Reason: Contamination markers, definition errors, IO consistency warnings
- Examples:
  - aging_measurement_definition_audit.csv (DEFINITION_CONTAMINATION)
  - aging_* derived artifacts (all contaminated)
  - io_consistency_*.md reports (NO outputs detected)

### Stale Artifacts (ARCHIVED)
- Destination: archive/stale/
- Count Archived: 21
- Reason: Non-canonical variants, pre-enforcement analysis
- Examples:
  - kappa1_phi1_local_v2* (failed local variants)
  - alpha_observable_* (legacy observable search)
  - representation_bridge_v2* (non-canonical bridge)

### Partial Artifacts (ISOLATED)
- Destination: Active directory (MARKED with .PARTIAL_DO_NOT_USE)
- Count Isolated: 22
- Action: Created marker files to prevent accidental use
- Examples:
  - kappa1_projection_test (EXECUTION_VALID=NO)
  - switching_migration_pilot* (timeout/no completion)
  - estimator_design_* (FAILURE)

## Conflicts Resolved

### Root vs Run-Level Conflicts
- **Status**: RESOLVED
- **Rule Applied**: RUN_LEVEL = SOURCE_OF_TRUTH
- **Action**: All run-level artifacts prioritized; root-level variants archived
- **Details**: Stale artifacts are primarily run-level variants with timestamps

## Final State

### Repository Structure After Cleanup

matlab-functions/
  archive/
    invalid/     (48 files)
    stale/       (21 files)
  tables/
  reports/
  [other active files]

### Active Artifacts
- **Canonical Only**: 51 core artifacts
- **Partial (Marked)**: 22 artifacts marked .PARTIAL_DO_NOT_USE
- **Result**: CLEAN repository with canonical + partial only

## Cleanup Status

- **INVALID_ARCHIVED**: YES (48 files)
- **STALE_ARCHIVED**: YES (21 files)
- **PARTIAL_ISOLATED**: YES (22 files marked)
- **CANONICAL_PROTECTED**: YES (51 files verified)
- **CLEANUP_SUCCESSFUL**: YES

---

## Detailed Log

See cleanup_execution_log.csv for artifact-by-artifact details.

**Execution completed**: 2026-03-30 21:46:52
Repository is now clean and canonical-ready.
