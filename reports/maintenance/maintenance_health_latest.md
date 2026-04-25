# Maintenance Publication Health

## Summary

- Date token: **2026_04_25**
- Agent output directory: `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_25`
- Overall **ALERT_LEVEL**: **ACTION**
- Rows evaluated: **17**

## Missing Artifacts

- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_25\repository_drift_guard_findings.csv` (repository_drift_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_25\repository_drift_guard_report.md` (repository_drift_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_25\run_output_audit_report.md` (run_output_audit)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_25\switching_canonical_boundary_guard_findings.csv` (switching_canonical_boundary_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_25\switching_canonical_boundary_guard_report.md` (switching_canonical_boundary_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_25\helper_duplication_guard_findings.csv` (helper_duplication_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_25\helper_duplication_guard_report.md` (helper_duplication_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_25\canonicalization_progress_guard_findings.csv` (canonicalization_progress_guard)
- `C:\Dev\matlab-functions\reports\maintenance\agent_outputs\2026_04_25\canonicalization_progress_guard_report.md` (canonicalization_progress_guard)
- `C:\Dev\matlab-functions\reports\maintenance\module_stewards\2026_04_25\switching_analysis_steward_findings.csv` (switching_analysis_steward)
- `C:\Dev\matlab-functions\reports\maintenance\module_stewards\2026_04_25\switching_analysis_steward_report.md` (switching_analysis_steward)

## Schema Problems

(none)

## Local Daily Task Status

- Daily log: `C:\Dev\matlab-functions\reports\maintenance\logs\daily_maintenance_2026_04_25.log`
- Governor latest CSV / summary and snapshot coverage outputs checked under `tables` / `reports/maintenance`.

## Agent Publication Status

## Expected Producers For This Date

- Date parsed for schedule: `2026_04_25` (DayOfWeek: `Saturday`)
- Daily expected Codex producers: `switching_canonical_boundary_guard, canonicalization_progress_guard`
- Weekly Sunday Codex producers: `repository_drift_guard, run_output_audit, helper_duplication_guard`
- Weekly Sunday producers required today: **NO**
- Expected for this date: `switching_canonical_boundary_guard, canonicalization_progress_guard`
- Module steward directory checked: `C:\Dev\matlab-functions\reports\maintenance\module_stewards\2026_04_25`

Expected producers evaluated for publication verdict are schedule-aware for this date.

## Module Steward Publication Status

- Producer: `switching_analysis_steward`
- Expected path:
  - `C:\Dev\matlab-functions\reports\maintenance\module_stewards\2026_04_25\switching_analysis_steward_findings.csv`
  - `C:\Dev\matlab-functions\reports\maintenance\module_stewards\2026_04_25\switching_analysis_steward_report.md`
- Missing steward outputs are currently classified as **WATCH** during stabilization.

## Final Verdicts

```text
MAINTENANCE_HEALTH_GUARD_COMPLETED = YES
LOCAL_DAILY_OUTPUTS_OK = YES
ALL_EXPECTED_AGENTS_PUBLISHED = NO
SCHEMA_CHECKS_OK = YES
ALERT_LEVEL = ACTION
```
