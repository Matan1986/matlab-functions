# F7C structured export sidecar patch report

- Writer files inspected: Aging/analysis/aging_structured_results_export.m
- Writer files modified: Aging/analysis/aging_structured_results_export.m
- Output artifacts covered by sidecars: structured export CSV outputs and smoke sample artifact
- Numeric structured export outputs unchanged: YES (patch limited to lineage sidecar writes)
- Plain Dip_depth remains unsafe unless resolved: YES
- Validation command type: sidecar-only smoke script (full writer not run)
- Validation result: SUCCESS
- Sidecar CSV: C:\Dev\matlab-functions\tables\aging\aging_F7C_structured_export_sample_observables_lineage.csv
- Sidecar JSON: C:\Dev\matlab-functions\tables\aging\aging_F7C_structured_export_sample_observables_lineage.json
- Sidecar manifest: C:\Dev\matlab-functions\tables\aging\aging_F7C_structured_export_sidecar_manifest.csv
- Sidecar issues: C:\Dev\matlab-functions\tables\aging\aging_F7C_structured_export_sidecar_issues.csv
- Limitation: smoke validates helper integration path only; full writer run not executed in F7C.
