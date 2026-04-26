# Maintenance Triage Log

## Purpose

Record human triage decisions for advisory maintenance findings so review intent is preserved without promoting advisory outputs into durable backlog state.

This log records advisory triage decisions only. It is not the durable backlog and does not mark findings RESOLVED/WONTFIX.

## Current Triage Entries

- Date: `2026_04_25` | Source: `repository_drift_guard` | Issue: `GitHub Issue #17` | Rule: `RS_OUT_001` | Module: `Switching` | Severity: `HIGH` | Decision: `INVESTIGATE_LATER` | Timing: `weekly`
- Date: `2026_04_25` | Source: `repository_drift_guard` | Issue: `GitHub Issue #17` | Rule: `RS_GIT_005` | Module: `multi_module` | Severity: `MEDIUM` | Decision: `DEFER` | Timing: `cleanup_window`
- Date: `2026_04_25` | Source: `repository_drift_guard` | Issue: `GitHub Issue #17` | Rule: `RS_HELPER_003` | Module: `Switching` | Severity: `MEDIUM` | Decision: `DEFER` | Timing: `weekly_or_refactor_window`
- Date: `2026_04_25` | Source: `repository_drift_guard` | Issue: `GitHub Issue #17` | Rule: `RS_LEGACY_004` | Module: `Switching` | Severity: `MEDIUM` | Decision: `WATCH` | Timing: `weekly`
- Date: `2026_04_25` | Source: `repository_drift_guard` | Issue: `GitHub Issue #17` | Rule: `RS_MOD_002` | Module: `Aging` | Severity: `MEDIUM` | Decision: `WATCH` | Timing: `module_canonicalization`

### Issue #18 (Switching Analysis Steward) - ACTION_NOW triaged entries

- Date: `2026_04_25` | Source: `switching_analysis_steward` | Issue: `Issue #18` | Rule: `SAS_OUTPUT_003` | Module: `Switching` | Severity: `HIGH` | Decision: `INVESTIGATE_LATER` | Timing: `weekly`
- Date: `2026_04_25` | Source: `switching_analysis_steward` | Issue: `Issue #18` | Rule: `SAS_SOURCE_009` | Module: `Switching` | Severity: `HIGH` | Decision: `INVESTIGATE_LATER` | Timing: `weekly`
- Date: `2026_04_25` | Source: `switching_analysis_steward` | Issue: `Issue #18` | Rule: `SAS_CROSS_006` | Module: `Switching` | Severity: `MEDIUM` | Decision: `WATCH` | Timing: `module_boundary_review`

## Not Backlog State

- Separate from `tables/system_backlog_registry.csv`.
- Advisory triage only; no lifecycle closure semantics are applied here.
- No finding is marked `RESOLVED` or `WONTFIX` in this log.

## 2026-04-26 Consolidated Maintenance Triage

Consolidated advisory findings from Issues #19-#23 into deduplicated triage rows, merging overlaps with existing Issue #18 triage where the same underlying maintenance risk was already captured. This update records actionable consolidation only rather than replaying each raw finding as a separate row.

### Consolidated Rows Added

- `CONSOLIDATED_SWITCHING_OUTPUT_SOURCE_OF_TRUTH_2026_04_26` (`Issue #18/#19/#21`) - root mirrors, flat fallback paths, and canonical-looking root outputs collapsed into one source-of-truth cleanup track.
- `CONSOLIDATED_SWITCHING_IDENTITY_ROUTE_2026_04_26` (`Issue #18/#21`) - latest-by-mtime and mixed canonical identity routes collapsed into one identity-locator decision track.
- `CONSOLIDATED_AGING_RELAXATION_STATUS_CONTRADICTION_2026_04_26` (`Issue #22`) - Aging/Relaxation canonicalization status contradictions elevated for wording alignment.
- `CONSOLIDATED_SWITCHING_HELPER_DUPLICATION_2026_04_26` (`Issue #23`) - helper-duplication scope narrowed to buildSwitchingMapRounded migration audit only.
- `CONSOLIDATED_RUN_OUTPUT_COVERAGE_LIMITATION_2026_04_26` (`Issue #20`) - run-output audit visibility limitation tracked as watch-only until local run-root truth is published.

### Raw Issues Covered

- `Issue #19` (Repository Drift Guard)
- `Issue #20` (Run Output Audit)
- `Issue #21` (Switching Analysis Steward)
- `Issue #22` (Canonicalization Progress Guard)
- `Issue #23` (Helper Duplication Guard)
- Overlap baseline retained: `Issue #18` (for dedupe anchors only)

Advisory triage only: this section does not mutate backlog lifecycle state and does not close findings.

No code fixes were performed; this update is log-only consolidation within approved maintenance triage scope.

Remediation follow-up (governance wording only): updated `tables/project_workstream_status.csv` Aging/Relaxation canonicalization rows to mark `canonical_code_status=WIP` and explicitly state that workstream progress is not module canonical closure while module status remains `NOT_CANONICAL`.

## Next Review

- Revisit all entries in the next weekly maintenance review cycle.
- Escalate to bounded action proposals only when operational anchors support action timing.
