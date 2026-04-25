# Maintenance Publication Health

## Summary

- Date token: **2026_04_26**
- Agent output directory: `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26`
- Overall **ALERT_LEVEL**: **ACTION**
- Rows evaluated: **15**

## Missing Artifacts

- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26\repository_drift_guard_findings.csv` (repository_drift_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26\repository_drift_guard_report.md` (repository_drift_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26\run_output_audit_report.md` (run_output_audit)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26\switching_canonical_boundary_guard_findings.csv` (switching_canonical_boundary_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26\switching_canonical_boundary_guard_report.md` (switching_canonical_boundary_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26\helper_duplication_guard_findings.csv` (helper_duplication_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26\helper_duplication_guard_report.md` (helper_duplication_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26\canonicalization_progress_guard_findings.csv` (canonicalization_progress_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26\canonicalization_progress_guard_report.md` (canonicalization_progress_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_26\run_output_audit_findings.csv` (run_output_audit)
- `C:\Dev\matlab-functions\reports\maintenance\logs\daily_maintenance_2026_04_26.log` (local_daily_maintenance)

## Schema Problems

(none)

## Local Daily Task Status

- Daily log: `C:\Dev\matlab-functions\reports\maintenance\logs\daily_maintenance_2026_04_26.log`
- Governor latest CSV / summary and snapshot coverage outputs checked under `tables` / `reports/maintenance`.

## Agent Publication Status

## Expected Producers For This Date

- Date parsed for schedule: `2026_04_26` (DayOfWeek: `Sunday`)
- Daily expected Codex producers: `switching_canonical_boundary_guard, canonicalization_progress_guard`
- Weekly Sunday Codex producers: `repository_drift_guard, run_output_audit, helper_duplication_guard`
- Weekly Sunday producers required today: **YES**
- Expected for this date: `switching_canonical_boundary_guard, canonicalization_progress_guard, repository_drift_guard, run_output_audit, helper_duplication_guard`

Expected producers evaluated for publication verdict are schedule-aware for this date.

## Final Verdicts

```text
MAINTENANCE_HEALTH_GUARD_COMPLETED = YES
LOCAL_DAILY_OUTPUTS_OK = NO
ALL_EXPECTED_AGENTS_PUBLISHED = NO
SCHEMA_CHECKS_OK = YES
ALERT_LEVEL = ACTION
```
